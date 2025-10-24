import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/auth_provider.dart';
import '../services/supabase_service.dart';
import '../models/user_model.dart';
import 'dart:io';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ImagePicker _picker = ImagePicker();
  bool _isUploading = false;

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
          
          final imageUrl = await SupabaseService.uploadProfileImage(userId, bytes);

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
        title: const Text('Profile'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Consumer<AuthProvider>(
        builder: (context, authProvider, child) {
          final UserModel? user = authProvider.userModel;
          
          if (user == null) {
            return const Center(
              child: Text('No user data available'),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 20),
                
                // Profile Image Section
                Stack(
                  children: [
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.blue,
                          width: 3,
                        ),
                      ),
                      child: ClipOval(
                        child: user.profileImageUrl != null && user.profileImageUrl!.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: user.profileImageUrl!,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => const CircularProgressIndicator(),
                                errorWidget: (context, url, error) => const Icon(
                                  Icons.person,
                                  size: 60,
                                  color: Colors.grey,
                                ),
                              )
                            : const Icon(
                                Icons.person,
                                size: 60,
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
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(
                                  Icons.camera_alt,
                                  color: Colors.white,
                                  size: 20,
                                ),
                          onPressed: _isUploading ? null : _showImageSourceDialog,
                        ),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 30),
                
                // User Information Cards
                Card(
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Personal Information',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        _buildInfoRow(Icons.person, 'Name', user.name),
                        const SizedBox(height: 12),
                        _buildInfoRow(Icons.email, 'Email', user.email),
                        const SizedBox(height: 12),
                        _buildInfoRow(Icons.badge, 'Employee ID', user.employeeId ?? 'N/A'),
                        const SizedBox(height: 12),
                        _buildInfoRow(Icons.work, 'Department', user.department ?? 'N/A'),
                        const SizedBox(height: 12),
                        _buildInfoRow(Icons.admin_panel_settings, 'Role', user.isAdmin ? 'Admin' : 'Employee'),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // Additional Actions
                Card(
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Account Actions',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        ListTile(
                          leading: const Icon(Icons.edit, color: Colors.blue),
                          title: const Text('Edit Profile'),
                          trailing: const Icon(Icons.arrow_forward_ios),
                          onTap: () {
                            // TODO: Navigate to edit profile screen
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Edit profile feature coming soon!'),
                              ),
                            );
                          },
                        ),
                        
                        const Divider(),
                        
                        ListTile(
                          leading: const Icon(Icons.logout, color: Colors.red),
                          title: const Text('Logout'),
                          trailing: const Icon(Icons.arrow_forward_ios),
                          onTap: () {
                            showDialog(
                              context: context,
                              builder: (BuildContext context) {
                                return AlertDialog(
                                  title: const Text('Logout'),
                                  content: const Text('Are you sure you want to logout?'),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text('Cancel'),
                                    ),
                                    TextButton(
                                      onPressed: () {
                                        Navigator.pop(context);
                                        authProvider.logout();
                                      },
                                      child: const Text('Logout'),
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
        Icon(icon, color: Colors.blue, size: 20),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              color: Colors.grey,
            ),
          ),
        ),
        Expanded(
          flex: 3,
          child: Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}