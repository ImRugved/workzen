import '../app_constants.dart';

class RequestModel {
  final String id;
  final String userId;
  final String userName;
  final String type; // leave, wfh, break
  final DateTime? fromDate; // For leave and wfh requests
  final DateTime? toDate; // For leave and wfh requests
  final DateTime? date; // For single-day requests or break requests
  final String? shift; // For leave requests
  final String reason;
  final String status;
  final String? adminRemark;
  final DateTime appliedOn;
  final Map<String, dynamic>? additionalData; // For future extensibility

  RequestModel({
    required this.id,
    required this.userId,
    required this.userName,
    required this.type,
    this.fromDate,
    this.toDate,
    this.date,
    this.shift,
    required this.reason,
    required this.status,
    this.adminRemark,
    required this.appliedOn,
    this.additionalData,
  });

  // Factory constructor for leave requests
  factory RequestModel.leave({
    required String id,
    required String userId,
    required String userName,
    required DateTime fromDate,
    required DateTime toDate,
    required String shift,
    required String reason,
    String status = AppConstants.statusPending,
    String? adminRemark,
    required DateTime appliedOn,
    Map<String, dynamic>? additionalData,
  }) {
    return RequestModel(
      id: id,
      userId: userId,
      userName: userName,
      type: AppConstants.requestTypeLeave,
      fromDate: fromDate,
      toDate: toDate,
      shift: shift,
      reason: reason,
      status: status,
      adminRemark: adminRemark,
      appliedOn: appliedOn,
      additionalData: additionalData,
    );
  }

  // Factory constructor for WFH requests
  factory RequestModel.wfh({
    required String id,
    required String userId,
    required String userName,
    required DateTime fromDate,
    required DateTime toDate,
    required String reason,
    String status = AppConstants.statusPending,
    String? adminRemark,
    required DateTime appliedOn,
  }) {
    return RequestModel(
      id: id,
      userId: userId,
      userName: userName,
      type: AppConstants.requestTypeWFH,
      fromDate: fromDate,
      toDate: toDate,
      reason: reason,
      status: status,
      adminRemark: adminRemark,
      appliedOn: appliedOn,
    );
  }

  // Factory constructor for break requests
  factory RequestModel.breakRequest({
    required String id,
    required String userId,
    required String userName,
    required DateTime date,
    required String reason,
    String status = AppConstants.statusPending,
    String? adminRemark,
    required DateTime appliedOn,
    Map<String, dynamic>? additionalData,
  }) {
    return RequestModel(
      id: id,
      userId: userId,
      userName: userName,
      type: AppConstants.requestTypeBreak,
      date: date,
      reason: reason,
      status: status,
      adminRemark: adminRemark,
      appliedOn: appliedOn,
      additionalData: additionalData,
    );
  }

  factory RequestModel.fromJson(Map<String, dynamic> json) {
    return RequestModel(
      id: json['id'] ?? '',
      userId: json['userId'] ?? '',
      userName: json['userName'] ?? '',
      type: json['type'] ?? AppConstants.requestTypeLeave,
      fromDate: json['fromDate']?.toDate(),
      toDate: json['toDate']?.toDate(),
      date: json['date']?.toDate(),
      shift: json['shift'],
      reason: json['reason'] ?? '',
      status: json['status'] ?? AppConstants.statusPending,
      adminRemark: json['adminRemark'],
      appliedOn: json['appliedOn']?.toDate() ?? DateTime.now(),
      additionalData: json['additionalData'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {
      'id': id,
      'userId': userId,
      'userName': userName,
      'type': type,
      'reason': reason,
      'status': status,
      'appliedOn': appliedOn,
    };

    // Add optional fields only if they exist
    if (fromDate != null) data['fromDate'] = fromDate;
    if (toDate != null) data['toDate'] = toDate;
    if (date != null) data['date'] = date;
    if (shift != null) data['shift'] = shift;
    if (adminRemark != null) data['adminRemark'] = adminRemark;
    if (additionalData != null) data['additionalData'] = additionalData;

    return data;
  }

  // Helper methods
  bool get isLeaveRequest => type == AppConstants.requestTypeLeave;
  bool get isWFHRequest => type == AppConstants.requestTypeWFH;
  bool get isBreakRequest => type == AppConstants.requestTypeBreak;

  bool get isPending => status == AppConstants.statusPending;
  bool get isApproved => status == AppConstants.statusApproved;
  bool get isRejected => status == AppConstants.statusRejected;

  // Get display date based on request type
  String get displayDate {
    if (isBreakRequest && date != null) {
      return '${date!.day}/${date!.month}/${date!.year}';
    } else if ((isLeaveRequest || isWFHRequest) &&
        fromDate != null &&
        toDate != null) {
      if (fromDate!.day == toDate!.day &&
          fromDate!.month == toDate!.month &&
          fromDate!.year == toDate!.year) {
        return '${fromDate!.day}/${fromDate!.month}/${fromDate!.year}';
      } else {
        return '${fromDate!.day}/${fromDate!.month}/${fromDate!.year} - ${toDate!.day}/${toDate!.month}/${toDate!.year}';
      }
    }
    return 'N/A';
  }

  // Get request type display name
  String get typeDisplayName {
    switch (type) {
      case AppConstants.requestTypeLeave:
        return 'Leave';
      case AppConstants.requestTypeWFH:
        return 'Work From Home';
      case AppConstants.requestTypeBreak:
        return 'Break';
      default:
        return type.toUpperCase();
    }
  }
}
