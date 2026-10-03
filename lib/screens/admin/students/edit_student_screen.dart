import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/validators.dart';
import '../../../providers/student_provider.dart';
import '../../../providers/bus_provider.dart';
import '../../../providers/parent_provider.dart';
import '../../../widgets/forms/form_fields.dart';
import '../../../widgets/common/loading_widget.dart';
import 'add_student_screen.dart';

/// Edit student screen - loads existing student data for modification.
class EditStudentScreen extends ConsumerStatefulWidget {
  final String studentId;

  const EditStudentScreen({super.key, required this.studentId});

  @override
  ConsumerState<EditStudentScreen> createState() => _EditStudentScreenState();
}

class _EditStudentScreenState extends ConsumerState<EditStudentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _studentCodeController = TextEditingController();
  final _addressController = TextEditingController();
  final _emergencyContactNameController = TextEditingController();
  final _emergencyContactPhoneController = TextEditingController();

  String? _selectedGender;
  String? _selectedClass;
  String? _selectedClassName;
  String? _selectedSection;
  String? _selectedBusId;
  String? _selectedParentId;
  String? _profilePhotoUrl;
  DateTime? _selectedDate;
  bool _isLoading = false;
  bool _isDataLoaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadStudentData();
  }

  Future<void> _loadStudentData() async {
    if (_isDataLoaded) return;
    final studentAsync = await ref.read(
      studentProvider(widget.studentId).future,
    );
    final student = studentAsync;
    if (student == null) return;
    setState(() {
      _fullNameController.text = student.fullName;
      _studentCodeController.text = student.studentCode;
      _addressController.text = student.address;
      _emergencyContactNameController.text = student.emergencyContactName;
      _emergencyContactPhoneController.text = student.emergencyContactPhone;
      _selectedGender = student.gender;
      _selectedClass = student.classId;
      _selectedClassName = student.className;
      _selectedSection = student.sectionId;
      _selectedBusId = student.busId;
      _selectedParentId = student.parentIds.isNotEmpty
          ? student.parentIds.first
          : null;
      _profilePhotoUrl = student.photoUrl;
      _selectedDate = student.dateOfBirth;
      _isDataLoaded = true;
    });
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _saveChanges() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _isLoading = true);

    try {
      final studentAsync = await ref.read(
        studentProvider(widget.studentId).future,
      );
      if (studentAsync == null) return;

      final updatedStudent = studentAsync.copyWith(
        fullName: _fullNameController.text.trim(),
        studentCode: _studentCodeController.text.trim(),
        gender: _selectedGender ?? 'male',
        dateOfBirth: _selectedDate,
        classId: _selectedClass ?? '',
        className: _selectedClassName ?? '',
        sectionId: _selectedSection,
        sectionName: _selectedSection,
        parentIds: _selectedParentId != null ? [_selectedParentId!] : [],
        busId: _selectedBusId,
        address: _addressController.text.trim(),
        emergencyContactName: _emergencyContactNameController.text.trim(),
        emergencyContactPhone: _emergencyContactPhoneController.text.trim(),
        updatedAt: DateTime.now(),
      );

      await ref
          .read(studentCrudProvider.notifier)
          .updateStudent(updatedStudent);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Student updated successfully!'),
          backgroundColor: AppColors.presentColor,
        ),
      );
      context.go('/admin/students');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _studentCodeController.dispose();
    _addressController.dispose();
    _emergencyContactNameController.dispose();
    _emergencyContactPhoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final studentAsync = ref.watch(studentProvider(widget.studentId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Student'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(12),
              child: SizedBox.square(
                dimension: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.delete, color: AppColors.schoolRed),
            onPressed: studentAsync.hasValue && studentAsync.value != null
                ? () => _deleteStudent(studentAsync.value!.id)
                : null,
          ),
        ],
      ),
      body: studentAsync.when(
        data: (student) {
          if (student == null) {
            return const Center(child: Text('Student not found.'));
          }
          if (!_isDataLoaded) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _loadStudentData();
            });
          }
          return _buildForm();
        },
        loading: () => const LoadingWidget(),
        error: (error, _) => Center(child: Text('Error: $error')),
      ),
      floatingActionButton: _isDataLoaded
          ? FloatingActionButton.extended(
              onPressed: _isLoading ? null : _saveChanges,
              backgroundColor: AppColors.primary,
              icon: _isLoading
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.save, color: Colors.white),
              label: const Text('Save Changes'),
            )
          : null,
    );
  }

  Widget _buildForm() {
    final parentsAsync = ref.watch(parentsProvider);
    final busesAsync = ref.watch(busesProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundImage: _profilePhotoUrl != null
                        ? CachedNetworkImageProvider(_profilePhotoUrl!)
                        : null,
                    child: _profilePhotoUrl == null
                        ? const Icon(Icons.person, size: 40)
                        : null,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            AppTextField(
              label: 'Student ID',
              controller: _studentCodeController,
              readOnly: true,
              validator: (v) => Validators.validateRequired(v, 'Student ID'),
            ),
            const SizedBox(height: 16),
            AppTextField(
              label: 'Full Name',
              controller: _fullNameController,
              validator: (v) => Validators.validateRequired(v, 'Full Name'),
              prefixIcon: Icons.person,
            ),
            const SizedBox(height: 16),
            _buildGenderSelector(),
            const SizedBox(height: 16),
            _buildDateSelector(),
            const SizedBox(height: 16),
            _buildClassSelector(),
            const SizedBox(height: 16),
            _buildSectionSelector(),
            const SizedBox(height: 16),
            parentsAsync.when(
              data: (parents) => AppDropdownField<String>(
                label: 'Parent/Guardian',
                hint: 'Select parent',
                value: _selectedParentId,
                items: parents
                    .map(
                      (p) => DropdownMenuItem(value: p.id, child: Text(p.name)),
                    )
                    .toList(),
                onChanged: (value) => setState(() => _selectedParentId = value),
              ),
              loading: () => const LoadingWidget(),
              error: (error, _) => Text('Error: $error'),
            ),
            const SizedBox(height: 16),
            busesAsync.when(
              data: (buses) => AppDropdownField<String>(
                label: 'Bus Assignment',
                hint: 'Select bus (optional)',
                value: _selectedBusId,
                items: [
                  const DropdownMenuItem(value: null, child: Text('None')),
                  ...buses.map(
                    (b) => DropdownMenuItem(
                      value: b.id,
                      child: Text('${b.busNumber} - ${b.plateNumber}'),
                    ),
                  ),
                ],
                onChanged: (value) => setState(() => _selectedBusId = value),
              ),
              loading: () => const LoadingWidget(),
              error: (error, _) => Text('Error: $error'),
            ),
            const SizedBox(height: 16),
            AppTextField(
              label: 'Address',
              hint: 'Enter student address',
              controller: _addressController,
              maxLines: 3,
              validator: (v) => Validators.validateRequired(v, 'Address'),
            ),
            const SizedBox(height: 16),
            AppTextField(
              label: 'Emergency Contact Name',
              controller: _emergencyContactNameController,
              validator: (v) =>
                  Validators.validateRequired(v, 'Emergency Contact Name'),
            ),
            const SizedBox(height: 16),
            AppTextField(
              label: 'Emergency Contact Phone',
              controller: _emergencyContactPhoneController,
              validator: Validators.validatePhone,
              keyboardType: TextInputType.phone,
            ),
          ],
        ),
      ),
    );
  }

  void _deleteStudent(String id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: const Text(
          'Are you sure you want to deactivate this student?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await ref.read(studentCrudProvider.notifier).deleteStudent(id);
              if (!context.mounted) return;
              Navigator.pop(context);
              context.go('/admin/students');
            },
            child: const Text(
              'Delete',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGenderSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Gender',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(child: _buildGenderOption(Icons.male, 'Male', 'male')),
            const SizedBox(width: 12),
            Expanded(
              child: _buildGenderOption(Icons.female, 'Female', 'female'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildGenderOption(IconData icon, String label, String value) {
    final selected = _selectedGender == value;
    return ChoiceTile(
      icon: icon,
      label: label,
      selected: selected,
      onTap: () => setState(() => _selectedGender = value),
    );
  }

  Widget _buildDateSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Date of Birth',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        InkWell(
          onTap: _selectDate,
          child: InputDecorator(
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.calendar_today),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              _selectedDate != null
                  ? '${_selectedDate!.month}/${_selectedDate!.day}/${_selectedDate!.year}'
                  : 'Select date of birth',
              style: TextStyle(
                color: _selectedDate != null
                    ? AppColors.textPrimary
                    : AppColors.textDisabled,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildClassSelector() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection(AppConstants.colClasses)
          .orderBy('name')
          .snapshots(),
      builder: (context, snap) {
        final docs = snap.data?.docs ?? [];
        return DropdownButtonFormField<String>(
          initialValue: (_selectedClass ?? '').isEmpty ? null : _selectedClass,
          decoration: const InputDecoration(
            labelText: 'Grade/Class',
            hintText: 'Select registered class',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.school),
          ),
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
          onChanged: (v) {
            setState(() {
              _selectedClass = v;
              final match = docs.where((d) => d.id == v).toList();
              _selectedClassName = match.isEmpty
                  ? ''
                  : (match.first.data() as Map<String, dynamic>)['name']
                            as String? ??
                        '';
            });
          },
        );
      },
    );
  }

  Widget _buildSectionSelector() {
    final sections = ['A', 'B', 'C', 'D'];
    return AppDropdownField<String>(
      label: 'Section',
      hint: 'Select section',
      value: _selectedSection,
      items: sections
          .map((s) => DropdownMenuItem(value: s, child: Text('Section $s')))
          .toList(),
      onChanged: (value) => setState(() => _selectedSection = value),
    );
  }
}
