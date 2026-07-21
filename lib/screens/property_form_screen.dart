import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../core/theme.dart';
import '../data/controllers/host_controller.dart';
import 'address_search_screen.dart';
import 'property_detail_screen.dart';

class PropertyFormScreen extends StatefulWidget {
  const PropertyFormScreen({super.key, this.property});

  final Map<String, dynamic>? property;

  @override
  State<PropertyFormScreen> createState() => _PropertyFormScreenState();
}

class _PropertyFormScreenState extends State<PropertyFormScreen> {
  final controller = Get.find<HostController>();
  final form = GlobalKey<FormState>();
  final fields = <String, TextEditingController>{};
  final selectedAmenities = <int>{};
  Map<String, dynamic> address = {};
  int? propertyTypeId;
  String petPolicy = 'ask_host';
  bool instantBook = false;
  bool furnished = true;
  bool familyFriendly = true;
  bool accessible = false;
  bool loading = false;
  int step = 0;

  bool get editing => widget.property != null;

  @override
  void initState() {
    super.initState();
    for (final key in [
      'title',
      'summary',
      'description',
      'house_rules',
      'check_in_from',
      'check_out_until',
      'base_guests',
      'max_guests',
      'bedrooms',
      'beds',
      'bathrooms',
      'minimum_nights',
      'maximum_nights',
      'base_nightly_rate',
      'weekend_nightly_rate',
      'cleaning_fee',
      'extra_guest_fee',
      'security_deposit',
      'weekly_discount_percent',
      'monthly_discount_percent',
      'directions',
    ]) {
      fields[key] = TextEditingController();
    }
    _defaults();
    if (editing) _load();
  }

  void _defaults() {
    fields['check_in_from']!.text = '14:00';
    fields['check_out_until']!.text = '11:00';
    fields['base_guests']!.text = '2';
    fields['max_guests']!.text = '4';
    fields['bedrooms']!.text = '1';
    fields['beds']!.text = '1';
    fields['bathrooms']!.text = '1';
    fields['minimum_nights']!.text = '1';
    fields['maximum_nights']!.text = '90';
    fields['cleaning_fee']!.text = '0';
    fields['extra_guest_fee']!.text = '0';
    fields['security_deposit']!.text = '0';
    fields['weekly_discount_percent']!.text = '0';
    fields['monthly_discount_percent']!.text = '0';
  }

  Future<void> _load() async {
    setState(() => loading = true);
    final property = await controller.propertyDetails(widget.property!);
    if (!mounted) return;
    setState(() => loading = false);
    if (property == null) {
      Get.snackbar('Could not load listing', 'Pull to refresh and try again.');
      return;
    }
    final host = _map(property['host_details']);
    final propertyAddress = _map(property['address']);
    setState(() {
      for (final key in [
        'title',
        'summary',
        'description',
        'house_rules',
        'check_in_from',
        'check_out_until',
        'max_guests',
        'bedrooms',
        'beds',
        'bathrooms',
        'minimum_nights',
        'maximum_nights',
      ]) {
        if (property[key] != null) fields[key]!.text = '${property[key]}';
      }
      for (final key in [
        'base_guests',
        'base_nightly_rate',
        'weekend_nightly_rate',
        'cleaning_fee',
        'extra_guest_fee',
        'security_deposit',
        'weekly_discount_percent',
        'monthly_discount_percent',
      ]) {
        if (host[key] != null) fields[key]!.text = '${host[key]}';
      }
      fields['directions']!.text = '${propertyAddress['directions'] ?? ''}';
      address = {
        ...propertyAddress,
        'country_code': host['country_code'] ?? 'ET',
      };
      propertyTypeId = int.tryParse(
        '${host['property_type_id'] ?? _map(property['property_type'])['id'] ?? ''}',
      );
      selectedAmenities.addAll(
        (host['amenity_ids'] as List? ?? const [])
            .map((e) => int.tryParse('$e'))
            .whereType<int>(),
      );
      petPolicy = '${property['pet_policy'] ?? 'ask_host'}';
      instantBook = property['instant_book'] == true;
      furnished = property['furnished'] != false;
      familyFriendly = property['family_friendly'] != false;
      accessible = property['accessible'] == true;
    });
  }

  @override
  void dispose() {
    for (final value in fields.values) {
      value.dispose();
    }
    super.dispose();
  }

  Future<void> _pickAddress() async {
    final selected = await Get.to<Map<String, dynamic>>(
      () => const AddressSearchScreen(),
    );
    if (selected != null) setState(() => address = selected);
  }

  String? _required(String? value) =>
      (value == null || value.trim().isEmpty) ? 'Required' : null;

  Future<void> _save() async {
    if (!form.currentState!.validate()) return;
    if (propertyTypeId == null) {
      Get.snackbar(
        'Select property type',
        'Choose the type of stay you are listing.',
      );
      setState(() => step = 0);
      return;
    }
    if (address['latitude'] == null || address['longitude'] == null) {
      Get.snackbar(
        'Select an address',
        'Search and choose the exact property location.',
      );
      setState(() => step = 1);
      return;
    }

    final payload = <String, dynamic>{
      'property_type_id': propertyTypeId,
      'title': fields['title']!.text.trim(),
      'summary': fields['summary']!.text.trim(),
      'description': fields['description']!.text.trim(),
      'house_rules': fields['house_rules']!.text.trim(),
      'check_in_from': fields['check_in_from']!.text.trim(),
      'check_out_until': fields['check_out_until']!.text.trim(),
      for (final key in [
        'base_guests',
        'max_guests',
        'bedrooms',
        'beds',
        'minimum_nights',
        'maximum_nights',
      ])
        key: int.tryParse(fields[key]!.text) ?? 0,
      'bathrooms': double.tryParse(fields['bathrooms']!.text) ?? 0,
      'instant_book': instantBook,
      'furnished': furnished,
      'family_friendly': familyFriendly,
      'accessible': accessible,
      'pet_policy': petPolicy,
      'currency': 'ETB',
      for (final key in [
        'base_nightly_rate',
        'weekend_nightly_rate',
        'cleaning_fee',
        'extra_guest_fee',
        'security_deposit',
        'weekly_discount_percent',
        'monthly_discount_percent',
      ])
        key: fields[key]!.text.trim().isEmpty
            ? null
            : double.tryParse(fields[key]!.text),
      'country_code': address['country_code'] ?? 'ET',
      'city': address['city'] ?? 'Addis Ababa',
      'neighborhood': address['neighborhood'],
      'address_line': address['address_line'],
      'directions': fields['directions']!.text.trim(),
      'latitude': address['latitude'],
      'longitude': address['longitude'],
      'amenity_ids': selectedAmenities.toList(),
    };
    final result = await controller.saveProperty(
      payload,
      reference: editing ? '${widget.property!['reference']}' : null,
    );
    if (!mounted) return;
    if (result.error != null) {
      Get.snackbar(
        'Could not save listing',
        result.error!,
        backgroundColor: AppColors.danger,
        colorText: Colors.white,
      );
      return;
    }
    if (editing) {
      Get.back<Map<String, dynamic>>(result: result.property);
    } else {
      Get.off<void>(() => PropertyDetailScreen(property: result.property!));
    }
    Get.snackbar(
      'Listing saved',
      editing
          ? 'Your changes are ready.'
          : 'Now add photos and verification documents.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final propertyTypes = _list(controller.configuration['property_types']);
    final amenities = _list(controller.configuration['amenities']);
    if (propertyTypeId == null && propertyTypes.isNotEmpty) {
      propertyTypeId = int.tryParse('${propertyTypes.first['id']}');
    }

    return Scaffold(
      appBar: AppBar(title: Text(editing ? 'Edit listing' : 'Add a property')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: form,
              child: Stepper(
                currentStep: step,
                onStepTapped: (value) => setState(() => step = value),
                controlsBuilder: (context, details) => Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: step == 3
                              ? _save
                              : () => setState(() => step++),
                          icon: Icon(
                            step == 3
                                ? Icons.save_outlined
                                : Icons.arrow_forward,
                          ),
                          label: Text(step == 3 ? 'Save listing' : 'Continue'),
                        ),
                      ),
                      if (step > 0) ...[
                        const SizedBox(width: 10),
                        IconButton(
                          tooltip: 'Previous step',
                          onPressed: () => setState(() => step--),
                          icon: const Icon(Icons.arrow_back),
                        ),
                      ],
                    ],
                  ),
                ),
                steps: [
                  Step(
                    title: const Text('Basics'),
                    isActive: step >= 0,
                    content: Column(
                      children: [
                        DropdownButtonFormField<int>(
                          initialValue: propertyTypeId,
                          decoration: const InputDecoration(
                            labelText: 'Property type',
                            prefixIcon: Icon(Icons.home_work_outlined),
                          ),
                          items: propertyTypes
                              .map(
                                (type) => DropdownMenuItem(
                                  value: int.tryParse('${type['id']}'),
                                  child: Text('${type['name']}'),
                                ),
                              )
                              .toList(),
                          onChanged: (value) =>
                              setState(() => propertyTypeId = value),
                        ),
                        _gap,
                        _field(
                          'title',
                          'Property title',
                          Icons.title,
                          validator: _required,
                        ),
                        _gap,
                        _field(
                          'summary',
                          'Short summary',
                          Icons.short_text,
                          maxLines: 2,
                          validator: _required,
                        ),
                        _gap,
                        _field(
                          'description',
                          'Full description',
                          Icons.notes,
                          maxLines: 5,
                          validator: _required,
                        ),
                        _gap,
                        _number(
                          'max_guests',
                          'Maximum guests',
                          Icons.groups_outlined,
                        ),
                        _gap,
                        Row(
                          children: [
                            Expanded(
                              child: _number(
                                'bedrooms',
                                'Bedrooms',
                                Icons.bedroom_parent_outlined,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _number(
                                'beds',
                                'Beds',
                                Icons.bed_outlined,
                              ),
                            ),
                          ],
                        ),
                        _gap,
                        _number(
                          'bathrooms',
                          'Bathrooms',
                          Icons.bathtub_outlined,
                          decimal: true,
                        ),
                      ],
                    ),
                  ),
                  Step(
                    title: const Text('Location'),
                    isActive: step >= 1,
                    content: Column(
                      children: [
                        InkWell(
                          onTap: _pickAddress,
                          borderRadius: BorderRadius.circular(8),
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Property address',
                              prefixIcon: Icon(Icons.location_on_outlined),
                              suffixIcon: Icon(Icons.chevron_right),
                            ),
                            child: Text(
                              '${address['address_line'] ?? 'Search and select an address'}',
                            ),
                          ),
                        ),
                        _gap,
                        _field(
                          'directions',
                          'Arrival directions (optional)',
                          Icons.signpost_outlined,
                          maxLines: 3,
                        ),
                        _gap,
                        _field(
                          'house_rules',
                          'House rules (optional)',
                          Icons.rule_outlined,
                          maxLines: 4,
                        ),
                        _gap,
                        Row(
                          children: [
                            Expanded(
                              child: _field(
                                'check_in_from',
                                'Check-in',
                                Icons.login,
                                validator: _required,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _field(
                                'check_out_until',
                                'Check-out',
                                Icons.logout,
                                validator: _required,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Step(
                    title: const Text('Amenities'),
                    isActive: step >= 2,
                    content: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: amenities.map((amenity) {
                            final id = int.tryParse('${amenity['id']}') ?? 0;
                            return FilterChip(
                              label: Text('${amenity['name']}'),
                              selected: selectedAmenities.contains(id),
                              onSelected: (selected) => setState(
                                () => selected
                                    ? selectedAmenities.add(id)
                                    : selectedAmenities.remove(id),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 14),
                        SwitchListTile.adaptive(
                          value: instantBook,
                          onChanged: (value) =>
                              setState(() => instantBook = value),
                          title: const Text('Instant booking'),
                          subtitle: const Text(
                            'Allow guests to confirm without manual approval',
                          ),
                        ),
                        SwitchListTile.adaptive(
                          value: furnished,
                          onChanged: (value) =>
                              setState(() => furnished = value),
                          title: const Text('Furnished'),
                        ),
                        SwitchListTile.adaptive(
                          value: familyFriendly,
                          onChanged: (value) =>
                              setState(() => familyFriendly = value),
                          title: const Text('Family friendly'),
                        ),
                        SwitchListTile.adaptive(
                          value: accessible,
                          onChanged: (value) =>
                              setState(() => accessible = value),
                          title: const Text('Accessible'),
                        ),
                        DropdownButtonFormField<String>(
                          initialValue: petPolicy,
                          decoration: const InputDecoration(
                            labelText: 'Pet policy',
                            prefixIcon: Icon(Icons.pets_outlined),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'allowed',
                              child: Text('Pets allowed'),
                            ),
                            DropdownMenuItem(
                              value: 'ask_host',
                              child: Text('Ask host first'),
                            ),
                            DropdownMenuItem(
                              value: 'not_allowed',
                              child: Text('No pets'),
                            ),
                          ],
                          onChanged: (value) =>
                              setState(() => petPolicy = value ?? 'ask_host'),
                        ),
                      ],
                    ),
                  ),
                  Step(
                    title: const Text('Pricing'),
                    isActive: step >= 3,
                    content: Column(
                      children: [
                        _number(
                          'base_nightly_rate',
                          'Nightly price (ETB)',
                          Icons.payments_outlined,
                          decimal: true,
                        ),
                        _gap,
                        _number(
                          'weekend_nightly_rate',
                          'Weekend price (optional)',
                          Icons.weekend_outlined,
                          decimal: true,
                          required: false,
                        ),
                        _gap,
                        Row(
                          children: [
                            Expanded(
                              child: _number(
                                'base_guests',
                                'Guests included',
                                Icons.group_outlined,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _number(
                                'extra_guest_fee',
                                'Extra guest fee',
                                Icons.person_add_alt,
                                decimal: true,
                              ),
                            ),
                          ],
                        ),
                        _gap,
                        _number(
                          'cleaning_fee',
                          'Cleaning fee',
                          Icons.cleaning_services_outlined,
                          decimal: true,
                        ),
                        _gap,
                        _number(
                          'security_deposit',
                          'Security deposit',
                          Icons.shield_outlined,
                          decimal: true,
                        ),
                        _gap,
                        Row(
                          children: [
                            Expanded(
                              child: _number(
                                'minimum_nights',
                                'Minimum nights',
                                Icons.nights_stay_outlined,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _number(
                                'maximum_nights',
                                'Maximum nights',
                                Icons.calendar_month_outlined,
                              ),
                            ),
                          ],
                        ),
                        _gap,
                        Row(
                          children: [
                            Expanded(
                              child: _number(
                                'weekly_discount_percent',
                                'Weekly discount %',
                                Icons.discount_outlined,
                                decimal: true,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _number(
                                'monthly_discount_percent',
                                'Monthly discount %',
                                Icons.discount_outlined,
                                decimal: true,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _field(
    String key,
    String label,
    IconData icon, {
    int maxLines = 1,
    String? Function(String?)? validator,
  }) => TextFormField(
    controller: fields[key],
    maxLines: maxLines,
    textCapitalization: maxLines > 1
        ? TextCapitalization.sentences
        : TextCapitalization.words,
    decoration: InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      alignLabelWithHint: maxLines > 1,
    ),
    validator: validator,
  );

  Widget _number(
    String key,
    String label,
    IconData icon, {
    bool decimal = false,
    bool required = true,
  }) => TextFormField(
    controller: fields[key],
    keyboardType: TextInputType.numberWithOptions(decimal: decimal),
    decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
    validator: required ? _required : null,
  );
}

const _gap = SizedBox(height: 14);
Map<String, dynamic> _map(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : {};
List<Map<String, dynamic>> _list(dynamic value) => value is List
    ? value.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
    : [];
