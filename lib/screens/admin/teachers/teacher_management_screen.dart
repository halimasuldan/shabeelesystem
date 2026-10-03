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
import '../../../models/teacher_model.dart';
import '../../../providers/teacher_provider.dart';
import '../../../widgets/forms/form_fields.dart';
import '../../../widgets/common/role_drawer.dart';
import '../../../widgets/common/loading_widget.dart';

/// Teacher management screen for admin.
class TeacherManagementScreen extends ConsumerStatefulWidget {
  const TeacherManagementScreen({super.key});

  @override
  ConsumerState<TeacherManagementScreen> createState() =>
      _TeacherManagementScreenState();
}

class _TeacherManagementScreenState extends ConsumerState<TeacherManagementScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();

  final _passwordController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }



  /// Creates a Firebase Auth account so this teacher can log in.
  /// Returns the auth uid (or a fallback uuid if no password given).
  Future<String> _ensureLoginAccount(String email, String role) async {
    final pw = _passwordController.text.trim();
    if (pw.length < 6) {
      throw Exception('Enter a login password (min 6 characters) - this will be used to log in.');
    }
    final secondary = await Firebase.initializeApp(
      name: 't-${DateTime.now().millisecondsSinceEpoch}',
      options: DefaultFirebaseOptions.currentPlatform,
    );
    try {
      final cred = await FirebaseAuth.instanceFor(app: secondary)
          .createUserWithEmailAndPassword(email: email, password: pw);
      final uid = cred.user!.uid;
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'name': _nameController.text.trim(),
        'email': email,
        'role': role,
        'phone': _phoneController.text.trim(),
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
      });
      return uid;
    } finally {
      await secondary.delete();
    }
  }

  Future<void> _createTeacher() async {
    setState(() => _isLoading = true);
    try {
      final teacher = TeacherModel(
        id: const Uuid().v4(),
        userId: await _ensureLoginAccount(_emailController.text.trim(), AppConstants.roleTeacher),
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        phone: _phoneController.text.trim(),
        classIds: [],
        className: [],
        createdAt: DateTime.now(),
      );
      await ref.read(teacherCrudProvider.notifier).createTeacher(teacher);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Teacher created!'),
            backgroundColor: AppColors.presentColor),
      );
      context.go('/admin/teachers');
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
    final teachersAsync = ref.watch(teachersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Teacher Management'),
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
              title: const Text('Add New Teacher'),
              leading: const Icon(Icons.add, color: AppColors.primary),
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      AppTextField(
                        label: 'Full Name',
                        hint: 'Enter teacher name',
                        controller: _nameController,
                        validator: (v) => Validators.validateRequired(v, 'Name'),
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
                          onPressed: _isLoading ? null : _createTeacher,
                          child: _isLoading
                              ? const SizedBox.square(
                                  dimension: 20,
                                  child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2))
                              : const Text('Create Teacher'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: teachersAsync.when(
              data: (teachers) {
                if (teachers.isEmpty) {
                  return const Center(child: Text('No teachers found.'));
                }
                return RefreshIndicator(
                  onRefresh: () async =>
                      ref.refresh(teachersProvider.future),
                  child: ListView.builder(
                    itemCount: teachers.length,
                    itemBuilder: (context, index) {
                      final teacher = teachers[index];
                      return Card(
                        child: ListTile(
                          leading: const CircleAvatar(
                              child: Icon(Icons.person,
                                  color: AppColors.teacherColor)),
                          title: Text(teacher.name,
                              style: TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text(teacher.email),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit,
                                    color: AppColors.schoolBlue),
                                onPressed: () => _editTeacher(teacher),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete,
                                    color: AppColors.schoolRed),
                                onPressed: () => ref
                                    .read(teacherCrudProvider.notifier)
                                    .deleteTeacher(teacher.id),
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


  Future<void> _editTeacher(TeacherModel teacher) async {
    final nameCtrl = TextEditingController(text: teacher.name);
    final phoneCtrl = TextEditingController(text: teacher.phone);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Teacher'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name')),
          const SizedBox(height: 12),
          TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'Phone')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await ref.read(teacherCrudProvider.notifier).updateTeacher(TeacherModel(
      id: teacher.id,
      userId: teacher.userId,
      name: nameCtrl.text.trim(),
      email: teacher.email,
      phone: phoneCtrl.text.trim(),
      classIds: teacher.classIds,
      className: teacher.className,
      photoUrl: teacher.photoUrl,
      isActive: teacher.isActive,
      createdAt: teacher.createdAt,
    ));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Teacher updated!'),
          backgroundColor: AppColors.presentColor));
    }
  }
}

