import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../data/controllers/host_controller.dart';

class AddressSearchScreen extends StatefulWidget {
  const AddressSearchScreen({super.key});

  @override
  State<AddressSearchScreen> createState() => _AddressSearchScreenState();
}

class _AddressSearchScreenState extends State<AddressSearchScreen> {
  final _search = TextEditingController();
  final _controller = Get.find<HostController>();
  List<Map<String, dynamic>> _results = [];
  Timer? _debounce;
  bool _loading = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _changed(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => _run(value));
  }

  Future<void> _run(String value) async {
    if (value.trim().length < 3) {
      if (mounted) setState(() => _results = []);
      return;
    }
    setState(() => _loading = true);
    final results = await _controller.searchAddresses(value);
    if (mounted) {
      setState(() {
        _results = results;
        _loading = false;
      });
    }
  }

  Future<void> _select(Map<String, dynamic> prediction) async {
    setState(() => _loading = true);
    final details = await _controller.placeDetails(
      '${prediction['place_id'] ?? ''}',
    );
    if (!mounted) return;
    setState(() => _loading = false);
    if (details == null) {
      Get.snackbar('Address unavailable', 'Choose another search result.');
      return;
    }

    final geometry = _map(details['geometry']);
    final location = _map(geometry['location']);
    final components = details['address_components'] is List
        ? details['address_components'] as List
        : const [];
    String component(List<String> types) {
      for (final raw in components.whereType<Map>()) {
        final item = Map<String, dynamic>.from(raw);
        final itemTypes =
            (item['types'] as List?)?.map((e) => '$e').toList() ?? [];
        if (types.any(itemTypes.contains)) return '${item['long_name'] ?? ''}';
      }
      return '';
    }

    Get.back<Map<String, dynamic>>(
      result: {
        'address_line':
            '${details['formatted_address'] ?? prediction['description'] ?? ''}',
        'city': component(['locality', 'administrative_area_level_2']).isEmpty
            ? 'Addis Ababa'
            : component(['locality', 'administrative_area_level_2']),
        'neighborhood': component([
          'sublocality',
          'neighborhood',
          'administrative_area_level_3',
        ]),
        'country_code':
            component(['country']).toLowerCase().contains('ethiopia')
            ? 'ET'
            : 'ET',
        'latitude': double.tryParse(
          '${location['lat'] ?? prediction['lat'] ?? ''}',
        ),
        'longitude': double.tryParse(
          '${location['lng'] ?? prediction['lng'] ?? ''}',
        ),
      },
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Select property address')),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _search,
            autofocus: true,
            onChanged: _changed,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              labelText: 'Search address or landmark',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _search.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear address search',
                      onPressed: () {
                        _search.clear();
                        _changed('');
                        setState(() {});
                      },
                      icon: const Icon(Icons.close),
                    ),
            ),
          ),
        ),
        if (_loading) const LinearProgressIndicator(minHeight: 2),
        Expanded(
          child: _results.isEmpty
              ? const _AddressHint()
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(8, 4, 8, 24),
                  itemCount: _results.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final result = _results[index];
                    final structured = _map(result['structured_formatting']);
                    return ListTile(
                      minTileHeight: 68,
                      leading: const Icon(Icons.location_on_outlined),
                      title: Text(
                        '${structured['main_text'] ?? result['description'] ?? 'Address'}',
                      ),
                      subtitle: structured['secondary_text'] == null
                          ? null
                          : Text('${structured['secondary_text']}'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _select(result),
                    );
                  },
                ),
        ),
      ],
    ),
  );
}

class _AddressHint extends StatelessWidget {
  const _AddressHint();

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.map_outlined,
            size: 52,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 12),
          Text(
            'Find the exact property',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 6),
          const Text(
            'Search by neighborhood, street, building, or nearby landmark.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}

Map<String, dynamic> _map(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : {};
