part of 'package:general/src/features/home/presentation/home/view/home_page.dart';

class _TabBarBody extends StatelessWidget {
  const _TabBarBody({required this.controller});

  final TabController controller;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Nudged right per owner request — was 5.wBox, sitting almost flush
        // against the screen edge.
        16.wBox,

        Expanded(
          child: TabBar(
            controller: controller,

            overlayColor: WidgetStateColor.transparent,

            indicatorSize: TabBarIndicatorSize.label,

            isScrollable: true,

            tabAlignment: TabAlignment.start,

            dividerHeight: 0,

            // One shared Home-header color token. Change
            // ColorManager.homeHeaderTextColor once and the tab text, indicator,
            // filter, search and audio icons all update together.
            indicator: MDIndicator(
              indicatorColor: ColorManager.homeHeaderTextColor,

              indicatorWidth: 17.0.w,

              indicatorHeight: 4.h,

              radius: 20,
            ),

            labelPadding: context.paddingOnly(end: 10),

            unselectedLabelStyle: context.bodyLarge.w500
                .colorExt(ColorManager.homeHeaderTextColor)
                .size(18),

            labelStyle: context.bodyLarge.w600
                .colorExt(ColorManager.homeHeaderTextColor)
                .size(18),

            tabs: [
              if (ConstantsManager.isAudioRoomsEnabled)
                Text(StringManager.me.tr()),

              if (ConstantsManager.isAudioRoomsEnabled)
                Text(StringManager.popular.tr()),

              // Discover now precedes Live (tabs swapped per owner request).
              Text(StringManager.discover.tr()),

              // LIVE TAB HIDDEN FOR DEFAULT HOME.
              // Kept here commented so it can be restored later without
              // rebuilding the original UI/functionality.
              /*
              if (ConstantsManager.isShowLive)
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Text(StringManager.live.tr()),
                    Positioned(
                      top: -5,
                      right: -10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: ColorManager.primary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          "New",
                          style: context.bodySmall.w600
                              .colorExt(ColorManager.buttonTextColor)
                              .size(8),
                        ),
                      ),
                    ),
                  ],
                ),
              */
            ],
          ),
        ),

        // Country/region filter — sits to the LEFT of the search icon, per
        // the reference design. Reuses the exact same picker
        // (CountryFilterPage) the Popular tab's own country re-tap already
        // opens elsewhere on this page, so there's only ever one
        // country-picker UI in the app, just two ways to reach it. Was a
        // bottomDailog() slide-up panel — now a real full page (on request),
        // pushed the normal way.
        IconButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CountryFilterPage()),
            );
          },

          icon: Image.asset(
            AssetsManager.icWorld,

            height: 22.h,

            width: 22.w,

            color: ColorManager.homeHeaderTextColor,
          ),
        ),

        IconButton(
          onPressed: () {
            Navigator.pushNamed(context, Routes.searchScreen);
          },
          icon: Image.asset(
            AssetsManager.icHomeSearch,
            height: 24.5.h,
            width: 24.5.w,
            color: ColorManager.homeHeaderTextColor,
          ),
        ),

        // Audio Room entry lives in the Home header now. This keeps the bottom
        // navigation dedicated to destinations only: Home, Moment, Games,
        // Inbox and Profile. The existing room-entry flow is reused unchanged.
        if (ConstantsManager.isAudioRoomsEnabled)
          BlocBuilder<FetchMyRoomDataBloc, FetchMyRoomDataState>(
            bloc: di<FetchMyRoomDataBloc>(),
            buildWhen: (prev, curr) =>
            prev.requestState != curr.requestState ||
                prev.rooms != curr.rooms,
            builder: (context, state) {
              if (state.requestState != RequestState.loaded) {
                return const SizedBox.shrink();
              }

              return IconButton(
                tooltip: 'Audio Room',
                onPressed: () async {
                  final utdCtrl = RoomData.instance.utdController;
                  if (utdCtrl != null && utdCtrl.minimize.isMinimizing) {
                    final navContext = SafeNavigator.context;
                    if (navContext == null) return;
                    await di<RoomStateManager>().exitRoom(navContext);
                  }

                  Methods.handleRoomEntry(context, state.rooms?.audio);
                },
                // Plain icon, same visual treatment as Search: no gradient,
                // circle, border or background.
                icon: Image.asset(
                  AssetsManager.homeIcon,
                  height: 24.5.h,
                  width: 24.5.w,
                  color: ColorManager.homeHeaderTextColor,
                ),
              );
            },
          ),
      ],
    );
  }
}