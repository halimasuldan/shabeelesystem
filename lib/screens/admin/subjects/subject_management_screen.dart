import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../widgets/common/role_drawer.dart';
import '../../../widgets/common/loading_widget.dart';

/// Admin screen: register subjects and associate them with classes.
class SubjectManagementScreen extends ConsumerStatefulWidget {
  const SubjectManagementScreen({super.key});

  @override
  ConsumerState<SubjectManagementScreen> createState() =>
      _SubjectManagementScreenState();
}

class _SubjectManagementScreenState
    extends ConsumerState<SubjectManagementScreen> {
  final _nameController = TextEditingController();
  String? _selectedClassId;
  String? _selectedClassName;
  bool _busy = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _createSubject() async {
    final name = _nameController.text.trim();
    if (name.isEmpty || _selectedClassId == null || _busy) return;
    setState(() => _busy = true);
    try {
      await FirebaseFirestore.instance
          .collection('subjects')
          .add({
        'name': name,
        'classId': _selectedClassId,
        'className': _selectedClassName ?? '',
        'createdAt': FieldValue.serverTimestamp(),
      });
      _nameController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Subject registered!'),
            backgroundColor: AppColors.presentColor));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: AppColors.error));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteSubject(String id) async {
    await FirebaseFirestore.instance.collection('subjects').doc(id).delete();
  }
  @override
  Widget build(BuildContext context) {
    final classesStream = FirebaseFirestore.instance
        .collection(AppConstants.colClasses)
        .orderBy('name')
        .snapshots();
    final subjectsStream = FirebaseFirestore.instance
        .collection('subjects')
        .orderBy('name')
        .snapshots();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Subject Registration'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      drawer: const RoleBasedDrawer(
          role: AppConstants.roleAdmin,
          userName: 'Admin',
          userEmail: 'admin@school.com'),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(children: [
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                      labelText: 'Subject Name',
                      hintText: 'E.g., Mathematics',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.menu_book)),
                ),
                const SizedBox(height: 12),
                StreamBuilder<QuerySnapshot>(
                  stream: classesStream,
                  builder: (context, snap) {
                    final docs = snap.data?.docs ?? [];
                    return DropdownButtonFormField<String>(
                      initialValue: _selectedClassId,
                      decoration: const InputDecoration(
                          labelText: 'Belongs to Class',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.school)),
                      items: docs
                          .map((d) => DropdownMenuItem(
                              value: d.id,
                              child: Text((d.data() as Map<String, dynamic>)[
                                      'name'] as String? ??
                                  d.id)))
                          .toList(),
                      onChanged: (v) => setState(() {
                        _selectedClassId = v;
                        final match = docs.where((d) => d.id == v).toList();
                        _selectedClassName = match.isEmpty
                            ? null
                            : (match.first.data()
                                as Map<String, dynamic>)['name'] as String?;
                      }),
                    );
                  },
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _busy ? null : _createSubject,
                    icon: const Icon(Icons.add),
                    label: const Text('Register Subject'),
                  ),
                ),
              ]),
            ),
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: subjectsStream,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const LoadingWidget();
              }
              final docs = snap.data?.docs ?? [];
              if (docs.isEmpty) {
                return const Center(child: Text('No subjects yet.'));
              }
              return ListView.builder(
                itemCount: docs.length,
                itemBuilder: (context, i) {
                  final data = docs[i].data() as Map<String, dynamic>;
                  return Card(
                    child: ListTile(
                      leading: const Icon(Icons.menu_book,
                          color: AppColors.teacherColor),
                      title: Text(data['name'] as String? ?? '',
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text('Class: ${data['className'] ?? ''}'),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete,
                            color: AppColors.schoolRed),
                        onPressed: () => _deleteSubject(docs[i].id),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ]),
    );
  }
}
