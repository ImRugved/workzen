import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../../app_constants.dart';
import '../../providers/auth_provider.dart';
import '../../providers/employee_details_provider.dart';
import '../../providers/employee_management_provider.dart';
import '../../widgets/device_info_card.dart';
import '../../widgets/sub_admin_permissions_picker.dart';
import '../../models/employee_model.dart';
import '../../models/department_model.dart';
import '../../models/user_model.dart';
import '../../constants/const_textstyle.dart';
import '../../constants/constant_textfield.dart';
import '../../constants/constant_snackbar.dart';
import '../../utils/validators.dart';
import '../../constants/constant_button.dart';
import '../../constants/constant_dropdown.dart';
import '../../constants/constant_date_time_picker.dart';
import '../../constants/constant_colors.dart';
import '../../constants/app_theme.dart';
import '../../constants/apploading_indicator.dart';

/// Admin view of one employee. All state (loaded data, edit mode, the values
/// being edited, sub admin access) lives in [EmployeeDetailsProvider]; this
/// widget only owns the text controllers, which need a lifecycle.
class EmployeeDetailsScreen extends StatefulWidget {
  final EmployeeModel employee;

  /// Opens straight in edit mode (the Edit button of the employee table).
  final bool startInEditMode;

  const EmployeeDetailsScreen({
    Key? key,
    required this.employee,
    this.startInEditMode = false,
  }) : super(key: key);

  @override
  State<EmployeeDetailsScreen> createState() => _EmployeeDetailsScreenState();
}

class _EmployeeDetailsScreenState extends State<EmployeeDetailsScreen> {
  final EmployeeDetailsProvider _details = EmployeeDetailsProvider();

  final _employeeIdController = TextEditingController();
  final _totalExperienceController = TextEditingController();
  final _emergencyContactController = TextEditingController();
  final _aadharController = TextEditingController();
  final _panController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadDetails();

    // Departments for the edit dropdowns
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<EmployeeManagementProvider>().fetchDepartments();
    });
  }

  Future<void> _loadDetails() async {
    await _details.load(widget.employee.id);
    _fillControllers();
    if (widget.startInEditMode && mounted && _details.user != null) {
      _details.startEditing();
    }
  }

  // Puts the saved values into the edit fields
  void _fillControllers() {
    final user = _details.user;
    _employeeIdController.text = user?.employeeId ?? '';
    _totalExperienceController.text = user?.totalExperience ?? '';
    _emergencyContactController.text = user?.emergencyContactNumber ?? '';
    _aadharController.text = user?.aadharNumber ?? '';
    _panController.text = user?.panCardNumber ?? '';
  }

  @override
  void dispose() {
    _employeeIdController.dispose();
    _totalExperienceController.dispose();
    _emergencyContactController.dispose();
    _aadharController.dispose();
    _panController.dispose();
    _details.dispose();
    super.dispose();
  }

  String? _orNull(TextEditingController c) =>
      c.text.trim().isEmpty ? null : c.text.trim();

  Future<void> _saveChanges() async {
    final provider = context.read<EmployeeManagementProvider>();

    final success = await provider.updateEmployee(
      employeeId: widget.employee.id,
      employeeIdValue: _orNull(_employeeIdController),
      department: _details.department.isEmpty ? null : _details.department,
      employmentRole: _details.employmentRole,
      jobRole: _details.role.isEmpty ? null : _details.role,
      totalExperience: _orNull(_totalExperienceController),
      emergencyContactNumber: _orNull(_emergencyContactController),
      joiningDate: _details.joiningDate,
      // Personal and contact info is managed by the employee
      address: null,
      mobileNumber: null,
      alternateNumber: null,
      bloodGroup: null,
      aadharNumber: _aadharController.text.trim(),
      panCardNumber: _panController.text.trim(),
    );

    if (success) {
      await _details.load(widget.employee.id);
      _details.stopEditing();
      _fillControllers();
      ConstantSnackbar.showSuccess(title: 'Employee details updated');
    } else {
      ConstantSnackbar.showError(
        title: provider.errorMessage ?? 'Failed to update employee',
      );
    }
  }

  Future<void> _savePermissions() async {
    final ok = await _details.savePermissions(widget.employee.id);
    if (ok) {
      ConstantSnackbar.showSuccess(title: 'Sub admin access saved');
    } else {
      ConstantSnackbar.showError(title: 'Failed to save access');
    }
  }

  // Clears the binding so the employee's next login registers a new device
  Future<void> _confirmResetDevice() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Reset Device?'),
        content: Text(
          '${widget.employee.name} will not be able to punch in or out until they log in again. Their next login will register that phone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          ConstantButton(
            text: 'Reset',
            onPressed: () => Navigator.pop(c, true),
            isFullWidth: false,
            height: 40.h,
            backgroundColor: ConstColors.errorRed,
          ),
        ],
      ),
    );
    if (confirm != true) return;

    final ok = await _details.resetDevice(widget.employee.id);
    if (ok) {
      ConstantSnackbar.showSuccess(title: 'Device reset');
    } else {
      ConstantSnackbar.showError(title: 'Failed to reset device');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<EmployeeDetailsProvider>.value(
      value: _details,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            'Employee Details',
            style: getTextTheme().titleLarge?.copyWith(
              color: ConstColors.textColor,
            ),
          ),
          backgroundColor: ConstColors.primary,
          foregroundColor: ConstColors.textColor,
          actions: [
            // Only the edit mode flag matters here, so Selector
            Selector<EmployeeDetailsProvider, bool>(
              selector: (_, d) => d.isEditing,
              builder: (_, editing, __) => editing
                  ? IconButton(
                      icon: Icon(Icons.close, size: 24.r),
                      onPressed: () {
                        _details.stopEditing();
                        _fillControllers();
                      },
                      tooltip: 'Cancel',
                    )
                  : IconButton(
                      icon: Icon(Icons.edit, size: 24.r),
                      onPressed: _details.startEditing,
                      tooltip: 'Edit',
                    ),
            ),
          ],
        ),
        body: Consumer<EmployeeDetailsProvider>(
          builder: (context, details, _) {
            if (details.isLoading) {
              return const Center(
                child: AppLoadingIndicator(
                  size: 40,
                  color: ConstColors.primaryDeep,
                ),
              );
            }

            final user = details.user;
            if (user == null) {
              return Center(
                child: Text(
                  'Employee not found',
                  style: getTextTheme().bodyLarge,
                ),
              );
            }

            final isAdmin = context.read<AuthProvider>().isAdmin;

            return SafeArea(
              child: SingleChildScrollView(
                padding: AppSpacing.screen,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildProfileSection(),
                    SizedBox(height: 24.h),

                    // Registered device (attendance device binding)
                    DeviceInfoCard(
                      deviceInfo: details.device,
                      onReset: details.device == null
                          ? null
                          : _confirmResetDevice,
                      emptyMessage:
                          'No device registered yet. It is registered automatically when the employee logs in for the first time.',
                    ),
                    SizedBox(height: 24.h),

                    // Sub admin access: only an admin can change it
                    if (widget.employee.isSubAdmin && isAdmin) ...[
                      _buildSectionTitle('Sub Admin Access'),
                      SizedBox(height: 12.h),
                      _buildPermissionsCard(details),
                      SizedBox(height: 24.h),
                    ],

                    _buildSectionTitle('Personal Information'),
                    SizedBox(height: 12.h),
                    _buildPersonalInfoCard(user),
                    SizedBox(height: 24.h),

                    _buildSectionTitle('Work Information'),
                    SizedBox(height: 12.h),
                    _buildWorkInfoCard(details, user),
                    SizedBox(height: 24.h),

                    _buildSectionTitle('Contact Information'),
                    SizedBox(height: 12.h),
                    _buildContactInfoCard(details, user),
                    SizedBox(height: 24.h),

                    _buildSectionTitle('Document Information (Admin Only)'),
                    SizedBox(height: 12.h),
                    _buildDocumentInfoCard(details, user),
                    SizedBox(height: 24.h),

                    if (details.isEditing)
                      ConstantButton(
                        text: 'Save Changes',
                        onPressed: _saveChanges,
                        backgroundColor: ConstColors.primary,
                        borderRadius: 12.r,
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildProfileSection() {
    final employee = widget.employee;

    return NeuCard(
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 24.h),
        child: Column(
          children: [
            CircleAvatar(
              radius: 60.r,
              backgroundColor: ConstColors.lightShade,
              child:
                  employee.profileImageUrl != null &&
                      employee.profileImageUrl!.isNotEmpty
                  ? ClipOval(
                      child: CachedNetworkImage(
                        imageUrl: employee.profileImageUrl!,
                        width: 120.w,
                        height: 120.h,
                        fit: BoxFit.cover,
                        placeholder: (context, url) =>
                            const AppLoadingIndicator(
                              size: 40,
                              color: ConstColors.primaryDeep,
                            ),
                        errorWidget: (context, url, error) =>
                            _avatarInitial(employee),
                      ),
                    )
                  : _avatarInitial(employee),
            ),
            SizedBox(height: 16.h),
            Text(
              employee.name,
              style: getTextTheme().headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8.h),
            Text(
              employee.email,
              style: getTextTheme().bodyLarge?.copyWith(
                color: ConstColors.textColorLight,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 16.h),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
              decoration: BoxDecoration(
                color:
                    (employee.isOnboarded
                            ? ConstColors.successGreen
                            : ConstColors.inProgressOrange)
                        .withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20.r),
                border: Border.all(
                  color: employee.isOnboarded
                      ? ConstColors.successGreen
                      : ConstColors.inProgressOrange,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    employee.isOnboarded ? Icons.check_circle : Icons.pending,
                    color: employee.isOnboarded
                        ? ConstColors.successGreen
                        : ConstColors.inProgressOrange,
                    size: 18.r,
                  ),
                  SizedBox(width: 8.w),
                  Text(
                    employee.isOnboarded ? 'Onboarded' : 'Pending',
                    style: getTextTheme().bodyMedium?.copyWith(
                      color: employee.isOnboarded
                          ? ConstColors.successGreen
                          : ConstColors.inProgressOrange,
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

  Widget _avatarInitial(EmployeeModel employee) {
    return Text(
      employee.name.isNotEmpty ? employee.name[0].toUpperCase() : 'E',
      style: getTextTheme().displayLarge?.copyWith(
        color: ConstColors.primaryDeep,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildPermissionsCard(EmployeeDetailsProvider details) {
    return Column(
      children: [
        SubAdminPermissionsPicker(
          selected: details.permissions,
          onChanged: details.setPermission,
          onSelectAll: details.setAllPermissions,
        ),
        SizedBox(height: 8.h),
        SizedBox(
          width: double.infinity,
          child: ConstantButton(
            text: 'Save Access',
            isLoading: details.isSavingPermissions,
            onPressed: _savePermissions,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: getTextTheme().titleLarge?.copyWith(
        fontWeight: FontWeight.bold,
        color: ConstColors.primaryDeep,
      ),
    );
  }

  Widget _infoNote(String text, {Color? color}) {
    return Row(
      children: [
        Icon(Icons.info_outline, color: ConstColors.primaryDeep, size: 18.r),
        SizedBox(width: 8.w),
        Expanded(
          child: Text(
            text,
            style: getTextTheme().bodySmall?.copyWith(
              color: color ?? ConstColors.primaryDeep,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      ],
    );
  }

  String _orNotSet(String? value) =>
      (value == null || value.isEmpty) ? 'Not Set' : value;

  Widget _buildPersonalInfoCard(UserModel user) {
    return NeuCard(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
        child: Column(
          children: [
            _infoNote('User manages this information from their profile'),
            Divider(height: 24.h),
            _buildStaticDetailRow(
              'Address',
              _orNotSet(user.address),
              Icons.home,
            ),
            Divider(height: 24.h),
            _buildStaticDetailRow(
              'Blood Group',
              _orNotSet(user.bloodGroup),
              Icons.bloodtype,
            ),
            Divider(height: 24.h),
            _buildStaticDetailRow(
              'Date of Birth',
              user.dateOfBirth == null
                  ? 'Not Set'
                  : DateFormat('dd/MM/yyyy').format(user.dateOfBirth!),
              Icons.cake_outlined,
            ),
            Divider(height: 24.h),
            _buildStaticDetailRow(
              'Gender',
              _orNotSet(user.gender),
              Icons.wc_outlined,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkInfoCard(EmployeeDetailsProvider details, UserModel user) {
    final dateFormat = DateFormat('dd/MM/yyyy');
    final editing = details.isEditing;

    return NeuCard(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
        child: Column(
          children: [
            _buildDetailRow(
              details,
              'Employee ID',
              _employeeIdController,
              user.employeeId,
              Icons.badge,
            ),
            Divider(height: 24.h),
            _buildEmploymentRoleRow(details, user),
            Divider(height: 24.h),
            _buildDepartmentRow(details, user),
            Divider(height: 24.h),
            _buildRoleRow(details, user),
            Divider(height: 24.h),
            _buildDetailRow(
              details,
              'Total Experience',
              _totalExperienceController,
              user.totalExperience,
              Icons.timeline,
            ),
            Divider(height: 24.h),
            _buildDateRow(
              'Joining Date',
              editing ? details.joiningDate : user.joiningDate,
              dateFormat,
              editing,
            ),
          ],
        ),
      ),
    );
  }

  // Department: a dropdown while editing, plain text otherwise
  Widget _buildDepartmentRow(EmployeeDetailsProvider details, UserModel user) {
    if (!details.isEditing) {
      return Row(
        children: [
          Expanded(
            child: _buildStaticDetailRow(
              'Department',
              _orNotSet(user.department),
              Icons.work,
            ),
          ),
          IconButton(
            icon: Icon(Icons.edit, size: 18.r, color: ConstColors.primaryDeep),
            onPressed: details.startEditing,
            tooltip: 'Edit Work Info',
          ),
        ],
      );
    }

    return Consumer<EmployeeManagementProvider>(
      builder: (context, departments, _) {
        if (departments.departments.isEmpty) {
          return _warningRow(
            Icons.work,
            'Please add departments first from Admin Dashboard > Departments & Roles',
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.work, size: 20.r, color: ConstColors.primaryDeep),
            SizedBox(width: 12.w),
            Expanded(
              child: ConstantDropdown<String>(
                key: ValueKey('dept-${details.department}'),
                value: details.department,
                label: 'Department',
                items: departments.departments.map((d) => d.name).toList(),
                itemLabel: (d) => d,
                onChanged: details.setDepartment,
              ),
            ),
          ],
        );
      },
    );
  }

  // Role: employee / intern / freelancer (dropdown while editing)
  Widget _buildEmploymentRoleRow(
    EmployeeDetailsProvider details,
    UserModel user,
  ) {
    if (!details.isEditing) {
      return _buildStaticDetailRow(
        'Role',
        user.roleLabel,
        Icons.admin_panel_settings,
      );
    }

    return Row(
      children: [
        Icon(
          Icons.admin_panel_settings,
          size: 20.r,
          color: ConstColors.primaryDeep,
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: ConstantDropdown<String>(
            value: details.employmentRole,
            label: 'Role',
            items: AppConstants.assignableRoles,
            itemLabel: AppConstants.roleLabel,
            onChanged: details.setEmploymentRole,
          ),
        ),
      ],
    );
  }

  // Job role: a dropdown of the chosen department's roles while editing
  Widget _buildRoleRow(EmployeeDetailsProvider details, UserModel user) {
    if (!details.isEditing) {
      return _buildStaticDetailRow(
        'Job Role',
        _orNotSet(user.jobRole),
        Icons.person_outline,
      );
    }

    return Consumer<EmployeeManagementProvider>(
      builder: (context, departments, _) {
        final selected = departments.departments.firstWhere(
          (d) => d.name == details.department,
          orElse: () => DepartmentModel(id: '', name: '', roles: []),
        );

        if (details.department.isEmpty) {
          return _warningRow(
            Icons.person_outline,
            'Please select a department first',
          );
        }
        if (selected.roles.isEmpty) {
          return _warningRow(
            Icons.person_outline,
            'No roles available for this department. Please add roles first',
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.person_outline,
              size: 20.r,
              color: ConstColors.primaryDeep,
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: ConstantDropdown<String>(
                key: ValueKey('role-${details.department}-${details.role}'),
                value: details.role,
                label: 'Job Role',
                items: selected.roles,
                itemLabel: (r) => r,
                onChanged: details.setRole,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _warningRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 20.r, color: ConstColors.inProgressOrange),
        SizedBox(width: 12.w),
        Expanded(
          child: Text(
            text,
            style: getTextTheme().bodyMedium?.copyWith(
              color: ConstColors.inProgressOrange,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildContactInfoCard(
    EmployeeDetailsProvider details,
    UserModel user,
  ) {
    return NeuCard(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
        child: Column(
          children: [
            _infoNote('User manages this information from their profile'),
            Divider(height: 24.h),
            _buildStaticDetailRow(
              'Mobile Number',
              _orNotSet(user.mobileNumber),
              Icons.phone,
            ),
            Divider(height: 24.h),
            _buildStaticDetailRow(
              'Alternate Number',
              _orNotSet(user.alternateNumber),
              Icons.phone_android,
            ),
            Divider(height: 24.h),
            _buildDetailRow(
              details,
              'Emergency Contact',
              _emergencyContactController,
              user.emergencyContactNumber,
              Icons.emergency,
              keyboardType: TextInputType.phone,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(10),
              ],
              validator: Validators.optionalMobileNumber,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentInfoCard(
    EmployeeDetailsProvider details,
    UserModel user,
  ) {
    return NeuCard(
      color: ConstColors.warningAmber.withValues(alpha: 0.12),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
        child: Column(
          children: [
            Row(
              children: [
                Icon(
                  Icons.security,
                  color: ConstColors.inProgressOrange,
                  size: 20.r,
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: Text(
                    'These fields are visible and editable only by admins',
                    style: getTextTheme().bodySmall?.copyWith(
                      color: ConstColors.inProgressOrange,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
            Divider(height: 24.h),
            _buildDetailRow(
              details,
              'Aadhar Number',
              _aadharController,
              user.aadharNumber,
              Icons.credit_card,
              keyboardType: TextInputType.number,
            ),
            Divider(height: 24.h),
            _buildDetailRow(
              details,
              'PAN Card Number',
              _panController,
              user.panCardNumber,
              Icons.payment,
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
        Icon(icon, size: 20.r, color: ConstColors.primaryDeep),
        SizedBox(width: 12.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: getTextTheme().bodySmall?.copyWith(
                  color: ConstColors.textColorLight,
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

  // A text field while editing, the saved value otherwise
  Widget _buildDetailRow(
    EmployeeDetailsProvider details,
    String label,
    TextEditingController controller,
    String? savedValue,
    IconData icon, {
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    List<TextInputFormatter>? inputFormatters,
  }) {
    final isEmpty = savedValue == null || savedValue.isEmpty;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20.r, color: ConstColors.primaryDeep),
        SizedBox(width: 12.w),
        Expanded(
          child: details.isEditing
              ? ConstTextField(
                  controller: controller,
                  customText: label,
                  maxline: 1,
                  keyoardType: keyboardType ?? TextInputType.text,
                  validator: validator,
                  inputFormatters: inputFormatters,
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: getTextTheme().bodySmall?.copyWith(
                        color: ConstColors.textColorLight,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      isEmpty ? 'Not Set' : savedValue,
                      style: getTextTheme().bodyLarge?.copyWith(
                        fontWeight: FontWeight.w500,
                        color: isEmpty ? ConstColors.textColorLight : null,
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
    bool editing,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.calendar_today, size: 20.r, color: ConstColors.primaryDeep),
        SizedBox(width: 12.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: getTextTheme().bodySmall?.copyWith(
                  color: ConstColors.textColorLight,
                ),
              ),
              SizedBox(height: editing ? 8.h : 4.h),
              if (editing)
                ConstantDatePicker(
                  value: date,
                  hint: 'Select Date',
                  firstDate: DateTime(2000),
                  lastDate: DateTime.now(),
                  onChanged: _details.setJoiningDate,
                )
              else
                Text(
                  date != null ? format.format(date) : 'Not Set',
                  style: getTextTheme().bodyLarge?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: date == null ? ConstColors.textColorLight : null,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
