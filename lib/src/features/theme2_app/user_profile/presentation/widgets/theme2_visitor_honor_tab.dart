import 'package:general/src/core/index.dart';
import 'package:general/src/features/theme2_app/user_profile/presentation/widgets/profile_frame_painter.dart';
import 'package:general/src/features/profile/presentation/medals/bloc/badge_bloc/badges_bloc.dart';
import 'package:general/src/features/profile/presentation/profile/bloc/bloc_badge/user_badges_bloc.dart';
import 'package:general/src/features/profile/presentation/profile/view/page/user_profile/bloc/get_user_intro_bloc/get_user_intro_bloc.dart';
import 'package:general/src/features/profile/presentation/profile/view/page/user_profile/bloc/get_user_intro_bloc/get_user_intro_event.dart';
import 'package:general/src/features/profile/presentation/profile/view/page/user_profile/bloc/get_user_intro_bloc/get_user_intro_state.dart';
import 'package:general/src/features/profile/presentation/profile/view/page/user_profile/bloc/gift_history_bloc/gift_history_bloc.dart';
import 'package:general/src/features/profile/presentation/profile/view/page/user_profile/bloc/gift_history_bloc/gift_history_state.dart';

/// تاب شرف - Medals + Gift Wall (Frames) + Titles + Entrance effects
class Theme2VisitorHonorTab extends StatelessWidget {
  final UserBadgesBloc userBadgesBloc;
  final GetBadgesBloc getBadgesBloc;
  final GetUserIntroBloc getUserIntroBloc;
  final GiftHistoryBloc giftHistoryBloc;
  final String userId;

  const Theme2VisitorHonorTab({
    super.key,
    required this.userBadgesBloc,
    required this.getBadgesBloc,
    required this.getUserIntroBloc,
    required this.giftHistoryBloc,
    required this.userId,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      // Nested inside _Theme2GeneralTab's scroll → shrink-wrap and disable its
      // own scrolling so the parent NestedScrollView owns all vertical scroll.
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      // Left/right gap reduced further still on request.
      padding: EdgeInsets.fromLTRB(2.w, 0, 2.w, 12.h),
      children: [
        // Sent-gifts section — badges removed from profile per product
        // decision (the feature still exists elsewhere).
        _SimpleSectionTitle(title: StringManager.giftsSent.tr()),

        BlocBuilder<GiftHistoryBloc, GiftHistoryState>(
          bloc: giftHistoryBloc,
          buildWhen: (prev, curr) => prev.giftModel != curr.giftModel,
          builder: (context, state) {
            final gifts = state.giftModel ?? [];
            if (gifts.isEmpty) {
              return _EmptySection(label: StringManager.noGifts.tr());
            }
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.only(top: 8.h),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 10.w,
                mainAxisSpacing: 10.h,
                childAspectRatio: 0.92,
              ),
              itemCount: gifts.length > 9 ? 9 : gifts.length,
              itemBuilder: (context, index) {
                final gift = gifts[index];
                return _FramedCard(
                  // `img` is the animated .svga send-effect; `show_img` is
                  // the static thumbnail meant for a grid like this.
                  picture: ImageViewWidget(
                    url: EndPoints.getImage(gift.data.showImg),
                    boxFit: BoxFit.contain,
                    width: double.infinity,
                  ),
                  line1: gift.num.isNotEmpty ? 'x${gift.num}' : '',
                  line2: gift.data.name,
                );
              },
            );
          },
        ),
        // Gap between sections reduced on request.
        8.hBox,

        // Entrance effects section (دخولية)
        _SimpleSectionTitle(title: StringManager.rideQuantity.tr()),
        2.hBox,
        BlocBuilder<GetUserIntroBloc, GetUserIntroState>(
          bloc: getUserIntroBloc,
          buildWhen: (prev, curr) =>
          prev.requestState != curr.requestState ||
              prev.userIntroModel != curr.userIntroModel,
          builder: (context, state) {
            final intros = state.userIntroModel ?? [];
            if (intros.isEmpty) {
              return GestureDetector(
                onTap: () =>
                    getUserIntroBloc.add(GetUserIntro(id: userId)),
                child: _EmptySection(label: StringManager.noDataYet.tr()),
              );
            }
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.only(top: 8.h),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 10.w,
                mainAxisSpacing: 10.h,
                childAspectRatio: 0.92,
              ),
              itemCount: intros.length,
              itemBuilder: (context, index) {
                final intro = intros[index];
                return _FramedCard(
                  picture: intro.image.contains('.svga')
                      ? CacheSvgaWidget(
                          url: EndPoints.getImage(intro.image),
                          boxFit: BoxFit.contain,
                        )
                      : ImageViewWidget(
                          url: EndPoints.getImage(intro.image),
                          boxFit: BoxFit.contain,
                          width: double.infinity,
                        ),
                  line1: '',
                  line2: intro.count > 0 ? 'x${intro.count}' : '',
                );
              },
            );
          },
        ),
        20.hBox,
      ],
    );
  }
}

class _SimpleSectionTitle extends StatelessWidget {
  final String title;

  const _SimpleSectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyle(
        color: ColorManager.black,
        fontSize: 16.sp,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _EmptySection extends StatelessWidget {
  final String label;

  const _EmptySection({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 12.h),
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            color: ColorManager.black,
            fontSize: 13.sp,
          ),
        ),
      ),
    );
  }
}
/// Card with a double border (a thin outer line and a rounded inner line) and
/// a small fan-shaped mark in each of the four corners, the picture in the
/// middle, a muted line and a bold line of text underneath.
class _FramedCard extends StatelessWidget {
  final Widget picture;
  final String line1;
  final String line2;

  const _FramedCard({
    required this.picture,
    required this.line1,
    required this.line2,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final w = c.maxWidth;
      final pad = w * 0.11;
      return CustomPaint(
        painter: const ProfileFramePainter(),
        child: Padding(
          padding: EdgeInsets.fromLTRB(pad, pad * 0.9, pad, pad * 0.7),
          child: Column(
            children: [
              Expanded(child: picture),
              SizedBox(height: 3.h),
              if (line1.isNotEmpty)
                Text(
                  line1,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF9A8BC9),
                  ),
                ),
              if (line2.isNotEmpty)
                Text(
                  line2,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF3B2A6B),
                  ),
                ),
            ],
          ),
        ),
      );
    });
  }
}
