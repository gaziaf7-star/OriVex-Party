import 'package:general/src/core/index.dart';
import 'package:general/src/features/room/room.dart';

/// Global audio kill-switch, driven by the backend's `global_audio_toggle`
/// broadcast (Centrifugo, routed here via [RealtimeClient.nonChatEvents] --
/// see `get_my_data_bloc.dart`'s `_listenToCentrifugoNonChatEvents`).
///
/// Unlike the room-scoped Rocket events, this one targets every device
/// (`room_id: 0` in the payload), not just the current room, so it is never
/// filtered by room id.
///
/// Payload contract (confirmed by the backend team):
///   { "action_type": "global_audio_toggle", "audio_on": 0 | 1, ... }
class GlobalAudioController {
  GlobalAudioController._();
  static final GlobalAudioController instance = GlobalAudioController._();

  /// Whether the Admin currently allows microphones to be unmuted. Read by
  /// [MicrophoneButton] before it lets a tap turn the mic on.
  final ValueNotifier<bool> isAudioEnabled = ValueNotifier(true);

  void handleEvent(dynamic payload) {
    if (payload is! Map) return;
    final json = Map<String, dynamic>.from(payload);
    // `live.stream.event` is the shared envelope name; only react to this
    // specific action_type so any other action later riding the same
    // channel is safely ignored here.
    if (json['action_type'] != 'global_audio_toggle') return;
    final audioOn = json['audio_on'];
    final enabled = audioOn == 1 || audioOn == true;

    isAudioEnabled.value = enabled;

    if (!enabled) {
      // Force-mute the local mic immediately, in whatever room the user is
      // currently in. Best-effort: the engine call can throw when the media
      // server is unreachable, same as MicrophoneButton's own toggle -- never
      // let that crash the app.
      final media = RoomData.instance.utdController?.mediaController;
      if (media != null && media.isMicEnabled.value) {
        media.setMicrophoneEnabled(false).catchError((Object e, StackTrace s) {
          Methods.recordNonFatal(e, s,
              reason: 'GlobalAudioController.forceMute');
        });
      }
      Methods.safeShowToast(
        message: StringManager.globalAudioMutedByAdmin.tr(),
        isError: true,
      );
    } else {
      Methods.safeShowToast(
        message: StringManager.globalAudioRestored.tr(),
      );
    }
  }
}
