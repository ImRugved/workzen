import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';
import 'package:package_info_plus/package_info_plus.dart';

class UpdateCheckScreen extends StatefulWidget {
  const UpdateCheckScreen({super.key});

  @override
  State<UpdateCheckScreen> createState() => _UpdateCheckScreenState();
}

class _UpdateCheckScreenState extends State<UpdateCheckScreen> {
  final ShorebirdUpdater _shorebirdUpdater = ShorebirdUpdater();
  bool _isCheckingForUpdates = false;
  bool _isDownloadingUpdate = false;
  bool _isUpdateAvailable = false;
  double _downloadProgress = 0.0;
  String _currentVersion = '';
  String _latestVersion = '';
  String _updateChannel = 'stable';
  String _lastChecked = 'Never';
  int? _currentPatchNumber;
  ScaffoldMessengerState? _scaffoldMessenger;

  @override
  void initState() {
    super.initState();
    _loadAppInfo();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Store reference to ScaffoldMessenger for safe access in dispose
    _scaffoldMessenger = ScaffoldMessenger.of(context);
  }

  @override
  void dispose() {
    // Use stored reference instead of accessing context
    _scaffoldMessenger?.hideCurrentMaterialBanner();
    super.dispose();
  }

  Future<void> _loadAppInfo() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentPatch = await _shorebirdUpdater.readCurrentPatch();

      setState(() {
        _currentVersion = "${packageInfo.version} (${packageInfo.buildNumber})";
        _currentPatchNumber = currentPatch?.number;
      });

      // Check for updates automatically on screen load
      _checkForUpdates();
    } catch (e) {
      debugPrint('Error loading app info: $e');
    }
  }

  Future<void> _checkForUpdates() async {
    if (_isCheckingForUpdates) return;
    try {
      setState(() {
        _isCheckingForUpdates = true;
        _isUpdateAvailable = false;
      });
      // Check whether a new update is available.
      final status = await _shorebirdUpdater.checkForUpdate();
      if (status == UpdateStatus.outdated) {
        setState(() {
          _isUpdateAvailable = true;
          _latestVersion = 'New version available';
        });
        _showUpdateAvailableBanner();
      } else {
        _showNoUpdateAvailableBanner();
      }
      // Update last checked timestamp
      final now = DateTime.now();
      setState(() {
        _lastChecked = '${now.hour}:${now.minute.toString().padLeft(2, '0')}';
      });
    } catch (e) {
      debugPrint('Error checking for update: $e');
      _showErrorBanner('Failed to check for updates: $e');
    } finally {
      if (mounted) {
        setState(() => _isCheckingForUpdates = false);
      }
    }
  }

  Future<void> _downloadAndInstallUpdate() async {
    if (_isDownloadingUpdate) return;

    try {
      setState(() => _isDownloadingUpdate = true);

      // Create a progress updater function
      void updateProgress(int current, int total) {
        if (mounted && total > 0) {
          setState(() {
            _downloadProgress = current / total;
          });
        }
      }

      // Perform the update with manual progress tracking
      setState(() => _downloadProgress = 0.0);

      // Using a timer to simulate progress since we don't have direct progress callback
      // In a real implementation, you would need to implement this differently
      final updateFuture = _shorebirdUpdater.update();

      // Start a timer to simulate progress updates
      const progressUpdateInterval = Duration(milliseconds: 100);
      final progressTimer = Timer.periodic(progressUpdateInterval, (timer) {
        if (_downloadProgress < 0.95) {
          setState(() {
            _downloadProgress += 0.01;
          });
        } else {
          timer.cancel();
        }
      });

      // Wait for the update to complete
      await updateFuture;

      // Cancel the timer if it's still active
      progressTimer.cancel();

      // Set progress to 100% when complete
      setState(() {
        _downloadProgress = 1.0;
      });

      _showInstallationSuccessBanner();
    } on Exception catch (e) {
      debugPrint('Error downloading update: $e');
      _showErrorBanner('Failed to download update: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isDownloadingUpdate = false;
        });
      }
    }
  }

  void _showNoUpdateAvailableBanner() {
    ScaffoldMessenger.of(context)
      ..hideCurrentMaterialBanner()
      ..showMaterialBanner(
        MaterialBanner(
          backgroundColor: Colors.green[100],
          content: const Text(
            'Your app is up to date!',
            style: TextStyle(color: Colors.green),
          ),
          leading: const Icon(Icons.check_circle, color: Colors.green),
          actions: [
            TextButton(
              onPressed: () =>
                  ScaffoldMessenger.of(context).hideCurrentMaterialBanner(),
              child: const Text('DISMISS'),
            ),
          ],
        ),
      );
  }

  void _showUpdateAvailableBanner() {
    ScaffoldMessenger.of(context)
      ..hideCurrentMaterialBanner()
      ..showMaterialBanner(
        MaterialBanner(
          backgroundColor: Colors.blue[100],
          content: Text(
            'Update available: $_latestVersion',
            style: const TextStyle(color: Colors.blue),
          ),
          leading: const Icon(Icons.system_update, color: Colors.blue),
          actions: [
            TextButton(
              onPressed: () =>
                  ScaffoldMessenger.of(context).hideCurrentMaterialBanner(),
              child: const Text('LATER'),
            ),
            TextButton(
              onPressed: _downloadAndInstallUpdate,
              child: const Text('UPDATE NOW'),
            ),
          ],
        ),
      );
  }

  void _showInstallationSuccessBanner() {
    ScaffoldMessenger.of(context)
      ..hideCurrentMaterialBanner()
      ..showMaterialBanner(
        MaterialBanner(
          backgroundColor: Colors.green[100],
          content: const Text(
            'Update installed! Restart app to apply changes.',
            style: TextStyle(color: Colors.green),
          ),
          leading: const Icon(Icons.check_circle, color: Colors.green),
          actions: [
            TextButton(
              onPressed: () =>
                  ScaffoldMessenger.of(context).hideCurrentMaterialBanner(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
  }

  void _showErrorBanner(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentMaterialBanner()
      ..showMaterialBanner(
        MaterialBanner(
          backgroundColor: Colors.red[100],
          content: Text(
            message,
            style: const TextStyle(color: Colors.red),
          ),
          leading: const Icon(Icons.error, color: Colors.red),
          actions: [
            TextButton(
              onPressed: () =>
                  ScaffoldMessenger.of(context).hideCurrentMaterialBanner(),
              child: const Text('DISMISS'),
            ),
          ],
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: theme.colorScheme.primary,
        title: const Text('Software Update'),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Update status card
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _isUpdateAvailable
                                ? Colors.blue.withOpacity(0.2)
                                : Colors.green.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            _isUpdateAvailable
                                ? Icons.system_update_alt
                                : Icons.check_circle_outline,
                            size: 28,
                            color:
                                _isUpdateAvailable ? Colors.blue : Colors.green,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _isUpdateAvailable
                                    ? 'Update Available'
                                    : 'App is Up to Date',
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: _isUpdateAvailable
                                      ? Colors.blue
                                      : Colors.green,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _isUpdateAvailable
                                    ? 'A new version is ready to install'
                                    : 'You have the latest version installed',
                                style: theme.textTheme.bodyMedium,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (_isUpdateAvailable && _isDownloadingUpdate) ...[
                      const SizedBox(height: 20),
                      const Text('Downloading update...'),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: _downloadProgress,
                        backgroundColor: Colors.grey[200],
                        valueColor: AlwaysStoppedAnimation<Color>(
                            theme.colorScheme.primary),
                      ),
                      const SizedBox(height: 4),
                      Text('${(_downloadProgress * 100).toInt()}%',
                          style: theme.textTheme.bodySmall),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Version information
            Text(
              'VERSION INFORMATION',
              style: theme.textTheme.labelLarge?.copyWith(
                color: Colors.grey[600],
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    _buildInfoRow('Current version', _currentVersion),
                    if (_currentPatchNumber != null)
                      _buildInfoRow(
                          'Current patch', _currentPatchNumber.toString()),
                    if (_isUpdateAvailable)
                      _buildInfoRow('Latest version', _latestVersion),
                    _buildInfoRow('Update channel', _updateChannel),
                    _buildInfoRow('Last checked', _lastChecked),
                  ],
                ),
              ),
            ),

            const Spacer(),

            // Update button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isCheckingForUpdates || _isDownloadingUpdate
                    ? null
                    : _isUpdateAvailable
                        ? _downloadAndInstallUpdate
                        : _checkForUpdates,
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isCheckingForUpdates
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          ),
                          SizedBox(width: 12),
                          Text('Checking for updates...'),
                        ],
                      )
                    : _isUpdateAvailable
                        ? const Text('INSTALL UPDATE')
                        : const Text('CHECK FOR UPDATES'),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
