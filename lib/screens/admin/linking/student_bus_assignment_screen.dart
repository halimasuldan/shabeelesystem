import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../models/bus_model.dart';
import '../../../models/student_model.dart';
import '../../../providers/bus_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../providers/student_provider.dart';
import '../../../widgets/common/role_drawer.dart';
import '../../../widgets/common/loading_widget.dart';

/// The students an admin can still assign for [selectedBusId].
///
/// With no bus selected every student is listed - including unassigned ones.
/// The old filter (`busId != selectedBusId`) hid exactly those students when
/// no bus had been picked yet, because `null != null` is false, so the screen
/// opened on "No students to assign." Once a bus is chosen, students already
/// riding it drop out of the list while unassigned students and students from
/// other buses remain selectable (they are moved, see [busMovesToClear]).
List<StudentModel> studentsVisibleForAssignment(
  List<StudentModel> students,
  String? selectedBusId,
) {
  if (selectedBusId == null) return List<StudentModel>.of(students);
  return students.where((s) => s.busId != selectedBusId).toList();
}

/// Current roster for the selected bus, kept visible while choosing transfers.
List<StudentModel> studentsAssignedToBus(
  List<StudentModel> students,
  String? selectedBusId,
) {
  if (selectedBusId == null) return <StudentModel>[];
  return students.where((student) => student.busId == selectedBusId).toList();
}

/// For each selected student, the bus they are being moved away from.
///
/// Maps `studentId -> previousBusId` for every selected student whose current
/// bus differs from [selectedBusId]. Those are the `buses.studentIds` mirror
/// entries that have to be removed on re-assignment, so a bus never keeps
/// counting a student who now rides another bus (the count feeds the bus
/// details screens and the driver dashboard's fallback number).
Map<String, String> busMovesToClear(
  List<StudentModel> students,
  Iterable<String> selectedStudentIds,
  String? selectedBusId,
) {
  final moves = <String, String>{};
  if (selectedBusId == null) return moves;
  final selected = selectedStudentIds.toSet();
  for (final student in students) {
    if (!selected.contains(student.id)) continue;
    final previous = student.busId;
    if (previous != null && previous.isNotEmpty && previous != selectedBusId) {
      moves[student.id] = previous;
    }
  }
  return moves;
}

/// Subtitle showing where a student rides today.
String busLabelForStudent(StudentModel student, Map<String, String> busLabels) {
  final busId = student.busId;
  if (busId == null || busId.isEmpty) return 'Not on a bus';
  return busLabels[busId] ?? 'Bus: $busId';
}

/// Screen for admin to assign students to buses.
class StudentBusAssignmentScreen extends ConsumerStatefulWidget {
  const StudentBusAssignmentScreen({super.key});

  @override
  ConsumerState<StudentBusAssignmentScreen> createState() =>
      _StudentBusAssignmentScreenState();
}

class _StudentBusAssignmentScreenState
    extends ConsumerState<StudentBusAssignmentScreen> {
  String? _selectedBusId;
  final Set<String> _selectedStudents = {};

  @override
  Widget build(BuildContext context) {
    final studentsAsync = ref.watch(studentsProvider);
    final busesAsync = ref.watch(busesProvider);

    final buses = busesAsync.valueOrNull ?? const <BusModel>[];
    final busLabels = {
      for (final bus in buses) bus.id: '${bus.busNumber} (${bus.plateNumber})',
    };
    BusModel? selectedBus;
    for (final bus in buses) {
      if (bus.id == _selectedBusId) selectedBus = bus;
    }
    final selectedDriverName = selectedBus?.driverName ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Student-Bus Assignment'),
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
          // Bus selector
          Padding(
            padding: const EdgeInsets.all(12),
            child: busesAsync.when(
              data: (buses) => DropdownButtonFormField<String>(
                initialValue: _selectedBusId,
                decoration: InputDecoration(
                  labelText: 'Select Bus',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                items: buses
                    .map(
                      (b) => DropdownMenuItem(
                        value: b.id,
                        child: Text('${b.busNumber} (${b.plateNumber})'),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() => _selectedBusId = value),
              ),
              loading: () => const LoadingWidget(),
              error: (error, _) => Text('Error: $error'),
            ),
          ),
          if (_selectedBusId != null)
            const Padding(
              padding: EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Choose students below to assign or move them to this bus.',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            ),
          // Confirm the students -> bus -> driver chain before saving.
          if (selectedBus != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                selectedDriverName.isEmpty
                    ? 'No driver on this bus yet - assign one under Buses, '
                          'otherwise the driver portal shows no students.'
                    : 'Students ride with driver: $selectedDriverName',
                style: TextStyle(
                  fontSize: 13,
                  color: selectedDriverName.isEmpty
                      ? AppColors.error
                      : AppColors.schoolBlue,
                ),
              ),
            ),
          // Selected count
          if (_selectedStudents.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                '${_selectedStudents.length} students selected',
                style: TextStyle(color: AppColors.schoolBlue),
              ),
            ),
          // Student list
          Expanded(
            child: studentsAsync.when(
              data: (students) {
                final assignedHere =
                    List<StudentModel>.of(
                      studentsAssignedToBus(students, _selectedBusId),
                    )..sort(
                      (a, b) => a.fullName.toLowerCase().compareTo(
                        b.fullName.toLowerCase(),
                      ),
                    );
                final available =
                    List<StudentModel>.of(
                      studentsVisibleForAssignment(students, _selectedBusId),
                    )..sort(
                      (a, b) => a.fullName.toLowerCase().compareTo(
                        b.fullName.toLowerCase(),
                      ),
                    );
                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: 16),
                  children: [
                    if (_selectedBusId != null) ...[
                      _sectionHeading(
                        'Already on this bus (${assignedHere.length})',
                      ),
                      if (assignedHere.isEmpty)
                        const ListTile(
                          leading: Icon(Icons.info_outline),
                          title: Text('No students assigned to this bus yet.'),
                        )
                      else
                        ...assignedHere.map(
                          (student) => Card(
                            child: ListTile(
                              leading: const Icon(
                                Icons.check_circle,
                                color: AppColors.presentColor,
                              ),
                              title: Text(student.fullName),
                              subtitle: Text(
                                '${student.studentCode} · ${busLabelForStudent(student, busLabels)}',
                              ),
                              trailing: const Icon(Icons.directions_bus),
                            ),
                          ),
                        ),
                      _sectionHeading(
                        'Select students to assign or move (${available.length})',
                      ),
                    ],
                    if (available.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Center(
                          child: Text(
                            _selectedBusId == null
                                ? 'No active students found.'
                                : assignedHere.isNotEmpty
                                ? 'All active students are already assigned to this bus.'
                                : 'No other students are available to assign.',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    else
                      ...available.map((student) {
                        final isSelected = _selectedStudents.contains(
                          student.id,
                        );
                        return Card(
                          child: CheckboxListTile(
                            value: isSelected,
                            onChanged: (_) => _toggleStudent(student.id),
                            title: Text(student.fullName),
                            subtitle: Text(
                              '${student.studentCode} · '
                              '${busLabelForStudent(student, busLabels)}',
                            ),
                            secondary: const Icon(Icons.school),
                          ),
                        );
                      }),
                  ],
                );
              },
              loading: () => const LoadingWidget(),
              error: (error, _) => Center(child: Text('Error: $error')),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: FilledButton.icon(
          onPressed: _selectedBusId == null || _selectedStudents.isEmpty
              ? null
              : _assignStudents,
          icon: const Icon(Icons.directions_bus),
          label: Text(
            _selectedBusId == null
                ? 'Select a bus first'
                : _selectedStudents.isEmpty
                ? 'Select students to assign or move'
                : 'Assign/move ${_selectedStudents.length} students',
          ),
        ),
      ),
    );
  }

  void _toggleStudent(String studentId) {
    setState(() {
      if (_selectedStudents.contains(studentId)) {
        _selectedStudents.remove(studentId);
      } else {
        _selectedStudents.add(studentId);
      }
    });
  }

  Widget _sectionHeading(String title) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
    child: Align(
      alignment: Alignment.centerLeft,
      child: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
    ),
  );

  Future<void> _assignStudents() async {
    if (_selectedBusId == null || _selectedStudents.isEmpty) return;

    try {
      final students =
          ref.read(studentsProvider).valueOrNull ?? const <StudentModel>[];
      final moves = busMovesToClear(
        students,
        _selectedStudents,
        _selectedBusId,
      );

      for (final studentId in _selectedStudents) {
        // Drop the student from their previous bus's mirror list so the old
        // bus stops counting them (best effort: a missing bus document must
        // not abort the assignment itself).
        final previousBusId = moves[studentId];
        if (previousBusId != null) {
          try {
            await FirebaseFirestore.instance
                .collection(AppConstants.colBuses)
                .doc(previousBusId)
                .update({
                  'studentIds': FieldValue.arrayRemove([studentId]),
                });
          } catch (e) {
            debugPrint('Previous bus cleanup skipped for $studentId: $e');
          }
        }

        // Update student bus assignment
        await FirebaseFirestore.instance
            .collection(AppConstants.colStudents)
            .doc(studentId)
            .update({'busId': _selectedBusId});

        // Add to bus student list
        await ref
            .read(busCrudProvider.notifier)
            .assignStudentToBus(_selectedBusId!, studentId);
      }

      if (!mounted) return;
      final assignedCount = _selectedStudents.length;
      ref.invalidate(studentsProvider);
      ref.invalidate(busesProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '$assignedCount students assigned to the selected bus.',
          ),
          backgroundColor: AppColors.presentColor,
        ),
      );
      setState(() {
        _selectedStudents.clear();
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
      );
    }
  }
}
