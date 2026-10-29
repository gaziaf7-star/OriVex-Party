import 'package:flutter_svga/flutter_svga.dart';
import 'package:general/src/core/cache/svga_movie_cache.dart';
import 'package:general/src/core/widgets/gradient_name.dart';
import 'package:general/src/core/index.dart';
import 'package:general/src/core/widgets/bottom_dialog.dart';
import 'package:general/src/core/widgets/show_svga.dart';
import 'package:general/src/features/auth/domain/entities/user_entity.dart';
import 'package:general/src/core/utils/relative_time.dart';
import 'package:general/src/features/messages/presentation/messages/blocs/user_online/user_online_bloc.dart';
import 'package:general/src/features/cp/presentation/cp_store/bloc/cp_profile_bloc/cp_profile_bloc.dart';
import 'package:general/src/features/profile/presentation/profile/bloc/bloc_user_badges/get_user_badges_bloc.dart';
import 'package:general/src/features/profile/presentation/profile/bloc/bloc_user_badges/get_user_badges_state.dart';
import 'package:general/src/features/profile/presentation/profile/bloc/bloc_badge/user_badges_bloc.dart';
import 'package:general/src/features/profile/presentation/profile/view/page/user_profile/widget/user_images_carousel.dart';
import 'package:general/src/features/theme2_app/user_profile/presentation/widgets/theme2_live_badge.dart';
import 'package:general/src/features/profile/presentation/profile/view/page/user_profile/bloc/get_user_intro_bloc/get_user_intro_bloc.dart';
import 'package:general/src/features/profile/presentation/profile/view/page/user_profile/bloc/get_user_intro_bloc/get_user_intro_state.dart';
import 'package:general/src/core/widgets/gender_widget.dart';
import 'package:general/src/core/widgets/level_container.dart';
import 'package:general/src/core/widgets/vip_container.dart';

/// Left-aligned "VIP room profile" header, on request. The cover photo is
/// the background all the way DOWN to the follow-stats row -- name/gender,
/// ID, online status, host/manager badge, level badges + country,
/// achievement + VIP badges, and the follow stats all sit directly on top
/// of it (BoxFit.cover, so the photo is never distorted/stretched, just
/// extended), behind a dark gradient scrim so the white text stays
/// readable regardless of the photo. On request: "cover image ta following
/// section ar nes porjonto thakba" -- no separate solid panel underneath
/// anymore. The avatar sits top-left, inside the photo. The tab bar right
/// below this widget ([Theme2VisitorProfilePage]'s Personal/Moment/Gift/
/// Relation/Achievements bar) is untouched.
///
/// Deliberately left out (no backing field/asset anywhere in this codebase,
/// so nothing to build them from): the giant "SVIP" watermark, "Noble"
/// badge, the "Good Host 9pm-11pm" schedule ribbon, the CP/family
/// mini-avatar's own separate "Lv3" tag, the decorative crown/wings/rose
/// artwork, the "YOU ARE INVITED" banner, and the ornate cursive name font.
class Theme2VisitorProfileHeader extends StatelessWidget {
  final UserEntity? user;
  final bool isMyProfile;
  final CpProfileBloc cpProfileBloc;
  final UserOnlineBloc userOnlineBloc;
  final UserBadgesBloc userBadgesBloc;
  final VoidCallback onEditTap;
  final VoidCallback onMoreTap;

  // A bit more compact than before, on request ("profile image ar size").
  static const double avatarRadius = 36;

  const Theme2VisitorProfileHeader({
    super.key,
    required this.user,
    required this.isMyProfile,
    required this.cpProfileBloc,
    required this.userOnlineBloc,
    required this.userBadgesBloc,
    required this.onEditTap,
    required this.onMoreTap,
  });

  String _lastSeenLabel(String? iso) {
    final rel = RelativeTime.fromIso(iso);
    if (rel == null) return StringManager.offline.tr();
    return StringManager.lastSeenAt.tr(namedArgs: {'time': rel});
  }

  // Small dot + "Online"/"Offline" text, on request -- a clean,
  // professional-looking status line instead of just the little dot on
  // the avatar.
  Widget _onlineStatusLabel(bool online) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7.r,
          height: 7.r,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: online
                ? const Color(0xFF4CD964)
                : ColorManager.grey,
          ),
        ),
        5.wBox,
        Text(
          online ? StringManager.online.tr() : StringManager.offline.tr(),
          style: TextStyle(
            color: online
                ? const Color(0xFF2FB344)
                : ColorManager.grey,
            fontSize: 12.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  bool _inRoom(UserEntity? user) {
    if (isMyProfile) return false;
    final room = user?.nowRoom;
    return room != null && (room.id ?? 0) > 0 && (room.isnInRoom ?? false);
  }

  void _openFullImage(BuildContext context) {
    bottomDailog(
      context: context,
      widget: Scaffold(
        backgroundColor: ColorManager.black,
        appBar: const AppBarWidget(
          iconColor: Colors.grey,
          backgroundColor: ColorManager.black,
          title: '',
        ),
        body: InteractiveViewer(
          child: Container(
            height: MediaQuery.sizeOf(context).height,
            width: MediaQuery.sizeOf(context).width,
            padding: EdgeInsets.all(10.r),
            child: ImageViewWidget(
              url: EndPoints.getImage(user?.profile?.image ?? ''),
              height: MediaQuery.sizeOf(context).height,
              width: MediaQuery.sizeOf(context).width,
              boxFit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }

  /// Compact round avatar used inside the CP pill.
  Widget _plainAvatar(String image, String? name, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: ColorManager.white, width: 2),
      ),
      child: ClipOval(
        child: ImageViewWidget(
          url: image,
          displayName: name,
          width: size,
          height: size,
          boxFit: BoxFit.cover,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasPhotos = (user?.images ?? []).isNotEmpty;
    final topInset = MediaQueryData.fromView(View.of(context)).padding.top;
    final screenW = MediaQuery.sizeOf(context).width;
    // Cover photo on top, the info card slides up over its bottom edge.
    final coverH = screenW * 0.95;
    final overlap = 26.h;
    final avatarSize = 58.h;
    final inRoom = _inRoom(user);

    Widget onlineDot() => isMyProfile
        ? const _OnlineDot(online: true)
        : BlocBuilder<UserOnlineBloc, UserOnlineState>(
            bloc: userOnlineBloc,
            buildWhen: (prev, curr) => prev.online != curr.online,
            builder: (context, state) => _OnlineDot(online: state.online != 0),
          );

    final family = user?.familyData;
    final hasFamily = family != null && (family.name ?? '').isNotEmpty;
    final bio = (user?.bio ?? '').trim();

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Cover — the user's own photos, or the default artwork.
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: coverH,
          child: Stack(
            fit: StackFit.expand,
            children: [
              UserImagesCarousel(userData: user ?? const UserEntity()),
              if (isMyProfile && !hasPhotos)
                _AddPhotosPrompt(
                  onTap: () => Navigator.pushNamed(
                    context,
                    Routes.addMultiPicture,
                    arguments: true,
                  ),
                ),
            ],
          ),
        ),
        // Soft shade at the very top so the back / menu buttons stay visible.
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: topInset + 70.h,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    ColorManager.black.withValues(alpha: 0.35),
                    ColorManager.black.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
        ),

        // Info card: yellow fading to white, rounded top, over the cover.
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(height: coverH - overlap),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFFFE93D), Color(0xFFFFFFFF)],
                  stops: [0.0, 0.4],
                ),
              ),
              padding: EdgeInsets.fromLTRB(16.w, 18.h, 16.w, 14.h),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Avatar — with a CP the two avatars and the connecting
                      // heart sit together in one pill.
                      BlocBuilder<CpProfileBloc, CpProfileStates>(
                        bloc: cpProfileBloc,
                        buildWhen: (prev, curr) =>
                            prev.reqStates != curr.reqStates ||
                            prev.data?.mainCp != curr.data?.mainCp,
                        builder: (context, cpState) {
                          final cpUser = cpState.data?.mainCp?.user;
                          final hasCp =
                              cpUser != null && (cpUser.image ?? '').isNotEmpty;
                          if (!hasCp) {
                            return Stack(
                              clipBehavior: Clip.none,
                              children: [
                                GestureDetector(
                                  onTap: () => _openFullImage(context),
                                  child: (user?.frame ?? '') != ''
                                      ? UserImage(
                                          image: user?.profile?.image ?? '',
                                          displayName: user?.name,
                                          imageSize: avatarSize * 1.05,
                                          frameSize: avatarSize * 1.9,
                                          frameType: user?.frameType ?? '',
                                          frame: user?.frame ?? '',
                                          boxFit: BoxFit.cover,
                                          borderRadius: 60.radius,
                                        )
                                      : _plainAvatar(
                                          user?.profile?.image ?? '',
                                          user?.name,
                                          avatarSize * 1.1),
                                ),
                                Positioned(right: 2.w, bottom: 2.h, child: onlineDot()),
                              ],
                            );
                          }
                          return Container(
                            height: avatarSize + 10.h,
                            padding: EdgeInsets.all(5.h),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(40.r),
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFFB8D4FF),
                                  Color(0xFFF2B8F5),
                                  Color(0xFFFFB3C8),
                                ],
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                GestureDetector(
                                  onTap: () => _openFullImage(context),
                                  child: Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      _plainAvatar(user?.profile?.image ?? '',
                                          user?.name, avatarSize),
                                      Positioned(
                                          right: 0, bottom: 0, child: onlineDot()),
                                    ],
                                  ),
                                ),
                                SizedBox(
                                  width: avatarSize * 1.5,
                                  child: ShowSVGA(
                                    svgaAssetPath: AssetsManager.cpLoveIcon,
                                    fit: BoxFit.contain,
                                    height: avatarSize * 1.4,
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () => Methods().userProfileNavigator(
                                    context: context,
                                    userId: '${cpUser.id}',
                                  ),
                                  child: _plainAvatar(
                                      cpUser.image ?? '', cpUser.name, avatarSize),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      12.hBox,
                      // Name, gender/age, levels and country on one flowing line.
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 6.w,
                        runSpacing: 4.h,
                        children: [
                          if (user?.vip?.img1 != null && user!.vip!.img1!.isNotEmpty)
                            ImageViewWidget(
                              url: user!.vip!.img1!,
                              width: 32.w,
                              height: 23.h,
                              boxFit: BoxFit.fill,
                              radius: 20,
                            ),
                          ConstrainedBox(
                            constraints: BoxConstraints(maxWidth: screenW * 0.55),
                            child: GradientName(
                              child: Text(
                                user?.name ?? '',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: ColorManager.white,
                                  fontSize: 22.sp,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                          if ((user?.profile?.gender ?? 0) != 0)
                            GenderWidget(
                              age: user?.profile?.age ?? 0,
                              gender: user?.profile?.gender ?? 2,
                              widthSize: 36,
                            ),
                          if ((user?.level?.senderImage ?? '').isNotEmpty)
                            LevelContainer(
                              boxFit: BoxFit.cover,
                              level: user?.level?.senderLevel ?? 1,
                              image: user?.level?.senderImage ?? '',
                              height: 19.h,
                              width: 60.w,
                            ),
                          if ((user?.level?.receiverImage ?? '').isNotEmpty)
                            LevelContainer(
                              boxFit: BoxFit.contain,
                              level: user?.level?.reciverLevel ?? 1,
                              image: user?.level?.receiverImage ?? '',
                              height: 19.h,
                              width: 60.w,
                            ),
                          if ((user?.country?.photo ?? '').isNotEmpty)
                            ImageViewWidget(
                              url: user?.country?.photo ?? '',
                              height: 19.h,
                              width: 27.w,
                            ),
                        ],
                      ),
                      8.hBox,
                      // ID + copy (+ presence).
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          GestureDetector(
                            onTap: () {
                              Clipboard.setData(
                                ClipboardData(text: '${user?.uuid ?? user?.id ?? ''}'),
                              );
                              Methods.showToast(context,
                                  message: StringManager.theTextHasBeenCopied.tr());
                            },
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                (user?.specialId != 0 &&
                                        (user?.specialId ?? '') != '' &&
                                        (user?.idImage ?? '').isNotEmpty)
                                    ? ImageViewWidget(
                                        url: user?.idImage ?? '',
                                        height: 22.h,
                                        width: 80.w,
                                        boxFit: BoxFit.fill,
                                      )
                                    : Text(
                                        "${StringManager.appName} ID: ${user?.uuid ?? user?.id ?? ''}",
                                        style: TextStyle(
                                          color: ColorManager.textPrimary,
                                          fontSize: 14.sp,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                4.wBox,
                                Icon(Icons.copy,
                                    size: 14.sp, color: ColorManager.grey),
                              ],
                            ),
                          ),
                          if (isMyProfile || !(user?.lastActiveHidden ?? false)) ...[
                            12.wBox,
                            isMyProfile
                                ? _onlineStatusLabel(true)
                                : BlocBuilder<UserOnlineBloc, UserOnlineState>(
                                    bloc: userOnlineBloc,
                                    buildWhen: (prev, curr) => prev.online != curr.online,
                                    builder: (context, state) =>
                                        _onlineStatusLabel(state.online != 0),
                                  ),
                          ],
                        ],
                      ),
                      // Host / agency / admin pill.
                      if ((user?.managerType?.image ?? '').isNotEmpty ||
                          (user?.managerType?.name ?? '').isNotEmpty)
                        Padding(
                          padding: EdgeInsets.only(top: 8.h),
                          child: Container(
                            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                            decoration: BoxDecoration(
                              gradient: ColorManager.brandGradient,
                              borderRadius: BorderRadius.circular(20.r),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if ((user?.managerType?.image ?? '').isNotEmpty) ...[
                                  ImageViewWidget(
                                    url: EndPoints.getImage(user!.managerType!.image!),
                                    width: 14.w,
                                    height: 14.h,
                                    boxFit: BoxFit.contain,
                                  ),
                                  4.wBox,
                                ],
                                Text(
                                  user?.managerType?.name ?? '',
                                  style: TextStyle(
                                    color: ColorManager.onBrandGradient,
                                    fontSize: 11.sp,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      // Admin-assigned badges + the SVIP badge on one scrolling line.
                      BlocBuilder<GetUserBadgesBloc, GetUserBadgesState>(
                        bloc: di<GetUserBadgesBloc>(),
                        buildWhen: (prev, curr) =>
                            prev.userBadge?.top != curr.userBadge?.top,
                        builder: (context, state) {
                          final ownedBadges = state.userBadge?.top ?? [];
                          final hasVip =
                              user?.vip != null && (user?.vip?.level ?? 0) != 0;
                          if (ownedBadges.isEmpty && !hasVip) {
                            return const SizedBox();
                          }
                          return Padding(
                            padding: EdgeInsets.only(top: 8.h),
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (hasVip) ...[
                                    VipContainer(
                                      vip: user!.vip!.img1 ?? '',
                                      width: 64.w,
                                      height: 34.h,
                                    ),
                                    3.wBox,
                                  ],
                                  for (final badge in ownedBadges) ...[
                                    badge.imageType == "svga"
                                        ? CacheSvgaWidget(
                                            url: EndPoints.getImage(badge.image),
                                            boxFit: BoxFit.contain,
                                            height: 42.h,
                                            width: 84.w,
                                          )
                                        : ImageViewWidget(
                                            url: EndPoints.getImage(badge.image),
                                            height: 42.h,
                                            width: 84.w,
                                            boxFit: BoxFit.contain,
                                          ),
                                    if (badge != ownedBadges.last) 3.wBox,
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                      // Achievement badges.
                      BlocBuilder<UserBadgesBloc, UserBadgesState>(
                        bloc: userBadgesBloc,
                        buildWhen: (prev, curr) => prev.userBadge != curr.userBadge,
                        builder: (context, state) {
                          final badges = (state.userBadge ?? []).take(6).toList();
                          if (badges.isEmpty) return const SizedBox();
                          return Padding(
                            padding: EdgeInsets.only(top: 8.h),
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  for (final b in badges)
                                    ImageViewWidget(
                                      url: EndPoints.getImage(b.image),
                                      height: 46.h,
                                      width: 48.w,
                                      boxFit: BoxFit.contain,
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                      // Family row.
                      if (hasFamily)
                        Padding(
                          padding: EdgeInsets.only(top: 10.h),
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () {
                              if ((family.ownerFamilyId ?? 0) != 0) {
                                Navigator.pushNamed(context, Routes.familyScreen,
                                    arguments: '${user!.familyId}');
                              } else {
                                context.pushNamedRoute(Routes.familyRankPage);
                              }
                            },
                            child: Row(
                              children: [
                                Container(
                                  padding: EdgeInsets.fromLTRB(4.w, 3.h, 12.w, 3.h),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(20.r),
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFF7BE35A), Color(0xFFE8F26B)],
                                    ),
                                    border: Border.all(
                                        color: const Color(0xFFFFFFFF), width: 1),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      ImageViewWidget(
                                        url: EndPoints.getImage(family.img ?? ''),
                                        displayName: family.name,
                                        width: 22.h,
                                        height: 22.h,
                                        shape: BoxShape.circle,
                                        boxFit: BoxFit.cover,
                                      ),
                                      6.wBox,
                                      ConstrainedBox(
                                        constraints:
                                            BoxConstraints(maxWidth: screenW * 0.5),
                                        child: Text(
                                          family.name ?? '',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: const Color(0xFF1E4D0F),
                                            fontSize: 13.sp,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Spacer(),
                                Icon(Icons.chevron_right_rounded,
                                    color: ColorManager.grey, size: 22.sp),
                              ],
                            ),
                          ),
                        ),
                      18.hBox,
                      _StatsTextRow(user: user, isMyProfile: isMyProfile),
                      if (bio.isNotEmpty) ...[
                        14.hBox,
                        Padding(
                          padding: EdgeInsets.only(right: inRoom ? 70.w : 0),
                          child: Text(
                            bio,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: ColorManager.grey,
                              fontSize: 15.sp,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  // LIVE card, bottom-right of the info card.
                  if (inRoom)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Theme2LiveBadge(nowRoom: user!.nowRoom!),
                    ),
                ],
              ),
            ),
          ],
        ),

        // The visited user's ACTIVE entrance effect ("entry"), shown on their
        // profile the way it is shown when they enter a room.
        //
        // The profile response often leaves `intro` empty and only carries
        // `intro_id` (the equipped one); the file itself is in the user's
        // intro list (/image-intro/{id}), so the id is looked up there. An
        // .svga plays once; a still image slides/fades in. Taps pass through.
        Positioned.fill(
          child: BlocBuilder<GetUserIntroBloc, GetUserIntroState>(
            bloc: di<GetUserIntroBloc>(),
            buildWhen: (prev, curr) =>
                prev.userIntroModel != curr.userIntroModel,
            builder: (context, state) {
              var path = user?.intro ?? '';
              final activeId = user?.introId ?? 0;
              if (path.isEmpty && activeId != 0) {
                for (final i in state.userIntroModel ?? const []) {
                  if (i.id == activeId) {
                    path = i.image;
                    break;
                  }
                }
              }
              if (path.isEmpty) return const SizedBox.shrink();
              final url = EndPoints.getImage(path);

              // Plays ONCE per profile visit (see _EntryEffect), keyed by the
              // file so a rebuild never replays it.
              return IgnorePointer(
                child: _EntryEffect(key: ValueKey(url), path: path, url: url),
              );
            },
          ),
        ),

        // Top bar: back + Edit (own) / More (visited) — over the cover.
        Positioned(
          top: topInset + 8,
          left: 8.w,
          right: 8.w,
          child: Row(
            children: [
              _RoundIconButton(
                icon: Icons.arrow_back_ios_new,
                onTap: () => Navigator.pop(context),
              ),
              const Spacer(),
              if (isMyProfile) ...[
                _RoundIconButton(
                  icon: Icons.add_photo_alternate_outlined,
                  onTap: () => Navigator.pushNamed(
                    context,
                    Routes.addMultiPicture,
                    arguments: true,
                  ),
                ),
                8.wBox,
                _RoundIconButton(icon: Icons.edit, onTap: onEditTap),
              ] else if (user?.id != null && user!.id != 0)
                _RoundIconButton(icon: Icons.more_horiz, onTap: onMoreTap),
            ],
          ),
        ),
      ],
    );
  }
}

/// "+ Add photos" prompt over the default cover artwork — own profile only,
/// only while there are no uploaded photos yet. Tapping opens the same
/// multi-picture screen the rest of the app already uses to manage photos.
class _AddPhotosPrompt extends StatelessWidget {
  final VoidCallback onTap;

  const _AddPhotosPrompt({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.symmetric(horizontal: 22.w, vertical: 8.h),
              decoration: BoxDecoration(
                border: Border.all(color: ColorManager.white.withValues(alpha: 0.7)),
                borderRadius: BorderRadius.circular(30.r),
              ),
              child: Icon(Icons.add, color: ColorManager.white, size: 22.sp),
            ),
            8.hBox,
            Text(
              StringManager.addPicture.tr(),
              style: TextStyle(
                color: ColorManager.white,
                fontSize: 13.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnlineDot extends StatelessWidget {
  final bool online;

  const _OnlineDot({required this.online});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 14.r,
      height: 14.r,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: online ? const Color(0xFF4CD964) : ColorManager.grey2,
        border: Border.all(color: ColorManager.white, width: 2),
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _RoundIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 34.r,
        height: 34.r,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: ColorManager.black.withValues(alpha: 0.28),
        ),
        child: Icon(icon, color: ColorManager.white, size: 17.sp),
      ),
    );
  }
}

/// Follow/Following/Friends/Visitors stats — stacked count-over-label,
/// like the reference image, directly over the photo with a thin vertical
/// divider between each. Own profile shows the app's real
/// Following/Followers/Friends/Visitors counts; a visited profile keeps
/// the existing privacy rule and shows only Views + Followers.
class _StatsTextRow extends StatelessWidget {
  final UserEntity? user;
  final bool isMyProfile;

  const _StatsTextRow({required this.user, required this.isMyProfile});

  @override
  Widget build(BuildContext context) {
    void openList(int index, VoidCallback readCounter) {
      Navigator.pushNamed(context, Routes.friendFollowing, arguments: index);
      readCounter();
    }

    final items = isMyProfile
        ? [
      _StatItem(
        '${user?.numberOfFollowings ?? 0}',
        StringManager.following.tr(),
        onTap: () => openList(0,
                () => di<FetchUserDataBloc>().add(const ReadCounterFollowingsEvent())),
      ),
      _StatItem(
        '${user?.numberOfFans ?? 0}',
        StringManager.followers.tr(),
        onTap: () => openList(1,
                () => di<FetchUserDataBloc>().add(const ReadCounterFollowersEvent())),
      ),
      _StatItem(
        '${user?.numberOfFriends ?? 0}',
        StringManager.friends.tr(),
        onTap: () => openList(2,
                () => di<FetchUserDataBloc>().add(const ReadCounterFriendsEvent())),
      ),
      _StatItem(
        '${user?.profileVisitors ?? 0}',
        StringManager.visitors.tr(),
        onTap: () => openList(3,
                () => di<FetchUserDataBloc>().add(const ReadCounterVistorsEvent())),
      ),
    ]
        : [
      _StatItem('${user?.totalViews ?? 0}', StringManager.views.tr()),
      _StatItem(
        '${user?.numberOfFans ?? 0}',
        StringManager.followers.tr(),
        onTap: () => openList(1,
                () => di<FetchUserDataBloc>().add(const ReadCounterFollowersEvent())),
      ),
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        for (int i = 0; i < items.length; i++) ...[
          GestureDetector(
            onTap: items[i].onTap,
            behavior: HitTestBehavior.opaque,
            // Center-aligned count/label, on request ("total count ta
            // text ar fast a nah, meddle borabor thakba").
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  items[i].count,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: ColorManager.textPrimary,
                    fontSize: 22.sp,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                3.hBox,
                Text(
                  items[i].label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: ColorManager.grey,
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _StatItem {
  final String count;
  final String label;
  final VoidCallback? onTap;

  const _StatItem(this.count, this.label, {this.onTap});
}

/// The visited user's entry effect, played exactly once when their profile is
/// opened: an .svga plays through once and disappears; a still image slides
/// in, stays for a moment and fades away.
class _EntryEffect extends StatefulWidget {
  const _EntryEffect({super.key, required this.path, required this.url});

  final String path;
  final String url;

  @override
  State<_EntryEffect> createState() => _EntryEffectState();
}

class _EntryEffectState extends State<_EntryEffect>
    with SingleTickerProviderStateMixin {
  SVGAAnimationController? _svga;
  AnimationController? _image;
  bool _done = false;

  bool get _isSvga => Methods().isSvgaFile(widget.path);

  @override
  void initState() {
    super.initState();
    if (_isSvga) {
      _playSvga();
    } else {
      _image = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 4000),
      )..forward().whenComplete(_finish);
    }
  }

  Future<void> _playSvga() async {
    try {
      final movie = await SvgaMovieCache.instance.loadFromUrl(widget.url);
      if (!mounted) return;
      if (movie == null) {
        _finish();
        return;
      }
      final controller = SVGAAnimationController(vsync: this)
        ..videoItem = movie;
      setState(() => _svga = controller);
      controller.forward(from: 0).whenComplete(_finish);
    } catch (_) {
      _finish();
    }
  }

  void _finish() {
    if (mounted) setState(() => _done = true);
  }

  @override
  void dispose() {
    _svga?.dispose();
    _image?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_done) return const SizedBox.shrink();

    if (_isSvga) {
      final c = _svga;
      if (c == null) return const SizedBox.shrink();
      return SVGAImage(c, fit: BoxFit.cover, clearsAfterStop: true);
    }

    final ctrl = _image!;
    return AnimatedBuilder(
      animation: ctrl,
      builder: (context, child) {
        final t = ctrl.value;
        final inT = Curves.easeOutCubic.transform((t / 0.27).clamp(0.0, 1.0));
        final out = t > 0.8 ? (1 - (t - 0.8) / 0.2) : 1.0;
        return Opacity(
          opacity: (inT * out).clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset((1 - inT) * 90.w, 0),
            child: child,
          ),
        );
      },
      child: ImageViewWidget(url: widget.url, boxFit: BoxFit.contain),
    );
  }
}
