import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/api_service.dart';
import 'page_layout.dart';

/// Shared loading, empty, error, and retry handling for collection screens.
class ApiCollectionView extends StatefulWidget {
  const ApiCollectionView({
    super.key,
    required this.title,
    required this.path,
    required this.emptyMessage,
    required this.itemBuilder,
    this.collectionBuilder,
    this.countLabel,
    this.refreshInterval,
  });
  final String title;
  final String path;
  final String emptyMessage;
  final Widget Function(Map<String, dynamic>) itemBuilder;
  final Widget Function(List<Map<String, dynamic>>)? collectionBuilder;
  final String? countLabel;
  final Duration? refreshInterval;

  @override
  State<ApiCollectionView> createState() => _ApiCollectionViewState();
}

class _ApiCollectionViewState extends State<ApiCollectionView>
    with WidgetsBindingObserver {
  late Future<List<Map<String, dynamic>>> _items;
  Timer? _timer;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _items = _load();
    if (widget.refreshInterval != null) {
      WidgetsBinding.instance.addObserver(this);
      _timer = Timer.periodic(widget.refreshInterval!, (_) {
        if (ModalRoute.of(context)?.isCurrent ?? true) _refresh();
      });
    }
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

  void _refresh() {
    if (mounted && !_loading) {
      final items = _load();
      setState(() {
        _items = items;
      });
    }
  }

  Future<List<Map<String, dynamic>>> _load() async {
    _loading = true;
    try {
      final data = await context.read<ApiService>().get(widget.path) as List;
      return data
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
    } finally {
      _loading = false;
    }
  }

  @override
  Widget build(BuildContext context) => PageLayout(
        title: widget.title,
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                tooltip: 'Refresh list',
                icon: const Icon(Icons.refresh),
                onPressed: _refresh,
              )),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _items,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Column(children: [
                  const Text('Unable to load this page. Please try again.'),
                  TextButton(onPressed: _refresh, child: const Text('Retry')),
                ]);
              }
              final items = snapshot.data!;
              if (items.isEmpty) return Text(widget.emptyMessage);
              return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (widget.countLabel != null) ...[
                      Text('${items.length} ${widget.countLabel}'),
                      const SizedBox(height: 12),
                    ],
                    if (widget.collectionBuilder != null)
                      widget.collectionBuilder!(items)
                    else
                      ...items.map(widget.itemBuilder),
                  ]);
            },
          ),
        ]),
      );
}
