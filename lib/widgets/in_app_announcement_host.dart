import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/storage.dart';
import '../core/urls.dart';
import '../data/api_service.dart';
import '../environment.dart';

class InAppAnnouncementHost extends StatefulWidget {
  const InAppAnnouncementHost({super.key});
  @override
  State<InAppAnnouncementHost> createState() => _AnnouncementState();
}

class _AnnouncementState extends State<InAppAnnouncementHost> {
  bool attempted = false;
  Timer? timer;
  final Set<String> shownThisSession = <String>{};
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    timer = Timer.periodic(const Duration(seconds: 10), (_) {
      attempted = false;
      _load();
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    if (attempted || !mounted) return;
    attempted = true;
    final api = Get.find<ApiService>(), storage = Get.find<AppStorage>();
    final response = await api.get('${Urls.announcements}?placement=home');
    if (!mounted || !response.success) return;
    final data = response.data, rows = data['announcements'];
    if (rows is! List) return;
    for (final raw in rows.whereType<Map>()) {
      final revision = '${raw['updated_at'] ?? raw['created_at'] ?? ''}'
          .replaceAll(RegExp(r'[^0-9]'), '');
      final key = 'announcement_seen_${raw['id']}_$revision',
          frequency = '${raw['frequency'] ?? 'once'}',
          seen = storage.announcementSeen(key),
          today = DateTime.now().toIso8601String().substring(0, 10);
      if (shownThisSession.contains(key)) continue;
      if (frequency == 'once' && seen != null) continue;
      if (frequency == 'daily' && seen == today) continue;
      shownThisSession.add(key);
      await _show(
        Map<String, dynamic>.from(raw),
        '${data['image_path'] ?? ''}',
      );
      await storage.markAnnouncementSeen(
        key,
        frequency == 'daily' ? today : DateTime.now().toIso8601String(),
      );
      break;
    }
  }

  Future<void> _show(Map<String, dynamic> item, String path) =>
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          clipBehavior: Clip.antiAlias,
          contentPadding: EdgeInsets.zero,
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(
                    image: true,
                    label: '${item['title'] ?? 'Announcement'}',
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.sizeOf(context).height * .48,
                      ),
                      child: Container(
                        width: double.infinity,
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                        child: Image.network(
                          '${Environment.domainUrl}/$path/${item['image']}',
                          width: double.infinity,
                          fit: BoxFit.contain,
                          errorBuilder: (_, _, _) => const Padding(
                            padding: EdgeInsets.all(44),
                            child: Icon(Icons.campaign_rounded, size: 64),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${item['title'] ?? ''}',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '${item['message'] ?? ''}',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text('Not now'),
                            ),
                            const Spacer(),
                            FilledButton(
                              onPressed: () async {
                                Navigator.pop(ctx);
                                final uri = Uri.tryParse(
                                  '${item['action_url'] ?? ''}',
                                );
                                if (uri != null && uri.hasScheme) {
                                  await launchUrl(
                                    uri,
                                    mode: LaunchMode.externalApplication,
                                  );
                                }
                              },
                              child: Text('${item['button_text'] ?? 'Got it'}'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
