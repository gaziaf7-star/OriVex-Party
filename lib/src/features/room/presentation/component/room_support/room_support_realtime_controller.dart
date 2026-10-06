import 'package:flutter/foundation.dart';
import 'package:general/src/features/room/room.dart';

/// Realtime nudge for the Room Support sheet. Backend broadcasts a
/// `room_support_updated` Centrifugo event (see
/// `get_my_data_bloc.dart`'s `_listenToCentrifugoNonChatEvents`) whenever a
/// gift lands or a level/partner changes for a room. There's no payload to
/// apply directly -- it's just a "go refetch" signal -- so this is a bare
/// tick counter the open sheet listens to and re-calls the REST endpoint
/// on, mirroring [RocketRealtimeController]'s room-id filtering.
class RoomSupportRealtimeController {
  RoomSupportRealtimeController._();
  static final RoomSupportRealtimeController instance =
      RoomSupportRealtimeController._();

  final ValueNotifier<int> refreshTick = ValueNotifier(0);

  int _asInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  void handleEvent(dynamic payload) {
    if (payload is! Map) return;
    final json = Map<String, dynamic>.from(payload);
    final eventRoomId = json['room_id'] ?? json['livestream_id'];
    final currentRoomId = RoomData.instance.roomOrNull?.id;
    if (eventRoomId != null &&
        currentRoomId != null &&
        _asInt(eventRoomId) != _asInt(currentRoomId)) {
      // Broadcast to every viewer's personal channel, not room-scoped --
      // ignore updates for a room the user isn't currently in.
      return;
    }
    refreshTick.value++;
  }
}
