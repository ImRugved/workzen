import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../app_constants.dart';
import '../constants/firestore_constants.dart';
import '../models/request_model.dart';
import '../utils/logger.dart';
import 'request_provider.dart';

/// The approved leave, comp off and WFH records of one employee, newest first,
/// for the "Leave records" sheet of Manage Employee Leaves. Scoped to the sheet
/// with ChangeNotifierProvider.
class LeaveRecordsProvider with ChangeNotifier {
  final String userId;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  LeaveRecordsProvider(this.userId) {
    load();
  }

  List<RequestModel> _records = [];
  bool _isLoading = true;
  String? _error;
  String? _deletingId;

  List<RequestModel> get records => _records;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Id of the record being deleted, or null.
  String? get deletingId => _deletingId;

  DateTime _startOf(RequestModel r) =>
      (r.isCompOffRequest ? r.compOffDate : r.fromDate) ?? r.appliedOn;

  Future<void> load() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final snapshot = await _firestore
          .collection(FirestoreCollections.users)
          .doc(userId)
          .collection(FirestoreSubCollections.requests)
          .where('status', isEqualTo: AppConstants.statusApproved)
          .get();
      _records =
          snapshot.docs
              .map((doc) => RequestModel.fromJson(doc.data()))
              .where(
                (r) => r.isLeaveRequest || r.isCompOffRequest || r.isWFHRequest,
              )
              .toList()
            ..sort((a, b) => _startOf(b).compareTo(_startOf(a)));
    } catch (e) {
      logDebug('Could not load leave records: $e');
      _error = 'Could not load the leave records';
    }
    _isLoading = false;
    notifyListeners();
  }

  /// Month a record falls in (the first day), for the month headers.
  DateTime monthOf(RequestModel r) {
    final d = _startOf(r);
    return DateTime(d.year, d.month);
  }

  /// Deletes a record and gives its days back. True when it was deleted.
  Future<bool> delete(RequestModel record, RequestProvider requests) async {
    _deletingId = record.id;
    notifyListeners();
    final done = await requests.deleteLeaveRecord(record);
    if (done) _records = _records.where((r) => r.id != record.id).toList();
    _deletingId = null;
    notifyListeners();
    return done;
  }
}
