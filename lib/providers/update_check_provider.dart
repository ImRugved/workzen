import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:restart_app/restart_app.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';
import '../utils/logger.dart';

/// Outcome of a check or install, for the screen to show a banner.
enum UpdateOutcome {
  updateAvailable,
  upToDate,
  installed,
  restartRequired,
  unavailable,
  error,
}

class UpdateResult {
  final UpdateOutcome outcome;
  final String? message;

  const UpdateResult(this.outcome, [this.message]);
}

/// What happened when the user asked to restart the app.
enum RestartOutcome {
  /// The app is restarting itself.
  restarting,

  /// This platform cannot restart an app by itself (iOS): ask the user to close
  /// it and open it again.
  manualRequired,
  failed,
}

/// Software updates (Shorebird code push) for the whole app: versions, checks,
/// the download and the restart that applies it. One instance is shared by the
/// Software Update screen and the update banner on both dashboards (see
/// main.dart), so a download started in one place shows in the other.
///
/// Shorebird works only in release builds made with `shorebird release`; in a
/// debug build [isUpdaterAvailable] is false and nothing is offered.
class UpdateCheckProvider with ChangeNotifier {
  final ShorebirdUpdater _updater = ShorebirdUpdater();

  bool _isChecking = false;
  bool _isDownloading = false;
  bool _isUpdateAvailable = false;
  // A patch is downloaded and waits for the app to be restarted
  bool _isRestartRequired = false;
  double _downloadProgress = 0.0;
  String _currentVersion = '';
  String _latestVersion = '';
  final String _updateChannel = 'stable';
  String _lastChecked = 'Never';
  DateTime? _lastCheckedAt;
  int? _currentPatchNumber;
  bool _disposed = false;

  bool get isChecking => _isChecking;
  bool get isDownloading => _isDownloading;
  bool get isUpdateAvailable => _isUpdateAvailable;
  bool get isRestartRequired => _isRestartRequired;
  double get downloadProgress => _downloadProgress;
  String get currentVersion => _currentVersion;
  String get latestVersion => _latestVersion;
  String get updateChannel => _updateChannel;
  String get lastChecked => _lastChecked;
  int? get currentPatchNumber => _currentPatchNumber;

  /// False in debug builds and on a build that was not made by Shorebird.
  bool get isUpdaterAvailable => _updater.isAvailable;

  /// Android can restart itself; iOS asks the user to close and reopen.
  bool get canRestartAutomatically => Platform.isAndroid;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> loadAppInfo() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentPatch = isUpdaterAvailable
          ? await _updater.readCurrentPatch()
          : null;

      _currentVersion = '${packageInfo.version} (${packageInfo.buildNumber})';
      _currentPatchNumber = currentPatch?.number;
      _notify();
    } catch (e) {
      logDebug('Error loading app info: $e');
    }
  }

  /// Quiet check for the dashboards: at most once every [minGap], and nothing
  /// is shown for "up to date" or errors (the banner appears only when there is
  /// something to do). Returns nothing; the banner listens to the provider.
  Future<void> autoCheck({
    Duration minGap = const Duration(minutes: 30),
  }) async {
    if (!isUpdaterAvailable || _isChecking || _isDownloading) return;
    final last = _lastCheckedAt;
    if (last != null && DateTime.now().difference(last) < minGap) return;
    await checkForUpdates();
  }

  /// Returns null when a check is already running.
  Future<UpdateResult?> checkForUpdates() async {
    if (_isChecking) return null;

    if (!isUpdaterAvailable) {
      return const UpdateResult(
        UpdateOutcome.unavailable,
        'Updates work only in the released app, not in a debug build.',
      );
    }

    UpdateResult result;
    try {
      _isChecking = true;
      _notify();

      final status = await _updater.checkForUpdate();
      switch (status) {
        case UpdateStatus.outdated:
          _isUpdateAvailable = true;
          _isRestartRequired = false;
          _latestVersion = 'New version available';
          result = const UpdateResult(UpdateOutcome.updateAvailable);
        case UpdateStatus.restartRequired:
          // Already downloaded earlier (maybe by the automatic update at launch)
          _isUpdateAvailable = false;
          _isRestartRequired = true;
          result = const UpdateResult(UpdateOutcome.restartRequired);
        case UpdateStatus.upToDate:
          _isUpdateAvailable = false;
          result = const UpdateResult(UpdateOutcome.upToDate);
        case UpdateStatus.unavailable:
          _isUpdateAvailable = false;
          result = const UpdateResult(
            UpdateOutcome.unavailable,
            'Updates are not available in this build.',
          );
      }

      final now = DateTime.now();
      _lastCheckedAt = now;
      _lastChecked = '${now.hour}:${now.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      logDebug('Error checking for update: $e');
      result = UpdateResult(
        UpdateOutcome.error,
        'Failed to check for updates: $e',
      );
    } finally {
      _isChecking = false;
      _notify();
    }
    return result;
  }

  /// Returns null when a download is already running.
  Future<UpdateResult?> downloadAndInstall() async {
    if (_isDownloading) return null;

    UpdateResult result;
    Timer? progressTimer;
    try {
      _isDownloading = true;
      _downloadProgress = 0.0;
      _notify();

      final updateFuture = _updater.update();

      // The updater has no progress callback, so the bar is simulated up to 95%
      progressTimer = Timer.periodic(const Duration(milliseconds: 100), (
        timer,
      ) {
        if (_downloadProgress < 0.95) {
          _downloadProgress += 0.01;
          _notify();
        } else {
          timer.cancel();
        }
      });

      await updateFuture;
      _downloadProgress = 1.0;
      // Installed: the new code runs the next time the app starts
      _isUpdateAvailable = false;
      _isRestartRequired = true;
      result = const UpdateResult(UpdateOutcome.installed);
    } on Exception catch (e) {
      logDebug('Error downloading update: $e');
      result = UpdateResult(
        UpdateOutcome.error,
        'Failed to download update: $e',
      );
    } finally {
      progressTimer?.cancel();
      _isDownloading = false;
      _notify();
    }
    return result;
  }

  /// Restarts the app so the downloaded update starts running. Android does it
  /// by itself (a full restart: the old process is ended, which is what lets
  /// the new code load). iOS has no way to restart an app, so the caller tells
  /// the user to close it from the app switcher and open it again.
  Future<RestartOutcome> restartApp() async {
    if (!canRestartAutomatically) return RestartOutcome.manualRequired;

    try {
      final result = await Restart.restartApp(forceKill: true);
      if (!result.success) {
        logDebug('Restart failed: ${result.code} ${result.message}');
        return RestartOutcome.failed;
      }
      return RestartOutcome.restarting;
    } catch (e) {
      logDebug('Error restarting the app: $e');
      return RestartOutcome.failed;
    }
  }
}
