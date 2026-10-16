import 'package:flutter/material.dart';
import '../app_constants.dart';
import '../constants/constant_colors.dart';
import '../models/request_model.dart';

/// Badge code, name and colour of a leave (PL / SL / CL / CO) or comp off
/// credit request. Shared by the request card and the requests table.
class RequestTypeStyle {
  final String code;
  final String name;
  final Color color;

  const RequestTypeStyle(this.code, this.name, this.color);

  static RequestTypeStyle of(RequestModel request) {
    if (request.isCompOffRequest) {
      return const RequestTypeStyle('+CO', 'Comp Off Credit', Colors.teal);
    }
    switch ((request.leaveType ?? '').toLowerCase()) {
      case AppConstants.leaveTypePL:
        return RequestTypeStyle('PL', 'Privilege Leave', ConstColors.infoBlue);
      case AppConstants.leaveTypeSL:
        return RequestTypeStyle('SL', 'Sick Leave', ConstColors.successGreen);
      case AppConstants.leaveTypeCL:
        return RequestTypeStyle(
          'CL',
          'Casual Leave',
          ConstColors.inProgressOrange,
        );
      case AppConstants.leaveTypeCO:
        return const RequestTypeStyle('CO', 'Comp Off', Colors.teal);
      default:
        return RequestTypeStyle(
          (request.leaveType ?? request.typeDisplayName).toUpperCase(),
          request.typeDisplayName,
          Colors.grey,
        );
    }
  }
}
