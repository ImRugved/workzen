import 'user_model.dart';

/// The personal details an employee edits on the profile screen; stored on the
/// users/{uid} document.
class PersonalInfoModel {
  final String address;
  final String mobileNumber;
  final String alternateNumber;
  final String bloodGroup;
  final String totalExperience;
  final String emergencyContactNumber;

  const PersonalInfoModel({
    this.address = '',
    this.mobileNumber = '',
    this.alternateNumber = '',
    this.bloodGroup = '',
    this.totalExperience = '',
    this.emergencyContactNumber = '',
  });

  factory PersonalInfoModel.fromUser(UserModel user) => PersonalInfoModel(
    address: user.address ?? '',
    mobileNumber: user.mobileNumber ?? '',
    alternateNumber: user.alternateNumber ?? '',
    bloodGroup: user.bloodGroup ?? '',
    totalExperience: user.totalExperience ?? '',
    emergencyContactNumber: user.emergencyContactNumber ?? '',
  );

  Map<String, dynamic> toJson() => {
    'address': address.trim(),
    'mobileNumber': mobileNumber.trim(),
    'alternateNumber': alternateNumber.trim(),
    'bloodGroup': bloodGroup.trim(),
    'totalExperience': totalExperience.trim(),
    'emergencyContactNumber': emergencyContactNumber.trim(),
  };
}
