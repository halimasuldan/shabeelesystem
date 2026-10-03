import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/auth_service.dart';
import '../../../models/parent_model.dart';
import '../../../widgets/common/role_drawer.dart';
import '../../../widgets/common/loading_widget.dart';
import '../../../widgets/forms/form_fields.dart';

/// Parent profile screen.
class ParentProfileScreen extends ConsumerStatefulWidget {
  const ParentProfileScreen({super.key});
  @override
  ConsumerState<ParentProfileScreen> createState() => _ParentProfileScreenState();
}

class _ParentProfileScreenState extends ConsumerState<ParentProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  _saveParent() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    final auth = AuthService();
    final userId = auth.currentUser?.uid ?? '';
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection(AppConstants.colUsers)
          .doc(userId)
          .get();
      final data = snapshot.data() as Map<String, dynamic>;
      final parent = ParentModel(
        id: userId,
        userId: userId,
        name: _nameController.text.trim(),
        email: auth.currentUser?.email ?? _emailController.text.trim(),
        phone: _phoneController.text.trim(),
        studentIds: List<String>.from(data['studentIds'] as List? ?? []),
        createdAt: DateTime.now(),
      );
      await FirebaseFirestore.instance
          .collection(AppConstants.colParents)
          .doc(userId)
          .set(parent.toMap(), SetOptions(merge: true));
      await FirebaseFirestore.instance
          .collection(AppConstants.colUsers)
          .doc(userId)
          .update({'name': parent.name, 'phone': parent.phone, 'photoUrl': parent.photoUrl});
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Profile updated!')));
        context.go('/parent/profile');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadParent();
  }

  Future<void> _loadParent() async {
    final auth = AuthService();
    final userId = auth.currentUser?.uid ?? '';
    final doc = await FirebaseFirestore.instance
        .collection(AppConstants.colParents)
        .doc(userId)
        .get();
    if (doc.exists) {
      final data = doc.data() as Map<String, dynamic>;
      setState(() {
        _nameController.text = data['name'] as String? ?? '';
        _phoneController.text = data['phone'] as String? ?? '';
        _emailController.text = auth.currentUser?.email ?? '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Parent Profile'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      drawer: RoleBasedDrawer(
        role: AppConstants.roleParent,
        userName: _nameController.text,
        userEmail: _emailController.text,
      ),
      body: _isLoading
          ? const LoadingWidget()
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  AppTextField(
                    controller: _nameController,
                    label: 'Full Name',
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  AppTextField(
                    controller: _emailController,
                    label: 'Email',
                    readOnly: true,
                  ),
                  const SizedBox(height: 12),
                  AppTextField(
                    controller: _phoneController,
                    label: 'Phone',
                    keyboardType: TextInputType.phone,
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _saveParent,
                      child: const Text('Save Changes'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
