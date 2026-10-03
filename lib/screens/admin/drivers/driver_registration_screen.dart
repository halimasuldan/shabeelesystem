import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_strings.dart';
import '../../../providers/driver_provider.dart';
import '../../../widgets/common/school_brand.dart';
import '../../../widgets/common/role_drawer.dart';

class DriverRegistrationScreen extends ConsumerStatefulWidget {
  const DriverRegistrationScreen({super.key});

  @override
  ConsumerState<DriverRegistrationScreen> createState() =>
      _DriverRegistrationScreenState();
}

class _DriverRegistrationScreenState
    extends ConsumerState<DriverRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _licCtrl = TextEditingController();
  final _licExpiryCtrl = TextEditingController();
  final _emerNameCtrl = TextEditingController();
  final _emerPhoneCtrl = TextEditingController();
  final _addrCtrl = TextEditingController();

  bool _obscurePw = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    _licCtrl.dispose();
    _licExpiryCtrl.dispose();
    _emerNameCtrl.dispose();
    _emerPhoneCtrl.dispose();
    _addrCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {});
    try {
      await ref.read(driverProvider.notifier).registerDriver(
            name: _nameCtrl.text.trim(),
            email: _emailCtrl.text.trim(),
            phone: _phoneCtrl.text.trim(),
            password: _passwordCtrl.text.trim(),
            licenseNumber:
                _licCtrl.text.trim().isEmpty ? null : _licCtrl.text.trim(),
            licenseExpiry: _licExpiryCtrl.text.trim().isEmpty
                ? null
                : _licExpiryCtrl.text.trim(),
            emergencyContactName:
                _emerNameCtrl.text.trim().isEmpty
                    ? null
                    : _emerNameCtrl.text.trim(),
            emergencyContactPhone:
                _emerPhoneCtrl.text.trim().isEmpty
                    ? null
                    : _emerPhoneCtrl.text.trim(),
            address:
                _addrCtrl.text.trim().isEmpty ? null : _addrCtrl.text.trim(),
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(AppStrings.driverRegisteredPending),
            backgroundColor: AppColors.warning,
          ),
        );
        context.go('/admin/drivers/pending');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Registration failed: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu_rounded),
            tooltip: 'Open menu',
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SchoolBrand(compact: true, light: true, showName: false),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                AppStrings.registerDriver,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      drawer: const RoleBasedDrawer(
        role: AppConstants.roleAdmin,
        userName: 'Admin',
        userEmail: 'admin@school.com',
      ),
      body: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _brandHeader(context),
            const SizedBox(height: 14),
            Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.warning.withValues(alpha: 0.4),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.info_outline,
                        color: AppColors.warning, size: 16),
                    SizedBox(width: 8),
                    Text(
                      "New drivers are created with 'pending' status. "
                      "Review and approve them in Pending Verification.",
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.warning,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  _sectionCard(
                    context,
                    AppStrings.personalInfo,
                    Icons.person,
                    AppColors.schoolBlue,
                    [
                      _field(AppStrings.fullName, _nameCtrl,
                          Icons.person_outline,
                          validator: (v) =>
                              v == null || v.isEmpty ? 'Required' : null),
                      const SizedBox(height: 12),
                      _field(AppStrings.email, _emailCtrl,
                          Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                          validator: (v) => v == null || v.isEmpty
                              ? 'Required'
                              : !v.contains('@')
                                  ? 'Invalid email'
                                  : null),
                      const SizedBox(height: 12),
                      _field(AppStrings.phone, _phoneCtrl,
                          Icons.phone_outlined,
                          keyboardType: TextInputType.phone,
                          validator: (v) =>
                              v == null || v.isEmpty ? 'Required' : null),
                      const SizedBox(height: 12),
                                            _field(AppStrings.password, _passwordCtrl,
                          Icons.lock_outlined,
                          obscure: _obscurePw,
                          onToggle: () =>
                              setState(() => _obscurePw = !_obscurePw),
                          validator: (v) => v == null || v.length < 6
                              ? 'At least 6 characters'
                              : null),
                      const SizedBox(height: 12),
                      _field(
                        'Confirm Password',
                        _confirmCtrl,
                        Icons.lock_outlined,
                        obscure: _obscureConfirm,
                        onToggle: () => setState(
                            () => _obscureConfirm = !_obscureConfirm),
                        validator: (v) {
                          final pw = _passwordCtrl.text.trim();
                          if (v == null || v.isEmpty) return 'Required';
                          if (v != pw) return 'Passwords do not match';
                          return null;
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _sectionCard(
                    context,
                    AppStrings.professionalDetails,
                    Icons.badge,
                    AppColors.driverColor,
                    [
                      _field(AppStrings.licenseNumber, _licCtrl,
                          Icons.account_balance_outlined,
                          hint: 'Optional'),
                      const SizedBox(height: 12),
                      _field(AppStrings.licenseExpiry, _licExpiryCtrl,
                          Icons.calendar_today_outlined,
                          hint: 'YYYY-MM-DD'),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _sectionCard(
                    context,
                    AppStrings.emergencyContact,
                    Icons.family_restroom,
                    AppColors.schoolTeal,
                    [
                      _field(AppStrings.emergencyContactName, _emerNameCtrl,
                          Icons.person_outline),
                      const SizedBox(height: 12),
                      _field(AppStrings.emergencyContactPhone, _emerPhoneCtrl,
                          Icons.phone_outlined,
                          keyboardType: TextInputType.phone),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _field(AppStrings.address, _addrCtrl,
                      Icons.location_on_outlined,
                      color: AppColors.schoolPurple,
                      hint: 'Optional', maxLines: 2),
                  const SizedBox(height: 22),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _submit,
                          icon: const Icon(Icons.person_add, size: 20),
                          label:
                              const Text(AppStrings.registerDriver),
                          style: ElevatedButton.styleFrom(
                            padding:
                                const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            backgroundColor: AppColors.driverColor,
                          ),
                        ),
                      ),
                    ],
                  ),
            ),
          ],
        ),
      ),
    );
  }


  Widget _brandHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.35),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          const SchoolBrand(
            compact: false,
            light: true,
            showName: false,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Driver Registration',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Add a new driver to the system',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionCard(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
    List<Widget> children,
  ) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }


  Widget _field(
    String title,
    TextEditingController ctrl,
    IconData icon, {
    Color? color,
    String? hint,
    TextInputType? keyboardType,
    int maxLines = 1,
    bool obscure = false,
    VoidCallback? onToggle,
    String? Function(String?)? validator,
  }) {
    final fieldColor = color ?? AppColors.textSecondary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: fieldColor, size: 18),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: fieldColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: ctrl,
          obscureText: obscure,
          maxLines: maxLines,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: AppColors.cardBackground,
            border: OutlineInputBorder(
              borderSide:
                  const BorderSide(color: AppColors.divider, width: 1.0),
              borderRadius: BorderRadius.circular(10),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide:
                  const BorderSide(color: AppColors.primary, width: 1.6),
              borderRadius: BorderRadius.circular(10),
            ),
            enabledBorder: OutlineInputBorder(
              borderSide:
                  const BorderSide(color: AppColors.divider, width: 1.0),
              borderRadius: BorderRadius.circular(10),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          ),
          validator: validator,
        ),
        if (onToggle != null) ...[
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: onToggle,
              child: Text(
                obscure ? 'Show' : 'Hide',
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

