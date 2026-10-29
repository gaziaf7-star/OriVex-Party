import 'package:general/src/core/index.dart';
import 'package:general/src/features/auth/domain/entities/now_room_entity.dart';
import 'package:general/src/features/home/domain/entities/room_entity.dart';

/// Animated "تتبع"/live badge shown on the visitor profile header when the
/// profiled user is currently inside a room. It pulses (scale + glow) to draw
/// attention and, on tap, enters that room reusing the canonical room-enter
/// flow ([RoomStateManager.navigateToRoom]) — the same path a room-list tap
/// uses (see theme2_room_card.dart), so password / PiP / same-room handling
/// all come for free.
class Theme2LiveBadge extends StatefulWidget {
  /// The room the profiled user is currently in. The badge is only built by the
  /// caller when this is non-null with a valid id, so we treat it as present.
  final NowRoomEntity nowRoom;

  const Theme2LiveBadge({super.key, required this.nowRoom});

  @override
  State<Theme2LiveBadge> createState() => _Theme2LiveBadgeState();
}

class _Theme2LiveBadgeState extends State<Theme2LiveBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _scale = Tween<double>(begin: 0.92, end: 1.12).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _enterRoom() {
    final roomId = widget.nowRoom.id;
    if (roomId == null || roomId == 0) return;

    final roomEntity = RoomEntity(
      id: roomId,
      name: widget.nowRoom.roomName,
      cover: widget.nowRoom.roomCover,
      roomBackground: widget.nowRoom.roomBackground,
      mode: widget.nowRoom.mode,
      giftPrice: widget.nowRoom.giftPrice,
      passwordStatus: widget.nowRoom.roomStatus,
    );

    di<RoomStateManager>().navigateToRoom(
      RoomEntryRequest(
        context: context,
        roomData: roomEntity,
        isLive: false,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _enterRoom,
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          width: 54.w,
          height: 54.w,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14.r),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFB6F04A), Color(0xFF45C21E)],
            ),
            border: Border.all(color: const Color(0xFFE7FFB0), width: 1.5),
            boxShadow: const [
              BoxShadow(color: Color(0x6645C21E), blurRadius: 8, spreadRadius: 1),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.equalizer_rounded, color: ColorManager.white, size: 24.sp),
              Text(
                'LIVE',
                style: TextStyle(
                  color: ColorManager.white,
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
