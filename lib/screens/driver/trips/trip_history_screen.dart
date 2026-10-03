import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../widgets/common/role_drawer.dart';
import '../../../widgets/common/loading_widget.dart';
import '../../../providers/driver_provider.dart';

/// Trip history screen for driver.
class TripHistoryScreen extends ConsumerWidget {
  const TripHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Trip History'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      drawer: const RoleBasedDrawer(
        role: AppConstants.roleDriver,
        userName: 'Driver',
        userEmail: '',
      ),
      body: ref
          .watch(driverBusIdProvider)
          .when(
            loading: () => const LoadingWidget(),
            error: (error, _) =>
                Center(child: Text('Unable to load your bus: $error')),
            data: (busId) {
              if (busId == null || busId.isEmpty) {
                return const Center(child: Text('No bus assigned.'));
              }
              return StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection(AppConstants.colBusTrips)
                    .where('busId', isEqualTo: busId)
                    .snapshots(),
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const LoadingWidget();
                  }
                  if (snap.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'Unable to load trip history: ${snap.error}',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }
                  final trips = [...?snap.data?.docs]
                    ..sort((a, b) {
                      final aData = a.data() as Map<String, dynamic>;
                      final bData = b.data() as Map<String, dynamic>;
                      final aStart = _tripStart(aData);
                      final bStart = _tripStart(bData);
                      if (aStart == null && bStart == null) return 0;
                      if (aStart == null) return 1;
                      if (bStart == null) return -1;
                      return bStart.compareTo(aStart);
                    });
                  if (trips.isEmpty) {
                    return const Center(child: Text('No trips yet.'));
                  }
                  return ListView.builder(
                    itemCount: trips.length,
                    itemBuilder: (context, index) {
                      final t = trips[index].data() as Map<String, dynamic>;
                      final start = (t['startTime'] as Timestamp?)?.toDate();
                      final end = (t['endTime'] as Timestamp?)?.toDate();
                      return Card(
                        child: ListTile(
                          title: Text('Trip ${index + 1}'),
                          subtitle: Text(
                            '${start != null ? start.toString().split('.').first : '?'} to ${end != null ? end.toString().split('.').first : 'Ongoing'}',
                          ),
                          trailing: Chip(
                            label: Text(t['status'] as String? ?? ''),
                            backgroundColor: (t['status'] == 'completed')
                                ? AppColors.schoolGreen
                                : AppColors.schoolOrange,
                          ),
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
}

DateTime? _tripStart(Map<String, dynamic> trip) {
  final value = trip['startTime'] ?? trip['createdAt'];
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return null;
}
