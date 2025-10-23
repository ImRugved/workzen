class LeaveModel {
  final String id;
  final String userId;
  final String userName;
  final DateTime fromDate;
  final DateTime toDate;
  final String shift;
  final String reason;
  final String status;
  final String? adminRemark;
  final DateTime appliedOn;

  LeaveModel({
    required this.id,
    required this.userId,
    required this.userName,
    required this.fromDate,
    required this.toDate,
    required this.shift,
    required this.reason,
    required this.status,
    this.adminRemark,
    required this.appliedOn,
  });

  factory LeaveModel.fromJson(Map<String, dynamic> json) {
    return LeaveModel(
      id: json['id'] ?? '',
      userId: json['userId'] ?? '',
      userName: json['userName'] ?? '',
      fromDate: json['fromDate'].toDate(),
      toDate: json['toDate'].toDate(),
      shift: json['shift'] ?? '',
      reason: json['reason'] ?? '',
      status: json['status'] ?? '',
      adminRemark: json['adminRemark'],
      appliedOn: json['appliedOn'].toDate(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'userName': userName,
      'fromDate': fromDate,
      'toDate': toDate,
      'shift': shift,
      'reason': reason,
      'status': status,
      'adminRemark': adminRemark,
      'appliedOn': appliedOn,
    };
  }
}
