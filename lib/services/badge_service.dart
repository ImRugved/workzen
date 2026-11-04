import 'package:app_badge_plus/app_badge_plus.dart';
import '../utils/logger.dart';

/// The number on the app icon: how many pushes the user has not seen yet.
///
/// iOS shows the number a push carries (`aps.badge`, set by FCMService) even
/// when the app is closed; this sets it when the app's own code runs. Android
/// launchers that support numeric badges (Samsung, Xiaomi, Huawei, Oppo, Vivo
/// ...) show it; Pixel and stock Android show a dot while a notification waits.
class BadgeService {
  BadgeService._();

  /// Shows [count] on the icon; 0 or less removes it.
  static Future<void> set(int count) async {
    try {
      await AppBadgePlus.updateBadge(count < 0 ? 0 : count);
    } catch (e) {
      // Not supported on every phone: never let it break the app
      logDebug('Could not set the app icon badge: $e');
    }
  }

  /// Removes the number (the user has opened the app).
  static Future<void> clear() => set(0);
}
