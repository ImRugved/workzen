import 'package:flutter/material.dart';

/// Scoped holder for one small piece of widget-local UI state (a picked date,
/// a selected tab and similar), so widgets need no setState. Create it with
/// ChangeNotifierProvider next to the widget that owns the value.
class ValueProvider<T> with ChangeNotifier {
  T _value;

  ValueProvider(this._value);

  T get value => _value;

  set value(T value) {
    if (_value == value) return;
    _value = value;
    notifyListeners();
  }
}
