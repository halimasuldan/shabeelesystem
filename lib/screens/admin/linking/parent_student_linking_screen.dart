import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../models/student_model.dart';
import '../../../providers/parent_provider.dart';
import '../../../providers/student_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../widgets/common/role_drawer.dart';
import '../../../widgets/common/loading_widget.dart';

/// Screen for admin to link parents to students.
class ParentStudentLinkingScreen extends ConsumerStatefulWidget {
  const ParentStudentLinkingScreen({super.key});

  @override
  ConsumerState<ParentStudentLinkingScreen> createState() =>
      _ParentStudentLinkingScreenState();
}

class _ParentStudentLinkingScreenState extends ConsumerState<ParentStudentLinkingScreen> {
  String? _selectedParentId;
  String? _selectedStudentId;

  @override
  Widget build(BuildContext context) {
    final parentsAsync = ref.watch(parentsProvider);
    final studentsAsync = ref.watch(studentsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Parent-Student Linking'),
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
            padding: const EdgeInsets.all(16),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Link Parent to Student',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 16),
                    parentsAsync.when(
                      data: (parents) => DropdownButtonFormField<String>(
                        initialValue: _selectedParentId,
                        decoration: InputDecoration(
                          labelText: 'Select Parent',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        items: parents
                            .map((p) => DropdownMenuItem(
                                value: p.id, child: Text(p.name)))
                            .toList(),
                        onChanged: (value) =>
                            setState(() => _selectedParentId = value),
                      ),
                      loading: () => const LoadingWidget(),
                      error: (error, _) => Text('Error: $error'),
                    ),
                    const SizedBox(height: 16),
                    studentsAsync.when(
                      data: (students) => DropdownButtonFormField<String>(
                        initialValue: _selectedStudentId,
                        decoration: InputDecoration(
                          labelText: 'Select Student',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        items: students
                            .map((s) => DropdownMenuItem(
                                value: s.id, child: Text(s.fullName)))
                            .toList(),
                        onChanged: (value) =>
                            setState(() => _selectedStudentId = value),
                      ),
                      loading: () => const LoadingWidget(),
                      error: (error, _) => Text('Error: $error'),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _selectedParentId == null ||
                                _selectedStudentId == null
                            ? null
                            : _linkParentToStudent,
                        child: const Text('Link Parent to Student'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: parentsAsync.when(
              data: (parents) {
                final linkedParents = parents.where((p) => p.studentIds.isNotEmpty).toList();
                if (linkedParents.isEmpty) {
                  return const Center(child: Text('No parents linked to students yet.'));
                }
                return ListView.builder(
                  itemCount: linkedParents.length,
                  itemBuilder: (context, index) {
                    final parent = linkedParents[index];
                    return Card(
                      child: ExpansionTile(
                        title: Text(parent.name),
                        subtitle: Text(parent.email),
                        children: parent.studentIds.map((studentId) {
                          return FutureBuilder(
                            future: FirebaseFirestore.instance
                                .collection(AppConstants.colStudents)
                                .doc(studentId)
                                .get(),
                            builder: (context, snapshot) {
                              if (!snapshot.hasData || !snapshot.data!.exists) {
                                return const ListTile(
                                  leading: Icon(Icons.person, color: AppColors.absentColor),
                                  title: Text('Student not found'),
                                );
                              }
                              final student = StudentModel.fromFirestore(snapshot.data!);
                              return ListTile(
                                leading: const Icon(Icons.school, color: AppColors.presentColor),
                                title: Text(student.fullName),
                                subtitle: Text(student.studentCode),
                                trailing: IconButton(
                                  icon: const Icon(Icons.link_off, color: AppColors.schoolRed),
                                  onPressed: () => ref
                                      .read(parentCrudProvider.notifier)
                                      .unlinkParentFromStudent(parent.id, studentId),
                                ),
                              );
                            },
                          );
                        }).toList(),
                      ),
                    );
                  },
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

  Future<void> _linkParentToStudent() async {
    if (_selectedParentId == null || _selectedStudentId == null) return;

    try {
      await ref
          .read(parentCrudProvider.notifier)
          .linkParentToStudent(_selectedParentId!, _selectedStudentId!);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Parent linked to student!'),
            backgroundColor: AppColors.presentColor),
      );
      setState(() {
        _selectedParentId = null;
        _selectedStudentId = null;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'),
            backgroundColor: AppColors.error),
      );
    }
  }
}


