import 'package:flutter/material.dart';
import '../models/leave_balance_model.dart';
import '../models/request_model.dart';

/// State of the employee dashboard: the pending requests stream and the leave
/// balances card. Scoped to the screen.
class UserHomeProvider with ChangeNotifier {
  Stream<List<RequestModel>>? _requestsStream;
  LeaveBalanceModel? _balances;
  bool _isLoadingBalances = true;
  bool _hasLoadedOnce = false;

  Stream<List<RequestModel>>? get requestsStream => _requestsStream;
  LeaveBalanceModel? get balances => _balances;

  /// True only for the first load, so a refresh keeps showing the old numbers.
  bool get showBalanceLoading => _isLoadingBalances && !_hasLoadedOnce;

  void setRequestsStream(Stream<List<RequestModel>>? stream) {
    _requestsStream = stream;
    notifyListeners();
  }

  void startLoadingBalances() {
    if (_hasLoadedOnce) return;
    _isLoadingBalances = true;
    notifyListeners();
  }

  /// [balances] is null when the employee has no leave allocation.
  void setBalances(LeaveBalanceModel? balances) {
    _balances = balances;
    _isLoadingBalances = false;
    _hasLoadedOnce = true;
    notifyListeners();
  }
}
