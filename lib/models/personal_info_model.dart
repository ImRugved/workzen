import 'package:cloud_firestore/cloud_firestore.dart';
import 'user_model.dart';

/// The personal details an employee edits on the profile screen; stored on the
/// users/{uid} document.
class PersonalInfoModel {
  final String address;
  final String mobileNumber;
  final String alternateNumber;
  final String bloodGroup;
  final DateTime? dateOfBirth;
  final String? gender;
  final String totalExperience;
  final String emergencyContactNumber;

  const PersonalInfoModel({
    this.address = '',
    this.mobileNumber = '',
    this.alternateNumber = '',
    this.bloodGroup = '',
    this.dateOfBirth,
    this.gender,
    this.totalExperience = '',
    this.emergencyContactNumber = '',
  });

  factory PersonalInfoModel.fromUser(UserModel user) => PersonalInfoModel(
    address: user.address ?? '',
    mobileNumber: user.mobileNumber ?? '',
    alternateNumber: user.alternateNumber ?? '',
    bloodGroup: user.bloodGroup ?? '',
    dateOfBirth: user.dateOfBirth,
    gender: user.gender,
    totalExperience: user.totalExperience ?? '',
    emergencyContactNumber: user.emergencyContactNumber ?? '',
  );

  Map<String, dynamic> toJson() => {
    'address': address.trim(),
    'mobileNumber': mobileNumber.trim(),
    'alternateNumber': alternateNumber.trim(),
    'bloodGroup': bloodGroup.trim(),
    // Left out when not picked, so an existing date is never wiped
    if (dateOfBirth != null)
      'dateOfBirth': Timestamp.fromDate(
        DateTime(dateOfBirth!.year, dateOfBirth!.month, dateOfBirth!.day),
      ),
    // Left out when not chosen, so an existing value is never wiped
    if (gender != null) 'gender': gender,
    'totalExperience': totalExperience.trim(),
    'emergencyContactNumber': emergencyContactNumber.trim(),
  };
}
