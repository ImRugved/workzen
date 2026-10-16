import 'package:flutter/material.dart';

/// State of a 6 digit PIN pad: the digits typed so far, the PIN setup
/// confirm step, and the unlock screen's failed attempts / cooldown and
/// biometric prompt flags. Scoped to the PIN screen.
class PinEntryProvider with ChangeNotifier {
  static const int pinLength = 6;
  static const int maxAttempts = 3;
  static const Duration cooldownDuration = Duration(seconds: 30);

  String _pin = '';
  String? _firstPin;
  bool _isConfirming = false;

  final List<DateTime> _failedAttemptTimes = [];
  bool _isCooldown = false;
  bool _isAuthenticating = false;
  bool _disposed = false;

  String get pin => _pin;
  bool get isConfirming => _isConfirming;
  bool get isCooldown => _isCooldown;
  bool get isAuthenticating => _isAuthenticating;
  int get failedAttempts => _failedAttemptTimes.length;

  /// True when the typed PIN matches the first entry (setup confirm step).
  bool get matchesFirstPin => _pin == _firstPin;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  /// Adds a digit. Returns true when the PIN is now complete.
  bool addDigit(String digit) {
    if (_isCooldown || _pin.length >= pinLength) return false;
    _pin += digit;
    notifyListeners();
    return _pin.length == pinLength;
  }

  void backspace() {
    if (_pin.isEmpty) return;
    _pin = _pin.substring(0, _pin.length - 1);
    notifyListeners();
  }

  void clear() {
    _pin = '';
    notifyListeners();
  }

  // --- PIN setup ---

  /// Keeps the first entry and asks for it again.
  void startConfirming() {
    _firstPin = _pin;
    _pin = '';
    _isConfirming = true;
    notifyListeners();
  }

  /// Back to the first entry after the two PINs did not match.
  void resetSetup() {
    _pin = '';
    _firstPin = null;
    _isConfirming = false;
    notifyListeners();
  }

  // --- Unlock ---

  void setAuthenticating(bool value) {
    _isAuthenticating = value;
    notifyListeners();
  }

  void clearFailedAttempts() => _failedAttemptTimes.clear();

  /// Records a wrong PIN (attempts older than a minute are forgotten) and
  /// clears the typed digits. Returns true when the cooldown has started.
  bool registerFailedAttempt() {
    final now = DateTime.now();
    _failedAttemptTimes.add(now);
    _failedAttemptTimes.removeWhere(
      (time) => now.difference(time) > const Duration(minutes: 1),
    );
    _pin = '';

    final cooldown = _failedAttemptTimes.length >= maxAttempts;
    if (cooldown) {
      _isCooldown = true;
      Future.delayed(cooldownDuration, () {
        if (_disposed) return;
        _isCooldown = false;
        _failedAttemptTimes.clear();
        notifyListeners();
      });
    }
    notifyListeners();
    return cooldown;
  }
}
