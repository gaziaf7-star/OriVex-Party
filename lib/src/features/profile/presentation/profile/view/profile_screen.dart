import 'package:general/src/core/index.dart';
import 'package:general/src/core/widgets/country_icon.dart';
import 'package:general/src/core/widgets/id_with_copy.dart';
import 'package:general/src/features/agency/presentation/charge_agency/view/component/host_withdrawel_screen/bloc/get_setting_manager/get_setting_bloc.dart';
import 'package:general/src/features/auth/auth.dart';
import 'package:general/src/features/chats/chats.dart';
import 'package:general/src/features/home/presentation/daily_prize/bloc/daily_prizes_bloc.dart';
import 'package:general/src/features/home/presentation/daily_prize/view/daily_prize_dialog.dart';
import 'package:general/src/features/profile/presentation/coins/bloc/my_store_bloc/my_store_bloc.dart';
import 'package:general/src/features/profile/presentation/profile/bloc/bloc_user_badges/get_user_badges_bloc.dart';
import 'package:general/src/features/profile/presentation/profile/bloc/bloc_user_badges/get_user_badges_state.dart';
import 'package:general/src/features/profile/presentation/profile/view/widgets/f_f_f_body.dart';
import 'package:general/src/features/profile/presentation/profile/view/widgets/third_card_body.dart';
import 'package:general/src/features/profile/presentation/profile/view/widgets/DashboardWebViewScreen.dart';
import 'package:general/src/core/widgets/level_container.dart';
import 'package:general/src/core/widgets/vip_container.dart';
// Role tags (BD / Agent / Seller / Host) shared with the in-room profile,
// so both read the same `user_types` and cannot disagree.

part 'components/colum_info_body.dart';
part 'components/fifth_card.dart';
part 'components/icon_and_title_body.dart';
part 'components/list_tile_body.dart';
part 'components/profile_body.dart';
part 'components/profile_card.dart';
part 'widgets/coins_or_agency_widget.dart';
part 'widgets/second_card.dart';
part 'widgets/level_charm_pills.dart';
part 'widgets/mine_header.dart';
part 'widgets/second_card_body.dart';
part 'widgets/user_info_bar.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  @override
  Widget build(BuildContext context) {
    return BackgroundImgWidget(
      // Home page's exact gradient band (was the panel-driven body theme/
      // scaffoldBg) — requested to match the Home page background.
      backgroundGradient: ColorManager.homeBackgroundGradient,
      child: Scaffold(
        // Fixed transparent in both themes so the gradient above shows
        // through (was ColorManager.background — an opaque near-black that
        // would have hidden it in theme1).
        backgroundColor: ColorManager.transparent,
        body: SafeArea(
          top: !ConstantsManager.isTheme1,
          child: BlocBuilder<FetchUserDataBloc, FetchUserDataState>(
            bloc: di<FetchUserDataBloc>(),
            buildWhen: (prev, curr) =>
            prev.reqState != curr.reqState ||
                prev.userEntity != curr.userEntity,
            builder: (context, state) {
              return RefreshIndicatorWidget(
                onRefresh: () async {
                  di<FetchUserDataBloc>().add(
                    const FetchMyDataEvent(isLoading: false),
                  );
                  di<GetSettingBloc>().add(const GetSettingsEvent());
                  di<MyStoreBloc>().add(const GetMyStoreEvent());
                },
                // Was a Stack with a ShowSVGA(AssetsManager.bgMine, height:
                // 400.h, ...) painted behind the content — that SVGA is its
                // own separate background artwork/animation, sitting on top
                // of (and hiding) the shared BackgroundImgWidget gradient
                // above, which is exactly why this page's top region looked
                // different from Home's (Home paints nothing here — it lets
                // that one shared gradient fade show through untouched).
                // Dropped so both themes now share the exact same visual:
                // just the Home-matching gradient behind plain content.
                child: body(state),
              );
            },
          ),
        ),
      ),
    );
  }

  HandlingDataWidget body(FetchUserDataState state) => HandlingDataWidget(
    reqState: state.reqState,
    title: "",
    subTitle: "",
    onTap: () => di<FetchUserDataBloc>()
        .add(const FetchMyDataEvent(isLoading: false)),
    child: ConstantsManager.isTheme1 == true
        ? _NewProfileBody(data: state.userEntity ?? const MyDataEntity())
        : SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: _ProfileBody(
          data: state.userEntity ?? const MyDataEntity()),
    ),
  );
}

class _NewProfileBody extends StatelessWidget {
  const _NewProfileBody({required this.data});
  final MyDataEntity data;

  // Grid order per request: Wallet, Store(Mall), VIP, Agency, Invite,
  // Badge, Coin Seller, Manager. Invitation is filtered by `showInvite` in
  // _FirstCardOnNewProfile by TITLE (not position) so it can sit anywhere
  // in this list.
  List<IconModel> getFirstIcons() {
    final List<IconModel> icons = [
      IconModel(
        icon: AssetsManager.theme1ProfileWallet,
        title: StringManager.wallet,
        onTap: () {
          navKey.currentContext?.pushNamedRoute(Routes.coinsPage);
        },
      ),
      IconModel(
        icon: AssetsManager.theme1ProfileMall,
        title: StringManager.mall,
        onTap: () {
          navKey.currentContext?.pushNamedRoute(Routes.mallScreen);
        },
      ),
      IconModel(
        icon: AssetsManager.theme1ProfileVip,
        title: StringManager.vip,
        onTap: () {
          navKey.currentContext?.pushNamedRoute(Routes.vipScreen);
        },
      ),
    ];

    if (ConstantsManager.isHostAgencyVisible == true) {
      icons.add(
        IconModel(
          icon: AssetsManager.theme1ProfileAgency,
          title: StringManager.agency1,
          onTap: () {
            if (StringManager.userType[2]! || StringManager.userType[1]!) {
              navKey.currentContext?.pushNamedRoute(Routes.newAgencyScreen);
            } else {
              navKey.currentContext?.pushNamedRoute(
                Routes.searchForAgencyScreen,
              );
            }
          },
        ),
      );
    }

    icons.add(
      IconModel(
        icon: AssetsManager.theme1ProfileInvite,
        title: StringManager.invitation,
        onTap: () {
          navKey.currentContext?.pushNamedRoute(Routes.inviteScreen);
        },
      ),
    );

    // CP (couple) — matches the default theme's grid, which has CP here
    // instead of Badge. Badge moved into the list below, per request.
    icons.add(
      IconModel(
        icon: 'assets/icons/coupleICon.png',
        title: StringManager.cP,
        onTap: () {
          navKey.currentContext?.pushNamedRoute(Routes.cpPage);
        },
      ),
    );

    // Coin Seller (Reseller) dashboard -- only shown to an account the
    // backend flags as a seller, same condition the default theme's
    // ThirdCardBody uses (StringManager.userType[7]).
    if (StringManager.userType[7] == true) {
      icons.add(
        IconModel(
          icon: 'assets/icons/coinSeller.png',
          title: StringManager.coinSeller,
          onTap: () {
            navKey.currentContext
                ?.pushNamedRoute(Routes.coinSellerScreen);
          },
        ),
      );
    }

    if (StringManager.userType[5] == true) {
      icons.add(
        IconModel(
          icon: 'assets/icons/manager.png',
          title: 'Manager',
          onTap: () {
            final context = navKey.currentContext;
            if (context == null) return;
            final userId = MyDataModel.getInstance().id;
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => DashboardWebViewScreen(
                  url:
                  'https://hello.im143.com/manager_dashboard/${userId ?? ''}',
                  title: 'Manager Dashboard',
                ),
              ),
            );
          },
        ),
      );
    }

    // Super Admin -- promoted into the icon grid right after Manager
    // (was a plain list row down in _secondListRows), on request.
    if (StringManager.userType[8] == true) {
      icons.add(
        IconModel(
          icon: 'assets/icons/super.png',
          title: 'Super Admin',
          onTap: () {
            final context = navKey.currentContext;
            if (context == null) return;
            final userId = MyDataModel.getInstance().id;
            final url =
                'https://hello.im143.com/super_admin_dashboard/${userId ?? ''}';
            Methods.printLog('🔗 [Super Admin Dashboard] link ===> $url');
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => DashboardWebViewScreen(
                  url: url,
                  title: 'Super Admin Dashboard',
                ),
              ),
            );
          },
        ),
      );
    }

    return icons;
  }

  // Everything else -- plain full-width rows below the grid card, matching
  // the reference layout (icon + label + chevron, one row per item).
  List<Widget> _secondListRows(BuildContext context) {
    return [
      // Badge moved here, above Check in, per request -- CP now takes its
      // spot in the grid above instead.
      ListTileBody(
        image: AssetsManager.theme1ProfileBadge,
        title: StringManager.badge.tr(),
        onTap: () {
          navKey.currentContext?.pushNamedRoute(Routes.medalsScreen);
        },
      ),
      ListTileBody(
        image: AssetsManager.theme1ProfileCheckIn,
        title: StringManager.checkIn.tr(),
        onTap: () {
          if (di<DailyPrizesBloc>().state.requestStateGetPrize.isLoaded) {
            showDialog(
              context: context,
              builder: (_) => const Dialog(
                backgroundColor: ColorManager.transparent,
                insetPadding: EdgeInsets.symmetric(
                  horizontal: 20.0,
                  vertical: 0,
                ),
                child: DailyPrizeDialog(isNeedCompleteInfoDialog: false),
              ),
            );
          } else {
            di<DailyPrizesBloc>().add(GetDailyPrizesEvent(context: context));
            Methods.safeShowToast(message: StringManager.noGift.tr());
          }
        },
      ),
      ListTileBody(
        image: AssetsManager.theme1ProfileFamily,
        title: StringManager.family.tr(),
        onTap: () {
          navKey.currentContext?.pushNamedRoute(Routes.familyRankPage);
        },
      ),
      if (StringManager.userType[3]! || StringManager.userType[6]!)
        ListTileBody(
          image: AssetsManager.icMeAgency,
          title: StringManager.chargeAgency.tr(),
          onTap: () {
            navKey.currentContext?.pushNamedRoute(Routes.chargeAgencyScreen);
          },
        ),
      ListTileBody(
        image: AssetsManager.theme1ProfileLevel,
        title: StringManager.myLevel.tr(),
        onTap: () {
          navKey.currentContext?.pushNamedRoute(Routes.levelScreen);
        },
      ),
      // Role-based external dashboards -- same role flags and target URLs
      // as the default theme's ThirdCardBody, only shown to accounts the
      // backend actually flags with that role.
      if (StringManager.userType[4] == true)
        ListTileBody(
          image: 'assets/icons/bd.png',
          title: 'BD',
          onTap: () {
            final userId = MyDataModel.getInstance().id;
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => DashboardWebViewScreen(
                  url:
                  'https://hello.im143.com/bd_dashboard/${userId ?? ''}',
                  title: 'BD Dashboard',
                ),
              ),
            );
          },
        ),
      if (StringManager.userType[6] == true)
        ListTileBody(
          image: AssetsManager.admins,
          title: 'Admin',
          onTap: () {
            final userId = MyDataModel.getInstance().id;
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => DashboardWebViewScreen(
                  url:
                  'https://hello.im143.com/bd_admin_dashboard/${userId ?? ''}',
                  title: 'Admin Dashboard',
                ),
              ),
            );
          },
        ),
      ListTileBody(
        image: AssetsManager.icMeBlack,
        title: StringManager.blockList.tr(),
        onTap: () {
          navKey.currentContext?.pushNamedRoute(Routes.blockListScreen);
        },
      ),
      ListTileBody(
        image: AssetsManager.icMeFeedback,
        title: StringManager.feedBack.tr(),
        onTap: () {
          navKey.currentContext?.pushNamedRoute(Routes.problemReportsScreen);
        },
      ),
      ListTileBody(
        image: AssetsManager.icMeSettings,
        title: StringManager.settings.tr(),
        onTap: () {
          navKey.currentContext?.pushNamedRoute(Routes.settingsScreen);
        },
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final user = MyDataModel.getInstance().convertMyDataEntityToUserEntity(
      data,
    );
    final secondRows = _secondListRows(context);
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Default-theme header layout, per request: avatar on the left,
          // name / uid / gender+flag / badges stacked on the right, with a
          // separate Edit control top-right — reuses MineHeader (already
          // built to match the reference app's Mine screen) instead of the
          // old centered avatar/name/id stack.
          //
          // This page runs with SafeArea(top: false) for theme1 (see
          // ProfilePage.build), so nothing here gets the status bar inset
          // for free — the header (and the Edit button on top of it) must
          // add MediaQuery's own top padding or they render under the
          // status bar/notch.
          SizedBox(height: MediaQuery.paddingOf(context).top + 12.h),
          Stack(
            children: [
              MineHeader(
                key: const ValueKey("mine_header_new_theme"),
                user: user,
                level: data.level,
                frame: data.frame ?? '',
              ),
              PositionedDirectional(
                top: 4.h,
                end: 14.w,
                child: InkWell(
                  onTap: () =>
                      navKey.currentContext?.pushNamedRoute(Routes.editProfile),
                  borderRadius: 20.radius,
                  child: Container(
                    padding: context.paddingAll(6),
                    decoration: BoxDecoration(
                      color: ColorManager.white.withValues(alpha: 0.6),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.edit,
                      size: 18.r,
                      color: ColorManager.momentPostTextColor,
                    ),
                  ),
                ),
              ),
            ],
          ),
          10.hBox,
          FFLFBody(
            isMyProfile: true,
            data: user,
            textColor: ColorManager.momentPostTextColor,
          ),
          20.hBox,
          _FirstCardOnNewProfile(firstIcons: getFirstIcons()),
          6.hBox,
          // Plain full-width list rows below the grid card, per request --
          // reuses the same ListTileBody the default theme's ThirdCardBody
          // uses for its own row list.
          Container(
            margin: context.paddingSymmetric(horizontal: 4),
            padding: context.paddingSymmetric(vertical: 10),
            decoration: BoxDecoration(
              color: ColorManager.white,
              borderRadius: 15.radius,
            ),
            child: Column(
              children: [
                for (final row in secondRows) ...[
                  Padding(
                    padding: context.paddingSymmetric(vertical: 8),
                    child: row,
                  ),
                ],
              ],
            ),
          ),
          10.hBox,
        ],
      ),
    );
  }
}

class _FirstCardOnNewProfile extends StatelessWidget {
  const _FirstCardOnNewProfile({required List<IconModel> firstIcons})
      : _firstIcons = firstIcons;

  final List<IconModel> _firstIcons;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Directionality(
          textDirection: TextDirection.ltr,
          child: Container(
            height: 55.h,
            width: ScreenUtil().screenWidth,
            margin: context.paddingSymmetric(horizontal: 8),
            clipBehavior: Clip.none,
            decoration: BoxDecoration(
              color: ColorManager.surfaceCardColor,
              borderRadius: BorderRadius.only(
                topLeft: 15.radiusCircular,
                topRight: 15.radiusCircular,
              ),
              image: DecorationImage(
                fit: BoxFit.fitWidth,
                image: AssetImage(AssetsManager.bgMineWallet1),
              ),
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  top: -20.h,
                  left: 10.w,
                  child: ImageWidget(
                    height: 110.h,
                    width: 110.w,
                    boxFit: BoxFit.cover,
                    image: AssetsManager.bgMineWallet2,
                  ),
                ),
                Positioned.fill(
                  left: ScreenUtil().screenWidth / 3.0,
                  right: 15.w,
                  child: Row(
                    children: [
                      TextWidget(
                        StringManager.myWallet,
                        style: context.bodyMedium
                            .colorExt(ColorManager.onDark)
                            .w600,
                        padding: context.paddingOnly(top: 10),
                      ),
                      const Spacer(),
                      Expanded(
                        child: ButtonWidget(
                          onPressed: () =>
                              context.pushNamedRoute(Routes.coinsPage),
                          title: StringManager.check,
                          height: 35,
                          fontSize: 13,
                          isFittedBox: false,
                          titleColor: ColorManager.orange,
                          backgroundColor: ColorManager.white,
                          paddingButton: context.paddingZero(),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        Container(
          width: ScreenUtil().screenWidth,
          margin: context.paddingSymmetric(horizontal: 8),
          padding: context.paddingSymmetric(horizontal: 10, vertical: 20),
          // Fixed white (was cardDecoration()'s panel-driven card gradient).
          decoration: BoxDecoration(
            color: ColorManager.white,
            borderRadius: BorderRadius.only(
              bottomLeft: 15.radiusCircular,
              bottomRight: 15.radiusCircular,
            ),
          ),
          child: BlocBuilder<FetchUserDataBloc, FetchUserDataState>(
            bloc: di<FetchUserDataBloc>(),
            buildWhen: (prev, curr) =>
            prev.userEntity?.showInvitationCode !=
                curr.userEntity?.showInvitationCode,
            builder: (context, state) {
              final showInvite = state.userEntity?.showInvitationCode == true;

              // Filter by identity (title), not position, now that
              // Invitation can sit anywhere in the grid order.
              final icons = _firstIcons.where((icon) {
                if (icon.title == StringManager.invitation) return showInvite;
                return true;
              }).toList();
              // Fixed 4-column grid (was Wrap + WrapAlignment.spaceBetween).
              // spaceBetween stretches gaps to fill the FULL row width, so a
              // partial last row (e.g. just Invite + CP) put one icon at the
              // far left and the other at the far right instead of sitting
              // together -- GridView always lines every icon up into the
              // same 4 columns, so a partial row just leaves trailing empty
              // cells on the right instead of spreading its icons apart.
              return GridView.builder(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  crossAxisSpacing: 15.w,
                  mainAxisSpacing: 25.h,
                  childAspectRatio: 65.w / 70.h,
                ),
                itemCount: icons.length,
                itemBuilder: (context, index) {
                  return InkWell(
                    onTap: icons[index].onTap,
                    child: Column(
                        children: [
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              ImageWidget(
                                height: 40.h,
                                width: icons[index].title ==
                                    StringManager.invitation
                                    ? 35.w
                                    : 40.w,
                                image: icons[index].icon,
                              ),
                              if (icons[index].title.toLowerCase() == "vip")
                                if (MyDataModel.getInstance().vip1?.id == null)
                                  Positioned(
                                    left: 30.w,
                                    child: Container(
                                      padding: context.paddingSymmetric(
                                        horizontal: 5.5,
                                        vertical: 2.5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: ColorManager.bColor,
                                        borderRadius: 30.radius,
                                      ),
                                      child: TextWidget(
                                        StringManager.become,
                                        // Fixed white — this badge sits on a
                                        // solid red (bColor) chip, not the
                                        // page background.
                                        style: context.bodyMedium
                                            .colorExt(ColorManager.white)
                                            .size(10),
                                      ),
                                    ),
                                  ),
                            ],
                          ),
                          5.hBox,
                          FittedBox(
                            child: TextWidget(
                              icons[index].title,
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: context.bodyMedium.size(12).colorExt(
                                ColorManager.momentPostTextColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class IconModel extends Equatable {
  final String icon, title;
  final VoidCallback onTap;

  const IconModel({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  List<Object?> get props => [icon, title, onTap];
}