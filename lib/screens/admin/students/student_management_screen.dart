import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../models/student_model.dart';
import '../../../providers/student_provider.dart';
import '../../../widgets/common/loading_widget.dart';
import '../../../widgets/common/student_card.dart';
import '../../../widgets/common/role_drawer.dart';

/// Student management screen (list, search, filter, deactivate).
class StudentManagementScreen extends ConsumerStatefulWidget {
  const StudentManagementScreen({super.key});

  @override
  ConsumerState<StudentManagementScreen> createState() =>
      _StudentManagementScreenState();
}

class _StudentManagementScreenState
    extends ConsumerState<StudentManagementScreen> {
  String _searchQuery = '';
  String _selectedClass = '';
  String _selectedGender = '';
  final String _selectedStatus = 'all';
  List<StudentModel> _searchResults = [];
  bool _isSearching = false;

  @override
  Widget build(BuildContext context) {
    final studentsAsync = ref.watch(studentsProvider);
    final crudState = ref.watch(studentCrudProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Student Management'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => context.go('/admin/students/add'),
          ),
        ],
      ),
      drawer: const RoleBasedDrawer(
        role: AppConstants.roleAdmin,
        userName: 'Admin',
        userEmail: 'admin@school.com',
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          _buildFilters(),
          Expanded(child: _buildStudentList(studentsAsync, crudState)),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.go('/admin/students/add'),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: TextField(
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
            _isSearching = value.isNotEmpty;
          });
          if (value.length >= 2) {
            _searchStudents(value);
          }
        },
        decoration: InputDecoration(
          hintText: 'Search students by name, ID, or class...',
          prefixIcon: const Icon(Icons.search),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Future<void> _searchStudents(String query) async {
    setState(() => _isSearching = true);
    final service = ref.read(studentCrudProvider.notifier);
    final results = await service.searchStudents(query);
    setState(() => _searchResults = results);
  }

  Widget _buildFilters() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection(AppConstants.colClasses)
          .snapshots(),
      builder: (context, snapshot) {
        final classDocs = [...?snapshot.data?.docs]
          ..sort(
            (a, b) => (a.data()['name'] as String? ?? '').compareTo(
              b.data()['name'] as String? ?? '',
            ),
          );
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('All classes', _selectedClass == '', () {
                  setState(() => _selectedClass = '');
                }),
                for (final classDoc in classDocs) ...[
                  const SizedBox(width: 8),
                  _buildFilterChip(
                    classDoc.data()['name'] as String? ?? classDoc.id,
                    _selectedClass == classDoc.id,
                    () => setState(() => _selectedClass = classDoc.id),
                  ),
                ],
                const SizedBox(width: 8),
                _buildFilterChip('Male', _selectedGender == 'male', () {
                  setState(
                    () => _selectedGender = _selectedGender == 'male'
                        ? ''
                        : 'male',
                  );
                }),
                const SizedBox(width: 8),
                _buildFilterChip('Female', _selectedGender == 'female', () {
                  setState(
                    () => _selectedGender = _selectedGender == 'female'
                        ? ''
                        : 'female',
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFilterChip(String label, bool selected, VoidCallback onTap) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: AppColors.primary.withValues(alpha: 0.2),
      backgroundColor: AppColors.surfaceVariant,
      checkmarkColor: AppColors.primary,
    );
  }

  Widget _buildStudentList(
    AsyncValue<List<StudentModel>> studentsAsync,
    AsyncValue<void> crudState,
  ) {
    return studentsAsync.when(
      data: (allStudents) {
        var students = allStudents;

        if (_isSearching && _searchQuery.isNotEmpty) {
          students = _searchResults;
        } else if (_selectedClass.isNotEmpty) {
          students = students
              .where((s) => s.classId == _selectedClass)
              .toList();
        }
        if (_selectedGender.isNotEmpty) {
          students = students
              .where((s) => s.gender == _selectedGender)
              .toList();
        }
        if (_selectedStatus != 'all') {
          students = students
              .where((s) => s.status == _selectedStatus)
              .toList();
        }

        if (students.isEmpty) {
          return const Center(child: Text('No students found.'));
        }

        return RefreshIndicator(
          onRefresh: () async => ref.refresh(studentsProvider.future),
          child: ListView.builder(
            itemCount: students.length,
            itemBuilder: (context, index) {
              final student = students[index];
              return StudentCard(
                student: student,
                onTap: () => context.go('/admin/students/edit/${student.id}'),
              );
            },
          ),
        );
      },
      loading: () => const LoadingWidget(),
      error: (error, _) => Center(child: Text('Error: $error')),
    );
  }
}
