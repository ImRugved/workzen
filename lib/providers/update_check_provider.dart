import 'dart:async';

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';
import '../utils/logger.dart';

/// Outcome of a check or install, for the screen to show a banner.
enum UpdateOutcome { updateAvailable, upToDate, installed, error }

class UpdateResult {
  final UpdateOutcome outcome;
  final String? message;

  const UpdateResult(this.outcome, [this.message]);
}

/// State of the software update screen (Shorebird code push): versions,
/// check / download progress and the last check time. Scoped to the screen.
class UpdateCheckProvider with ChangeNotifier {
  final ShorebirdUpdater _updater = ShorebirdUpdater();

  bool _isChecking = false;
  bool _isDownloading = false;
  bool _isUpdateAvailable = false;
  double _downloadProgress = 0.0;
  String _currentVersion = '';
  String _latestVersion = '';
  final String _updateChannel = 'stable';
  String _lastChecked = 'Never';
  int? _currentPatchNumber;
  bool _disposed = false;

  bool get isChecking => _isChecking;
  bool get isDownloading => _isDownloading;
  bool get isUpdateAvailable => _isUpdateAvailable;
  double get downloadProgress => _downloadProgress;
  String get currentVersion => _currentVersion;
  String get latestVersion => _latestVersion;
  String get updateChannel => _updateChannel;
  String get lastChecked => _lastChecked;
  int? get currentPatchNumber => _currentPatchNumber;

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
      final currentPatch = await _updater.readCurrentPatch();

      _currentVersion = '${packageInfo.version} (${packageInfo.buildNumber})';
      _currentPatchNumber = currentPatch?.number;
      _notify();
    } catch (e) {
      logDebug('Error loading app info: $e');
    }
  }

  /// Returns null when a check is already running.
  Future<UpdateResult?> checkForUpdates() async {
    if (_isChecking) return null;

    UpdateResult result;
    try {
      _isChecking = true;
      _isUpdateAvailable = false;
      _notify();

      final status = await _updater.checkForUpdate();
      if (status == UpdateStatus.outdated) {
        _isUpdateAvailable = true;
        _latestVersion = 'New version available';
        result = const UpdateResult(UpdateOutcome.updateAvailable);
      } else {
        result = const UpdateResult(UpdateOutcome.upToDate);
      }

      final now = DateTime.now();
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
      progressTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
        if (_downloadProgress < 0.95) {
          _downloadProgress += 0.01;
          _notify();
        } else {
          timer.cancel();
        }
      });

      await updateFuture;
      _downloadProgress = 1.0;
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
}
