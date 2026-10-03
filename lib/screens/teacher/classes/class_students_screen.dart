import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../widgets/common/role_drawer.dart';
import '../../../widgets/common/loading_widget.dart';
import '../../../widgets/common/student_card.dart';
import '../../../models/student_model.dart';
import '../class_selector_dropdown.dart';

/// Screen listing students in a teacher's assigned class.
class ClassStudentsScreen extends ConsumerStatefulWidget {
  final String? classId;
  const ClassStudentsScreen({super.key, this.classId});
  @override
  ConsumerState<ClassStudentsScreen> createState() =>
      _ClassStudentsScreenState();
}

class _ClassStudentsScreenState extends ConsumerState<ClassStudentsScreen> {
  String? _selectedClassId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Class Students'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: _classDropdown()),
        ],
      ),
      drawer: const RoleBasedDrawer(
          role: AppConstants.roleTeacher,
          userName: 'Teacher', userEmail: ''),
      body: _selectedClassId == null
          ? const Center(
              child: Text('Select a class to view students.'),
            )
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection(AppConstants.colStudents)
                  .where('classId', isEqualTo: _selectedClassId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const LoadingWidget();
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                final students = snapshot.data?.docs ?? [];
                if (students.isEmpty) {
                  return const Center(child: Text('No students in this class.'));
                }
                return ListView.builder(
                  itemCount: students.length,
                  itemBuilder: (context, index) {
                                        final s = students[index].data() as Map<String, dynamic>;
                                        final studentData = s;
                    return Column(
                      children: [
                        StudentCard(
                          student: StudentModel.fromFirestore(students[index]),
                          onTap: () => context.go(
                              '/teacher/student/${students[index].id}'),
                        ),
                        _linkedParentsLine(studentData),
                      ],
                    );
                  },
                );
              },
            ),
    );
  }

  Widget _classDropdown() {
    return ClassSelectorDropdown(
      value: _selectedClassId,
      onChanged: (val) => setState(() => _selectedClassId = val),
    );
  }

  Widget _linkedParentsLine(Map<String, dynamic> studentData) {
    final ids = List<String>.from(studentData['parentIds'] as List? ?? const []);
    if (ids.isEmpty) return const SizedBox.shrink();
    return FutureBuilder<List<DocumentSnapshot<Map<String, dynamic>>>>(
      future: Future.wait(ids
          .take(2)
          .map((id) => FirebaseFirestore.instance
              .collection(AppConstants.colParents)
              .doc(id)
              .get())
          .toList()),
      builder: (context, snap) {
        if (!snap.hasData) return const SizedBox.shrink();
        final names = <String>[];
        for (final d in snap.data!) {
          if (d.exists) {
            final pd = d.data()!;
            names.add((pd['name'] as String? ?? '') +
                ((pd['phone'] as String? ?? '').isNotEmpty
                    ? ' | ${pd['phone'] as String}'
                    : ''));
          }
        }
        if (names.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
          child: Row(children: [
            const Icon(Icons.family_restroom,
                size: 16, color: AppColors.parentColor),
            const SizedBox(width: 6),
            Expanded(
                child: Text('Parent: ${names.join(' , ')}',
                    style: TextStyle(
                        fontSize: 12, color: AppColors.textSecondary))),
          ]),
        );
      },
    );
  }
}

