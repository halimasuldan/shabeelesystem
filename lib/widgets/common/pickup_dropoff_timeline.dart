import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/date_utils.dart';
import '../../models/pickup_dropoff_model.dart';
import '../../providers/pickup_dropoff_provider.dart';
import 'loading_widget.dart';

/// Timeline of the pickup / drop-off events recorded for one student.
///
/// This is what answers a parent's "when was my child picked up and dropped
/// off?": the driver portal appends one event per status change, so this widget
/// can show the times even though `students/{id}` only stores the latest state.
class PickupDropoffTimeline extends ConsumerWidget {
  const PickupDropoffTimeline({
    super.key,
    required this.studentId,
    this.maxItems,
    this.showEmptyState = true,
  });

  /// Student whose events are shown.
  final String studentId;

  /// When set, only the newest [maxItems] events are rendered.
  final int? maxItems;

  /// Whether to render an explanation when no event exists yet.
  final bool showEmptyState;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(studentPickupDropoffProvider(studentId));

    return eventsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: LoadingWidget(),
      ),
      error: (error, _) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          'Could not load bus activity: $error',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
      ),
      data: (events) {
        final visible = maxItems == null
            ? events
            : events.take(maxItems!).toList();
        if (visible.isEmpty) {
          if (!showEmptyState) return const SizedBox.shrink();
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'No pickup or drop-off has been recorded for this child yet.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          );
        }
        return Column(
          children: <Widget>[
            for (var i = 0; i < visible.length; i++)
              _buildEvent(visible[i], isLast: i == visible.length - 1),
          ],
        );
      },
    );
  }

  Widget _buildEvent(PickupDropoffModel event, {required bool isLast}) {
    final color = _colorFor(event.status);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Timeline rail: a marker per event joined by a connector line.
          Column(
            children: <Widget>[
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(_iconFor(event), size: 16, color: color),
              ),
              if (!isLast)
                Expanded(child: Container(width: 2, color: AppColors.divider)),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    PickupDropoffModel.labelFor(event.status),
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  // Which of the driver's two daily runs this belongs to, so
                  // a parent can tell the morning trip from the afternoon one
                  // at a glance ("Home → school" vs "School → home").
                  Text(
                    PickupDropoffModel.labelForTrip(event.tripType),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.schoolBlue,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    DateTimeUtils.formatDateTime(event.timestamp),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  if (event.note != null && event.note!.isNotEmpty)
                    Text(
                      event.note!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            event.isPickup ? 'Pickup' : 'Drop-off',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconFor(PickupDropoffModel event) {
    switch (event.status) {
      case 'at_school':
        return Icons.school_rounded;
      case 'on_bus':
        return Icons.airport_shuttle_rounded;
      case 'picked_up':
        return Icons.directions_bus_rounded;
      case 'dropped_off':
        return Icons.home_rounded;
      case 'absent':
        return Icons.person_off_rounded;
      default:
        return event.isPickup
            ? Icons.directions_bus_rounded
            : Icons.home_rounded;
    }
  }

  Color _colorFor(String status) {
    switch (status) {
      case 'at_school':
      case 'dropped_off':
        return AppColors.schoolGreen;
      case 'picked_up':
      case 'on_bus':
        return AppColors.schoolBlue;
      case 'absent':
        return AppColors.schoolRed;
      default:
        return AppColors.textSecondary;
    }
  }
}
