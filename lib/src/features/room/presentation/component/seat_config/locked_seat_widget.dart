import 'dart:io';
import 'package:general/src/core/index.dart';
import 'package:general/src/features/room/presentation/component/seat_config/charisma_badge_widget.dart';
import 'package:general/src/features/room/presentation/component/seat_config/seat_metrics.dart';

class LockedSeatWidget extends StatelessWidget {
  final int index;

  /// The full seat slot size provided by the audio-room kit. The icon is sized
  /// to [SeatMetrics.avatar] — the SAME shared source the occupied avatar and
  /// the empty seat use — so all seat states match exactly, and leave room for
  /// the index label so the column never overflows the tight square the kit lays
  /// the seat out in.
  final double size;
  const LockedSeatWidget({super.key, required this.index, required this.size});

  @override
  Widget build(BuildContext context) {
    final m = SeatMetrics.forSeat(size);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        // Mirrors EmptySeat: cap the icon at the shared avatar size but let it
        // shrink in a tight slot so the column never overflows the square.
        // The reference icon (a self-contained circular graphic) is drawn
        // directly at the full seat slot size -- no separate white disc
        // behind it -- on request.
        Flexible(
          child: AspectRatio(
            aspectRatio: 1,
            child: SizedBox(
              width: m.avatar,
              height: m.avatar,
              child: Methods.getMicImageClose() != null
                  ? ClipOval(
                child: Image.file(
                  File(Methods.getMicImageClose() ?? ''),
                  fit: BoxFit.cover,
                ),
              )
                  : Image.asset(
                AssetsManager.lockSeat,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
        Text(
          "${index + 1}",
          textAlign: TextAlign.center,
          style: context.bodyMedium
              .copyWith(fontSize: m.indexFont)
              .w400
              .colorExt(ColorManager.white),
        ),
        CharismaValueLine(
          userId: '',
          fontSize: m.charismaFont,
          iconSize: m.charismaIcon,
        ),
      ],
    );
  }
}