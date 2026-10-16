import 'package:flutter/material.dart';

/// Scoped on/off flag for small widget-local UI state (expanded, obscured,
/// loading and similar), so widgets need no setState. Create it with
/// ChangeNotifierProvider next to the widget that owns the flag.
class ToggleProvider with ChangeNotifier {
  bool _value;

  ToggleProvider([this._value = false]);

  bool get value => _value;

  void toggle() => set(!_value);

  void set(bool value) {
    if (_value == value) return;
    _value = value;
    notifyListeners();
  }
}
