import 'dart:async';

import 'package:general/src/core/index.dart';
import 'package:general/src/features/live_room/presentation/live_room_data.dart';
import 'package:general/src/features/room/data/model/user_in_room_model.dart';
import 'package:general/src/features/room/room.dart';
import 'package:permission_handler/permission_handler.dart';

/// Tracks which seated users in the AUDIO room were muted by the owner or an
/// admin, as opposed to muting themselves.
///
/// The RTC engine only knows "mic off", so a self-mute and a moderator mute
/// looked identical: a moderator could "unmute" someone who chose to be
/// silent, a moderator-muted user could just tap their mic back on, and the
/// moderator unmute went through the server's remote-unmute, which the
/// engine rejects, so the owner could never undo their own mute.
///
/// Rules:
/// - Self-muted: only the user can unmute; moderators only see "Mute".
/// - Moderator-muted: the user cannot unmute; the owner or any admin can.
///
/// The state travels as a [messageType] room data message. Every client keeps
/// the set; the muted user's own client enforces it on its mic.
class ModeratorMute {
  ModeratorMute._();

  static final ModeratorMute instance = ModeratorMute._();

  static const String messageType = 'modMute';

  /// Identities currently muted by the owner/an admin.
  final ValueNotifier<Set<String>> mutedIds = ValueNotifier(<String>{});

  UTDRoomController? _controller;
  StreamSubscription<Map<String, dynamic>>? _sub;

  /// My mic state right before a moderator muted me, restored on unmute so a
  /// moderator unmute never turns on a mic I had switched off myself.
  bool _micOnBeforeLock = false;

  static String get _myId => MyDataModel.getInstance().id.toString();

  bool isLocked(String userId) => mutedIds.value.contains(userId);

  bool get isMeLocked => isLocked(_myId);

  /// Attaches unless already listening to [controller].
  void ensureAttached(UTDRoomController controller) {
    if (!identical(_controller, controller)) attach(controller);
  }

  void attach(UTDRoomController controller) {
    detach();
    _controller = controller;
    _sub = controller.dataStream.listen((data) {
      if (data['type'] != messageType) return;
      final id = data['identity']?.toString();
      if (id == null || id.isEmpty) return;
      Methods.printLog('🔇 [ModeratorMute] received identity=$id '
          'muted=${data['muted']}');
      _apply(id, data['muted'] == true);
    });
  }

  void detach() {
    _sub?.cancel();
    _sub = null;
    _controller = null;
    _micOnBeforeLock = false;
    mutedIds.value = <String>{};
  }

  /// Sends the lock/unlock to the room. Data messages are not echoed back to
  /// the sender, so it is applied locally as well.
  Future<void> broadcast(UTDRoomController controller, String userId,
      {required bool muted}) async {
    ensureAttached(controller);
    _apply(userId, muted);
    Methods.printLog('🔇 [ModeratorMute] send $messageType '
        'identity=$userId muted=$muted');
    await controller.sendRoomMessage(
        {'type': messageType, 'identity': userId, 'muted': muted});
  }

  void _apply(String userId, bool muted) {
    if (isLocked(userId) == muted) return;
    final next = {...mutedIds.value};
    muted ? next.add(userId) : next.remove(userId);
    mutedIds.value = next;
    if (userId == _myId) unawaited(_enforceOnMyMic(muted));
  }

  Future<void> _enforceOnMyMic(bool muted) async {
    final media = _controller?.mediaController;
    if (media == null) return;
    final ctx = navKey.currentContext;
    try {
      if (muted) {
        _micOnBeforeLock = media.isMicEnabled.value;
        if (media.isMicEnabled.value) await media.setMicrophoneEnabled(false);
      } else if (_micOnBeforeLock &&
          media.canPublish.value &&
          await Permission.microphone.isGranted) {
        await media.setMicrophoneEnabled(true);
      }
    } catch (e, s) {
      Methods.recordNonFatal(e, s, reason: 'ModeratorMute.enforceOnMyMic');
    }
    if (ctx != null) {
      Methods.showToast(
        ctx,
        message: (muted
                ? StringManager.mutedByModerator
                : StringManager.unmutedByModerator)
            .tr(),
      );
    }
  }
}

/// Mutes or unmutes [userData]'s mic as the owner/an admin. In an audio room
/// "unmute" is offered only for a user a moderator muted (see
/// [ModeratorMute]); a self-muted user can only be muted (locked). The target
/// stays on their seat — this is a mic mute, not a kick. No-op if the user is
/// not on a seat. Gating to host/admin is handled by the calling menu.
Future<void> toggleUtdMute(UserInRoomModel userData) async {
  // Route to the ACTIVE controller — in a LIVE broadcast the audio utdController
  // is null, so the previous code returned here and mute silently did nothing.
  final isLive = di<RoomStateManager>().isInVideoRoom;
  final userId = userData.id.toString();
  final actor = MyDataModel.getInstance().id.toString();
  final ctx = navKey.currentContext;

  bool ok = false;
  bool isMuted;
  if (isLive) {
    final c = LiveRoomData.instance.liveController;
    if (c == null) return;
    isMuted = c.mutedParticipants.value.contains(userId);
    final seatIndex = c.seatController.getSeatIndexByUserId(userId);
    if (seatIndex < 0) return; // not on a seat -> no mic to mute
    // Live kit uses setRemoteMicEnabled (engine API) not seatController mute
    ok = await c.setRemoteMicEnabled(userId, isMuted);
  } else {
    final c = RoomData.instance.utdController;
    if (c == null) return;
    isMuted = ModeratorMute.instance.isLocked(userId);
    final seatIndex = c.seatController.getSeatIndexByUserId(userId);
    if (seatIndex < 0) return;
    if (isMuted) {
      // The target's own client turns its mic back on. The server-side
      // remote unmute is also tried, but the engine usually rejects it, so
      // its result is ignored.
      await ModeratorMute.instance.broadcast(c, userId, muted: false);
      await c.seatController.unmuteSeat(seatIndex, identity: actor);
      ok = true;
    } else {
      // Lock first so the target records its mic state before the server
      // mute below switches it off.
      // The server mute is only a backstop (it errors for a mic that is
      // already off); the target's client enforces the lock itself.
      await ModeratorMute.instance.broadcast(c, userId, muted: true);
      await c.seatController.muteSeat(seatIndex, identity: actor);
      ok = true;
    }
  }

  if (ctx != null) {
    Methods.showToast(
      ctx,
      message:
          ok
              ? (isMuted ? StringManager.userUnmuted : StringManager.userMuted)
                  .tr()
              : StringManager.someThingWentWrong.tr(),
      isError: !ok,
    );
  }
}
