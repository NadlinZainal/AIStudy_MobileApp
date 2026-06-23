import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../providers/auth_provider.dart';
import '../utils/custom_snackbar.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  
  String? _profileImagePath;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().user;
    if (user != null) {
      _nameController.text = user.name;
      _emailController.text = user.email;
      _profileImagePath = user.profileImageUrl;
    }
  }

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      // Save image to local directory
      final appDir = await getApplicationDocumentsDirectory();
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${p.basename(pickedFile.path)}';
      final savedImage = await File(pickedFile.path).copy('${appDir.path}/$fileName');
      
      setState(() {
        _profileImagePath = savedImage.path;
      });
    }
  }

  void _saveProfile() async {
    if (_nameController.text.isEmpty || _emailController.text.isEmpty) {
      CustomSnackBar.show(
        context,
        message: 'Name and email cannot be empty',
        type: SnackBarType.error,
      );
      return;
    }
    
    await context.read<AuthProvider>().updateProfile(
      _nameController.text,
      _emailController.text,
      _profileImagePath,
    );
    
    if (mounted) {
      CustomSnackBar.show(
        context,
        message: 'Profile updated successfully!',
        type: SnackBarType.success,
      );
      Navigator.pop(context);
    }
  }

  void _changePassword() async {
    if (_currentPasswordController.text.isEmpty || _newPasswordController.text.isEmpty) {
      CustomSnackBar.show(
        context,
        message: 'Please fill both password fields',
        type: SnackBarType.error,
      );
      return;
    }
    
    final success = await context.read<AuthProvider>().updatePassword(
      _currentPasswordController.text,
      _newPasswordController.text,
    );
    
    if (mounted) {
      if (success) {
        CustomSnackBar.show(
          context,
          message: 'Password updated successfully!',
          type: SnackBarType.success,
        );
        _currentPasswordController.clear();
        _newPasswordController.clear();
      } else {
        CustomSnackBar.show(
          context,
          message: 'Incorrect current password',
          type: SnackBarType.error,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          'Edit Profile',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: authProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                children: [
                  // Top Gradient Header with Avatar (consistent with ProfileScreen)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.only(top: 110, bottom: 40),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isDark
                            ? const [Color(0xFF0B0F19), Color(0xFF1E1B4B)]
                            : [colorScheme.primary, colorScheme.secondary],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(40),
                        bottomRight: Radius.circular(40),
                      ),
                    ),
                    child: Center(
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 4),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.15),
                              blurRadius: 12,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Stack(
                          children: [
                            CircleAvatar(
                              radius: 54,
                              backgroundColor: Colors.white.withValues(alpha: 0.2),
                              backgroundImage: _profileImagePath != null && File(_profileImagePath!).existsSync()
                                  ? FileImage(File(_profileImagePath!))
                                  : null,
                              child: _profileImagePath == null || !File(_profileImagePath!).existsSync()
                                  ? const Icon(Icons.person, size: 54, color: Colors.white)
                                  : null,
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: GestureDetector(
                                onTap: _pickImage,
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF1E1B4B) : colorScheme.primary,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 2),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.1),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(Icons.camera_alt, color: Colors.white, size: 18),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Forms and details
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 600),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Section: Personal Details
                            _buildSectionHeader(context, 'Personal Details'),
                            const SizedBox(height: 20),

                            TextField(
                              controller: _nameController,
                              style: const TextStyle(fontSize: 15),
                              decoration: InputDecoration(
                                labelText: 'Name',
                                labelStyle: TextStyle(color: colorScheme.primary.withValues(alpha: 0.8)),
                                filled: true,
                                fillColor: colorScheme.primary.withValues(alpha: 0.05),
                                prefixIcon: Icon(Icons.person_outline_rounded, color: colorScheme.primary, size: 22),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(color: colorScheme.primary.withValues(alpha: 0.15)),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(color: colorScheme.primary.withValues(alpha: 0.15)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              ),
                            ),
                            const SizedBox(height: 16),

                            TextField(
                              controller: _emailController,
                              style: const TextStyle(fontSize: 15),
                              keyboardType: TextInputType.emailAddress,
                              decoration: InputDecoration(
                                labelText: 'Email',
                                labelStyle: TextStyle(color: colorScheme.primary.withValues(alpha: 0.8)),
                                filled: true,
                                fillColor: colorScheme.primary.withValues(alpha: 0.05),
                                prefixIcon: Icon(Icons.mail_outline_rounded, color: colorScheme.primary, size: 22),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(color: colorScheme.primary.withValues(alpha: 0.15)),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(color: colorScheme.primary.withValues(alpha: 0.15)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              ),
                            ),
                            const SizedBox(height: 24),

                            ElevatedButton.icon(
                              onPressed: _saveProfile,
                              icon: const Icon(Icons.check_rounded, color: Colors.white, size: 20),
                              label: const Text(
                                'Save Profile',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: colorScheme.primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                elevation: 1,
                              ),
                            ),
                            
                            const SizedBox(height: 40),

                            // Section: Change Password
                            _buildSectionHeader(context, 'Change Password'),
                            const SizedBox(height: 20),

                            TextField(
                              controller: _currentPasswordController,
                              style: const TextStyle(fontSize: 15),
                              obscureText: true,
                              decoration: InputDecoration(
                                labelText: 'Current Password',
                                labelStyle: TextStyle(color: colorScheme.primary.withValues(alpha: 0.8)),
                                filled: true,
                                fillColor: colorScheme.primary.withValues(alpha: 0.05),
                                prefixIcon: Icon(Icons.lock_outline_rounded, color: colorScheme.primary, size: 22),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(color: colorScheme.primary.withValues(alpha: 0.15)),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(color: colorScheme.primary.withValues(alpha: 0.15)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              ),
                            ),
                            const SizedBox(height: 16),

                            TextField(
                              controller: _newPasswordController,
                              style: const TextStyle(fontSize: 15),
                              obscureText: true,
                              decoration: InputDecoration(
                                labelText: 'New Password',
                                labelStyle: TextStyle(color: colorScheme.primary.withValues(alpha: 0.8)),
                                filled: true,
                                fillColor: colorScheme.primary.withValues(alpha: 0.05),
                                prefixIcon: Icon(Icons.lock_reset_rounded, color: colorScheme.primary, size: 22),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(color: colorScheme.primary.withValues(alpha: 0.15)),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(color: colorScheme.primary.withValues(alpha: 0.15)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              ),
                            ),
                            const SizedBox(height: 24),

                            OutlinedButton.icon(
                              onPressed: _changePassword,
                              icon: Icon(Icons.lock_outline, color: colorScheme.primary, size: 20),
                              label: const Text(
                                'Change Password',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: colorScheme.primary,
                                side: BorderSide(color: colorScheme.primary, width: 1.2),
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                            ),
                            
                            const SizedBox(height: 40),

                            // Section: Danger Zone
                            _buildSectionHeader(context, 'Danger Zone', color: Colors.redAccent),
                            const SizedBox(height: 20),

                            OutlinedButton.icon(
                              onPressed: _confirmDeleteAccount,
                              icon: const Icon(Icons.delete_forever_rounded, color: Colors.redAccent, size: 20),
                              label: const Text(
                                'Delete Account',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.redAccent),
                              ),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Colors.redAccent, width: 1.2),
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  void _confirmDeleteAccount() {
    final authProvider = context.read<AuthProvider>();
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 28),
              SizedBox(width: 10),
              Text('Delete Account?'),
            ],
          ),
          content: const Text(
            'Are you sure you want to permanently delete your account and all study data? This action is irreversible.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(dialogContext); // Close dialog
                final success = await authProvider.deleteAccount();
                if (mounted) {
                  if (success) {
                    CustomSnackBar.show(
                      context,
                      message: 'Account successfully deleted.',
                      type: SnackBarType.success,
                    );
                  } else {
                    CustomSnackBar.show(
                      context,
                      message: 'Failed to delete account. Please log out and back in first.',
                      type: SnackBarType.error,
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Delete Permanently'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title, {Color? color}) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            color: color ?? theme.colorScheme.primary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            letterSpacing: 0.3,
            color: color,
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    super.dispose();
  }
}
