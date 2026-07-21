import 'package:pusher_channels_flutter/pusher_channels_flutter.dart';

import '../data/api_service.dart';

class HostRealtimeService {
  HostRealtimeService(this.api, this.onUpdate);
  final ApiService api;
  final Future<void> Function() onUpdate;
  final pusher = PusherChannelsFlutter.getInstance();
  bool started = false;

  Future<void> connect({
    required int userId,
    required Map<String, dynamic> config,
  }) async {
    if (started || userId <= 0 || '${config['key'] ?? ''}'.isEmpty) return;
    started = true;
    final scheme = '${config['scheme'] ?? 'https'}';
    final port =
        int.tryParse('${config['port'] ?? ''}') ??
        (scheme == 'https' ? 443 : 80);
    await pusher.init(
      apiKey: '${config['key']}',
      cluster: '',
      useTLS: scheme == 'https',
      host: '${config['host'] ?? ''}',
      wsPort: port,
      wssPort: port,
      onEvent: (event) {
        if (event.eventName.toLowerCase() == 'stay.booking.updated') onUpdate();
      },
      onAuthorizer: (channel, socketId, _) async {
        final result = await api.post('pusher/auth/$socketId/$channel', {});
        if (result.body is Map && result.body['auth'] != null) {
          return {'auth': '${result.body['auth']}'};
        }
        return null;
      },
    );
    await pusher.connect();
    await pusher.subscribe(channelName: 'private-user.$userId');
  }

  Future<void> disconnect() async {
    started = false;
    try {
      await pusher.disconnect();
    } catch (_) {}
  }
}
