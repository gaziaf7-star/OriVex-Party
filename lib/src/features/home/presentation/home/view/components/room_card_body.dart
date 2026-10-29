import 'package:general/src/core/widgets/show_svga.dart';
import 'package:general/src/features/home/presentation/home/view/widgets/lock_pk_icon.dart';
import '../../../../../../core/index.dart';
import '../../../../../../core/widgets/on_multiable_tab.dart';
import '../../../../domain/entities/room_entity.dart';
import '../widgets/visitors_count.dart';

// NEW THEME (was _RoomCardBody, a home_page.dart part-file private class —
// made public so it can be reused outside the home feed, e.g. the Live tab).
class RoomCardBody extends StatelessWidget {
  const RoomCardBody({
    super.key,
    required this.data,
    this.isLoading = false,
    this.isShowSVGA = false,
    this.isLive = false,
    this.rank,
  });

  final RoomEntity data;
  final bool isLoading;
  final bool isShowSVGA;

  /// Whether tapping this card should enter the room as a live broadcast
  /// (RoomEntryRequest.isLive). Defaults false, matching every existing
  /// call site's behavior; the Live tab passes true.
  final bool isLive;

  /// 1-based position of this room in the currently displayed list. The
  /// rank-frame badge it used to draw (top 1/2/3) is hidden now -- see the
  /// build() note below -- but the field stays so callers don't need to
  /// change.
  final int? rank;

  static const _gradientDecoration = BoxDecoration(
    gradient: LinearGradient(
      colors: [Color(0x66000000), Colors.transparent],
      begin: AlignmentDirectional.bottomCenter,
      end: AlignmentDirectional.topCenter,
    ),
  );

  @override
  Widget build(BuildContext context) {
    // Cache dimension calculations
    final topPosition = isShowSVGA ? 20.h : 5.h;
    final sidePosition = isShowSVGA ? 12.w : 5.w;
    final containerHeight = isShowSVGA ? 60.h : 50.h;
    final startPadding = isShowSVGA ? 12.5 : 7.5;

    // Cover image sits inset inside the ornate frame (on request) so the
    // frame's border art shows fully around it with a small gap, instead of
    // the picture running edge-to-edge underneath the frame.
    final cardInset = isShowSVGA ? EdgeInsets.all(3.w) : EdgeInsets.zero;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Padding(
          padding: cardInset,
          child: MultiTapCard(
          onTap: () {
            if (isLoading) {
              di<RoomStateManager>().navigateToRoom(
                RoomEntryRequest(
                  context: context,
                  roomData: data,
                  isLive: isLive,
                ),
              );
            }
          },
          child: ClipRRect(
            borderRadius: 12.radius,
            child: Stack(
              alignment: AlignmentDirectional.bottomCenter,
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: ImageViewWidget(
                    url: data.cover ?? "",
                    boxFit: BoxFit.cover,
                    displayName: data.name ?? '',
                    isRoomCover: true,
                  ),
                ),
                // Room owner's profile picture, top-left, per request.
                // Nudged right + up a bit on the framed top-4 cards, on
                // request, so it clears the frame's top-left ornament corner.
                PositionedDirectional(
                  top: isShowSVGA ? 10.h : topPosition,
                  start: isShowSVGA ? 10.w : 5.w,
                  child: Container(
                    width: 36.w,
                    height: 36.w,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: ColorManager.white,
                        width: 1.2,
                      ),
                    ),
                    child: ClipOval(
                      child: ImageViewWidget(
                        url: data.ownerImage ?? '',
                        displayName: data.ownerName ?? '',
                        boxFit: BoxFit.cover,
                        width: 36.w,
                        height: 36.w,
                      ),
                    ),
                  ),
                ),
                PositionedDirectional(
                  top: topPosition,
                  end: 5.w,
                  child: LockAndPkIcon(
                    isPK: data.isPK ?? false,
                    isPassword: data.passwordStatus ?? false,
                    isHasLuckyBox: data.hasLuckyBox ?? false,
                  ),
                ),
                if (data.roomLevelImage != null &&
                    data.roomLevelImage!.isNotEmpty)
                  Positioned(
                    top: isShowSVGA ? 20.h : 10.h,
                    left: sidePosition,
                    right: sidePosition,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        ImageViewWidget(
                          url: data.roomLevelImage!,
                          boxFit: BoxFit.contain,
                          width: 34.w,
                          height: 18.h,
                        ),
                      ],
                    ),
                  ),
                Align(
                  alignment: AlignmentDirectional.bottomCenter,
                  child: Container(
                    width: ScreenUtil().screenWidth,
                    height: containerHeight,
                    padding: context.paddingOnly(
                      start: startPadding,
                      end: 3.5,
                    ),
                    decoration: _gradientDecoration,
                    child: SizedBox.shrink(
                      child: Align(
                        alignment: AlignmentDirectional.topStart,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                ImageViewWidget(
                                  url: data.country?.flag ?? "",
                                  height: 25,
                                  width: 25,
                                ),
                                5.0.wBox,
                                Expanded(
                                  child: TextWidget(
                                    Methods.capitalizeFirstLetter(
                                        data.name ?? ""),
                                    style: context.bodyMedium
                                        .colorExt(ColorManager.white),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                5.0.wBox,
                              ],
                            ),
                            Row(
                              children: [
                                Expanded(
                                  child: ConstrainedBox(
                                    constraints:
                                        BoxConstraints(maxWidth: 120.w),
                                    child: Text(
                                      data.roomIntro ?? '',
                                      style: context.bodySmall
                                          .colorExt(ColorManager.white),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                  ),
                                ),
                                5.wBox,
                                VisitorsCount(
                                  count: (data.visitorsCount ?? 0).toString(),
                                  fontSize: 12,
                                  color: ColorManager.white,
                                  fontWeight: FontWeight.w500,
                                  icon: AssetsManager.icHomeItemAudio,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          ),
        ),
        // Old animated SVGA border (only drawn on the first 4 "top rooms"
        // cards, via isShowSVGA) removed, on request -- replaced by the
        // static ornate frame below.
        // Top-1/2/3 rank frame hidden, on request -- it overlapped the
        // owner avatar now shown in the same top-left corner.
        // Decorative border frame -- only the first 4 "top rooms" cards
        // (isShowSVGA, same gate the old SVGA border used), on request; the
        // rest of the grid stays plain with its normal card gap/spacing.
        // Positioned MUST be the direct Stack child (an IgnorePointer
        // wrapping it broke that -- "Incorrect use of ParentDataWidget").
        // IgnorePointer instead wraps just the Image, inside the Positioned,
        // so the ornate art (which has its own transparent center) never
        // steals the card's tap target.
        // Top 1/2/3 cards get their own animated frame (on request,
        // replacing the old static ornate frame).
        if (isShowSVGA &&
            rank != null &&
            rank! >= 1 &&
            rank! <= AssetsManager.roomCardTopFrames.length)
          Positioned.fill(
            child: IgnorePointer(
              child: ShowSVGA(
                svgaAssetPath: AssetsManager.roomCardTopFrames[rank! - 1],
                fit: BoxFit.fill,
              ),
            ),
          ),
      ],
    );
  }
}
