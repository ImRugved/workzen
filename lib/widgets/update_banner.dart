import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../constants/app_theme.dart';
import '../constants/const_textstyle.dart';
import '../constants/constant_button.dart';
import '../constants/constant_colors.dart';
import '../constants/constant_snackbar.dart';
import '../providers/update_check_provider.dart';
import 'app_dialog_card.dart';

/// Shown at the top of the admin and employee dashboards only when there is
/// something to do about a software update (Shorebird code push):
/// - a new update is available: "Update" downloads it,
/// - it is downloading: a progress bar,
/// - it is installed: "Restart" restarts the app so the update starts running.
/// Nothing is shown when the app is up to date, in a debug build, or after an
/// error (the Software Update screen reports those).
class UpdateBanner extends StatelessWidget {
  const UpdateBanner({super.key});

  Future<void> _install(UpdateCheckProvider updates) async {
    final result = await updates.downloadAndInstall();
    if (result != null && result.outcome == UpdateOutcome.error) {
      ConstantSnackbar.showError(title: result.message ?? 'Update failed');
    }
  }

  /// Restarts the app. Used by this banner and the Software Update screen.
  static Future<void> restart(
    BuildContext context,
    UpdateCheckProvider updates,
  ) async {
    final outcome = await updates.restartApp();
    if (!context.mounted) return;

    if (outcome == RestartOutcome.manualRequired) {
      // iOS cannot restart an app by itself
      showDialog<void>(
        context: context,
        builder: (dialogContext) => AppDialogCard(
          icon: Icons.system_update,
          title: 'Update ready',
          message:
              'Close the app completely (swipe it away in the app switcher) '
              'and open it again to start the new version.',
          confirmLabel: 'OK',
          onCancel: () => Navigator.of(dialogContext).pop(),
          onConfirm: () => Navigator.of(dialogContext).pop(),
        ),
      );
    } else if (outcome == RestartOutcome.failed) {
      ConstantSnackbar.showError(
        title: 'Could not restart. Close the app and open it again.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<UpdateCheckProvider>(
      builder: (context, updates, _) {
        final String title;
        final String subtitle;
        final IconData icon;
        Widget? action;

        if (updates.isDownloading) {
          title = 'Updating the app...';
          subtitle = '${(updates.downloadProgress * 100).toInt()}%';
          icon = Icons.downloading;
        } else if (updates.isRestartRequired) {
          title = 'Update installed';
          subtitle = updates.canRestartAutomatically
              ? 'Restart the app to start using the new version'
              : 'Close the app and open it again to use the new version';
          icon = Icons.check_circle_outline;
          action = ConstantButton(
            text: 'Restart',
            isFullWidth: false,
            height: 38.h,
            onPressed: () => restart(context, updates),
            backgroundColor: ConstColors.primary,
            textColor: ConstColors.textColor,
          );
        } else if (updates.isUpdateAvailable) {
          title = 'New update available';
          subtitle = 'Update now to get the latest improvements';
          icon = Icons.system_update_alt;
          action = ConstantButton(
            text: 'Update',
            isFullWidth: false,
            height: 38.h,
            onPressed: () => _install(updates),
            backgroundColor: ConstColors.primary,
            textColor: ConstColors.textColor,
          );
        } else {
          return const SizedBox.shrink();
        }

        return Padding(
          padding: EdgeInsets.only(bottom: 16.h),
          child: NeuCard(
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40.r,
                      height: 40.r,
                      decoration: BoxDecoration(
                        color: ConstColors.primary.withValues(alpha: 0.35),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        icon,
                        size: 22.r,
                        color: ConstColors.primaryDeep,
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: getTextTheme().titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: ConstColors.textColor,
                            ),
                          ),
                          SizedBox(height: 2.h),
                          Text(
                            subtitle,
                            style: getTextTheme().bodySmall?.copyWith(
                              color: ConstColors.textColorLight,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (action != null) ...[SizedBox(width: 8.w), action],
                  ],
                ),
                if (updates.isDownloading) ...[
                  SizedBox(height: 10.h),
                  LinearProgressIndicator(
                    value: updates.downloadProgress,
                    backgroundColor: ConstColors.borderColor,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      ConstColors.primaryDeep,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
