import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../constants/const_textstyle.dart';
import '../constants/constant_button.dart';
import '../constants/constant_colors.dart';
import '../providers/update_check_provider.dart';

/// The update state lives in [UpdateCheckProvider]; this State only owns the
/// provider and the ScaffoldMessenger used to clear the banner on exit.
class UpdateCheckScreen extends StatefulWidget {
  const UpdateCheckScreen({super.key});

  @override
  State<UpdateCheckScreen> createState() => _UpdateCheckScreenState();
}

class _UpdateCheckScreenState extends State<UpdateCheckScreen> {
  final UpdateCheckProvider _updates = UpdateCheckProvider();
  ScaffoldMessengerState? _scaffoldMessenger;

  @override
  void initState() {
    super.initState();
    _load();
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
    _updates.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    await _updates.loadAppInfo();
    // Check for updates automatically on screen load
    await _checkForUpdates();
  }

  Future<void> _checkForUpdates() async {
    final result = await _updates.checkForUpdates();
    if (result == null || !mounted) return;

    switch (result.outcome) {
      case UpdateOutcome.updateAvailable:
        _showUpdateAvailableBanner();
      case UpdateOutcome.upToDate:
        _showNoUpdateAvailableBanner();
      case UpdateOutcome.error:
        _showErrorBanner(result.message ?? 'Update check failed');
      case UpdateOutcome.installed:
        break;
    }
  }

  Future<void> _downloadAndInstallUpdate() async {
    final result = await _updates.downloadAndInstall();
    if (result == null || !mounted) return;

    if (result.outcome == UpdateOutcome.installed) {
      _showInstallationSuccessBanner();
    } else {
      _showErrorBanner(result.message ?? 'Update failed');
    }
  }

  void _showNoUpdateAvailableBanner() {
    ScaffoldMessenger.of(context)
      ..hideCurrentMaterialBanner()
      ..showMaterialBanner(
        MaterialBanner(
          backgroundColor: Colors.green[100],
          content: Text(
            'Your app is up to date!',
            style: getTextTheme().bodyMedium?.copyWith(color: Colors.green),
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
            'Update available: ${_updates.latestVersion}',
            style: getTextTheme().bodyMedium?.copyWith(color: Colors.blue),
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
          content: Text(
            'Update installed! Restart app to apply changes.',
            style: getTextTheme().bodyMedium?.copyWith(color: Colors.green),
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
            style: getTextTheme().bodyMedium?.copyWith(color: Colors.red),
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
    return ChangeNotifierProvider.value(
      value: _updates,
      child: Consumer<UpdateCheckProvider>(
        builder: (context, updates, _) => _buildScreen(context, updates),
      ),
    );
  }

  Widget _buildScreen(BuildContext context, UpdateCheckProvider updates) {
    final theme = Theme.of(context);
    final isUpdateAvailable = updates.isUpdateAvailable;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: theme.colorScheme.primary,
        title: Text(
          'Software Update',
          style: getTextTheme().titleLarge?.copyWith(color: Colors.white),
        ),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Update status card
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16.r),
              ),
              child: Padding(
                padding: EdgeInsets.all(20.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(12.w),
                          decoration: BoxDecoration(
                            color: isUpdateAvailable
                                ? Colors.blue.withValues(alpha: 0.2)
                                : Colors.green.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                          child: Icon(
                            isUpdateAvailable
                                ? Icons.system_update_alt
                                : Icons.check_circle_outline,
                            size: 28.r,
                            color: isUpdateAvailable
                                ? Colors.blue
                                : Colors.green,
                          ),
                        ),
                        SizedBox(width: 16.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isUpdateAvailable
                                    ? 'Update Available'
                                    : 'App is Up to Date',
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: isUpdateAvailable
                                      ? Colors.blue
                                      : Colors.green,
                                ),
                              ),
                              SizedBox(height: 4.h),
                              Text(
                                isUpdateAvailable
                                    ? 'A new version is ready to install'
                                    : 'You have the latest version installed',
                                style: theme.textTheme.bodyMedium,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (isUpdateAvailable && updates.isDownloading) ...[
                      SizedBox(height: 20.h),
                      Text(
                        'Downloading update...',
                        style: getTextTheme().bodyMedium,
                      ),
                      SizedBox(height: 8.h),
                      LinearProgressIndicator(
                        value: updates.downloadProgress,
                        backgroundColor: Colors.grey[200],
                        valueColor: AlwaysStoppedAnimation<Color>(
                          theme.colorScheme.primary,
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        '${(updates.downloadProgress * 100).toInt()}%',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
            ),

            SizedBox(height: 24.h),

            // Version information
            Text(
              'VERSION INFORMATION',
              style: theme.textTheme.labelLarge?.copyWith(
                color: Colors.grey[600],
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8.h),
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16.r),
              ),
              child: Padding(
                padding: EdgeInsets.all(16.w),
                child: Column(
                  children: [
                    _buildInfoRow('Current version', updates.currentVersion),
                    if (updates.currentPatchNumber != null)
                      _buildInfoRow(
                        'Current patch',
                        updates.currentPatchNumber.toString(),
                      ),
                    if (isUpdateAvailable)
                      _buildInfoRow('Latest version', updates.latestVersion),
                    _buildInfoRow('Update channel', updates.updateChannel),
                    _buildInfoRow('Last checked', updates.lastChecked),
                  ],
                ),
              ),
            ),

            const Spacer(),

            // Update button
            SizedBox(
              width: double.infinity,
              child: ConstantButton(
                text: isUpdateAvailable
                    ? 'INSTALL UPDATE'
                    : 'CHECK FOR UPDATES',
                isLoading: updates.isChecking,
                onPressed: updates.isChecking || updates.isDownloading
                    ? null
                    : isUpdateAvailable
                    ? _downloadAndInstallUpdate
                    : _checkForUpdates,
                backgroundColor: ConstColors.primary,
                textColor: ConstColors.white,
              ),
            ),
            SizedBox(height: 16.h),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8.0.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: getTextTheme().bodyMedium?.copyWith(color: Colors.grey),
          ),
          Text(
            value,
            style: getTextTheme().bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
