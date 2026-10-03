import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../widgets/common/role_drawer.dart';
import '../../../widgets/common/loading_widget.dart';

/// Admin screen: register classes, assign teachers, edit & delete.
class ClassManagementScreen extends ConsumerStatefulWidget {
  const ClassManagementScreen({super.key});

  @override
  ConsumerState<ClassManagementScreen> createState() =>
      _ClassManagementScreenState();
}

class _ClassManagementScreenState extends ConsumerState<ClassManagementScreen> {
  final _nameController = TextEditingController();
  String? _selectedTeacherId;
  bool _busy = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Stream<QuerySnapshot> get _classes => FirebaseFirestore.instance
      .collection(AppConstants.colClasses)
      .orderBy('name')
      .snapshots();

  Stream<QuerySnapshot> get _teachers => FirebaseFirestore.instance
      .collection(AppConstants.colTeachers)
      .where('isActive', isEqualTo: true)
      .snapshots();

  Future<void> _createClass() async {
    final name = _nameController.text.trim();
    if (name.isEmpty || _busy) return;
    setState(() => _busy = true);
    try {
      final existing = await FirebaseFirestore.instance
          .collection(AppConstants.colClasses)
          .get();
      final duplicate = existing.docs.any((doc) {
        final existingName = (doc.data()['name'] as String? ?? '')
            .trim()
            .toLowerCase();
        return existingName == name.toLowerCase();
      });
      if (duplicate) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('A class with this name already exists.'),
              backgroundColor: AppColors.error,
            ),
          );
        }
        return;
      }

      final classRef = await FirebaseFirestore.instance
          .collection(AppConstants.colClasses)
          .add({
            'name': name,
            'teacherId': _selectedTeacherId ?? '',
            'createdAt': FieldValue.serverTimestamp(),
          });
      // Keep teacher.classIds in sync using the class document ID.
      if (_selectedTeacherId != null && _selectedTeacherId!.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection(AppConstants.colTeachers)
            .doc(_selectedTeacherId)
            .update({
              'classIds': FieldValue.arrayUnion([classRef.id]),
              'className': FieldValue.arrayUnion([name]),
            });
      }
      _nameController.clear();
      setState(() => _selectedTeacherId = null);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Class created!'),
            backgroundColor: AppColors.presentColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _assignTeacher(
    String classId,
    String className,
    String currentTeacherId,
  ) async {
    String? picked = currentTeacherId.isEmpty ? null : currentTeacherId;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Assign Teacher - $className'),
        content: StreamBuilder<QuerySnapshot>(
          stream: _teachers,
          builder: (context, snap) {
            final docs = snap.data?.docs ?? [];
            return DropdownButtonFormField<String>(
              initialValue: picked,
              decoration: const InputDecoration(labelText: 'Select Teacher'),
              items: docs
                  .map(
                    (d) => DropdownMenuItem(
                      value: d.id,
                      child: Text(
                        (d.data() as Map<String, dynamic>)['name'] as String? ??
                            d.id,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (v) => picked = v,
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Assign'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await FirebaseFirestore.instance
        .collection(AppConstants.colClasses)
        .doc(classId)
        .update({'teacherId': picked ?? ''});
    if (picked != null && picked!.isNotEmpty) {
      await FirebaseFirestore.instance
          .collection(AppConstants.colTeachers)
          .doc(picked)
          .update({
            'classIds': FieldValue.arrayUnion([classId]),
            'className': FieldValue.arrayUnion([className]),
          });
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Teacher assigned!'),
          backgroundColor: AppColors.presentColor,
        ),
      );
    }
  }

  Future<void> _deleteClass(String id, String name) async {
    final assigned = await FirebaseFirestore.instance
        .collection(AppConstants.colStudents)
        .get();
    final hasStudents = assigned.docs.any((student) {
      final data = student.data();
      return data['classId'] == id ||
          ((data['classId'] as String? ?? '').isEmpty &&
              data['className'] == name);
    });
    if (hasStudents) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Move students out of $name before deleting the class.',
            ),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }
    await FirebaseFirestore.instance
        .collection(AppConstants.colClasses)
        .doc(id)
        .delete();
  }

  Future<void> _transferStudents(
    String sourceClassId,
    String sourceClassName,
    List<QueryDocumentSnapshot> classDocs,
    List<QueryDocumentSnapshot> studentDocs,
  ) async {
    final sourceStudents = studentDocs.where((student) {
      final data = student.data() as Map<String, dynamic>;
      return data['classId'] == sourceClassId ||
          ((data['classId'] as String? ?? '').isEmpty &&
              data['className'] == sourceClassName);
    }).toList();
    if (sourceStudents.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('There are no students in this class to transfer.'),
        ),
      );
      return;
    }

    String? targetClassId;
    final selectedStudentIds = <String>{};
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Transfer students from $sourceClassName'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: targetClassId,
                  decoration: const InputDecoration(
                    labelText: 'Destination class',
                    border: OutlineInputBorder(),
                  ),
                  items: classDocs.where((doc) => doc.id != sourceClassId).map((
                    doc,
                  ) {
                    final data = doc.data() as Map<String, dynamic>;
                    return DropdownMenuItem<String>(
                      value: doc.id,
                      child: Text(data['name'] as String? ?? doc.id),
                    );
                  }).toList(),
                  onChanged: (value) =>
                      setDialogState(() => targetClassId = value),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 320,
                  child: ListView(
                    children: sourceStudents.map((student) {
                      final data = student.data() as Map<String, dynamic>;
                      final name = data['fullName'] as String? ?? student.id;
                      return CheckboxListTile(
                        dense: true,
                        value: selectedStudentIds.contains(student.id),
                        title: Text(name),
                        onChanged: (selected) => setDialogState(() {
                          if (selected == true) {
                            selectedStudentIds.add(student.id);
                          } else {
                            selectedStudentIds.remove(student.id);
                          }
                        }),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              onPressed: targetClassId == null || selectedStudentIds.isEmpty
                  ? null
                  : () => Navigator.pop(dialogContext, true),
              icon: const Icon(Icons.move_up),
              label: Text('Transfer ${selectedStudentIds.length}'),
            ),
          ],
        ),
      ),
    );
    if (saved != true || targetClassId == null || !mounted) return;

    final target = classDocs.firstWhere((doc) => doc.id == targetClassId);
    final targetName =
        (target.data() as Map<String, dynamic>)['name'] as String? ?? '';
    final batch = FirebaseFirestore.instance.batch();
    for (final studentId in selectedStudentIds) {
      batch.update(
        FirebaseFirestore.instance
            .collection(AppConstants.colStudents)
            .doc(studentId),
        {
          'classId': targetClassId,
          'className': targetName,
          'sectionId': null,
          'sectionName': null,
          'updatedAt': FieldValue.serverTimestamp(),
        },
      );
    }
    await batch.commit();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${selectedStudentIds.length} students transferred to $targetName.',
          ),
          backgroundColor: AppColors.presentColor,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Class Registration'),
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
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Class Name',
                        hintText: 'E.g., Grade 4',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.school),
                      ),
                    ),
                    const SizedBox(height: 12),
                    StreamBuilder<QuerySnapshot>(
                      stream: _teachers,
                      builder: (context, snap) {
                        final docs = snap.data?.docs ?? [];
                        return DropdownButtonFormField<String>(
                          initialValue: _selectedTeacherId,
                          decoration: const InputDecoration(
                            labelText: 'Class Teacher (optional)',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.person),
                          ),
                          items: docs
                              .map(
                                (d) => DropdownMenuItem(
                                  value: d.id,
                                  child: Text(
                                    (d.data() as Map<String, dynamic>)['name']
                                            as String? ??
                                        d.id,
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (v) =>
                              setState(() => _selectedTeacherId = v),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _busy ? null : _createClass,
                        icon: const Icon(Icons.add),
                        label: const Text('Register Class'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _classes,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const LoadingWidget();
                }
                final docs = snap.data?.docs ?? [];
                if (docs.isEmpty) {
                  return const Center(child: Text('No classes yet.'));
                }
                return StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection(AppConstants.colStudents)
                      .snapshots(),
                  builder: (context, studentSnap) {
                    if (studentSnap.hasError) {
                      return Center(
                        child: Text(
                          'Unable to load class rosters: ${studentSnap.error}',
                        ),
                      );
                    }
                    final studentDocs = studentSnap.data?.docs ?? [];
                    return ListView.builder(
                      itemCount: docs.length,
                      itemBuilder: (context, i) {
                        final d = docs[i];
                        final data = d.data() as Map<String, dynamic>;
                        final name = data['name'] as String? ?? d.id;
                        final tid = data['teacherId'] as String? ?? '';
                        final studentCount = studentDocs.where((student) {
                          final studentData =
                              student.data() as Map<String, dynamic>;
                          return studentData['classId'] == d.id ||
                              ((studentData['classId'] as String? ?? '')
                                      .isEmpty &&
                                  studentData['className'] == name);
                        }).length;
                        return Card(
                          child: ListTile(
                            leading: const Icon(
                              Icons.school,
                              color: AppColors.primary,
                            ),
                            title: Text(
                              name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              '$studentCount students · '
                              '${tid.isEmpty ? 'No teacher assigned' : 'Teacher: $tid'}',
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(
                                    Icons.drive_file_move_outline,
                                    color: AppColors.schoolBlue,
                                  ),
                                  tooltip: 'Transfer students',
                                  onPressed: () => _transferStudents(
                                    d.id,
                                    name,
                                    docs,
                                    studentDocs,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.person_add_alt,
                                    color: AppColors.schoolBlue,
                                  ),
                                  tooltip: 'Assign Teacher',
                                  onPressed: () =>
                                      _assignTeacher(d.id, name, tid),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete,
                                    color: AppColors.schoolRed,
                                  ),
                                  tooltip: 'Delete class',
                                  onPressed: () => _deleteClass(d.id, name),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
