import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../providers/auth_provider.dart';
import '../../../core/services/notification_service.dart';
import '../../../widgets/common/loading_widget.dart';
import '../../../widgets/common/role_drawer.dart';

String calculateExamGrade(num score) {
  if (score >= 80) return 'A';
  if (score >= 70) return 'B';
  if (score >= 60) return 'C';
  if (score >= 50) return 'D';
  return 'F';
}

/// Screen for teachers to enter exam results by class, subject and student.
class ExamResultsScreen extends ConsumerStatefulWidget {
  const ExamResultsScreen({super.key});

  @override
  ConsumerState<ExamResultsScreen> createState() => _ExamResultsScreenState();
}

class _ExamResultsScreenState extends ConsumerState<ExamResultsScreen> {
  final _scoreController = TextEditingController();

  String? _selectedExamId;
  String? _selectedExamName;
  String? _selectedClassId;
  String? _selectedClassName;
  num _selectedMaxMarks = 100;
  String? _selectedSubjectId;
  String? _selectedSubjectName;
  Map<String, num> _selectedSubjectMaxMarks = const {};
  Set<String> _selectedExamSubjectIds = const {};
  String? _selectedStudentId;
  String? _teacherDocId;

  @override
  Widget build(BuildContext context) {
    final userId = ref.read(authServiceProvider).currentUser?.uid ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Exam Results'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      drawer: RoleBasedDrawer(
        role: AppConstants.roleTeacher,
        userName:
            ref.read(authServiceProvider).currentUser?.displayName ?? 'Teacher',
        userEmail: ref.read(authServiceProvider).currentUser?.email ?? '',
      ),
      body: userId.isEmpty
          ? const Center(child: Text('Teacher session not found.'))
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection(AppConstants.colTeachers)
                  .where('userId', isEqualTo: userId)
                  .limit(1)
                  .snapshots(),
              builder: (context, teacherSnap) {
                if (teacherSnap.connectionState == ConnectionState.waiting) {
                  return const LoadingWidget();
                }

                final teacherDoc = teacherSnap.data?.docs.isNotEmpty == true
                    ? teacherSnap.data!.docs.first
                    : null;
                final teacherData =
                    teacherDoc?.data() as Map<String, dynamic>? ?? {};
                final teacherClassIds = List<String>.from(
                  teacherData['classIds'] as List? ?? const [],
                );
                final teacherClassNames = List<String>.from(
                  teacherData['className'] as List? ?? const [],
                );
                _teacherDocId = teacherDoc?.id;

                return StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection(AppConstants.colClasses)
                      .snapshots(),
                  builder: (context, classSnap) {
                    final assignedClassIds = (classSnap.data?.docs ?? [])
                        .where((doc) {
                          final classData = doc.data() as Map<String, dynamic>;
                          final className = classData['name'] as String? ?? '';
                          return classData['teacherId'] == teacherDoc?.id ||
                              teacherClassIds.contains(doc.id) ||
                              teacherClassIds.contains(className) ||
                              teacherClassNames.contains(className);
                        })
                        .map((doc) => doc.id)
                        .toList();

                    return StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection(AppConstants.colExamDefinitions)
                          .where(
                            'classId',
                            whereIn: assignedClassIds.isEmpty
                                ? ['__none__']
                                : assignedClassIds,
                          )
                          .snapshots(),
                      builder: (context, examSnap) {
                        final exams = examSnap.data?.docs ?? [];

                        return SingleChildScrollView(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (exams.isEmpty)
                                const Text(
                                  'No exams created for your classes yet.',
                                )
                              else ...[
                                DropdownButtonFormField<String>(
                                  initialValue: _selectedExamId,
                                  decoration: const InputDecoration(
                                    labelText: 'Select Exam',
                                    border: OutlineInputBorder(),
                                  ),
                                  items: exams.map((doc) {
                                    final data =
                                        doc.data() as Map<String, dynamic>;
                                    final name =
                                        (data['name'] as String?) ?? doc.id;
                                    final courseName =
                                        (data['courseName'] as String?) ??
                                        (data['className'] as String?) ??
                                        'Course';
                                    return DropdownMenuItem(
                                      value: doc.id,
                                      child: Text('$name · $courseName'),
                                    );
                                  }).toList(),
                                  onChanged: (value) async {
                                    if (value == null) return;
                                    final examDoc = await FirebaseFirestore
                                        .instance
                                        .collection(
                                          AppConstants.colExamDefinitions,
                                        )
                                        .doc(value)
                                        .get();
                                    final examData = examDoc.data() ?? {};
                                    setState(() {
                                      _selectedExamId = value;
                                      _selectedExamName =
                                          examData['name'] as String? ?? 'Exam';
                                      _selectedClassId =
                                          examData['classId'] as String? ?? '';
                                      _selectedClassName =
                                          examData['courseName'] as String? ??
                                          examData['className'] as String? ??
                                          'Unknown';
                                      _selectedMaxMarks =
                                          (examData['maxMarks'] as num?) ?? 100;
                                      _selectedSubjectMaxMarks = {
                                        for (final subject
                                            in examData['subjects'] as List? ??
                                                const [])
                                          if (subject is Map &&
                                              subject['subjectId'] != null)
                                            subject['subjectId'].toString():
                                                subject['maxMarks'] is num
                                                ? subject['maxMarks'] as num
                                                : num.tryParse(
                                                        subject['maxMarks']
                                                                ?.toString() ??
                                                            '',
                                                      ) ??
                                                      100,
                                      };
                                      _selectedExamSubjectIds =
                                          _selectedSubjectMaxMarks.keys.toSet();
                                      _selectedStudentId = null;
                                      _selectedSubjectId = null;
                                      _selectedSubjectName = null;
                                    });
                                  },
                                ),
                                const SizedBox(height: 16),
                                if (_selectedExamId != null) ...[
                                  _buildSubjectSelector(),
                                  const SizedBox(height: 16),
                                ],
                                if (_selectedSubjectId != null) ...[
                                  _buildStudentSelector(),
                                  const SizedBox(height: 16),
                                ],
                              ],
                              const SizedBox(height: 16),
                              TextField(
                                controller: _scoreController,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                decoration: const InputDecoration(
                                  labelText: 'Score',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text('Maximum marks: $_selectedMaxMarks'),
                              const SizedBox(height: 20),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: _saveResult,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    foregroundColor: Colors.white,
                                  ),
                                  child: const Text('Save Result'),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
    );
  }

  Widget _buildStudentSelector() {
    if (_selectedClassId == null || _selectedClassId!.isEmpty) {
      return const SizedBox();
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection(AppConstants.colStudents)
          .snapshots(),
      builder: (context, studentSnap) {
        final docs = (studentSnap.data?.docs ?? []).where((doc) {
          final student = doc.data() as Map<String, dynamic>;
          return student['classId'] == _selectedClassId ||
              student['className'] == _selectedClassName;
        }).toList();
        if (docs.isEmpty) {
          return const Text('No students in this class yet.');
        }

        return DropdownButtonFormField<String>(
          initialValue: _selectedStudentId,
          decoration: const InputDecoration(
            labelText: 'Select Student',
            border: OutlineInputBorder(),
          ),
          items: docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final name = (data['fullName'] as String?) ?? doc.id;
            return DropdownMenuItem(value: doc.id, child: Text(name));
          }).toList(),
          onChanged: (value) {
            if (value == null) return;
            setState(() {
              _selectedStudentId = value;
            });
          },
        );
      },
    );
  }

  Widget _buildSubjectSelector() {
    if (_selectedClassId == null || _selectedClassId!.isEmpty) {
      return const SizedBox();
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection(AppConstants.colSubjects)
          .snapshots(),
      builder: (context, subjectSnap) {
        final docs = (subjectSnap.data?.docs ?? []).where((doc) {
          final subject = doc.data() as Map<String, dynamic>;
          final belongsToClass =
              subject['classId'] == _selectedClassId ||
              subject['className'] == _selectedClassName;
          final assignedToExam =
              _selectedExamSubjectIds.isEmpty ||
              _selectedExamSubjectIds.contains(doc.id);
          return belongsToClass && assignedToExam;
        }).toList();

        if (docs.isEmpty) {
          return const Text('No subjects are assigned to this exam.');
        }

        return DropdownButtonFormField<String>(
          initialValue: _selectedSubjectId,
          decoration: const InputDecoration(
            labelText: 'Select Subject',
            border: OutlineInputBorder(),
          ),
          items: docs.map((doc) {
            final subject = doc.data() as Map<String, dynamic>;
            return DropdownMenuItem<String>(
              value: doc.id,
              child: Text(subject['name'] as String? ?? doc.id),
            );
          }).toList(),
          onChanged: (value) {
            if (value == null) return;
            final subjectDoc = docs.firstWhere((doc) => doc.id == value);
            final subject = subjectDoc.data() as Map<String, dynamic>;
            setState(() {
              _selectedSubjectId = value;
              _selectedSubjectName = subject['name'] as String? ?? 'Subject';
              _selectedMaxMarks =
                  _selectedSubjectMaxMarks[value] ?? _selectedMaxMarks;
              _selectedStudentId = null;
            });
          },
        );
      },
    );
  }

  Future<void> _saveResult() async {
    final studentId = _selectedStudentId;
    final classId = _selectedClassId;
    final examName = _selectedExamName ?? 'Exam';
    final subjectId = _selectedSubjectId;
    final subjectName = _selectedSubjectName;
    final scoreText = _scoreController.text.trim();

    if (_selectedExamId == null) {
      _showMessage('Please select an exam first.');
      return;
    }

    if (studentId == null || classId == null || classId.isEmpty) {
      _showMessage('Please select a student first.');
      return;
    }

    if (subjectId == null || subjectName == null || subjectName.isEmpty) {
      _showMessage('Please select a subject first.');
      return;
    }

    final parsedScore = num.tryParse(scoreText);
    if (parsedScore == null ||
        parsedScore < 0 ||
        parsedScore > _selectedMaxMarks) {
      _showMessage('Score must be between 0 and $_selectedMaxMarks.');
      return;
    }

    final studentDoc = await FirebaseFirestore.instance
        .collection(AppConstants.colStudents)
        .doc(studentId)
        .get();
    final student = studentDoc.data() ?? {};

    await FirebaseFirestore.instance
        .collection(AppConstants.colExamResults)
        .doc('${_selectedExamId}_${studentId}_$subjectId')
        .set({
          'studentId': studentId,
          'studentName': student['fullName'] as String? ?? '',
          'classId': classId,
          'className': _selectedClassName ?? '',
          'courseId': classId,
          'courseName': _selectedClassName ?? '',
          'examType': 'general',
          'examId': _selectedExamId,
          'examName': examName,
          'subjectId': subjectId,
          'subject': subjectName,
          'maxMarks': _selectedMaxMarks,
          'score': parsedScore,
          'percentage': parsedScore / _selectedMaxMarks * 100,
          'grade': calculateExamGrade(parsedScore / _selectedMaxMarks * 100),
          'date': Timestamp.fromDate(DateTime.now()),
          'teacherId': _teacherDocId ?? '',
          'enteredAt': Timestamp.fromDate(DateTime.now()),
          'createdAt': FieldValue.serverTimestamp(),
        });
    await NotificationService.instance.notifyStudentParents(
      studentId: studentId,
      title: 'Exam result available',
      message: '$examName - $subjectName: $parsedScore/$_selectedMaxMarks.',
      type: 'exam',
    );

    if (!mounted) return;
    _showMessage('Result saved successfully.');
    setState(() {
      _selectedStudentId = null;
      _selectedClassId = null;
      _selectedClassName = null;
      _selectedMaxMarks = 100;
      _selectedExamId = null;
      _selectedExamName = null;
      _selectedSubjectId = null;
      _selectedSubjectName = null;
      _selectedSubjectMaxMarks = const {};
      _selectedExamSubjectIds = const {};
      _scoreController.clear();
    });
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
