import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/api_service.dart';
import '../../utils/themes.dart';
import '../../widgets/api_collection_view.dart';
import '../../widgets/status_badge.dart';

class ApplicationReviewView extends StatelessWidget {
  const ApplicationReviewView({super.key});

  @override
  Widget build(BuildContext context) => ApiCollectionView(
        title: 'Review applications',
        path: '/applications',
        refreshInterval: const Duration(seconds: 15),
        emptyMessage: 'There are no applications to review yet.',
        itemBuilder: (item) =>
            ApplicationReviewCard(key: ValueKey(item['id']), application: item),
        collectionBuilder: (items) {
          final groups = <String, List<Map<String, dynamic>>>{};
          for (final item in items) {
            final id = (item['opportunity_id'] ?? item['opportunity_title'])
                .toString();
            groups.putIfAbsent(id, () => []).add(item);
          }
          final applicants = items
              .map((item) =>
                  item['learner_id'] ??
                  item['candidate_email'] ??
                  item['candidate_name'])
              .toSet();
          return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                    '${items.length} applications from ${applicants.length} '
                    '${applicants.length == 1 ? 'applicant' : 'applicants'}',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 16),
                for (final applications in groups.values) ...[
                  Text(
                      '${applications.first['opportunity_title']} (${applications.length})',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  for (final item in applications)
                    ApplicationReviewCard(
                        key: ValueKey(item['id']), application: item),
                  const SizedBox(height: 16),
                ],
              ]);
        },
      );
}

class ApplicationReviewCard extends StatefulWidget {
  const ApplicationReviewCard({super.key, required this.application});
  final Map<String, dynamic> application;

  @override
  State<ApplicationReviewCard> createState() => _ApplicationReviewCardState();
}

class _ApplicationReviewCardState extends State<ApplicationReviewCard> {
  bool _busy = false;
  late String _status;

  @override
  void initState() {
    super.initState();
    _status = widget.application['status'] as String;
  }

  @override
  void didUpdateWidget(covariant ApplicationReviewCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.application['status'] != widget.application['status']) {
      _status = widget.application['status'] as String;
    }
  }

  Future<void> _shortlist() async {
    setState(() => _busy = true);
    try {
      final id = Uri.encodeComponent(widget.application['id'].toString());
      await context
          .read<ApiService>()
          .put('/applications/$id', {'status': 'shortlisted'});
      if (mounted) setState(() => _status = 'shortlisted');
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content:
                Text('Unable to shortlist this candidate. Please try again.')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final candidateName = widget.application['candidate_name'] as String;
    final isShortlisted = _status == 'shortlisted';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.primaryLight,
                  foregroundColor: AppColors.primary,
                  radius: 20,
                  child: Text(
                    candidateName.isNotEmpty
                        ? candidateName[0].toUpperCase()
                        : '?',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        candidateName,
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${widget.application['opportunity_title']} • $_status',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                if (isShortlisted)
                  const StatusBadge.success(
                    label: 'Shortlisted',
                    icon: Icons.check_circle_outline,
                  )
                else
                  const StatusBadge.info(
                    label: 'Under Review',
                    icon: Icons.pending_outlined,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (widget.application['candidate_email'] is String) ...[
              Text(widget.application['candidate_email'] as String),
              const SizedBox(height: 8),
            ],
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.borderLight),
              ),
              child: Text(
                'Application reference: ${widget.application['id']}',
                style: theme.textTheme.labelMedium
                    ?.copyWith(color: AppColors.textMuted),
              ),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                icon: Icon(
                  isShortlisted ? Icons.check : Icons.star_outline,
                  size: 18,
                ),
                onPressed: _busy || isShortlisted ? null : _shortlist,
                style: FilledButton.styleFrom(
                  backgroundColor:
                      isShortlisted ? AppColors.success : AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                label: Text(
                  _busy
                      ? 'Saving…'
                      : isShortlisted
                          ? 'Shortlisted'
                          : 'Shortlist candidate',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
