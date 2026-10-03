import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../firebase/options.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/validators.dart';
import '../../../models/parent_model.dart';
import '../../../providers/parent_provider.dart';
import '../../../widgets/forms/form_fields.dart';
import '../../../widgets/common/role_drawer.dart';
import '../../../widgets/common/loading_widget.dart';

/// Parent management screen for admin.
class ParentManagementScreen extends ConsumerStatefulWidget {
  const ParentManagementScreen({super.key});

  @override
  ConsumerState<ParentManagementScreen> createState() =>
      _ParentManagementScreenState();
}

class _ParentManagementScreenState extends ConsumerState<ParentManagementScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();

  final _passwordController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _addressController.dispose();
    super.dispose();
  }



  /// Creates a Firebase Auth account so this parent can log in.
  Future<String> _ensureParentLogin(String email) async {
    final pw = _passwordController.text.trim();
    if (pw.length < 6) {
      throw Exception('Enter a login password (min 6 characters) - this will be used to log in.');
    }
    final secondary = await Firebase.initializeApp(
      name: 'p-${DateTime.now().millisecondsSinceEpoch}',
      options: DefaultFirebaseOptions.currentPlatform,
    );
    try {
      final cred = await FirebaseAuth.instanceFor(app: secondary)
          .createUserWithEmailAndPassword(email: email, password: pw);
      final uid = cred.user!.uid;
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'name': _nameController.text.trim(),
        'email': email,
        'role': AppConstants.roleParent,
        'phone': _phoneController.text.trim(),
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
      });
      return uid;
    } finally {
      await secondary.delete();
    }
  }

  Future<void> _createParent() async {
    setState(() => _isLoading = true);
    try {
      final parent = ParentModel(
        id: const Uuid().v4(),
        userId: await _ensureParentLogin(_emailController.text.trim()),
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        phone: _phoneController.text.trim(),
        address: _addressController.text.trim(),
        studentIds: [],
        createdAt: DateTime.now(),
      );

      await ref.read(parentCrudProvider.notifier).createParent(parent);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Parent created successfully!'),
            backgroundColor: AppColors.presentColor),
      );
      context.go('/admin/parents');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'),
              backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final parentsAsync = ref.watch(parentsProvider);


    return Scaffold(
      appBar: AppBar(
        title: const Text('Parent Management'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      drawer: const RoleBasedDrawer(
        role: AppConstants.roleAdmin,
        userName: 'Admin',
        userEmail: 'admin@school.com',
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: ExpansionTile(
              title: const Text('Add New Parent'),
              leading: const Icon(Icons.add, color: AppColors.primary),
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Form(
                    child: Column(
                      children: [
                        AppTextField(
                          label: 'Full Name',
                          hint: 'Enter parent name',
                          controller: _nameController,
                          validator: (v) =>
                              Validators.validateRequired(v, 'Name'),
                          prefixIcon: Icons.person,
                        ),
                        const SizedBox(height: 12),
                        AppTextField(
                          label: 'Login Email',
                          hint: 'Enter email',
                          controller: _emailController,
                          validator: Validators.validateEmail,
                          prefixIcon: Icons.email,
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 12),
                        AppTextField(
                          label: 'Phone',
                          hint: 'Enter phone number',
                          controller: _phoneController,
                          validator: Validators.validatePhone,
                          prefixIcon: Icons.phone,
                          keyboardType: TextInputType.phone,
                        ),
                        const SizedBox(height: 12),
                        AppTextField(
                          label: 'Address',
                          hint: 'Enter address (optional)',
                          controller: _addressController,
                          maxLines: 3,
                        ),
                        const SizedBox(height: 16),
AppTextField(
                          label: 'Login Password',
                          hint: 'Min 6 characters - person logs in with this',
                          controller: _passwordController,
                          validator: (v) =>
                              (v ?? '').length < 6 ? 'Min 6 characters' : null,
                          prefixIcon: Icons.lock_outline,
                        ),
                        const SizedBox(height: 12),
                        const SizedBox(height: 16),

                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _createParent,
                            child: _isLoading
                                ? const SizedBox.square(
                                    dimension: 20,
                                    child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2))
                                : const Text('Create Parent'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: parentsAsync.when(
              data: (parents) {
                if (parents.isEmpty) {
                  return const Center(child: Text('No parents found.'));
                }
                return RefreshIndicator(
                  onRefresh: () async =>
                      ref.refresh(parentsProvider.future),
                  child: ListView.builder(
                    itemCount: parents.length,
                    itemBuilder: (context, index) {
                      final parent = parents[index];
                      return Card(
                        child: ListTile(
                          leading: const CircleAvatar(
                              child: Icon(Icons.family_restroom)),
                          title: Text(parent.name,
                              style: TextStyle(
                                  fontWeight: FontWeight.w600)),
                          subtitle: Text(parent.email),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit,
                                    color: AppColors.schoolBlue),
                                onPressed: () => _editParent(parent),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete,
                                    color: AppColors.schoolRed),
                                onPressed: () => ref
                                    .read(parentCrudProvider.notifier)
                                    .deleteParent(parent.id),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
              loading: () => const LoadingWidget(),
              error: (error, _) => Center(child: Text('Error: $error')),
            ),
          ),
        ],
      ),
    );
  }


  Future<void> _editParent(ParentModel parent) async {
    final nameCtrl = TextEditingController(text: parent.name);
    final phoneCtrl = TextEditingController(text: parent.phone ?? '');
    final addressCtrl = TextEditingController(text: parent.address ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Parent'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name')),
          const SizedBox(height: 12),
          TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'Phone')),
          const SizedBox(height: 12),
          TextField(controller: addressCtrl, decoration: const InputDecoration(labelText: 'Address')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await ref.read(parentCrudProvider.notifier).updateParent(parent.copyWith(
      name: nameCtrl.text.trim(),
      phone: phoneCtrl.text.trim(),
      address: addressCtrl.text.trim(),
    ));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Parent updated!'),
          backgroundColor: AppColors.presentColor));
    }
  }
}

