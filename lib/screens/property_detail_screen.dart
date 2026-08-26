import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/theme.dart';
import '../data/controllers/host_controller.dart';
import 'property_form_screen.dart';
import 'property_rules_screen.dart';

class PropertyDetailScreen extends StatefulWidget {
  const PropertyDetailScreen({super.key, required this.property});
  final Map<String, dynamic> property;

  @override
  State<PropertyDetailScreen> createState() => _PropertyDetailScreenState();
}

class _PropertyDetailScreenState extends State<PropertyDetailScreen> {
  final controller = Get.find<HostController>();
  Map<String, dynamic>? property;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final details = await controller.propertyDetails(widget.property);
    if (mounted) {
      setState(() {
        property = details ?? widget.property;
        loading = false;
      });
    }
  }

  Future<void> addPhotos() async {
    final photos = await ImagePicker().pickMultiImage(
      imageQuality: 88,
      limit: 12,
    );
    if (photos.isEmpty || property == null) return;
    for (final photo in photos) {
      final error = await controller.uploadPropertyPhoto(
        property!,
        photo,
        '${property!['title']} property photo',
      );
      if (error != null) {
        Get.snackbar('Photo upload failed', error);
        break;
      }
    }
    await load();
  }

  Future<void> addDocument(String type) async {
    final document = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 92,
    );
    if (document == null || property == null) return;
    final error = await controller.uploadPropertyDocument(
      property!,
      document,
      type,
    );
    if (error == null) {
      await load();
      Get.snackbar('Document uploaded', 'The review team can now verify it.');
    } else {
      Get.snackbar('Document upload failed', error);
    }
  }

  Future<void> deletePhoto(Map<String, dynamic> photo) async {
    final id = int.tryParse('${photo['id'] ?? ''}');
    if (id == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove this photo?'),
        content: const Text(
          'The image will be permanently removed from the listing.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep photo'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final error = await controller.deletePropertyPhoto(id);
    if (error == null) {
      await load();
    } else {
      Get.snackbar('Could not remove photo', error);
    }
  }

  Future<void> setCover(Map<String, dynamic> photo) async {
    if (property == null) return;
    final id = int.tryParse('${photo['id'] ?? ''}');
    if (id == null) return;
    final error = await controller.setCoverPhoto(
      property!,
      _list(property!['media']),
      id,
    );
    if (error == null) {
      await load();
      Get.snackbar('Cover updated', 'Guests will see this photo first.');
    } else {
      Get.snackbar('Could not update cover', error);
    }
  }

  Future<void> blockDates() async {
    if (property == null) return;
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (range == null) return;
    final error = await controller.blockDates(
      property!,
      range.start,
      range.end,
      'Blocked by host',
    );
    Get.snackbar(
      error == null ? 'Calendar updated' : 'Could not update calendar',
      error ?? 'Those dates are unavailable to guests.',
    );
  }

  Future<void> submit() async {
    if (property == null) return;
    final error = await controller.submitProperty(property!);
    if (error == null) {
      await load();
      Get.snackbar(
        'Submitted for review',
        'Swift will notify you when the listing is approved.',
      );
    } else {
      Get.snackbar(
        'Listing is not ready',
        error,
        backgroundColor: AppColors.danger,
        colorText: Colors.white,
      );
    }
  }

  Future<void> openMap() async {
    final address = _map(property?['address']);
    final lat = address['latitude'];
    final lng = address['longitude'];
    if (lat == null || lng == null) return;
    await launchUrl(
      Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng'),
      mode: LaunchMode.externalApplication,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final item = property ?? widget.property;
    final media = _list(item['media']);
    final documents = _list(item['documents']);
    final address = _map(item['address']);
    final status = '${item['status'] ?? 'draft'}';
    final identityReady = controller.profile['identity_verified'] == true;
    final payoutReady = controller.profile['payout_configured'] == true;
    final photosReady = media.length >= 3;
    final canSubmit = status == 'draft' || status == 'rejected';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Listing workspace'),
        actions: [
          IconButton(
            tooltip: 'Edit listing',
            onPressed: () async {
              await Get.to<void>(() => PropertyFormScreen(property: item));
              await load();
            },
            icon: const Icon(Icons.edit_outlined),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: load,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            _Gallery(
              media: media,
              fallback: '${item['cover_image'] ?? ''}',
              onAdd: addPhotos,
              onDelete: deletePhoto,
              onSetCover: setCover,
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${item['title'] ?? 'Untitled property'}',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                      ),
                      _StatusBadge(status),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${address['address_line'] ?? address['neighborhood'] ?? ''}${address['city'] == null ? '' : ', ${address['city']}'}',
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _Fact(
                        icon: Icons.groups_outlined,
                        value: '${item['max_guests'] ?? 0}',
                        label: 'guests',
                      ),
                      _Fact(
                        icon: Icons.bed_outlined,
                        value: '${item['beds'] ?? 0}',
                        label: 'beds',
                      ),
                      _Fact(
                        icon: Icons.bathtub_outlined,
                        value: '${item['bathrooms'] ?? 0}',
                        label: 'baths',
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Listing readiness',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 10),
                  _Check(
                    label: 'Host identity approved',
                    complete: identityReady,
                    action: identityReady ? null : 'Pending admin review',
                  ),
                  _Check(
                    label: 'Payout account configured',
                    complete: payoutReady,
                    action: payoutReady ? null : 'Complete profile',
                  ),
                  _Check(
                    label: 'At least 3 property photos',
                    complete: photosReady,
                    action: photosReady ? null : '${media.length}/3 uploaded',
                  ),
                  _Check(label: 'Property details complete', complete: true),
                  const SizedBox(height: 22),
                  _SectionHeader(
                    title: 'Photos',
                    action: 'Add photos',
                    icon: Icons.add_a_photo_outlined,
                    onTap: addPhotos,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${media.length} photos uploaded. The first image is used as the cover.',
                  ),
                  const SizedBox(height: 22),
                  _SectionHeader(
                    title: 'Verification documents',
                    action: 'Upload',
                    icon: Icons.upload_file_outlined,
                    onTap: () => _documentSheet(context),
                  ),
                  const SizedBox(height: 8),
                  if (documents.isEmpty)
                    const Text(
                      'Upload ownership or authorization documents before review.',
                    )
                  else
                    ...documents.map(
                      (document) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.description_outlined),
                        title: Text(_label('${document['type']}')),
                        subtitle: Text(
                          'Review: ${_label('${document['status'] ?? 'pending'}')}',
                        ),
                        trailing: Icon(
                          document['status'] == 'approved'
                              ? Icons.verified
                              : Icons.schedule,
                          color: document['status'] == 'approved'
                              ? AppColors.success
                              : AppColors.warning,
                        ),
                      ),
                    ),
                  const SizedBox(height: 18),
                  _SectionHeader(
                    title: 'Availability',
                    action: 'Block dates',
                    icon: Icons.event_busy_outlined,
                    onTap: blockDates,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Prevent bookings for maintenance, personal use, or unavailable dates.',
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () async {
                      await Get.to<void>(
                        () => PropertyRulesScreen(property: item),
                      );
                      await load();
                    },
                    icon: const Icon(Icons.tune),
                    label: const Text('Manage units, pricing & stay rules'),
                  ),
                  const SizedBox(height: 18),
                  _SectionHeader(
                    title: 'Location',
                    action: 'Open map',
                    icon: Icons.map_outlined,
                    onTap: openMap,
                  ),
                  const SizedBox(height: 8),
                  Text('${address['address_line'] ?? 'Address not set'}'),
                  if ('${address['directions'] ?? ''}'.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text('${address['directions']}'),
                  ],
                  if (canSubmit) ...[
                    const SizedBox(height: 26),
                    FilledButton.icon(
                      onPressed: identityReady && payoutReady && photosReady
                          ? submit
                          : null,
                      icon: const Icon(Icons.send_outlined),
                      label: const Text('Submit listing for review'),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _documentSheet(BuildContext context) =>
      showModalBottomSheet<void>(
        context: context,
        builder: (context) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Choose document type',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                const Text('Choose a clear photo or scan from your gallery.'),
                const SizedBox(height: 4),
                for (final item in const [
                  ('ownership', 'Proof of ownership', Icons.home_work_outlined),
                  (
                    'lease_authorization',
                    'Lease authorization',
                    Icons.key_outlined,
                  ),
                  (
                    'business_license',
                    'Business license',
                    Icons.business_center_outlined,
                  ),
                  (
                    'safety_certificate',
                    'Safety certificate',
                    Icons.health_and_safety_outlined,
                  ),
                ])
                  ListTile(
                    leading: Icon(item.$3),
                    title: Text(item.$2),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.pop(context);
                      addDocument(item.$1);
                    },
                  ),
              ],
            ),
          ),
        ),
      );
}

class _Gallery extends StatelessWidget {
  const _Gallery({
    required this.media,
    required this.fallback,
    required this.onAdd,
    required this.onDelete,
    required this.onSetCover,
  });
  final List<Map<String, dynamic>> media;
  final String fallback;
  final VoidCallback onAdd;
  final ValueChanged<Map<String, dynamic>> onDelete;
  final ValueChanged<Map<String, dynamic>> onSetCover;
  @override
  Widget build(BuildContext context) {
    final urls = media
        .map((e) => '${e['url'] ?? ''}')
        .where((e) => e.isNotEmpty)
        .toList();
    if (urls.isEmpty && fallback.isNotEmpty) urls.add(fallback);
    if (urls.isEmpty) {
      return SizedBox(
        height: 240,
        child: Material(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: InkWell(
            onTap: onAdd,
            child: const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add_photo_alternate_outlined, size: 52),
                  SizedBox(height: 8),
                  Text('Add property photos'),
                ],
              ),
            ),
          ),
        ),
      );
    }
    return SizedBox(
      height: 250,
      child: PageView.builder(
        itemCount: urls.length,
        itemBuilder: (_, index) => Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              urls[index],
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const Center(
                child: Icon(Icons.broken_image_outlined, size: 48),
              ),
            ),
            if (index < media.length)
              Positioned(
                top: 10,
                right: 10,
                child: Row(
                  children: [
                    IconButton.filledTonal(
                      tooltip: 'Use as cover photo',
                      onPressed: () => onSetCover(media[index]),
                      icon: Icon(
                        media[index]['is_cover'] == true
                            ? Icons.star
                            : Icons.star_outline,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      tooltip: 'Remove photo',
                      onPressed: () => onDelete(media[index]),
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.icon, required this.value, required this.label});
  final IconData icon;
  final String value;
  final String label;
  @override
  Widget build(BuildContext context) => Expanded(
    child: Row(
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: 6),
        Flexible(child: Text('$value $label')),
      ],
    ),
  );
}

class _Check extends StatelessWidget {
  const _Check({required this.label, required this.complete, this.action});
  final String label;
  final bool complete;
  final String? action;
  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    minTileHeight: 52,
    leading: Icon(
      complete ? Icons.check_circle : Icons.radio_button_unchecked,
      color: complete ? AppColors.success : AppColors.warning,
    ),
    title: Text(label),
    subtitle: action == null ? null : Text(action!),
  );
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.action,
    required this.icon,
    required this.onTap,
  });
  final String title;
  final String action;
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(title, style: Theme.of(context).textTheme.titleLarge),
      ),
      TextButton.icon(onPressed: onTap, icon: Icon(icon), label: Text(action)),
    ],
  );
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge(this.status);
  final String status;
  @override
  Widget build(BuildContext context) => Chip(
    label: Text(_label(status)),
    avatar: const Icon(Icons.circle, size: 10),
  );
}

Map<String, dynamic> _map(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : {};
List<Map<String, dynamic>> _list(dynamic value) => value is List
    ? value.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
    : [];
String _label(String value) =>
    toBeginningOfSentenceCase(value.replaceAll('_', ' '));
