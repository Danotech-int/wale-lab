import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/job_opportunity.dart';
import '../../services/api_service.dart';
import '../../utils/constants.dart';
import '../../widgets/app_button.dart';
import '../../widgets/page_layout.dart';

class OpportunitiesView extends StatefulWidget {
  const OpportunitiesView({super.key});

  @override
  State<OpportunitiesView> createState() => _OpportunitiesViewState();
}

class _OpportunitiesViewState extends State<OpportunitiesView>
    with WidgetsBindingObserver {
  late Future<List<JobOpportunity>> _opportunities;
  final Set<String> _applying = {};
  final Set<String> _applied = {};
  Timer? _timer;
  bool _openOnly = true;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _opportunities = _load();
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (ModalRoute.of(context)?.isCurrent ?? true) _refresh();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<List<JobOpportunity>> _load() async {
    _loading = true;
    try {
      final data =
          await context.read<ApiService>().get('/opportunities') as List;
      return data
          .map((item) =>
              JobOpportunity.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList();
    } finally {
      _loading = false;
    }
  }

  void _refresh() {
    if (mounted && !_loading) {
      final opportunities = _load();
      setState(() {
        _opportunities = opportunities;
      });
    }
  }

  Future<void> _apply(JobOpportunity opportunity) async {
    if (!_applying.add(opportunity.id)) return;
    setState(() {});
    try {
      await context.read<ApiService>().post(
          '/opportunities/${Uri.encodeComponent(opportunity.id)}/apply', {});
      if (!mounted) return;
      setState(() => _applied.add(opportunity.id));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('Application submitted. Track it in Your applications.')),
      );
    } catch (error) {
      if (!mounted) return;
      if (error is ApiException && error.statusCode == 409) {
        setState(() => _applied.add(opportunity.id));
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(error is ApiException
            ? error.message
            : 'Unable to apply. Please try again.'),
      ));
    } finally {
      if (mounted) setState(() => _applying.remove(opportunity.id));
    }
  }

  @override
  Widget build(BuildContext context) => PageLayout(
        title: 'Job opportunities',
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('Explore roles published by the recruitment team.'),
          const SizedBox(height: 8),
          Wrap(spacing: 12, children: [
            TextButton.icon(
                onPressed: _refresh,
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh opportunities')),
            TextButton.icon(
                onPressed: () =>
                    Navigator.pushNamed(context, AppRoutes.applications),
                icon: const Icon(Icons.inbox_outlined),
                label: const Text('Your applications')),
          ]),
          const SizedBox(height: 16),
          FutureBuilder<List<JobOpportunity>>(
            future: _opportunities,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Column(children: [
                  const Text('Unable to load opportunities. Please try again.'),
                  TextButton(onPressed: _refresh, child: const Text('Retry')),
                ]);
              }
              final opportunities = snapshot.data!;
              if (opportunities.isEmpty) {
                return const Text(
                    'No opportunities have been published yet. Check back soon.');
              }
              final open = opportunities
                  .where((item) => item.deadline.isAfter(DateTime.now()))
                  .toList();
              final visible = _openOnly ? open : opportunities;
              return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Wrap(spacing: 8, children: [
                      ChoiceChip(
                          label: Text('Open (${open.length})'),
                          selected: _openOnly,
                          onSelected: (_) => setState(() => _openOnly = true)),
                      ChoiceChip(
                          label: Text('All (${opportunities.length})'),
                          selected: !_openOnly,
                          onSelected: (_) => setState(() => _openOnly = false)),
                    ]),
                    const SizedBox(height: 16),
                    if (visible.isEmpty)
                      const Text('There are no open opportunities right now.'),
                    ...visible.map(_card),
                  ]);
            },
          ),
        ]),
      );

  Widget _card(JobOpportunity opportunity) {
    final applied = opportunity.hasApplied || _applied.contains(opportunity.id);
    final closed = !opportunity.deadline.isAfter(DateTime.now());
    return Card(
      key: ValueKey('opportunity-${opportunity.id}'),
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(opportunity.title,
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text('${opportunity.company} • ${opportunity.location}'),
          const SizedBox(height: 8),
          Text(
              'Apply by ${DateFormat.yMMMd().format(opportunity.deadline.toLocal())}'),
          const SizedBox(height: 16),
          Text(opportunity.description),
          const SizedBox(height: 16),
          Align(
              alignment: Alignment.centerLeft,
              child: AppButton(
                key: ValueKey('apply-${opportunity.id}'),
                label: applied
                    ? 'Applied'
                    : closed
                        ? 'Applications closed'
                        : 'Apply now',
                icon: applied ? Icons.check : Icons.send_outlined,
                loading: _applying.contains(opportunity.id),
                onPressed: applied || closed ? null : () => _apply(opportunity),
              )),
        ]),
      ),
    );
  }
}
