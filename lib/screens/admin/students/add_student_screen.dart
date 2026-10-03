import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/validators.dart';
import '../../../models/student_model.dart';
import '../../../providers/student_provider.dart';
import '../../../providers/bus_provider.dart';
import '../../../providers/parent_provider.dart';
import '../../../widgets/forms/form_fields.dart';
import '../../../widgets/common/loading_widget.dart';

/// Add student screen with comprehensive form.
class AddStudentScreen extends ConsumerStatefulWidget {
  const AddStudentScreen({super.key});

  @override
  ConsumerState<AddStudentScreen> createState() => _AddStudentScreenState();
}

class _AddStudentScreenState extends ConsumerState<AddStudentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _studentCodeController = TextEditingController();
  final _addressController = TextEditingController();
  final _emergencyContactNameController = TextEditingController();
  final _emergencyContactPhoneController = TextEditingController();
  final _parentPhoneController = TextEditingController();

  String? _selectedGender;
  String? _selectedClass;
  String? _selectedClassName;
  String? _selectedSection;
  String? _selectedBusId;
  String? _selectedParentId;
  String? _profilePhotoUrl;
  DateTime? _selectedDate;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _studentCodeController.text =
        'STU-${DateTime.now().year}-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _studentCodeController.dispose();
    _addressController.dispose();
    _emergencyContactNameController.dispose();
    _emergencyContactPhoneController.dispose();
    _parentPhoneController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _saveStudent() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isLoading = true);

    try {
      final student = StudentModel(
        id: const Uuid().v4(),
        studentCode: _studentCodeController.text.trim(),
        fullName: _fullNameController.text.trim(),
        gender: _selectedGender ?? 'male',
        dateOfBirth: _selectedDate,
        classId: _selectedClass ?? '',
        className: _selectedClassName ?? '',
        sectionId: _selectedSection,
        sectionName: _selectedSection,
        parentIds: _selectedParentId != null ? [_selectedParentId!] : [],
        busId: _selectedBusId,
        address: _addressController.text.trim(),
        emergencyContactName:
            _emergencyContactNameController.text.trim(),
        emergencyContactPhone:
            _emergencyContactPhoneController.text.trim(),
        photoUrl: _profilePhotoUrl,
        status: 'active',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await ref.read(studentCrudProvider.notifier).createStudent(student);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Student added successfully!'),
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
  Widget build(BuildContext context) {
    final parentsAsync = ref.watch(parentsProvider);
    final busesAsync = ref.watch(busesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Student'),
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
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Profile Photo
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
                      if (_profilePhotoUrl != null)
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: CircleAvatar(
                            radius: 18,
                            backgroundColor: AppColors.error,
                            child: const Icon(Icons.delete,
                                color: Colors.white, size: 20),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Student Code
                AppTextField(
                  label: 'Student ID',
                  controller: _studentCodeController,
                  validator: (v) => Validators.validateRequired(v, 'Student ID'),
                  prefixIcon: Icons.badge,
                ),
                const SizedBox(height: 16),
                // Full Name
                AppTextField(
                  label: 'Full Name',
                  hint: 'Enter student full name',
                  controller: _fullNameController,
                  validator: (v) => Validators.validateRequired(v, 'Full Name'),
                  prefixIcon: Icons.person,
                ),
                const SizedBox(height: 16),
                // Gender
                _buildGenderSelector(),
                const SizedBox(height: 16),
                // Date of Birth
                _buildDateSelector(),
                const SizedBox(height: 16),
                // Class
                _buildClassSelector(),
                const SizedBox(height: 16),
                // Section
                _buildSectionSelector(),
                const SizedBox(height: 16),
                // Parent
                parentsAsync.when(
                  data: (parents) => AppDropdownField<String>(
                    label: 'Parent/Guardian',
                    hint: 'Select parent',
                    value: _selectedParentId,
                    items: parents
                        .map((p) => DropdownMenuItem(
                            value: p.id, child: Text(p.name)))
                        .toList(),
                    onChanged: (value) {
                      setState(() => _selectedParentId = value);
                    },
                    prefixIcon: Icons.family_restroom,
                  ),
                  loading: () => const LoadingWidget(),
                  error: (error, _) =>
                      Text('Error loading parents: $error'),
                ),
                const SizedBox(height: 16),
                // Parent Phone
                AppTextField(
                  label: 'Parent Phone Number',
                  controller: _parentPhoneController,
                  validator: Validators.validatePhone,
                  prefixIcon: Icons.phone,
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 16),
                // Bus Assignment
                busesAsync.when(
                  data: (buses) => AppDropdownField<String>(
                    label: 'Bus Assignment',
                    hint: 'Select bus (optional)',
                    value: _selectedBusId,
                    items: [
                      const DropdownMenuItem(value: null, child: Text('None')),
                      ...buses.map((b) => DropdownMenuItem(
                          value: b.id,
                          child: Text('${b.busNumber} - ${b.plateNumber}')))
                    ],
                    onChanged: (value) {
                      setState(() => _selectedBusId = value);
                    },
                    prefixIcon: Icons.directions_bus,
                  ),
                  loading: () => const LoadingWidget(),
                  error: (error, _) =>
                      Text('Error loading buses: $error'),
                ),
                const SizedBox(height: 16),
                // Address
                AppTextField(
                  label: 'Address',
                  hint: 'Enter student address',
                  controller: _addressController,
                  maxLines: 3,
                  validator: (v) => Validators.validateRequired(v, 'Address'),
                  prefixIcon: Icons.home,
                ),
                const SizedBox(height: 16),
                // Emergency Contact
                AppTextField(
                  label: 'Emergency Contact Name',
                  controller: _emergencyContactNameController,
                  validator: (v) => Validators.validateRequired(v, 'Emergency Contact Name'),
                  prefixIcon: Icons.contact_phone,
                ),
                const SizedBox(height: 16),
                AppTextField(
                  label: 'Emergency Contact Phone',
                  controller: _emergencyContactPhoneController,
                  validator: Validators.validatePhone,
                  prefixIcon: Icons.phone,
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _saveStudent,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text('Save Student',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGenderSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Gender',
            style:
                TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: _buildGenderOption(Icons.male, 'Male', 'male')),
            const SizedBox(width: 12),
            Expanded(
              child: _buildGenderOption(Icons.female, 'Female', 'female')),
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
        const Text('Date of Birth',
            style:
                TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        InkWell(
          onTap: _selectDate,
          child: InputDecorator(
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.calendar_today),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12)),
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
              prefixIcon: Icon(Icons.school)),
          items: docs
              .map((d) => DropdownMenuItem(
                  value: d.id,
                  child: Text((d.data()
                          as Map<String, dynamic>)['name'] as String? ??
                      d.id)))
              .toList(),
          onChanged: (v) {
            setState(() {
              _selectedClass = v;
              final match =
                  docs.where((d) => d.id == v).toList();
              _selectedClassName = match.isEmpty
                  ? ''
                  : (match.first.data()
                          as Map<String, dynamic>)['name'] as String? ??
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
      prefixIcon: Icons.view_module,
    );
  }
}

/// Reusable choice tile for gender selection.
class ChoiceTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const ChoiceTile({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.1)
              : AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.divider,
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Icon(icon,
                color: selected ? AppColors.primary : AppColors.textSecondary,
                size: 28),
            const SizedBox(height: 4),
            Text(label,
                style: TextStyle(
                    color: selected
                        ? AppColors.primary
                        : AppColors.textSecondary,
                    fontWeight: selected
                        ? FontWeight.w600
                        : FontWeight.normal)),
          ],
        ),
      ),
    );
  }
}
