import 'package:general/src/core/index.dart';
import 'package:general/src/features/profile/data/model/gift_history_model.dart';
import 'package:general/src/features/room/data/model/extra_profile_data_model.dart';
import 'package:general/src/features/room/data/model/user_in_room_model.dart';

/// CP pill shown to the right of the avatar: beating heart, the CP partner's
/// picture and how many days they have been together. Renders nothing when
/// the user has no CP.
class RoomProfileCpPill extends StatelessWidget {
  final ExtraProfileDataModel? extra;
  const RoomProfileCpPill({super.key, required this.extra});

  @override
  Widget build(BuildContext context) {
    final cp = extra?.cp;
    final partner = cp?.user;
    if (cp == null || partner == null || (partner.image ?? '').isEmpty) {
      return const SizedBox.shrink();
    }
    final days = cp.di ?? 0;
    return Container(
      height: 40.h,
      padding: EdgeInsets.fromLTRB(8.w, 3.h, 3.h, 3.h),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30.r),
        gradient: const LinearGradient(
          colors: [Color(0xFFFFD6E8), Color(0xFFFF8FBF)],
        ),
        border: Border.all(color: Colors.white, width: 1.2),
        boxShadow: const [
          BoxShadow(color: Color(0x33FF4F9A), blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _BeatingHeart(),
          5.wBox,
          Flexible(
            child: Text(
              Methods.formatCompactNumber(days),
              maxLines: 1,
              softWrap: false,
              style: TextStyle(
                color: const Color(0xFFB0185F),
                fontSize: 12.sp,
                fontWeight: FontWeight.w700,
                decoration: TextDecoration.none,
              ),
            ),
          ),
          5.wBox,
          ImageViewWidget(
            url: partner.image ?? '',
            displayName: partner.name ?? '',
            width: 34.h,
            height: 34.h,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 1.5),
          ),
        ],
      ),
    );
  }
}

/// Heart that pulses like a heartbeat (quick double thump, then rest).
class _BeatingHeart extends StatefulWidget {
  const _BeatingHeart();

  @override
  State<_BeatingHeart> createState() => _BeatingHeartState();
}

class _BeatingHeartState extends State<_BeatingHeart>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat();
    _scale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.3).chain(CurveTween(curve: Curves.easeOut)), weight: 12),
      TweenSequenceItem(tween: Tween(begin: 1.3, end: 1.0).chain(CurveTween(curve: Curves.easeIn)), weight: 12),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.2).chain(CurveTween(curve: Curves.easeOut)), weight: 10),
      TweenSequenceItem(tween: Tween(begin: 1.2, end: 1.0).chain(CurveTween(curve: Curves.easeIn)), weight: 10),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 56),
    ]).animate(_c);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: Image.asset(AssetsManager.heartCpProfile, height: 24.h, width: 24.h),
    );
  }
}

/// SVIP / total-gift / family / agency cards under the badge row. Every card
/// is only built when the user actually has the thing it shows.
class RoomProfileCards extends StatelessWidget {
  /// Family / agency cards are switched off for now (requested). Flip to true
  /// to bring them back.
  static const bool showGroupCards = false;

  final UserInRoomModel user;
  final ExtraProfileDataModel? extra;
  const RoomProfileCards({super.key, required this.user, required this.extra});

  @override
  Widget build(BuildContext context) {
    final vip = user.vipLevel ?? 0;
    final gifts = (extra?.gifts ?? [])
        .where((g) => (g.data.showImg.isNotEmpty || g.data.img.isNotEmpty))
        .toList();
    final family = extra?.familyData;
    final hasFamily = showGroupCards &&
        family != null && (family.id ?? 0) != 0 && (family.name ?? '').isNotEmpty;
    final agency = user.myAgency;
    final hasAgency = showGroupCards &&
        agency != null && (agency.id ?? 0) != 0;

    final top = <Widget>[
      if (vip > 0) _SvipCard(level: vip, badge: user.vipImage ?? ''),
      if (gifts.isNotEmpty) _GiftCard(gifts: gifts),
    ];
    if (top.isEmpty && !hasFamily && !hasAgency) return const SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.fromLTRB(15.w, 10.h, 15.w, 0),
      child: Column(
        children: [
          if (top.isNotEmpty)
            Row(
              children: [
                for (var i = 0; i < top.length; i++) ...[
                  if (i > 0) 8.wBox,
                  Expanded(flex: top[i] is _GiftCard ? 6 : 5, child: top[i]),
                ],
              ],
            ),
          if (hasFamily) ...[
            if (top.isNotEmpty) 8.hBox,
            _GroupCard(
              image: family.img ?? '',
              name: family.name ?? '',
              info: '${family.memberNum ?? 0}/${family.maxNum ?? 0}',
            ),
          ],
          if (hasAgency) ...[
            if (top.isNotEmpty || hasFamily) 8.hBox,
            _GroupCard(
              image: agency.img ?? '',
              name: agency.name ?? '',
              info: 'ID ${agency.id}',
              isAgency: true,
            ),
          ],
        ],
      ),
    );
  }
}

class _SvipCard extends StatelessWidget {
  final int level;
  final String badge; // the user's SVIP badge (svga / image url)
  const _SvipCard({required this.level, required this.badge});

  // Plain colour per tier instead of a background picture.
  static const _tierColors = <int, Color>{
    1: Color(0xFF3D6BB3),
    2: Color(0xFF0E8A9E),
    3: Color(0xFF4B3FD6),
    4: Color(0xFF8E3FD6),
    5: Color(0xFFC02F8F),
    6: Color(0xFFB3202F),
    7: Color(0xFFD9731A),
    8: Color(0xFF14182B),
  };

  @override
  Widget build(BuildContext context) {
    final color = _tierColors[level.clamp(1, 8)] ?? _tierColors[1]!;
    return Container(
      height: 56.h,
      padding: EdgeInsets.symmetric(horizontal: 10.w),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10.r),
        color: color,
        border: Border.all(color: const Color(0xFFFFD27A), width: 1.2),
      ),
      child: Row(
        children: [
          if (badge.isNotEmpty) ...[
            ImageViewWidget(
              url: badge,
              width: 44.w,
              height: 36.h,
              boxFit: BoxFit.contain,
            ),
            8.wBox,
          ],
          Flexible(
            child: Text(
              'SVIP$level',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white,
                fontSize: 22.sp,
                fontWeight: FontWeight.w900,
                fontStyle: FontStyle.italic,
                decoration: TextDecoration.none,
                shadows: const [Shadow(color: Color(0x88000000), blurRadius: 3)],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GiftCard extends StatelessWidget {
  final List<GiftHistoryModel> gifts;
  const _GiftCard({required this.gifts});

  @override
  Widget build(BuildContext context) {
    final sorted = [...gifts]
      ..sort((a, b) => (int.tryParse(b.num) ?? 0).compareTo(int.tryParse(a.num) ?? 0));
    final total = gifts.fold<int>(0, (s, g) => s + (int.tryParse(g.num) ?? 0));
    final top3 = sorted.take(3).toList();

    return Container(
      height: 56.h,
      padding: EdgeInsets.symmetric(horizontal: 10.w),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10.r),
        gradient: const LinearGradient(
          colors: [Color(0xFF8A0F14), Color(0xFF5A0508)],
        ),
        border: Border.all(color: const Color(0xFFD98A3D), width: 1.2),
      ),
      child: Row(
        children: [
          Image.asset(AssetsManager.icMeCheckIn, height: 26.h, width: 26.h),
          4.wBox,
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'x${Methods.formatCompactNumber(total)}',
                  maxLines: 1,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w700,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
            ),
          ),
          for (final g in top3) ...[
            3.wBox,
            ClipRRect(
              borderRadius: BorderRadius.circular(4.r),
              child: ImageViewWidget(
                url: g.data.showImg.isNotEmpty ? g.data.showImg : g.data.img,
                width: 22.h,
                height: 22.h,
                boxFit: BoxFit.cover,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _GroupCard extends StatelessWidget {
  final String image;
  final String name;
  final String info;
  final bool isAgency;

  const _GroupCard({
    required this.image,
    required this.name,
    required this.info,
    this.isAgency = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 54.h,
      padding: EdgeInsets.all(5.h),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10.r),
        gradient: LinearGradient(
          colors: isAgency
              ? const [Color(0xFF1F6FD8), Color(0xFF6A3FD0)]
              : const [Color(0xFF7B2FD0), Color(0xFFC93FC9)],
        ),
      ),
      child: Row(
        children: [
          ImageViewWidget(
            url: EndPoints.getImage(image),
            displayName: name,
            width: 44.h,
            height: 44.h,
            radius: 6.r,
            boxFit: BoxFit.cover,
          ),
          10.wBox,
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                    decoration: TextDecoration.none,
                  ),
                ),
                Text(
                  info,
                  maxLines: 1,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 11.sp,
                    decoration: TextDecoration.none,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: Colors.white70, size: 22.sp),
        ],
      ),
    );
  }
}
