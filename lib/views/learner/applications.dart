import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../widgets/api_collection_view.dart';
import '../../widgets/app_card.dart';
import '../../widgets/status_badge.dart';

class ApplicationsView extends StatelessWidget {
  const ApplicationsView({super.key});

  static Widget _statusBadge(String status) => switch (status.toLowerCase()) {
        'shortlisted' => const StatusBadge.success(
            label: 'Shortlisted', icon: Icons.check_circle_outline),
        'submitted' =>
          const StatusBadge.info(label: 'Submitted', icon: Icons.send_outlined),
        'reviewing' => const StatusBadge.warning(
            label: 'In Review', icon: Icons.pending_outlined),
        'rejected' => const StatusBadge(label: 'Not selected'),
        _ => StatusBadge(label: status),
      };

  @override
  Widget build(BuildContext context) => ApiCollectionView(
        title: 'Your applications',
        path: '/applications/me',
        refreshInterval: const Duration(seconds: 15),
        countLabel: 'applications',
        emptyMessage: 'Your submitted applications will appear here.',
        itemBuilder: (item) {
          final status = (item['status'] as String?) ?? 'Submitted';
          final createdAt =
              DateTime.parse(item['created_at'] as String).toLocal();
          return AppCard(
            key: ValueKey(item['id']),
            title: item['opportunity_title'] as String,
            icon: Icons.work_outline,
            statusBadge: _statusBadge(status),
            subtitle: '$status • ${DateFormat.yMMMd().format(createdAt)}',
          );
        },
      );
}
