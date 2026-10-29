import 'package:general/src/core/widgets/gradient_name.dart';
import 'package:general/src/core/widgets/show_svga.dart';
import 'dart:ui' as ui;
import 'package:general/src/features/auth/domain/entities/user_entity.dart';
import 'package:general/src/features/cp/cp.dart';
import 'package:general/src/core/index.dart';

/// Theme2 version of CpBlockView - uses CP background + corner images
class Theme2VisitorCpCard extends StatefulWidget {
  final UserEntity userEntity;
  final bool myProfile;
  final CpProfileBloc cpProfileBloc;

  const Theme2VisitorCpCard({
    required this.myProfile,
    required this.userEntity,
    required this.cpProfileBloc,
    super.key,
  });

  @override
  State<Theme2VisitorCpCard> createState() => _Theme2VisitorCpCardState();
}

class _Theme2VisitorCpCardState extends State<Theme2VisitorCpCard> {
  final List<String> frames = [
    AssetsManager.cpFrame2,
    AssetsManager.cpFrame3,
    AssetsManager.cpFrame1,
  ];

  final List<String> title_ = [
    StringManager.friend.tr(),
    StringManager.brother.tr(),
    StringManager.couple.tr(),
  ];

  final List<Color> colors_ = [
    const Color(0xFF239FFE),
    const Color(0xFFFF8F1B),
    const Color(0xFFE6115D),
  ];

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<CpProfileBloc, CpProfileStates>(
      bloc: widget.cpProfileBloc,
      listener: (context, state) {
        if (state.buyCpReqStates == RequestState.loaded) {
          Methods.showToast(context, message: state.buyCpMessage);
          widget.cpProfileBloc.add(
            GetCpProfileEvents(
                userId: widget.userEntity.id.toString(), forceRefresh: true),
          );
        } else if (state.buyCpReqStates == RequestState.error) {
          Methods.showToast(context,
              isError: true, message: state.buyCpErrorMessage);
        } else if (state.buyCpReqStates == RequestState.loading) {
          Methods.showToast(context, isLoading: true);
        }
      },
      builder: (context, state) {
        return HandlingDataWidget(
          reqState: state.reqStates,
          title: state.message,
          subTitle: state.message,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // CP title row
              // Padding(
              //   padding: context.paddingSymmetric(horizontal: 1),
              //   child: Row(
              //     children: [
              //       // TextWidget(
              //       //   StringManager.cP.tr(),
              //       //   style: context.bodyMedium
              //       //       .size(16)
              //       //       .colorExt(ColorManager.theme2TextPrimary),
              //       // ),
              //       // const Spacer(),
              //       InkWell(
              //         onTap: () =>
              //             Navigator.pushNamed(context, Routes.cpStorePage),
              //         child: Row(
              //           children: [
              //             TextWidget(
              //               StringManager.cpSpace.tr(),
              //               style: context.bodyMedium
              //                   .size(14)
              //                   .colorExt(ColorManager.black),
              //             ),
              //             5.wBox,
              //             Icon(
              //               Icons.arrow_forward_ios,
              //               color: ColorManager.black,
              //               size: 14.sp,
              //             ),
              //           ],
              //         ),
              //       ),
              //     ],
              //   ),
              // ),
              5.hBox,
              // CP card with background
              Directionality(
                textDirection: ui.TextDirection.ltr,
                child: Padding(
                  padding: context.paddingSymmetric(horizontal: 1),
                  child: Stack(
                    clipBehavior: Clip.none,
                    alignment: AlignmentDirectional.center,
                    children: [
                      // CP card art (keeps its own aspect ratio).
                      LayoutBuilder(
                        builder: (context, c) => Image.asset(
                          AssetsManager.cpCardBg,
                          fit: BoxFit.fill,
                          height: c.maxWidth * 311 / 802,
                          width: double.infinity,
                        ),
                      ),
                      // Avatars + Love icon
                      Row(
                        children: [
                          state.data?.mainCp != null ? 30.wBox : 50.wBox,
                          // User avatar
                          Stack(
                            alignment: AlignmentDirectional.center,
                            children: [
                              state.data?.mainCp != null
                                  ? ImageViewWidget(
                                url: widget.userEntity.profile?.image ??
                                    '',
                                displayName: widget.userEntity.name ?? '',
                                height: 55.h,
                                width: 55.w,
                                radius: 60.r,
                                padding: EdgeInsetsDirectional.zero,
                                margin: EdgeInsetsDirectional.zero,
                                boxFit: BoxFit.cover,
                              )
                                  : CircleAvatar(
                                radius: 32.r,
                                backgroundColor: ColorManager.theme2BgDark,
                                child: ImageViewWidget(
                                  url: widget.userEntity.profile?.image ??
                                      '',
                                  displayName:
                                  widget.userEntity.name ?? '',
                                  height: 60.w,
                                  width: 60.w,
                                  radius: 60.r,
                                  padding: EdgeInsetsDirectional.zero,
                                ),
                              ),
                              if (state.data?.mainCp != null)
                                ShowSVGA(
                                  svgaAssetPath: AssetsManager.cpHeartAvatar,
                                  height: 110.h,
                                  width: 110.w,
                                ),
                            ],
                          ),
                          15.wBox,
                          // Love icon
                          Expanded(
                            child: ShowSVGA(
                              svgaAssetPath: AssetsManager.cpLoveIcon,
                              fit: BoxFit.cover,
                              height: 60.w,
                              width: 80.w,
                            ),
                          ),
                          15.wBox,
                          // CP partner avatar
                          Stack(
                            alignment: AlignmentDirectional.center,
                            children: [
                              if (state.data?.mainCp == null) ...{
                                CircleAvatar(
                                  radius: 32.r,
                                  backgroundColor: ColorManager.theme2BgDark,
                                  child: Image.asset(
                                    AssetsManager.emptyUserRelation,
                                    height: 60.w,
                                    width: 60.w,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              } else ...{
                                InkWell(
                                  onTap: () {
                                    Methods().userProfileNavigator(
                                      context: context,
                                      userId: state.data?.mainCp!.user!.id
                                          .toString(),
                                    );
                                  },
                                  child: ImageViewWidget(
                                    url: state.data?.mainCp?.user?.image ?? "",
                                    displayName:
                                    state.data?.mainCp?.user?.name ?? '',
                                    height: 55.h,
                                    width: 55.w,
                                    padding: EdgeInsetsDirectional.zero,
                                    radius: 60.r,
                                  ),
                                ),
                                IgnorePointer(
                                  child: ShowSVGA(
                                    svgaAssetPath: AssetsManager.cpHeartAvatar,
                                    height: 110.w,
                                    width: 110.w,
                                  ),
                                ),
                              },
                            ],
                          ),
                          state.data?.mainCp != null ? 30.wBox : 50.wBox,
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              10.hBox,
              // Remaining CP relations grid
              (!widget.myProfile && (state.data?.remainingCp ?? []).isEmpty)
                  ? const SizedBox()
                  : Padding(
                padding: context.paddingSymmetric(horizontal: 5),
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: context.paddingZero(),
                  itemCount: state.data?.seats ?? 0,
                  gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 0.77,
                  ),
                  itemBuilder: (context, index) {
                    if (index < (state.data?.seats ?? 0)) {
                      final cpList = state.data?.remainingCp ?? [];
                      if (index < cpList.length) {
                        final cp = cpList[index];
                        return _buildCpCard(cp, context);
                      }
                      return _buildEmptyCpSlot(context, state, index);
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCpCard(RemainingCp cp, BuildContext context) {
    return InkWell(
      onTap: () {
        Methods().userProfileNavigator(
          context: context,
          userId: cp.user?.id.toString(),
        );
      },
      child: LayoutBuilder(builder: (context, c) {
        final w = c.maxWidth, h = c.maxHeight;
        final d = w * 0.4; // fits inside the ring of the frame art
        return Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(AssetsManager.acceptFriendCard, fit: BoxFit.fill),
            // Picture inside the ring.
            Positioned(
              top: h * 0.385 - d / 2,
              left: (w - d) / 2,
              width: d,
              height: d,
              child: ClipOval(
                child: ImageViewWidget(
                  url: cp.user?.image ?? '',
                  displayName: cp.user?.name ?? '',
                  height: d,
                  width: d,
                  boxFit: BoxFit.cover,
                  padding: EdgeInsetsDirectional.zero,
                  margin: EdgeInsetsDirectional.zero,
                ),
              ),
            ),
            // Name between the ring and the pill.
            Positioned(
              left: w * 0.12,
              right: w * 0.12,
              top: h * 0.665,
              child: GradientName(
                child: Text(
                  cp.user?.name ?? '',
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: ColorManager.onDark,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            // Days on the pill.
            Positioned(
              left: w * 0.22,
              right: w * 0.22,
              top: h * 0.815,
              height: h * 0.075,
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '${cp.di ?? 0}D',
                    maxLines: 1,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _buildEmptyCpSlot(
      BuildContext context, CpProfileStates state, int index) {
    return GestureDetector(
      onTap: widget.myProfile
          ? () => Navigator.pushNamed(context, Routes.cpStorePage)
          : null,
      child: const _CpAddCard(),
    );
  }
}

/// "Add" slot: the supplied gold-framed card art with a round "+" button in
/// the middle and the label on its pill.
class _CpAddCard extends StatelessWidget {
  const _CpAddCard();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final w = c.maxWidth, h = c.maxHeight;
      final d = w * 0.46;
      return Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(AssetsManager.cpAddCard, fit: BoxFit.fill),
          Positioned(
            top: h * 0.24,
            left: (w - d) / 2,
            width: d,
            height: d,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFD9A8FF), Color(0xFFA766F2)],
                ),
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: const [
                  BoxShadow(color: Color(0x55A766F2), blurRadius: 8),
                ],
              ),
              child: Icon(Icons.add_rounded, color: Colors.white, size: d * 0.62),
            ),
          ),
          Positioned(
            left: w * 0.2,
            right: w * 0.2,
            top: h * 0.735,
            height: h * 0.13,
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  StringManager.add.tr(),
                  maxLines: 1,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w700,
                    shadows: const [Shadow(color: Color(0x88603BAA), blurRadius: 3)],
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    });
  }
}
