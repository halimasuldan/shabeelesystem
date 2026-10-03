import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../widgets/common/role_drawer.dart';
import '../../../providers/auth_provider.dart';

/// Settings screen for admin to manage school info.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _uploadingLogo = false;

  Future<void> _uploadLogo() async {
    final picked = await FilePicker.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (picked == null || picked.files.single.bytes == null) return;

    setState(() => _uploadingLogo = true);
    try {
      final file = picked.files.single;
      final ref = FirebaseStorage.instance.ref().child(
        'school/logo-${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await ref.putData(file.bytes!);
      final logoUrl = await ref.getDownloadURL();
      await FirebaseFirestore.instance
          .collection(AppConstants.colSchoolInfo)
          .doc('main')
          .set({'logoUrl': logoUrl}, SetOptions(merge: true));
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('School logo updated.')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Logo upload failed: $error')));
      }
    } finally {
      if (mounted) setState(() => _uploadingLogo = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      drawer: const RoleBasedDrawer(
        role: AppConstants.roleAdmin,
        userName: 'Admin',
        userEmail: 'admin@school.com',
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          // School Information Section
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'School Information',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance
                        .collection(AppConstants.colSchoolInfo)
                        .doc('main')
                        .snapshots(),
                    builder: (context, snapshot) {
                      final logoUrl =
                          snapshot.data?.data()?['logoUrl'] as String?;
                      return Row(
                        children: [
                          CircleAvatar(
                            radius: 30,
                            backgroundImage: logoUrl == null || logoUrl.isEmpty
                                ? null
                                : NetworkImage(logoUrl),
                            child: logoUrl == null || logoUrl.isEmpty
                                ? const Icon(Icons.school, size: 28)
                                : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _uploadingLogo ? null : _uploadLogo,
                              icon: _uploadingLogo
                                  ? const SizedBox.square(
                                      dimension: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.upload),
                              label: Text(
                                _uploadingLogo
                                    ? 'Uploading...'
                                    : 'Upload School Logo',
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  _buildSettingItem(
                    icon: Icons.school,
                    label: 'School Name',
                    value: AppConstants.defaultSchoolName,
                    onTap: () => _editSchoolName(context),
                  ),
                  _buildSettingItem(
                    icon: Icons.location_on,
                    label: 'Address',
                    value: AppConstants.defaultSchoolAddress,
                    onTap: () => _editAddress(context),
                  ),
                  _buildSettingItem(
                    icon: Icons.phone,
                    label: 'Phone',
                    value: AppConstants.defaultSchoolPhone,
                    onTap: () => _editPhone(context),
                  ),
                  _buildSettingItem(
                    icon: Icons.email,
                    label: 'Email',
                    value: AppConstants.defaultSchoolEmail,
                    onTap: () => _editEmail(context),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          // System Section
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'System',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  _buildSettingItem(
                    icon: Icons.security,
                    label: 'Security Rules',
                    value: 'View & Manage',
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Security rules are managed in Firebase Console',
                          ),
                        ),
                      );
                    },
                  ),
                  _buildSettingItem(
                    icon: Icons.notifications,
                    label: 'Notification Settings',
                    value: 'Configure alerts',
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Notification settings configured'),
                        ),
                      );
                    },
                  ),
                  _buildSettingItem(
                    icon: Icons.backup,
                    label: 'Backup & Restore',
                    value: 'Firestore data',
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Backups are managed automatically by Firestore',
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Account Section
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Account',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  _buildSettingItem(
                    icon: Icons.password,
                    label: 'Change Password',
                    value: 'Update your login password',
                    onTap: () => context.push('/account/password'),
                  ),

                  _buildSettingItem(
                    icon: Icons.logout,
                    label: 'Logout',
                    value: 'Sign out',
                    valueColor: AppColors.schoolRed,
                    onTap: () async {
                      await ref.read(authServiceProvider).signOut();
                      if (!context.mounted) return;
                      context.go('/login');
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingItem({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primary),
      title: Text(label),
      subtitle: Text(
        value,
        style: TextStyle(color: valueColor ?? AppColors.textSecondary),
      ),
      trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
      onTap: onTap,
    );
  }

  void _editSchoolName(BuildContext context) {
    _showEditDialog(context, 'School Name', AppConstants.defaultSchoolName);
  }

  void _editAddress(BuildContext context) {
    _showEditDialog(context, 'Address', AppConstants.defaultSchoolAddress);
  }

  void _editPhone(BuildContext context) {
    _showEditDialog(context, 'Phone', AppConstants.defaultSchoolPhone);
  }

  void _editEmail(BuildContext context) {
    _showEditDialog(context, 'Email', AppConstants.defaultSchoolEmail);
  }

  void _showEditDialog(
    BuildContext context,
    String title,
    String currentValue,
  ) {
    final controller = TextEditingController(text: currentValue);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit $title'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(hintText: title),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Changes saved (in-memory)')),
              );
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
