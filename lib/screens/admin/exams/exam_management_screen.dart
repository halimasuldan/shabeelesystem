import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/auth_service.dart';
import '../../../widgets/common/loading_widget.dart';
import '../../../widgets/common/role_drawer.dart';

class ExamManagementScreen extends StatefulWidget {
  final String role;

  const ExamManagementScreen({super.key, this.role = AppConstants.roleAdmin});

  @override
  State<ExamManagementScreen> createState() => _ExamManagementScreenState();
}

class _ExamManagementScreenState extends State<ExamManagementScreen> {
  final _nameController = TextEditingController();
  String? _selectedClassId;
  String? _selectedClassName;
  bool _busy = false;
  List<String> _allowedClassIds = const [];
  bool _permissionsReady = false;
  final Map<String, TextEditingController> _subjectMarkControllers = {};

  bool get _isTeacher => widget.role == AppConstants.roleTeacher;

  @override
  void initState() {
    super.initState();
    _loadTeacherClasses();
  }

  Future<void> _loadTeacherClasses() async {
    if (!_isTeacher) {
      if (mounted) setState(() => _permissionsReady = true);
      return;
    }

    final userId = AuthService().currentUser?.uid ?? '';
    final teacherSnap = await FirebaseFirestore.instance
        .collection(AppConstants.colTeachers)
        .where('userId', isEqualTo: userId)
        .limit(1)
        .get();
    final teacherDoc = teacherSnap.docs.isEmpty ? null : teacherSnap.docs.first;
    final teacherData = teacherDoc?.data() ?? <String, dynamic>{};
    final configuredIds = List<String>.from(
      teacherData['classIds'] as List? ?? const [],
    );
    final configuredNames = List<String>.from(
      teacherData['className'] as List? ?? const [],
    );
    final classes = await FirebaseFirestore.instance
        .collection(AppConstants.colClasses)
        .get();
    final allowedIds = classes.docs
        .where((doc) {
          final data = doc.data();
          return data['teacherId'] == teacherDoc?.id ||
              configuredIds.contains(doc.id) ||
              configuredIds.contains(data['name']) ||
              configuredNames.contains(data['name']);
        })
        .map((doc) => doc.id)
        .toList();

    if (mounted) {
      setState(() {
        _allowedClassIds = allowedIds;
        _permissionsReady = true;
      });
    }
  }

  Stream<QuerySnapshot> get _classStream => FirebaseFirestore.instance
      .collection(AppConstants.colClasses)
      .orderBy('name')
      .snapshots();

  Stream<QuerySnapshot> get _subjectStream => FirebaseFirestore.instance
      .collection(AppConstants.colSubjects)
      .snapshots();

  void _selectClass(String? classId, String? className) {
    for (final controller in _subjectMarkControllers.values) {
      controller.dispose();
    }
    _subjectMarkControllers.clear();
    setState(() {
      _selectedClassId = classId;
      _selectedClassName = className;
    });
  }

  Future<void> _createExam() async {
    final examName = _nameController.text.trim();
    if (examName.isEmpty || _selectedClassId == null || _busy) {
      return;
    }

    setState(() => _busy = true);
    try {
      final classDoc = await FirebaseFirestore.instance
          .collection(AppConstants.colClasses)
          .doc(_selectedClassId!)
          .get();
      final className = (classDoc.data()?['name'] as String?) ?? '';
      final subjectSnapshot = await FirebaseFirestore.instance
          .collection(AppConstants.colSubjects)
          .where('classId', isEqualTo: _selectedClassId)
          .get();
      if (subjectSnapshot.docs.isEmpty) {
        _showMessage('Add subjects to this class before setting up an exam.');
        return;
      }

      final examSubjects = <Map<String, dynamic>>[];
      for (final subjectDoc in subjectSnapshot.docs) {
        final subjectData = subjectDoc.data();
        final subjectName = subjectData['name'] as String? ?? 'Subject';
        final maxMarks = num.tryParse(
          _subjectMarkControllers[subjectDoc.id]?.text.trim() ?? '',
        );
        if (maxMarks == null || maxMarks <= 0) {
          _showMessage('Enter valid maximum marks for $subjectName.');
          return;
        }
        examSubjects.add({
          'subjectId': subjectDoc.id,
          'subjectName': subjectName,
          'maxMarks': maxMarks,
        });
      }
      final totalMaxMarks = examSubjects.fold<num>(
        0,
        (total, subject) => total + (subject['maxMarks'] as num),
      );

      await FirebaseFirestore.instance
          .collection(AppConstants.colExamDefinitions)
          .add({
            'name': examName,
            'courseId': _selectedClassId,
            'courseName': className,
            'classId': _selectedClassId,
            'className': className,
            'subjects': examSubjects,
            'maxMarks': totalMaxMarks,
            'createdAt': FieldValue.serverTimestamp(),
          });

      _nameController.clear();
      _selectClass(null, null);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Exam created successfully.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to create exam: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteExam(String id) async {
    await FirebaseFirestore.instance
        .collection(AppConstants.colExamDefinitions)
        .doc(id)
        .delete();
  }

  Future<void> _editExam(QueryDocumentSnapshot doc) async {
    final data = doc.data() as Map<String, dynamic>;
    final nameController = TextEditingController(
      text: (data['name'] as String?) ?? '',
    );
    final marksController = TextEditingController(
      text: '${data['maxMarks'] ?? 100}',
    );

    final save = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Exam'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Exam Name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: marksController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: 'Maximum Marks'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (save != true) {
      nameController.dispose();
      marksController.dispose();
      return;
    }

    final name = nameController.text.trim();
    final maxMarks = num.tryParse(marksController.text.trim());
    nameController.dispose();
    marksController.dispose();
    if (name.isEmpty || maxMarks == null || maxMarks <= 0) {
      _showMessage('Enter a valid exam name and maximum marks.');
      return;
    }

    await FirebaseFirestore.instance
        .collection(AppConstants.colExamDefinitions)
        .doc(doc.id)
        .update({'name': name, 'maxMarks': maxMarks});
    _showMessage('Exam updated successfully.');
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    _nameController.dispose();
    for (final controller in _subjectMarkControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isTeacher ? 'My Exams' : 'Exam Setup'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      drawer: RoleBasedDrawer(
        role: widget.role,
        userName: _isTeacher ? 'Teacher' : 'Admin',
        userEmail: _isTeacher ? '' : 'admin@school.com',
      ),
      body: !_permissionsReady
          ? const LoadingWidget()
          : Column(
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
                              labelText: 'Exam Name',
                              hintText: 'Midterm, Final, Quiz 1',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          StreamBuilder<QuerySnapshot>(
                            stream: _classStream,
                            builder: (context, snapshot) {
                              final allDocs = snapshot.data?.docs ?? [];
                              final docs = _isTeacher
                                  ? allDocs.where((doc) {
                                      final data =
                                          doc.data() as Map<String, dynamic>;
                                      return _allowedClassIds.contains(
                                            doc.id,
                                          ) ||
                                          _allowedClassIds.contains(
                                            data['classId'],
                                          );
                                    }).toList()
                                  : allDocs;
                              return DropdownButtonFormField<String>(
                                initialValue: _selectedClassId,
                                decoration: const InputDecoration(
                                  labelText: 'Course Name',
                                  border: OutlineInputBorder(),
                                ),
                                items: docs.map((doc) {
                                  final data =
                                      doc.data() as Map<String, dynamic>;
                                  final name =
                                      (data['name'] as String?) ?? doc.id;
                                  return DropdownMenuItem(
                                    value: doc.id,
                                    child: Text(name),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  final selected = docs
                                      .where((doc) => doc.id == value)
                                      .firstOrNull;
                                  final selectedData =
                                      selected?.data() as Map<String, dynamic>?;
                                  _selectClass(
                                    value,
                                    selectedData?['name'] as String?,
                                  );
                                },
                              );
                            },
                          ),
                          if (_selectedClassId != null) ...[
                            const SizedBox(height: 12),
                            StreamBuilder<QuerySnapshot>(
                              stream: _subjectStream,
                              builder: (context, snapshot) {
                                if (snapshot.connectionState ==
                                    ConnectionState.waiting) {
                                  return const LinearProgressIndicator();
                                }
                                final subjects = (snapshot.data?.docs ?? [])
                                    .where((doc) {
                                      final data =
                                          doc.data() as Map<String, dynamic>;
                                      return data['classId'] ==
                                              _selectedClassId ||
                                          data['className'] ==
                                              _selectedClassName;
                                    })
                                    .toList();
                                if (subjects.isEmpty) {
                                  return const Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      'No subjects linked to this class yet.',
                                    ),
                                  );
                                }
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Align(
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        'Set maximum marks for each subject',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    for (final subjectDoc in subjects)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 8,
                                        ),
                                        child: TextField(
                                          controller: _subjectMarkControllers
                                              .putIfAbsent(
                                                subjectDoc.id,
                                                () => TextEditingController(
                                                  text: '100',
                                                ),
                                              ),
                                          keyboardType:
                                              const TextInputType.numberWithOptions(
                                                decimal: true,
                                              ),
                                          decoration: InputDecoration(
                                            labelText:
                                                '${(subjectDoc.data() as Map<String, dynamic>)['name'] ?? 'Subject'} maximum marks',
                                            border: const OutlineInputBorder(),
                                          ),
                                        ),
                                      ),
                                  ],
                                );
                              },
                            ),
                          ],
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _busy ? null : _createExam,
                              icon: const Icon(Icons.add),
                              label: const Text('Create Exam'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection(AppConstants.colExamDefinitions)
                        .orderBy('createdAt', descending: true)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const LoadingWidget();
                      }

                      final allDocs = snapshot.data?.docs ?? [];
                      final docs = _isTeacher
                          ? allDocs.where((doc) {
                              final data = doc.data() as Map<String, dynamic>;
                              return _allowedClassIds.contains(data['classId']);
                            }).toList()
                          : allDocs;
                      if (docs.isEmpty) {
                        return const Center(
                          child: Text('No exams created yet.'),
                        );
                      }

                      return ListView.builder(
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          final data =
                              docs[index].data() as Map<String, dynamic>;
                          final examName = (data['name'] as String?) ?? 'Exam';
                          final courseName =
                              (data['courseName'] as String?) ??
                              (data['className'] as String?) ??
                              'Course';
                          final maxMarks = data['maxMarks'] ?? 100;

                          return Card(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            child: ListTile(
                              leading: const Icon(
                                Icons.quiz,
                                color: AppColors.primary,
                              ),
                              title: Text(examName),
                              subtitle: Text(
                                'Course: $courseName • Maximum marks: $maxMarks',
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    tooltip: 'Edit exam',
                                    icon: const Icon(
                                      Icons.edit,
                                      color: AppColors.primary,
                                    ),
                                    onPressed: () => _editExam(docs[index]),
                                  ),
                                  IconButton(
                                    tooltip: 'Delete exam',
                                    icon: const Icon(
                                      Icons.delete,
                                      color: AppColors.schoolRed,
                                    ),
                                    onPressed: () =>
                                        _deleteExam(docs[index].id),
                                  ),
                                ],
                              ),
                            ),
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
