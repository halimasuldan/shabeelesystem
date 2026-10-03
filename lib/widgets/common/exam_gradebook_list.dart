import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/exam_gradebook_utils.dart';

class ExamGradebookList extends StatelessWidget {
  const ExamGradebookList({
    super.key,
    required this.results,
    required this.emptyMessage,
    this.onDeleteSubject,
    this.shrinkWrap = false,
    this.useCards = true,
  });

  final List<Map<String, dynamic>> results;
  final String emptyMessage;
  final Future<void> Function(List<String> resultIds)? onDeleteSubject;
  final bool shrinkWrap;
  final bool useCards;

  @override
  Widget build(BuildContext context) {
    final reports = buildExamGradebookReports(results);
    if (reports.isEmpty) return Center(child: Text(emptyMessage));

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      shrinkWrap: shrinkWrap,
      physics: shrinkWrap ? const NeverScrollableScrollPhysics() : null,
      itemCount: reports.length,
      itemBuilder: (context, index) {
        final report = reports[index];
        final reportContent = Padding(
          padding: EdgeInsets.all(useCards ? 16 : 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                report.studentName,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text('Class: ${report.className} · Course: ${report.courseName}'),
              const Divider(height: 24),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  horizontalMargin: 8,
                  columnSpacing: 20,
                  columns: [
                    const DataColumn(label: Text('Subject')),
                    for (final exam in report.exams.values)
                      DataColumn(label: Text(exam.name)),
                    const DataColumn(label: Text('Subject total')),
                    if (onDeleteSubject != null)
                      const DataColumn(label: Text('')),
                  ],
                  rows: [
                    for (final entry in report.subjects.entries)
                      DataRow(
                        cells: [
                          DataCell(Text(entry.value.name)),
                          for (final exam in report.exams.values)
                            DataCell(
                              Text(_formatMark(entry.value.examMarks[exam.id])),
                            ),
                          DataCell(
                            Text(
                              '${entry.value.totalScore} / ${entry.value.totalMaxMarks}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (onDeleteSubject != null)
                            DataCell(
                              entry.value.resultIds.isEmpty
                                  ? const SizedBox.shrink()
                                  : IconButton(
                                      tooltip:
                                          'Delete ${entry.value.name} marks',
                                      visualDensity: VisualDensity.compact,
                                      icon: const Icon(
                                        Icons.delete_outline,
                                        color: AppColors.schoolRed,
                                      ),
                                      onPressed: () => onDeleteSubject!(
                                        entry.value.resultIds,
                                      ),
                                    ),
                            ),
                        ],
                      ),
                  ],
                ),
              ),
              const Divider(height: 24),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Total',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  Text(
                    '${report.totalScore} / ${report.totalMaxMarks}',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
        if (!useCards) return reportContent;
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: reportContent,
        );
      },
    );
  }

  String _formatMark(dynamic mark) {
    if (mark == null) return '-';
    return '${mark.score} / ${mark.maxMarks}';
  }
}
