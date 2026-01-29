import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/employee_management_provider.dart';
import '../../models/employee_model.dart';
import '../../constants/const_textstyle.dart';
import '../../app_constants.dart';

class EmployeeDetailsScreen extends StatefulWidget {
  final EmployeeModel employee;

  const EmployeeDetailsScreen({Key? key, required this.employee})
    : super(key: key);

  @override
  State<EmployeeDetailsScreen> createState() => _EmployeeDetailsScreenState();
}

class _EmployeeDetailsScreenState extends State<EmployeeDetailsScreen> {
  bool _isEditing = false;
  late TextEditingController _departmentController;
  late TextEditingController _addressController;
  late TextEditingController _mobileController;
  late TextEditingController _alternateController;
  late TextEditingController _bloodGroupController;
  late TextEditingController _aadharController;
  late TextEditingController _panController;
  late TextEditingController _employeeIdController;
  late TextEditingController _roleController;
  late TextEditingController _totalExperienceController;
  late TextEditingController _emergencyContactController;
  DateTime? _selectedDate;

  // Extra user data from Firestore
  Map<String, dynamic>? _userData;
  bool _isLoadingData = true;

  @override
  void initState() {
    super.initState();
    _departmentController = TextEditingController(
      text: widget.employee.department ?? '',
    );
    _addressController = TextEditingController();
    _mobileController = TextEditingController();
    _alternateController = TextEditingController();
    _bloodGroupController = TextEditingController();
    _aadharController = TextEditingController();
    _panController = TextEditingController();
    _employeeIdController = TextEditingController(
      text: widget.employee.employeeId ?? '',
    );
    _roleController = TextEditingController(
      text: widget.employee.role ?? '',
    );
    _totalExperienceController = TextEditingController(
      text: widget.employee.totalExperience ?? '',
    );
    _emergencyContactController = TextEditingController(
      text: widget.employee.emergencyContactNumber ?? '',
    );
    _selectedDate = widget.employee.joiningDate;
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection(AppConstants.userCollection)
          .doc(widget.employee.id)
          .get();

      if (doc.exists) {
        setState(() {
          _userData = doc.data();
          _addressController.text = (_userData?['address'] ?? '').toString();
          _mobileController.text = (_userData?['mobileNumber'] ?? '')
              .toString();
          _alternateController.text = (_userData?['alternateNumber'] ?? '')
              .toString();
          _bloodGroupController.text = (_userData?['bloodGroup'] ?? '')
              .toString();
          _aadharController.text = (_userData?['aadharNumber'] ?? '')
              .toString();
          _panController.text = (_userData?['panCardNumber'] ?? '').toString();
          _totalExperienceController.text = (_userData?['totalExperience'] ?? '')
              .toString();
          _emergencyContactController.text =
              (_userData?['emergencyContactNumber'] ?? '').toString();
          _employeeIdController.text = (_userData?['employeeId'] ?? '')
              .toString();
          _roleController.text = (_userData?['role'] ?? '').toString();
          _isLoadingData = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoadingData = false;
      });
      print('Error loading user data: $e');
    }
  }

  @override
  void dispose() {
    _departmentController.dispose();
    _addressController.dispose();
    _mobileController.dispose();
    _alternateController.dispose();
    _bloodGroupController.dispose();
    _aadharController.dispose();
    _panController.dispose();
    _employeeIdController.dispose();
    _roleController.dispose();
    _totalExperienceController.dispose();
    _emergencyContactController.dispose();
    super.dispose();
  }

  Future<void> _saveChanges() async {
    final provider = Provider.of<EmployeeManagementProvider>(
      context,
      listen: false,
    );

    final success = await provider.updateEmployee(
      employeeId: widget.employee.id,
      employeeIdValue: _employeeIdController.text.trim().isEmpty
          ? null
          : _employeeIdController.text.trim(),
      department: _departmentController.text.trim().isEmpty
          ? null
          : _departmentController.text.trim(),
      role: _roleController.text.trim().isEmpty
          ? null
          : _roleController.text.trim(),
      totalExperience: _totalExperienceController.text.trim().isEmpty
          ? null
          : _totalExperienceController.text.trim(),
      emergencyContactNumber: _emergencyContactController.text.trim().isEmpty
          ? null
          : _emergencyContactController.text.trim(),
      joiningDate: _selectedDate,
      // Don't update personal and contact info - user manages these
      address: null,
      mobileNumber: null,
      alternateNumber: null,
      bloodGroup: null,
      aadharNumber: _aadharController.text.trim(),
      panCardNumber: _panController.text.trim(),
    );

    if (success) {
      setState(() {
        _isEditing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Employee details updated successfully',
            style: getTextTheme().bodyMedium?.copyWith(color: Colors.white),
          ),
          backgroundColor: Colors.green,
        ),
      );
      // Reload data
      await _loadUserData();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            provider.errorMessage ?? 'Failed to update employee',
            style: getTextTheme().bodyMedium?.copyWith(color: Colors.white),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Employee Details',
          style: getTextTheme().titleLarge?.copyWith(color: Colors.white),
        ),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
          if (!_isEditing)
            IconButton(
              icon: Icon(Icons.edit, size: 24.r),
              onPressed: () {
                setState(() {
                  _isEditing = true;
                });
              },
              tooltip: 'Edit',
            ),
          if (_isEditing)
            IconButton(
              icon: Icon(Icons.close, size: 24.r),
              onPressed: () {
                setState(() {
                  _isEditing = false;
                  // Reset values
                  _departmentController.text = widget.employee.department ?? '';
                  _selectedDate = widget.employee.joiningDate;
                  _addressController.text = (_userData?['address'] ?? '')
                      .toString();
                  _mobileController.text = (_userData?['mobileNumber'] ?? '')
                      .toString();
                  _alternateController.text =
                      (_userData?['alternateNumber'] ?? '').toString();
                  _bloodGroupController.text = (_userData?['bloodGroup'] ?? '')
                      .toString();
                  _aadharController.text = (_userData?['aadharNumber'] ?? '')
                      .toString();
                  _panController.text = (_userData?['panCardNumber'] ?? '')
                      .toString();
                  _employeeIdController.text = (_userData?['employeeId'] ?? '')
                      .toString();
                  _roleController.text = (_userData?['role'] ?? '').toString();
                  _totalExperienceController.text =
                      (_userData?['totalExperience'] ?? '').toString();
                  _emergencyContactController.text =
                      (_userData?['emergencyContactNumber'] ?? '').toString();
                });
              },
              tooltip: 'Cancel',
            ),
        ],
      ),
      body: _isLoadingData
          ? Center(child: CircularProgressIndicator(color: Colors.indigo))
          : SingleChildScrollView(
              padding: EdgeInsets.all(16.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Profile Section
                  _buildProfileSection(),
                  SizedBox(height: 24.h),

                  // Personal Information
                  _buildSectionTitle('Personal Information'),
                  SizedBox(height: 12.h),
                  _buildPersonalInfoCard(),
                  SizedBox(height: 24.h),

                  // Work Information
                  _buildSectionTitle('Work Information'),
                  SizedBox(height: 12.h),
                  _buildWorkInfoCard(),
                  SizedBox(height: 24.h),

                  // Contact Information
                  _buildSectionTitle('Contact Information'),
                  SizedBox(height: 12.h),
                  _buildContactInfoCard(),
                  SizedBox(height: 24.h),

                  // Admin Only Fields
                  _buildSectionTitle('Document Information (Admin Only)'),
                  SizedBox(height: 12.h),
                  _buildDocumentInfoCard(),
                  SizedBox(height: 24.h),

                  // Save Button
                  if (_isEditing)
                    SizedBox(
                      width: double.infinity,
                      height: 50.h,
                      child: ElevatedButton(
                        onPressed: _saveChanges,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.indigo,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                        ),
                        child: Text(
                          'Save Changes',
                          style: getTextTheme().titleMedium?.copyWith(
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildProfileSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(24.w),
        child: Column(
          children: [
            // Profile Picture
            CircleAvatar(
              radius: 60.r,
              backgroundColor: Colors.indigo.shade100,
              child:
                  widget.employee.profileImageUrl != null &&
                      widget.employee.profileImageUrl!.isNotEmpty
                  ? ClipOval(
                      child: CachedNetworkImage(
                        imageUrl: widget.employee.profileImageUrl!,
                        width: 120.w,
                        height: 120.h,
                        fit: BoxFit.cover,
                        placeholder: (context, url) =>
                            CircularProgressIndicator(color: Colors.indigo),
                        errorWidget: (context, url, error) => Text(
                          widget.employee.name.isNotEmpty
                              ? widget.employee.name[0].toUpperCase()
                              : 'E',
                          style: getTextTheme().displayLarge?.copyWith(
                            color: Colors.indigo,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    )
                  : Text(
                      widget.employee.name.isNotEmpty
                          ? widget.employee.name[0].toUpperCase()
                          : 'E',
                      style: getTextTheme().displayLarge?.copyWith(
                        color: Colors.indigo,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
            SizedBox(height: 16.h),

            // Name
            Text(
              widget.employee.name,
              style: getTextTheme().headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8.h),

            // Email
            Text(
              widget.employee.email,
              style: getTextTheme().bodyLarge?.copyWith(
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 16.h),

            // Status Chip
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
              decoration: BoxDecoration(
                color: widget.employee.isOnboarded
                    ? Colors.green.shade50
                    : Colors.orange.shade50,
                borderRadius: BorderRadius.circular(20.r),
                border: Border.all(
                  color: widget.employee.isOnboarded
                      ? Colors.green
                      : Colors.orange,
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    widget.employee.isOnboarded
                        ? Icons.check_circle
                        : Icons.pending,
                    color: widget.employee.isOnboarded
                        ? Colors.green
                        : Colors.orange,
                    size: 18.r,
                  ),
                  SizedBox(width: 8.w),
                  Text(
                    widget.employee.isOnboarded ? 'Onboarded' : 'Pending',
                    style: getTextTheme().bodyMedium?.copyWith(
                      color: widget.employee.isOnboarded
                          ? Colors.green
                          : Colors.orange,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: getTextTheme().titleLarge?.copyWith(
        fontWeight: FontWeight.bold,
        color: Colors.indigo,
      ),
    );
  }

  Widget _buildPersonalInfoCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
      color: Colors.grey.shade50,
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          children: [
            Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: Colors.blue.shade700,
                  size: 18.r,
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: Text(
                    'User manages this information from their profile',
                    style: getTextTheme().bodySmall?.copyWith(
                      color: Colors.blue.shade900,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
            Divider(height: 24.h),
            _buildStaticDetailRow(
              'Address',
              _addressController.text.isEmpty
                  ? 'Not Set'
                  : _addressController.text,
              Icons.home,
            ),
            Divider(height: 24.h),
            _buildStaticDetailRow(
              'Blood Group',
              _bloodGroupController.text.isEmpty
                  ? 'Not Set'
                  : _bloodGroupController.text,
              Icons.bloodtype,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkInfoCard() {
    final dateFormat = DateFormat('dd/MM/yyyy');

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          children: [
            _buildDetailRow(
              'Employee ID',
              _employeeIdController,
              Icons.badge,
              isEditable: true,
            ),
            Divider(height: 24.h),
            _buildDetailRow(
              'Department',
              _departmentController,
              Icons.work,
              isEditable: true,
            ),
            Divider(height: 24.h),
            _buildDetailRow(
              'Role',
              _roleController,
              Icons.person_outline,
              isEditable: true,
            ),
            Divider(height: 24.h),
            _buildDetailRow(
              'Total Experience',
              _totalExperienceController,
              Icons.timeline,
              isEditable: true,
            ),
            Divider(height: 24.h),
            _buildDateRow(
              'Joining Date',
              _selectedDate,
              dateFormat,
              Icons.calendar_today,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactInfoCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
      color: Colors.grey.shade50,
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          children: [
            Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: Colors.blue.shade700,
                  size: 18.r,
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: Text(
                    'User manages this information from their profile',
                    style: getTextTheme().bodySmall?.copyWith(
                      color: Colors.blue.shade900,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
            Divider(height: 24.h),
            _buildStaticDetailRow(
              'Mobile Number',
              _mobileController.text.isEmpty
                  ? 'Not Set'
                  : _mobileController.text,
              Icons.phone,
            ),
            Divider(height: 24.h),
            _buildStaticDetailRow(
              'Alternate Number',
              _alternateController.text.isEmpty
                  ? 'Not Set'
                  : _alternateController.text,
              Icons.phone_android,
            ),
            Divider(height: 24.h),
            _buildDetailRow(
              'Emergency Contact',
              _emergencyContactController,
              Icons.emergency,
              isEditable: true,
              keyboardType: TextInputType.phone,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentInfoCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
      color: Colors.amber.shade50,
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          children: [
            Row(
              children: [
                Icon(Icons.security, color: Colors.amber.shade700, size: 20.r),
                SizedBox(width: 8.w),
                Expanded(
                  child: Text(
                    'These fields are visible and editable only by admins',
                    style: getTextTheme().bodySmall?.copyWith(
                      color: Colors.amber.shade900,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
            Divider(height: 24.h),
            _buildDetailRow(
              'Aadhar Number',
              _aadharController,
              Icons.credit_card,
              isEditable: true,
              keyboardType: TextInputType.number,
            ),
            Divider(height: 24.h),
            _buildDetailRow(
              'PAN Card Number',
              _panController,
              Icons.payment,
              isEditable: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStaticDetailRow(String label, String value, IconData icon) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20.r, color: Colors.indigo),
        SizedBox(width: 12.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: getTextTheme().bodySmall?.copyWith(
                  color: Colors.grey.shade600,
                ),
              ),
              SizedBox(height: 4.h),
              Text(
                value,
                style: getTextTheme().bodyLarge?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(
    String label,
    TextEditingController controller,
    IconData icon, {
    bool isEditable = false,
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20.r, color: Colors.indigo),
        SizedBox(width: 12.w),
        Expanded(
          child: _isEditing && isEditable
              ? TextField(
                  controller: controller,
                  maxLines: maxLines,
                  keyboardType: keyboardType,
                  decoration: InputDecoration(
                    labelText: label,
                    labelStyle: getTextTheme().bodyMedium,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12.w,
                      vertical: 8.h,
                    ),
                  ),
                  style: getTextTheme().bodyLarge,
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: getTextTheme().bodySmall?.copyWith(
                        color: Colors.grey.shade600,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      controller.text.isEmpty ? 'Not Set' : controller.text,
                      style: getTextTheme().bodyLarge?.copyWith(
                        fontWeight: FontWeight.w500,
                        color: controller.text.isEmpty
                            ? Colors.grey.shade400
                            : null,
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildDateRow(
    String label,
    DateTime? date,
    DateFormat format,
    IconData icon,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20.r, color: Colors.indigo),
        SizedBox(width: 12.w),
        Expanded(
          child: _isEditing
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: getTextTheme().bodySmall?.copyWith(
                        color: Colors.grey.shade600,
                      ),
                    ),
                    SizedBox(height: 8.h),
                    InkWell(
                      onTap: () async {
                        final DateTime? picked = await showDatePicker(
                          context: context,
                          initialDate: _selectedDate ?? DateTime.now(),
                          firstDate: DateTime(2000),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null) {
                          setState(() {
                            _selectedDate = picked;
                          });
                        }
                      },
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 12.w,
                          vertical: 12.h,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _selectedDate != null
                                  ? format.format(_selectedDate!)
                                  : 'Select Date',
                              style: getTextTheme().bodyLarge,
                            ),
                            Icon(Icons.edit_calendar, size: 20.r),
                          ],
                        ),
                      ),
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: getTextTheme().bodySmall?.copyWith(
                        color: Colors.grey.shade600,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      date != null ? format.format(date) : 'Not Set',
                      style: getTextTheme().bodyLarge?.copyWith(
                        fontWeight: FontWeight.w500,
                        color: date == null ? Colors.grey.shade400 : null,
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}
