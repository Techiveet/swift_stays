import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../core/theme.dart';
import '../data/controllers/host_controller.dart';

class PropertyRulesScreen extends StatefulWidget {
  const PropertyRulesScreen({super.key, required this.property});
  final Map<String, dynamic> property;

  @override
  State<PropertyRulesScreen> createState() => _PropertyRulesScreenState();
}

class _PropertyRulesScreenState extends State<PropertyRulesScreen> {
  final controller = Get.find<HostController>();
  Map<String, dynamic>? details;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final value = await controller.propertyDetails(widget.property);
    if (mounted) setState(() => details = value ?? widget.property);
  }

  @override
  Widget build(BuildContext context) {
    final item = details;
    if (item == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final units = _list(item['units']);
    final prices = _list(item['price_rules']);
    final availability = _list(item['availability_rules']);
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Inventory & pricing'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Units'),
              Tab(text: 'Pricing'),
              Tab(text: 'Rules'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _RulesList(
              icon: Icons.meeting_room_outlined,
              empty: 'Add a room, apartment, or rentable unit.',
              button: 'Add unit',
              onAdd: () => _unitSheet(context),
              children: units
                  .map(
                    (unit) => ListTile(
                      leading: const Icon(Icons.bedroom_parent_outlined),
                      title: Text('${unit['name'] ?? 'Unit'}'),
                      subtitle: Text(
                        '${unit['inventory_count'] ?? 1} available | ${unit['max_guests'] ?? 0} guests',
                      ),
                      trailing: const Icon(Icons.edit_outlined),
                      onTap: () => _unitSheet(context, unit: unit),
                    ),
                  )
                  .toList(),
            ),
            _RulesList(
              icon: Icons.price_change_outlined,
              empty: 'Set seasonal or event-based nightly prices.',
              button: 'Add seasonal price',
              onAdd: () => _priceSheet(context),
              children: prices
                  .map(
                    (rule) => ListTile(
                      leading: const Icon(Icons.event_available_outlined),
                      title: Text('${rule['name'] ?? 'Seasonal price'}'),
                      subtitle: Text(
                        '${rule['starts_on'] ?? ''} to ${rule['ends_on'] ?? ''}',
                      ),
                      trailing: Text(
                        'ETB ${_money(rule['nightly_rate'])}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  )
                  .toList(),
            ),
            _RulesList(
              icon: Icons.rule_folder_outlined,
              empty: 'Add date-specific minimum and maximum stay rules.',
              button: 'Add stay rule',
              onAdd: () => _availabilitySheet(context),
              children: availability
                  .map(
                    (rule) => ListTile(
                      leading: Icon(
                        rule['available'] == false
                            ? Icons.event_busy
                            : Icons.event_available,
                      ),
                      title: Text(
                        rule['available'] == false
                            ? 'Unavailable'
                            : 'Stay length rule',
                      ),
                      subtitle: Text(
                        '${rule['starts_on'] ?? 'All dates'} to ${rule['ends_on'] ?? 'ongoing'} | ${rule['minimum_nights'] ?? 1}-${rule['maximum_nights'] ?? 'any'} nights',
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _unitSheet(
    BuildContext context, {
    Map<String, dynamic>? unit,
  }) async {
    final name = TextEditingController(text: '${unit?['name'] ?? ''}');
    final code = TextEditingController(text: '${unit?['unit_code'] ?? ''}');
    final inventory = TextEditingController(
      text: '${unit?['inventory_count'] ?? 1}',
    );
    final guests = TextEditingController(text: '${unit?['max_guests'] ?? 2}');
    final bedrooms = TextEditingController(text: '${unit?['bedrooms'] ?? 1}');
    final bathrooms = TextEditingController(text: '${unit?['bathrooms'] ?? 1}');
    final rate = TextEditingController(text: '${unit?['nightly_rate'] ?? ''}');
    final bedType = TextEditingController(text: 'queen');
    final beds = TextEditingController(text: '1');
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _FormSheet(
        title: unit == null ? 'Add rentable unit' : 'Edit rentable unit',
        action: 'Save unit',
        onSave: () async {
          if (name.text.trim().isEmpty) return 'Enter a unit name.';
          final error = await controller.saveUnit(widget.property, {
            'name': name.text.trim(),
            'unit_code': code.text.trim(),
            'inventory_count': int.tryParse(inventory.text) ?? 1,
            'max_guests': int.tryParse(guests.text) ?? 1,
            'bedrooms': int.tryParse(bedrooms.text) ?? 0,
            'bathrooms': double.tryParse(bathrooms.text) ?? 1,
            if (rate.text.trim().isNotEmpty)
              'nightly_rate': double.tryParse(rate.text),
            'active': true,
            'beds': [
              {
                'room_name': 'Bedroom',
                'bed_type': bedType.text.trim(),
                'quantity': int.tryParse(beds.text) ?? 1,
              },
            ],
          }, unitId: int.tryParse('${unit?['id'] ?? ''}'));
          if (error == null) await load();
          return error;
        },
        children: [
          _input(name, 'Unit name', Icons.meeting_room_outlined),
          _input(code, 'Unit code (optional)', Icons.tag),
          Row(
            children: [
              Expanded(
                child: _input(
                  inventory,
                  'Inventory',
                  Icons.numbers,
                  number: true,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _input(
                  guests,
                  'Guests',
                  Icons.groups_outlined,
                  number: true,
                ),
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: _input(
                  bedrooms,
                  'Bedrooms',
                  Icons.bedroom_parent_outlined,
                  number: true,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _input(
                  bathrooms,
                  'Bathrooms',
                  Icons.bathtub_outlined,
                  number: true,
                ),
              ),
            ],
          ),
          _input(
            rate,
            'Nightly rate override (optional)',
            Icons.payments_outlined,
            number: true,
          ),
          Row(
            children: [
              Expanded(child: _input(bedType, 'Bed type', Icons.bed_outlined)),
              const SizedBox(width: 10),
              Expanded(
                child: _input(beds, 'Quantity', Icons.numbers, number: true),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _priceSheet(BuildContext context) async {
    final name = TextEditingController();
    final rate = TextEditingController();
    final minimum = TextEditingController(text: '1');
    DateTimeRange? range;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => _FormSheet(
          title: 'Seasonal pricing',
          action: 'Save price',
          onSave: () async {
            if (range == null) return 'Select the date range.';
            final error = await controller.savePriceRule(widget.property, {
              'name': name.text.trim(),
              'starts_on': _date(range!.start),
              'ends_on': _date(range!.end),
              'nightly_rate': double.tryParse(rate.text),
              'minimum_nights': int.tryParse(minimum.text),
              'active': true,
              'priority': 100,
            });
            if (error == null) await load();
            return error;
          },
          children: [
            _input(name, 'Rule name', Icons.label_outline),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.date_range),
              title: Text(
                range == null
                    ? 'Select dates'
                    : '${_date(range!.start)} to ${_date(range!.end)}',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                final picked = await showDateRangePicker(
                  context: context,
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 730)),
                );
                if (picked != null) setSheetState(() => range = picked);
              },
            ),
            _input(
              rate,
              'Nightly rate (ETB)',
              Icons.payments_outlined,
              number: true,
            ),
            _input(
              minimum,
              'Minimum nights',
              Icons.nights_stay_outlined,
              number: true,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _availabilitySheet(BuildContext context) async {
    final minimum = TextEditingController(text: '1');
    final maximum = TextEditingController(text: '90');
    DateTimeRange? range;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => _FormSheet(
          title: 'Stay length rule',
          action: 'Save rule',
          onSave: () async {
            if (range == null) return 'Select the date range.';
            final error = await controller
                .saveAvailabilityRule(widget.property, {
                  'starts_on': _date(range!.start),
                  'ends_on': _date(range!.end),
                  'minimum_nights': int.tryParse(minimum.text),
                  'maximum_nights': int.tryParse(maximum.text),
                  'available': true,
                  'priority': 100,
                });
            if (error == null) await load();
            return error;
          },
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.date_range),
              title: Text(
                range == null
                    ? 'Select dates'
                    : '${_date(range!.start)} to ${_date(range!.end)}',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                final picked = await showDateRangePicker(
                  context: context,
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 730)),
                );
                if (picked != null) setSheetState(() => range = picked);
              },
            ),
            Row(
              children: [
                Expanded(
                  child: _input(
                    minimum,
                    'Minimum nights',
                    Icons.first_page,
                    number: true,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _input(
                    maximum,
                    'Maximum nights',
                    Icons.last_page,
                    number: true,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RulesList extends StatelessWidget {
  const _RulesList({
    required this.icon,
    required this.empty,
    required this.button,
    required this.onAdd,
    required this.children,
  });
  final IconData icon;
  final String empty;
  final String button;
  final VoidCallback onAdd;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      FilledButton.icon(
        onPressed: onAdd,
        icon: const Icon(Icons.add),
        label: Text(button),
      ),
      const SizedBox(height: 14),
      if (children.isEmpty)
        Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            children: [
              Icon(icon, size: 48, color: AppColors.muted),
              const SizedBox(height: 10),
              Text(empty, textAlign: TextAlign.center),
            ],
          ),
        )
      else
        ...children,
    ],
  );
}

class _FormSheet extends StatefulWidget {
  const _FormSheet({
    required this.title,
    required this.action,
    required this.onSave,
    required this.children,
  });
  final String title;
  final String action;
  final Future<String?> Function() onSave;
  final List<Widget> children;
  @override
  State<_FormSheet> createState() => _FormSheetState();
}

class _FormSheetState extends State<_FormSheet> {
  bool busy = false;
  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      16,
      4,
      16,
      MediaQuery.viewInsetsOf(context).bottom + 20,
    ),
    child: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(widget.title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 14),
          for (final child in widget.children) ...[
            child,
            const SizedBox(height: 12),
          ],
          FilledButton(
            onPressed: busy
                ? null
                : () async {
                    setState(() => busy = true);
                    final error = await widget.onSave();
                    if (!mounted) return;
                    setState(() => busy = false);
                    if (error == null) {
                      Navigator.of(this.context).pop();
                    } else {
                      Get.snackbar('Could not save', error);
                    }
                  },
            child: Text(busy ? 'Saving...' : widget.action),
          ),
        ],
      ),
    ),
  );
}

Widget _input(
  TextEditingController controller,
  String label,
  IconData icon, {
  bool number = false,
}) => TextField(
  controller: controller,
  keyboardType: number
      ? const TextInputType.numberWithOptions(decimal: true)
      : TextInputType.text,
  decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
);
List<Map<String, dynamic>> _list(dynamic value) => value is List
    ? value.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
    : [];
String _date(DateTime value) => DateFormat('yyyy-MM-dd').format(value);
String _money(dynamic value) =>
    NumberFormat('#,##0.##').format(num.tryParse('$value') ?? 0);
