import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:get/get.dart';
import '../providers/auth_provider.dart';
import '../services/supabase_service.dart';
import '../models/user_model.dart';
import 'dart:io';
import '../constants/const_textstyle.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../app_constants.dart';
import 'security_settings_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ImagePicker _picker = ImagePicker();
  bool _isUploading = false;
  bool _isEditingPersonal = false;
  final _personalFormKey = GlobalKey<FormState>();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _mobileController = TextEditingController();
  final TextEditingController _alternateMobileController =
      TextEditingController();
  final TextEditingController _bloodGroupController = TextEditingController();

  @override
  void dispose() {
    _addressController.dispose();
    _mobileController.dispose();
    _alternateMobileController.dispose();
    _bloodGroupController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _isUploading = true;
        });

        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        final userId = authProvider.user?.uid;

        if (userId != null) {
          final File imageFile = File(image.path);
          final bytes = await imageFile.readAsBytes();

          final imageUrl = await SupabaseService.uploadProfileImage(
            userId,
            bytes,
          );

          if (imageUrl.isNotEmpty) {
            // Refresh user data to get updated profile image
            await authProvider.refreshUserData();

            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Profile image updated successfully!'),
                backgroundColor: Colors.green,
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Failed to upload image. Please try again.'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isUploading = false;
      });
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Profile',
          style: getTextTheme().titleLarge?.copyWith(color: Colors.white),
        ),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
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
            padding: EdgeInsets.all(16.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(height: 20.h),

                // Profile Image Section
                Stack(
                  children: [
                    Container(
                      width: 120.w,
                      height: 120.w,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.blue, width: 3),
                      ),
                      child: ClipOval(
                        child:
                            user.profileImageUrl != null &&
                                user.profileImageUrl!.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: user.profileImageUrl!,
                                fit: BoxFit.cover,
                                placeholder: (context, url) =>
                                    const CircularProgressIndicator(),
                                errorWidget: (context, url, error) => Icon(
                                  Icons.person,
                                  size: 60.r,
                                  color: Colors.grey,
                                ),
                              )
                            : Icon(
                                Icons.person,
                                size: 60.r,
                                color: Colors.grey,
                              ),
                      ),
                    ),

                    // Edit/Camera Button
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        decoration: const BoxDecoration(
                          color: Colors.blue,
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: _isUploading
                              ? SizedBox(
                                  width: 20.w,
                                  height: 20.w,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : Icon(
                                  Icons.camera_alt,
                                  color: Colors.white,
                                  size: 20.r,
                                ),
                          onPressed: _isUploading
                              ? null
                              : _showImageSourceDialog,
                        ),
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 30.h),

                // User Information Cards
                Card(
                  elevation: 4,
                  child: Padding(
                    padding: EdgeInsets.all(16.w),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Personal Information',
                                style: getTextTheme().titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue,
                                ),
                              ),
                            ),
                            if (!_isEditingPersonal)
                              TextButton.icon(
                                onPressed: () async {
                                  if (_isEditingPersonal) return;
                                  try {
                                    final doc = await FirebaseFirestore.instance
                                        .collection(
                                          AppConstants.usersCollection,
                                        )
                                        .doc(user.userId)
                                        .get();
                                    final data = doc.data() ?? {};
                                    _addressController.text =
                                        (data['address'] ?? '').toString();
                                    _mobileController.text =
                                        (data['mobileNumber'] ?? '').toString();
                                    _alternateMobileController.text =
                                        (data['alternateNumber'] ?? '')
                                            .toString();
                                    _bloodGroupController.text =
                                        (data['bloodGroup'] ?? '').toString();
                                  } catch (_) {}
                                  setState(() {
                                    _isEditingPersonal = true;
                                  });
                                },
                                icon: Icon(Icons.edit, size: 16.r),
                                label: Text(
                                  'Edit',
                                  style: getTextTheme().labelLarge?.copyWith(
                                    color: Colors.blue,
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
                        StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                          stream: FirebaseFirestore.instance
                              .collection(AppConstants.usersCollection)
                              .doc(user.userId)
                              .snapshots(),
                          builder: (context, snapshot) {
                            final data = snapshot.data?.data();
                            final empId =
                                (data?['employeeId']?.toString() ??
                                user.employeeId ??
                                'N/A');
                            return _buildInfoRow(
                              Icons.badge,
                              'Employee ID',
                              empId,
                            );
                          },
                        ),
                        SizedBox(height: 12.h),
                        _buildInfoRow(
                          Icons.work,
                          'Department',
                          user.department ?? 'N/A',
                        ),
                        SizedBox(height: 12.h),
                        _buildInfoRow(
                          Icons.admin_panel_settings,
                          'Role',
                          user.isAdmin ? 'Admin' : 'Employee',
                        ),
                        if (_isEditingPersonal) ...[
                          SizedBox(height: 16.h),
                          Form(
                            key: _personalFormKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Address',
                                  style: getTextTheme().bodySmall,
                                ),
                                SizedBox(height: 6.h),
                                TextFormField(
                                  controller: _addressController,
                                  decoration: InputDecoration(
                                    hintText: 'Enter address',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8.r),
                                    ),
                                    contentPadding: EdgeInsets.all(12.w),
                                  ),
                                  maxLines: 2,
                                ),
                                SizedBox(height: 12.h),
                                Text(
                                  'Mobile Number',
                                  style: getTextTheme().bodySmall,
                                ),
                                SizedBox(height: 6.h),
                                TextFormField(
                                  controller: _mobileController,
                                  keyboardType: TextInputType.phone,
                                  decoration: InputDecoration(
                                    hintText: 'Enter mobile number',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8.r),
                                    ),
                                    contentPadding: EdgeInsets.all(12.w),
                                  ),
                                ),
                                SizedBox(height: 12.h),
                                Text(
                                  'Alternate Number',
                                  style: getTextTheme().bodySmall,
                                ),
                                SizedBox(height: 6.h),
                                TextFormField(
                                  controller: _alternateMobileController,
                                  keyboardType: TextInputType.phone,
                                  decoration: InputDecoration(
                                    hintText: 'Enter alternate number',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8.r),
                                    ),
                                    contentPadding: EdgeInsets.all(12.w),
                                  ),
                                ),
                                SizedBox(height: 12.h),
                                Text(
                                  'Blood Group',
                                  style: getTextTheme().bodySmall,
                                ),
                                SizedBox(height: 6.h),
                                TextFormField(
                                  controller: _bloodGroupController,
                                  decoration: InputDecoration(
                                    hintText: 'Enter blood group',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8.r),
                                    ),
                                    contentPadding: EdgeInsets.all(12.w),
                                  ),
                                ),
                                SizedBox(height: 16.h),
                                Row(
                                  children: [
                                    ElevatedButton(
                                      onPressed: () async {
                                        try {
                                          await FirebaseFirestore.instance
                                              .collection(
                                                AppConstants.usersCollection,
                                              )
                                              .doc(user.userId)
                                              .update({
                                                'address': _addressController
                                                    .text
                                                    .trim(),
                                                'mobileNumber':
                                                    _mobileController.text
                                                        .trim(),
                                                'alternateNumber':
                                                    _alternateMobileController
                                                        .text
                                                        .trim(),
                                                'bloodGroup':
                                                    _bloodGroupController.text
                                                        .trim(),
                                              });
                                          if (mounted) {
                                            setState(() {
                                              _isEditingPersonal = false;
                                            });
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  'Personal information updated',
                                                  style:
                                                      getTextTheme().bodyMedium,
                                                ),
                                                backgroundColor: Colors.green,
                                              ),
                                            );
                                          }
                                        } catch (e) {
                                          if (mounted) {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  'Failed to update: $e',
                                                  style:
                                                      getTextTheme().bodyMedium,
                                                ),
                                                backgroundColor: Colors.red,
                                              ),
                                            );
                                          }
                                        }
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.blue,
                                        foregroundColor: Colors.white,
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 16.w,
                                          vertical: 10.h,
                                        ),
                                      ),
                                      child: Text(
                                        'Save',
                                        style: getTextTheme().labelLarge
                                            ?.copyWith(color: Colors.white),
                                      ),
                                    ),
                                    SizedBox(width: 12.w),
                                    TextButton(
                                      onPressed: () {
                                        setState(() {
                                          _isEditingPersonal = false;
                                        });
                                      },
                                      child: Text(
                                        'Cancel',
                                        style: getTextTheme().labelLarge,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                SizedBox(height: 20.h),

                // Additional Actions
                Card(
                  elevation: 4,
                  child: Padding(
                    padding: EdgeInsets.all(16.w),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Account Actions',
                          style: getTextTheme().titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                        SizedBox(height: 16.h),

                        const Divider(),

                        ListTile(
                          leading: const Icon(Icons.security, color: Colors.blue),
                          title: Text(
                            'Security',
                            style: getTextTheme().bodyMedium,
                          ),
                          trailing: Icon(Icons.arrow_forward_ios, size: 16.r),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const SecuritySettingsScreen(),
                              ),
                            );
                          },
                        ),
                        const Divider(),

                        ListTile(
                          leading: const Icon(Icons.logout, color: Colors.red),
                          title: Text(
                            'Logout',
                            style: getTextTheme().bodyMedium,
                          ),
                          trailing: Icon(Icons.arrow_forward_ios, size: 16.r),
                          onTap: () {
                            showDialog(
                              context: context,
                              builder: (BuildContext context) {
                                return AlertDialog(
                                  title: Text(
                                    'Logout',
                                    style: getTextTheme().titleMedium,
                                  ),
                                  content: Text(
                                    'Are you sure you want to logout?',
                                    style: getTextTheme().bodyMedium,
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: Text(
                                        'Cancel',
                                        style: getTextTheme().labelLarge,
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: () async {
                                        Navigator.pop(context);
                                        await authProvider.logout();
                                        if (context.mounted) {
                                          Get.offAllNamed('/login_screen');
                                        }
                                      },
                                      child: Text(
                                        'Logout',
                                        style: getTextTheme().labelLarge,
                                      ),
                                    ),
                                  ],
                                );
                              },
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: Colors.blue, size: 20.r),
        SizedBox(width: 12.w),
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: getTextTheme().bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
              color: Colors.grey,
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
