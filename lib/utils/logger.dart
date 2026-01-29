import 'dart:developer';

import 'package:flutter/foundation.dart';

void logDebug(Object? msg) {
  if (kDebugMode) {
    log('DEBUG: $msg');
  }
}
