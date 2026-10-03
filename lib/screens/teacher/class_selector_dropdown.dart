import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/auth_service.dart';
import '../../providers/auth_provider.dart';

/// Reusable class selector dropdown.
///
/// Teachers only see classes associated with their profile
/// (classes whose `teacherId` matches their teacher doc id, or whose
/// name appears in the teacher's `classIds` list). Admins see all.
class ClassSelectorDropdown extends ConsumerWidget {
  final String? value;
  final void Function(String?) onChanged;
  const ClassSelectorDropdown({super.key, this.value, required this.onChanged});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final isTeacher = user?.role == AppConstants.roleTeacher;
    final uid = AuthService().currentUser?.uid ?? '';

    if (isTeacher && uid.isNotEmpty) {
      return StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection(AppConstants.colTeachers)
            .where('userId', isEqualTo: uid)
            .limit(1)
            .snapshots(),
        builder: (context, tSnap) {
          String? teacherDocId;
          List<String> classNames = const [];
          if (tSnap.hasData && tSnap.data!.docs.isNotEmpty) {
            final t = tSnap.data!.docs.first.data() as Map<String, dynamic>;
            teacherDocId = tSnap.data!.docs.first.id;
            classNames = List<String>.from(t['classIds'] as List? ?? const []);
          }
          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection(AppConstants.colClasses)
                .where('teacherId', isEqualTo: teacherDocId ?? '__none__')
                .snapshots(),
            builder: (context, cSnap) {
              final docs = cSnap.data?.docs ?? [];
              if (docs.isNotEmpty || teacherDocId == null) {
                return _buildDropdown(docs);
              }
              // Fallback: match by class name when teacherId isn't set.
              return StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection(AppConstants.colClasses)
                    .snapshots(),
                builder: (context, allSnap) {
                  final all = allSnap.data?.docs ?? [];
                  final filtered = all
                      .where(
                        (d) =>
                            classNames.contains(d['name'] as String?) ||
                            classNames.contains(d.id),
                      )
                      .toList();
                  return _buildDropdown(filtered.isEmpty ? all : filtered);
                },
              );
            },
          );
        },
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection(AppConstants.colClasses)
          .snapshots(),
      builder: (context, snapshot) => _buildDropdown(snapshot.data?.docs ?? []),
    );
  }

  Widget _buildDropdown(List<QueryDocumentSnapshot> docs) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: const InputDecoration(labelText: 'Select Class'),
      items: docs
          .map(
            (d) => DropdownMenuItem(
              value: d.id,
              child: Text(
                (d.data() as Map<String, dynamic>)['name'] as String? ?? d.id,
              ),
            ),
          )
          .toList(),
      onChanged: onChanged,
    );
  }
}
