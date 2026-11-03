import 'package:flutter/material.dart';
import '../models/request_model.dart';

/// State of the employee dashboard: the requests stream behind the recent
/// requests list. Scoped to the screen. (The leave balances are live in
/// RequestProvider.)
class UserHomeProvider with ChangeNotifier {
  Stream<List<RequestModel>>? _requestsStream;

  Stream<List<RequestModel>>? get requestsStream => _requestsStream;

  void setRequestsStream(Stream<List<RequestModel>>? stream) {
    _requestsStream = stream;
    notifyListeners();
  }
}
