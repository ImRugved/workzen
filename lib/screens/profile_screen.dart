import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:get/get.dart';
import 'package:workzen/utils/logger.dart';
import '../models/personal_info_model.dart';
import '../models/user_model.dart';
import '../providers/auth_provider.dart';
import '../providers/profile_screen_provider.dart';
import '../constants/const_textstyle.dart';
import '../constants/constant_snackbar.dart';
import '../constants/constant_button.dart';
import '../constants/constant_colors.dart';
import '../constants/app_theme.dart';
import '../constants/apploading_indicator.dart';
import '../constants/constant_textfield.dart';
import '../constants/constant_date_time_picker.dart';
import '../constants/constant_dropdown.dart';
import '../app_constants.dart';
import 'security_settings_screen.dart';

/// Profile and personal details. The user comes from [AuthProvider] (live);
/// the upload / edit / logout state is in [ProfileScreenProvider]. This State
/// only owns the provider, the image picker and the form controllers.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ProfileScreenProvider _profile = ProfileScreenProvider();
  final ImagePicker _picker = ImagePicker();
  final _personalFormKey = GlobalKey<FormState>();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _mobileController = TextEditingController();
  final TextEditingController _alternateMobileController =
      TextEditingController();
  final TextEditingController _bloodGroupController = TextEditingController();
  final TextEditingController _totalExperienceController =
      TextEditingController();
  final TextEditingController _emergencyContactController =
      TextEditingController();

  @override
  void initState() {
    super.initState();
    // Refresh user data when screen loads to ensure we have latest profileImageUrl
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (authProvider.user != null) {
        logDebug('ProfileScreen initState - refreshing user data');
        authProvider.refreshUserData();
      }
    });
  }

  @override
  void dispose() {
    _addressController.dispose();
    _mobileController.dispose();
    _alternateMobileController.dispose();
    _bloodGroupController.dispose();
    _totalExperienceController.dispose();
    _emergencyContactController.dispose();
    _profile.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadImage(ImageSource source) async {
    final auth = context.read<AuthProvider>();
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      if (image == null) {
        logDebug('No image selected by user');
        return;
      }

      final bytes = await File(image.path).readAsBytes();
      final error = await _profile.uploadProfileImage(auth, bytes);
      if (error == null) {
        ConstantSnackbar.showSuccess(
          title: 'Profile image updated successfully!',
        );
      } else {
        ConstantSnackbar.showError(title: error);
      }
    } catch (e) {
      logDebug('Error picking profile image: $e');
      ConstantSnackbar.showError(title: 'Error: $e');
    }
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.photo_camera),
                title: const Text('Camera'),
                onTap: () {
                  Navigator.pop(context);
                  _pickAndUploadImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Gallery'),
                onTap: () {
                  Navigator.pop(context);
                  _pickAndUploadImage(ImageSource.gallery);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // Fills the form from the live user, then shows it
  void _startEditing(UserModel user) {
    final info = PersonalInfoModel.fromUser(user);
    _addressController.text = info.address;
    _mobileController.text = info.mobileNumber;
    _alternateMobileController.text = info.alternateNumber;
    _bloodGroupController.text = info.bloodGroup;
    _totalExperienceController.text = info.totalExperience;
    _emergencyContactController.text = info.emergencyContactNumber;
    _profile.startEditing(dateOfBirth: info.dateOfBirth, gender: info.gender);
  }

  Future<void> _savePersonalInfo(AuthProvider auth) async {
    final error = await _profile.savePersonalInfo(
      auth,
      PersonalInfoModel(
        address: _addressController.text,
        mobileNumber: _mobileController.text,
        alternateNumber: _alternateMobileController.text,
        bloodGroup: _bloodGroupController.text,
        dateOfBirth: _profile.dateOfBirth,
        gender: _profile.gender,
        totalExperience: _totalExperienceController.text,
        emergencyContactNumber: _emergencyContactController.text,
      ),
    );
    if (error == null) {
      ConstantSnackbar.showSuccess(title: 'Personal information updated');
    } else {
      ConstantSnackbar.showError(title: error);
    }
  }

  Future<void> _logout(AuthProvider auth) async {
    final error = await _profile.logout(auth);
    if (error == null) {
      Get.offAllNamed('/login_screen');
    } else {
      if (mounted) Navigator.of(context).pop();
      ConstantSnackbar.showError(title: error);
    }
  }

  void _showLogoutDialog(AuthProvider authProvider) {
    showDialog(
      context: context,
      barrierDismissible: !_profile.isLoggingOut,
      builder: (BuildContext dialogContext) {
        return ChangeNotifierProvider.value(
          value: _profile,
          child: Consumer<ProfileScreenProvider>(
            builder: (context, profile, _) => AlertDialog(
              title: Text('Logout', style: getTextTheme().titleMedium),
              content: Text(
                'Are you sure you want to logout?',
                style: getTextTheme().bodyMedium,
              ),
              actions: [
                if (!profile.isLoggingOut)
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: Text('Cancel', style: getTextTheme().labelLarge),
                  ),
                TextButton(
                  onPressed: profile.isLoggingOut
                      ? null
                      : () => _logout(authProvider),
                  child: profile.isLoggingOut
                      ? SizedBox(
                          width: 20.w,
                          height: 20.h,
                          child: const AppLoadingIndicator(size: 20),
                        )
                      : Text('Logout', style: getTextTheme().labelLarge),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _profile,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            'Profile',
            style: getTextTheme().titleLarge?.copyWith(
              color: ConstColors.textColor,
            ),
          ),
        ),
        body: Consumer<AuthProvider>(
          builder: (context, authProvider, child) {
            final UserModel? user = authProvider.userModel;

            if (user == null) {
              return Center(
                child: Text(
                  'No user data available',
                  style: getTextTheme().bodyMedium,
                ),
              );
            }

            return SingleChildScrollView(
              padding: AppSpacing.screen,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(height: 20.h),
                  _buildProfileImage(user),
                  SizedBox(height: 30.h),
                  _buildPersonalInfoCard(user, authProvider),
                  SizedBox(height: 20.h),
                  _buildAccountActionsCard(authProvider),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildProfileImage(UserModel user) {
    return Stack(
      children: [
        Container(
          width: 120.w,
          height: 120.w,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: ConstColors.primary, width: 3),
          ),
          child: ClipOval(
            child:
                user.profileImageUrl != null && user.profileImageUrl!.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: user.profileImageUrl!,
                    width: 120.w,
                    height: 120.w,
                    fit: BoxFit.cover,
                    placeholder: (context, url) =>
                        const AppLoadingIndicator(size: 40),
                    errorWidget: (context, url, error) {
                      logDebug('Error loading profile image: $error');
                      return Icon(
                        Icons.person,
                        size: 60.r,
                        color: ConstColors.textColorLight,
                      );
                    },
                  )
                : Icon(
                    Icons.person,
                    size: 60.r,
                    color: ConstColors.textColorLight,
                  ),
          ),
        ),

        // Edit/Camera Button
        Positioned(
          bottom: 0,
          right: 0,
          child: Container(
            decoration: const BoxDecoration(
              color: ConstColors.primary,
              shape: BoxShape.circle,
            ),
            child: Selector<ProfileScreenProvider, bool>(
              selector: (_, p) => p.isUploading,
              builder: (context, isUploading, _) => IconButton(
                icon: isUploading
                    ? SizedBox(
                        width: 20.w,
                        height: 20.w,
                        child: AppLoadingIndicator(
                          size: 20,
                          color: ConstColors.textColor,
                        ),
                      )
                    : Icon(
                        Icons.camera_alt,
                        color: ConstColors.textColor,
                        size: 20.r,
                      ),
                onPressed: isUploading ? null : _showImageSourceDialog,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPersonalInfoCard(UserModel user, AuthProvider authProvider) {
    return NeuCard(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
        child: Consumer<ProfileScreenProvider>(
          builder: (context, profile, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Personal Information',
                      style: getTextTheme().titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: ConstColors.primaryDeep,
                      ),
                    ),
                  ),
                  if (!profile.isEditingPersonal)
                    TextButton.icon(
                      onPressed: () => _startEditing(user),
                      icon: Icon(Icons.edit, size: 16.r),
                      label: Text(
                        'Edit',
                        style: getTextTheme().labelLarge?.copyWith(
                          color: ConstColors.primaryDeep,
                        ),
                      ),
                    ),
                ],
              ),
              SizedBox(height: 16.h),

              _buildInfoRow(Icons.person, 'Name', user.name),
              SizedBox(height: 12.h),
              _buildInfoRow(Icons.email, 'Email', user.email),
              SizedBox(height: 12.h),
              _buildInfoRow(
                Icons.badge,
                'Employee ID',
                user.employeeId ?? 'N/A',
              ),
              SizedBox(height: 12.h),
              _buildInfoRow(Icons.work, 'Department', user.department ?? 'N/A'),
              SizedBox(height: 12.h),
              _buildInfoRow(Icons.admin_panel_settings, 'Role', user.roleLabel),
              SizedBox(height: 12.h),
              _buildInfoRow(
                Icons.badge_outlined,
                'Job Role',
                user.jobRole ?? 'N/A',
              ),
              SizedBox(height: 12.h),
              _buildInfoRow(
                Icons.cake_outlined,
                'Date of Birth',
                user.dateOfBirth == null
                    ? 'Not set'
                    : DateFormat('dd MMM yyyy').format(user.dateOfBirth!),
              ),
              SizedBox(height: 12.h),
              _buildInfoRow(
                Icons.wc_outlined,
                'Gender',
                user.gender ?? 'Not set',
              ),
              if (profile.isEditingPersonal) ...[
                SizedBox(height: 16.h),
                _buildPersonalForm(authProvider),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPersonalForm(AuthProvider authProvider) {
    return Form(
      key: _personalFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ConstTextField(
            customText: 'Address',
            controller: _addressController,
            maxline: 2,
          ),
          SizedBox(height: 12.h),
          ConstTextField(
            customText: 'Mobile Number',
            controller: _mobileController,
            keyoardType: TextInputType.phone,
          ),
          SizedBox(height: 12.h),
          ConstTextField(
            customText: 'Alternate Number',
            controller: _alternateMobileController,
            keyoardType: TextInputType.phone,
          ),
          SizedBox(height: 12.h),
          ConstTextField(
            customText: 'Blood Group',
            controller: _bloodGroupController,
          ),
          SizedBox(height: 12.h),
          // Date of birth: the people's own past date, so no future dates
          Selector<ProfileScreenProvider, DateTime?>(
            selector: (_, p) => p.dateOfBirth,
            builder: (context, dob, _) => ConstantDatePicker(
              label: 'Date of Birth',
              hint: 'Select date of birth',
              value: dob,
              firstDate: DateTime(1950),
              lastDate: DateTime.now(),
              onChanged: _profile.setDateOfBirth,
            ),
          ),
          SizedBox(height: 12.h),
          Selector<ProfileScreenProvider, String?>(
            selector: (_, p) => p.gender,
            builder: (context, gender, _) => ConstantDropdown<String>(
              label: 'Gender',
              hint: 'Select gender',
              value: gender,
              items: AppConstants.genders,
              itemLabel: (g) => g,
              onChanged: _profile.setGender,
            ),
          ),
          SizedBox(height: 12.h),
          ConstTextField(
            customText: 'Total Experience',
            controller: _totalExperienceController,
          ),
          SizedBox(height: 12.h),
          ConstTextField(
            customText: 'Emergency Contact Number',
            controller: _emergencyContactController,
            keyoardType: TextInputType.phone,
          ),
          SizedBox(height: 16.h),
          Row(
            children: [
              ConstantButton(
                text: 'Save',
                onPressed: () => _savePersonalInfo(authProvider),
                backgroundColor: ConstColors.primary,
                textColor: ConstColors.textColor,
                isFullWidth: false,
                height: 40.h,
              ),
              SizedBox(width: 12.w),
              TextButton(
                onPressed: _profile.stopEditing,
                child: Text('Cancel', style: getTextTheme().labelLarge),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAccountActionsCard(AuthProvider authProvider) {
    return NeuCard(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Account Actions',
              style: getTextTheme().titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: ConstColors.primaryDeep,
              ),
            ),
            SizedBox(height: 16.h),

            const Divider(),

            ListTile(
              leading: const Icon(
                Icons.security,
                color: ConstColors.primaryDeep,
              ),
              title: Text('Security', style: getTextTheme().bodyMedium),
              trailing: Icon(Icons.arrow_forward_ios, size: 16.r),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SecuritySettingsScreen(),
                  ),
                );
              },
            ),
            const Divider(),

            ListTile(
              leading: const Icon(Icons.logout, color: ConstColors.errorRed),
              title: Text('Logout', style: getTextTheme().bodyMedium),
              trailing: Icon(Icons.arrow_forward_ios, size: 16.r),
              onTap: () => _showLogoutDialog(authProvider),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: ConstColors.primaryDeep, size: 20.r),
        SizedBox(width: 12.w),
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: getTextTheme().bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
              color: ConstColors.textColorLight,
            ),
          ),
        ),
        Expanded(
          flex: 3,
          child: Text(
            value,
            style: getTextTheme().bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
