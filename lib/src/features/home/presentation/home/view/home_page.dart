import 'dart:async';
import 'dart:io';
import 'package:shimmer/shimmer.dart';
import 'package:general/src/features/home/presentation/home/view/widgets/CountryFilterPage.dart';
import 'package:general/src/core/widgets/md_indicator.dart';
import 'package:general/src/core/widgets/on_multiable_tab.dart';
import 'package:general/src/features/auth/auth.dart';
import 'package:general/src/features/games/games.dart';
import 'package:general/src/features/games/presentation/games/view/widgets/country_widget.dart';
import 'package:general/src/features/games/presentation/games/view/widgets/games_grid_widget.dart';
import 'package:general/src/features/games/presentation/ranking/rank_screen.dart';
import 'package:general/src/features/home/home.dart';
import 'package:general/src/features/home/presentation/home/bloc/fetch_my_room_data_manager/fetch_my_room_data_bloc.dart';
import 'package:general/src/features/home/presentation/home/bloc/fetch_my_room_data_manager/fetch_my_room_data_state.dart';
import 'package:general/src/features/home/presentation/home/bloc/fetch_my_room_data_manager/fetch_my_room_data_event.dart';
import 'package:general/src/features/home/presentation/home/bloc/fetch_top_ranking_manager/fetch_top_ranking_bloc.dart';
import 'package:general/src/features/home/presentation/home/bloc/get_carousel_manager/get_carousel_bloc.dart';
import 'package:general/src/features/home/presentation/home/view/widgets/carousel_widget.dart';
import 'package:general/src/features/home/presentation/home/view/widgets/new_room_card_widget.dart';
import 'package:general/src/features/room/room.dart';
// LIVE TAB HIDDEN on the default Home UI. Keep this import commented for easy restore.
// import 'package:general/src/features/theme2_app/home/presentation/view/widgets/theme2_lives_body.dart';
import 'components/my_room_card.dart';
// The star-ranking carousel is no longer built into the home body; the header
// button opens Routes.rankScreen instead. The widget file is kept in case the
// strip is ever wanted back.
// import 'components/s_r_r_carousel_widget.dart';
import 'widgets/home_banner_metrics.dart';
// The live/video strip is not on the home feed for now — one banner after the
// fourth party row was enough. The widget stays for when it is wanted back.
// import 'widgets/home_live_strip.dart';
import 'widgets/home_ranking_cards_row.dart';
import 'components/top_three_room_body.dart';
import 'components/room_card_body.dart';

part 'components/all_view_body.dart';
part 'components/countries_body.dart';
part 'components/discover_view_body.dart';
part 'components/me_view_body.dart';
part 'components/tab_bar_body.dart';

int currentIndex = 0;

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  static bool isFirstTime = true;
  static bool isConnectToInternet = true;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  late final TabController _controller;
  final _bloc = di<HomeBloc>();

  int _calculateTabLength() {
    final bool showAudio = ConstantsManager.isAudioRoomsEnabled;

    // LIVE tab is intentionally hidden on the default Home UI.
    // Keep the controller length aligned with the visible tabs:
    // audio on  -> Me, Popular, Discover (3)
    // audio off -> Discover (1)
    return showAudio ? 3 : 1;
  }

  int _calculateInitialIndex() {
    final bool showAudio = ConstantsManager.isAudioRoomsEnabled;

    // LIVE default-start logic is kept disabled while the Live tab is hidden.
    //
    // if (ConstantsManager.homeScreen == 'live' &&
    //     ConstantsManager.isShowLive) {
    //   return showAudio ? 3 : 1;
    // }

    if (!showAudio) {
      return 0;
    }

    return 1; // Popular default
  }

  /// Live is the LAST tab: Me,Popular,Discover,Live when audio rooms are on,
  /// Discover,Live when they are off. Kept next to
  /// [_calculateInitialIndex], which encodes the same ordering.
  int get _liveTabIndex => ConstantsManager.isAudioRoomsEnabled ? 3 : 1;

  bool _livesRequested = false;

  void _fetchLivesOnFirstOpen() {
    if (_livesRequested || _controller.indexIsChanging) return;
    if (_controller.index != _liveTabIndex) return;

    _livesRequested = true;
    _bloc.add(const FetchLiveRoomsEvent(isFirstPage: true));
  }

  @override
  void initState() {
    super.initState();

    _controller = TabController(
      initialIndex: _calculateInitialIndex(),
      length: _calculateTabLength(),
      vsync: this,
    );

    // Performance fix: removed ChangeCurrentIndexEvent from tab listener
    // to avoid emitting new HomeBloc state on every animation frame during swipe.

    // The Live tab fetches LAZILY — on first open, not at startup. The home
    // screen already fires ~18 requests while booting; adding a nineteenth for
    // a tab most sessions never touch would make the cold start worse for
    // everyone. `indexIsChanging` filters the intermediate frames of a swipe so
    // this fires once per arrival, not once per animation tick.
    if (ConstantsManager.isShowLive) {
      _controller.addListener(_fetchLivesOnFirstOpen);
      if (_controller.index == _liveTabIndex) _fetchLivesOnFirstOpen();
    }

    // Phase 1: Critical above-the-fold data
    if (!_bloc.state.reqStatePopular.isLoaded &&
        ConstantsManager.isAudioRoomsEnabled) {
      _bloc.add(const FetchPopularRoomsEvent(isPopularLoading: true));
    }

    if (!di<GetCarouselBloc>().state.reqStateHomeTop.isLoaded) {
      di<GetCarouselBloc>().add(const GetHomeTopCarouselEvent());
    }

    if (ConstantsManager.isAudioRoomsEnabled) {
      _bloc.add(const PopularAddListenerEvent());
    }

    // Phase 2: Secondary data (after first frame renders)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!di<FetchMyRoomDataBloc>().state.requestState.isLoaded) {
        di<FetchMyRoomDataBloc>().add(const FetchMyRoomDataEvent());
      }

      if (!di<CountriesBloc>().state.categoriesRequestState.isLoaded) {
        di<CountriesBloc>().add(const FetchCountryCategoriesEvent());
      }

      if (!di<DailyPrizesBloc>().state.requestStateGetPrize.isLoaded) {
        di<DailyPrizesBloc>().add(GetDailyPrizesEvent(context: context));
      }

      // Phase 3: Low-priority data (delayed)
      Future.delayed(const Duration(milliseconds: 500), () {
        if (!di<GetCarouselBloc>().state.reqStateHomeMiddle.isLoaded) {
          di<GetCarouselBloc>().add(const GetHomeMiddleCarouselEvent());
        }

        if (!di<FetchTopUserImageBloc>().state.requestState.isLoaded) {
          di<FetchTopUserImageBloc>().add(const FetchTopUserImageEvent());
        }
      });
    });
  }

  @override
  void dispose() {
    if (ConstantsManager.isAudioRoomsEnabled) {
      _bloc.add(const PopularRemoveListenerEvent());
    }

    if (ConstantsManager.isShowLive) {
      _controller.removeListener(_fetchLivesOnFirstOpen);
    }

    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // The games shortcut used to float over the room list here. Removed at
      // the owner's request: the home feed is for finding rooms, and a raised
      // circular button in that corner competed with the go-live control in the
      // bottom bar. Games are still reachable from their own route
      // (Routes.gamesPage) and from inside a room.
      body: BackgroundImgWidget(
        // Fixed purple-fading-to-light gradient, requested explicitly for
        // the Home page only — every other screen using BackgroundImgWidget
        // keeps its existing look untouched.
        backgroundGradient: ColorManager.homeBackgroundGradient,
        child: ConstantsManager.isTheme1
            ? _NewUIBody(bloc: _bloc)
            : _DefaultUIBody(
          controller: _controller,
          bloc: _bloc,
        ),
      ),
    );
  }
}

class _DefaultUIBody extends StatelessWidget {
  const _DefaultUIBody({
    required TabController controller,
    required HomeBloc bloc,
  })  : _controller = controller,
        _bloc = bloc;

  final TabController _controller;
  final HomeBloc _bloc;

  int _calculateTabLength() {
    final bool showAudio = ConstantsManager.isAudioRoomsEnabled;

    // LIVE tab is hidden in the default Home UI.
    return showAudio ? 3 : 1;
  }

  @override
  Widget build(BuildContext context) {
    final bool showAudio = ConstantsManager.isAudioRoomsEnabled;

    return DefaultTabController(
      length: _calculateTabLength(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          27.5.hBox,
          _TabBarBody(controller: _controller),
          Expanded(
            child: TabBarView(
              controller: _controller,
              children: [
                // ME TAB
                if (showAudio)
                  _MeViewBody(
                    bloc: _bloc,
                    controller: _controller,
                  ),

                // POPULAR TAB
                if (showAudio)
                  _AllViewBody(
                    bloc: _bloc,
                  ),

                // DISCOVER TAB (always visible) — now precedes Live to match
                // the swapped tab labels.
                _DiscoverViewBody(
                  bloc: _bloc,
                ),

                // LIVE TAB HIDDEN FOR DEFAULT HOME.
                // Original body kept commented for easy restore later.
                /*
                if (ConstantsManager.isShowLive)
                  Theme2LivesBody(bloc: _bloc),
                */
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NewUIBody extends StatefulWidget {
  final HomeBloc bloc;
  const _NewUIBody({required this.bloc});

  @override
  State<_NewUIBody> createState() => _NewUIBodyState();
}

class _NewUIBodyState extends State<_NewUIBody> with TickerProviderStateMixin {
  late final TabController parentTabController;
  late final TabController stickyTabController;

  @override
  void initState() {
    super.initState();
    parentTabController = TabController(
      length: ConstantsManager.isAudioRoomsEnabled ? 4 : 1, // ← changed
      vsync: this,
      initialIndex: ConstantsManager.isAudioRoomsEnabled ? 1 : 0, // ← changed
    );
    stickyTabController = TabController(
      length: ConstantsManager.isShowLive ? 4 : 3,
      vsync: this,
      initialIndex:
      ConstantsManager.homeScreen == 'live' && ConstantsManager.isShowLive
          ? 1
          : 0,
    );

    parentTabController.addListener(_addListener);
  }

  void _addListener() {
    if (parentTabController.index == 0) {
      if (!widget.bloc.state.reqStateFollow.isLoaded) {
        widget.bloc.add(const FetchFollowRoomsEvent());
        widget.bloc.add(const FollowAddListenerEvent());
      }
    } else if (parentTabController.index == 2) {
      if (!widget.bloc.state.reqStateFilter.isLoaded) {
        di<CountriesBloc>()
            .add(const SelectedCountryEvent(isNullCountry: true));
        di<HomeBloc>().add(
          FilterPopularRoomsEvent(
            countryId: MyDataModel.getInstance().country?.id,
          ),
        );
        di<GetCarouselBloc>().add(
          GetCountryCarouselEvent(
            isLoading: true,
            countryId: '${MyDataModel.getInstance().country?.id}',
          ),
        );
        widget.bloc.add(const FilterAddListenerEvent());
      }
    }
  }

  @override
  void dispose() {
    parentTabController.removeListener(_addListener);
    parentTabController.dispose();
    stickyTabController.dispose();
    widget.bloc.add(const FollowRemoveListenerEvent());
    widget.bloc.add(const FilterRemoveListenerEvent());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColorManager.transparent,
      body: Padding(
        padding: context.paddingOnly(
          top: 30.h,
        ),
        child: Column(
          children: [
            _NewTabBarBody(
              controller: parentTabController,
              stickyTabController: stickyTabController,
            ),
            Expanded(
              child: BlocBuilder<HomeBloc, HomeState>(
                bloc: widget.bloc,
                buildWhen: (previous, current) =>
                previous.follow != current.follow ||
                    previous.reqStateFollow != current.reqStateFollow ||
                    previous.isPaginatingFollow != current.isPaginatingFollow ||
                    previous.filteredRooms != current.filteredRooms ||
                    previous.reqStateFilter != current.reqStateFilter ||
                    previous.isPaginatingFilter != current.isPaginatingFilter,
                builder: (context, homeState) {
                  return TabBarView(
                    controller: parentTabController,
                    clipBehavior: Clip.none,
                    // Tab switch only on tapping the tab itself, not on
                    // swiping the page body, per request.
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      if (ConstantsManager.isAudioRoomsEnabled) ...[
                        // FOLLOW SECTION
                        RefreshIndicatorWidget(
                          onRefresh: () async {
                            widget.bloc.add(
                              const FetchFollowRoomsEvent(
                                  isFollowLoading: false, isFirstPage: true),
                            );
                            di<GetCarouselBloc>().add(
                              const GetHomeMiddleCarouselEvent(
                                  isLoading: false),
                            );
                          },
                          child: Padding(
                            padding: context.paddingOnly(top: 5),
                            child: _RoomsWithCarouselGrid(
                              rooms: homeState.follow,
                              reqState: homeState.reqStateFollow,
                              controller: homeState.followScrollCtrl,
                              scrollable: true,
                              isPaginating: homeState.isPaginatingFollow,
                              onTap: () {
                                widget.bloc.add(
                                  const FetchFollowRoomsEvent(
                                      isFollowLoading: false,
                                      isFirstPage: true),
                                );
                                di<GetCarouselBloc>().add(
                                  const GetHomeMiddleCarouselEvent(
                                      isLoading: false),
                                );
                              },
                            ),
                          ),
                        ),
                        // POPULAR SECTION
                        _PopularBody(
                          parentTabController: parentTabController,
                          stickyTabController: stickyTabController,
                          bloc: widget.bloc,
                        ),
                        // COUNTRY SECTION
                        RefreshIndicatorWidget(
                          onRefresh: () async {
                            final id =
                            di<CountriesBloc>().state.countryEntity == null
                                ? MyDataModel.getInstance().country?.id
                                : di<CountriesBloc>()
                                .state
                                .countryEntity
                                ?.id;
                            di<HomeBloc>().add(FilterPopularRoomsEvent(
                                isLoading: false,
                                countryId: id,
                                isFirstPage: true));
                            di<GetCarouselBloc>().add(GetCountryCarouselEvent(
                                isLoading: false, countryId: '$id'));
                          },
                          child: Padding(
                            padding: context.paddingOnly(top: 5),
                            child: _RoomsWithCarouselGrid(
                              rooms: homeState.filteredRooms,
                              reqState: homeState.reqStateFilter,
                              controller: homeState.filterScrollCtrl,
                              scrollable: true,
                              type: "country",
                              isPaginating: homeState.isPaginatingFilter,
                              onTap: () {
                                final id =
                                di<CountriesBloc>().state.countryEntity ==
                                    null
                                    ? MyDataModel.getInstance().country?.id
                                    : di<CountriesBloc>()
                                    .state
                                    .countryEntity
                                    ?.id;
                                di<HomeBloc>().add(FilterPopularRoomsEvent(
                                    isLoading: false,
                                    countryId: id,
                                    isFirstPage: true));
                                di<GetCarouselBloc>().add(
                                    GetCountryCarouselEvent(
                                        isLoading: false, countryId: '$id'));
                              },
                            ),
                          ),
                        ),
                      ],

                      // DISCOVER TAB (always visible)
                      _DiscoverViewBody(
                        bloc: widget.bloc,
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PopularBody extends StatelessWidget {
  final HomeBloc bloc;
  final TabController parentTabController, stickyTabController;
  const _PopularBody({
    required this.bloc,
    required this.parentTabController,
    required this.stickyTabController,
  });

  /// Selected country in the country row; null means Popular (no filter).
  static int? get _selectedCountryId =>
      di<CountriesBloc>().state.countryEntity?.id;

  void _handlePagination() {
    final state = bloc.state;
    // The country row replaced the Recommend/Stream/Friends sub-tabs.
    final countryId = _selectedCountryId;
    if (countryId != null) {
      if (state.filterLastPage > state.filterCurrentPage) {
        bloc.add(FilterPopularRoomsEvent(isLoading: false, countryId: countryId));
      }
      return;
    }
    final index = stickyTabController.index;
    final friendsIndex = ConstantsManager.isShowLive ? 2 : 1;
    final multiPkIndex = ConstantsManager.isShowLive ? 3 : 2;

    if (index == 0 || index == multiPkIndex) {
      if (state.popularLastPage > state.popularCurrentPage) {
        bloc.add(const FetchPopularRoomsEvent(isPopularLoading: false));
      }
    } else if (ConstantsManager.isShowLive && index == 1) {
      if (state.streamLastPage > state.liveCurrentPage) {
        bloc.add(const FetchLiveRoomsEvent(isLiveLoading: false));
      }
    } else if (index == friendsIndex) {
      if (state.friendsLastPage > state.friendsCurrentPage) {
        bloc.add(const FetchFriendsRoomsEvent(isFriendsLoading: false));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    bool didSwitchParentTab = false;

    return NotificationListener<ScrollNotification>(
      onNotification: (ScrollNotification notification) {
        // Detect RTL or LTR. maybeOf (not of) — context can be detached
        // mid-scroll, and Directionality.of throws a null-check crash then.
        final bool isRTL =
            Directionality.maybeOf(context) == TextDirection.rtl;

        if (notification is OverscrollNotification &&
            notification.dragDetails != null &&
            !didSwitchParentTab) {
          // Read dx
          double dragDx = notification.dragDetails?.delta.dx ?? 0;

          // Reverse dx when RTL
          if (isRTL) dragDx = -dragDx;

          // Swipe Right → Move to previous parent tab
          if (dragDx > 0 && stickyTabController.index == 0) {
            if (parentTabController.index > 0) {
              parentTabController.animateTo(parentTabController.index - 1);
              didSwitchParentTab = true;
            }
          }
          // Swipe Left → Move to next parent tab
          else if (dragDx < 0 &&
              stickyTabController.index == stickyTabController.length - 1) {
            if (parentTabController.index <
                parentTabController.length - 1) {
              parentTabController.animateTo(parentTabController.index + 1);
              didSwitchParentTab = true;
            }
          }
        }

        // Reset flag when scroll ends
        if (notification is ScrollEndNotification) {
          didSwitchParentTab = false;
        }

        if (notification is ScrollUpdateNotification ||
            notification is ScrollEndNotification) {
          final metrics = notification.metrics;
          if (metrics.pixels >= metrics.maxScrollExtent - 50 &&
              metrics.maxScrollExtent > 0) {
            _handlePagination();
          }
        }

        return true; // Allow notification to continue
      },
      child: RefreshIndicator.adaptive(
        strokeWidth: 2.0,
        color: ColorManager.primary,
        backgroundColor: ColorManager.scaffoldBg,
        notificationPredicate: (notification) {
          return notification.depth == 2;
        },
        onRefresh: () async {
          final index = stickyTabController.index;
          di<FetchTopUserImageBloc>().add(const FetchTopUserImageEvent());
          di<GetCarouselBloc>()
              .add(const GetHomeTopCarouselEvent(isLoading: false));
          final countryId = _selectedCountryId;
          if (countryId != null) {
            bloc.add(FilterPopularRoomsEvent(
                isLoading: false, countryId: countryId, isFirstPage: true));
          } else if (index == 0) {
            Methods.printLog("RECOMMEND");
            bloc.add(const FetchPopularRoomsEvent(
                isPopularLoading: false, isFirstPage: true));
            di<GetCarouselBloc>()
                .add(const GetHomeMiddleCarouselEvent(isLoading: false));
          } else if (ConstantsManager.isShowLive && index == 1) {
            Methods.printLog("STREAM");
            bloc.add(const FetchLiveRoomsEvent(
                isLiveLoading: false, isFirstPage: true));
            di<GetCarouselBloc>()
                .add(const GetLiveCarouselEvent(isLoading: false));
          } else if (index == (ConstantsManager.isShowLive ? 2 : 1)) {
            Methods.printLog("FRIENDS");
            bloc.add(const FetchFriendsRoomsEvent(
                isFriendsLoading: false, isFirstPage: true));
            di<GetCarouselBloc>()
                .add(const GetHomeMiddleCarouselEvent(isLoading: false));
          } else {
            Methods.printLog("MULTI-PK-POPULAR");
            bloc.add(const FetchPopularRoomsEvent(
                isPopularLoading: false, isFirstPage: true));
            di<GetCarouselBloc>()
                .add(const GetHomeMiddleCarouselEvent(isLoading: false));
          }
        },
        child: NestedScrollView(
          key: const ValueKey('nested-scroll-view-key'),
          physics: const AlwaysScrollableScrollPhysics(),
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            // Restored, on request -- the banner next to the tab bar stays;
            // only the one embedded inside the room grid was removed.
            SliverToBoxAdapter(
              child: Padding(
                padding: context.paddingOnly(
                  start: 10,
                  end: 10,
                  top: 8,
                ),
                child: CarouselWidget(
                  type: "event",
                  source: 'homeTop',
                  height: 130.h,
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: context.paddingSymmetric(vertical: 10),
                child: const RankingsWidget(),
              ),
            ),
            SliverPersistentHeader(
              pinned: true,
              delegate: _StickyTabBarDelegate(
                // Country row (user's country, Popular, then the rest) in
                // place of the Recommend/Stream/Friends/Multi-PK pills.
                child: const CountriesBody(),
              ),
            ),
          ],
          body: Column(
            children: [
              Expanded(
                child: BlocBuilder<CountriesBloc, CountriesState>(
                  bloc: di<CountriesBloc>(),
                  buildWhen: (prev, curr) =>
                      prev.countryEntity?.id != curr.countryEntity?.id,
                  builder: (context, countryState) {
                    final countryId = countryState.countryEntity?.id;
                    if (countryId != null) {
                      return BlocBuilder<HomeBloc, HomeState>(
                        bloc: bloc,
                        buildWhen: (prev, curr) =>
                            prev.filteredRooms != curr.filteredRooms ||
                            prev.reqStateFilter != curr.reqStateFilter ||
                            prev.isPaginatingFilter != curr.isPaginatingFilter,
                        builder: (context, state) => _RoomsWithCarouselGrid(
                          key: ValueKey('country-$countryId'),
                          rooms: state.filteredRooms,
                          reqState: state.reqStateFilter,
                          scrollable: true,
                          type: 'country',
                          isPaginating: state.isPaginatingFilter,
                          onTap: () => bloc.add(FilterPopularRoomsEvent(
                              countryId: countryId, isFirstPage: true)),
                        ),
                      );
                    }
                    return _popularRooms();
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Popular rooms — shown when no country is selected in the row.
  Widget _popularRooms() {
    return BlocBuilder<HomeBloc, HomeState>(
      bloc: bloc,
      buildWhen: (prev, curr) =>
          prev.popular != curr.popular ||
          prev.reqStatePopular != curr.reqStatePopular ||
          prev.isPaginatingPopular != curr.isPaginatingPopular,
      builder: (context, state) => _RoomsWithCarouselGrid(
        key: const ValueKey("recommend-key"),
        rooms: state.popular,
        reqState: state.reqStatePopular,
        scrollable: true,
        isPaginating: state.isPaginatingPopular,
        onTap: () {
          bloc.add(const FetchPopularRoomsEvent(isFirstPage: true));
          di<GetCarouselBloc>()
              .add(const GetHomeTopCarouselEvent(isLoading: false));
          di<GetCarouselBloc>()
              .add(const GetHomeMiddleCarouselEvent(isLoading: false));
        },
      ),
    );
  }
}

class _StickyTabBarDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  _StickyTabBarDelegate({required this.child});

  @override
  double get minExtent => 40.h;
  @override
  double get maxExtent => 40.h;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) =>
      SizedBox(
        height: maxExtent,
        child: Container(
          color: ColorManager.transparent,
          child: child,
        ),
      );

  @override
  bool shouldRebuild(covariant _StickyTabBarDelegate oldDelegate) => false;
}

class _NewTabBarBody extends StatefulWidget {
  final TabController controller, stickyTabController;
  const _NewTabBarBody(
      {required this.controller, required this.stickyTabController});

  @override
  State<_NewTabBarBody> createState() => _NewTabBarBodyState();
}

class _NewTabBarBodyState extends State<_NewTabBarBody> {
  // Performance fix: use ValueNotifier instead of setState to avoid
  // rebuilding the entire TabBar on every animation frame during swipe.
  late final ValueNotifier<int> _currentIndex;
  bool isFirstTapDone = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = ValueNotifier(
      ConstantsManager.isAudioRoomsEnabled ? 1 : 0,
    );

    widget.controller.animation?.addListener(_animationListener);
  }

  void _animationListener() {
    final value = widget.controller.animation?.value ?? 0;
    final newIndex = value.round();
    if (newIndex != _currentIndex.value && (value - newIndex).abs() < 0.2) {
      _currentIndex.value = newIndex;
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_animationListener);
    _currentIndex.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: context.paddingSymmetric(vertical: 8),
      child: Row(
      children: [
        10.wBox,
        Expanded(
          child: TabBar(
            controller: widget.controller,
            overlayColor: WidgetStateColor.transparent,
            indicatorSize: TabBarIndicatorSize.label,
            tabAlignment: TabAlignment.start,
            isScrollable: true,
            dividerHeight: 0,
            onTap: (index) {
              _currentIndex.value = index;

              if (index == 2) {
                if (isFirstTapDone == false) {
                  isFirstTapDone = true;
                } else {
                  // Was bottomDailog(CountriesDialog()) — a slide-up panel —
                  // now a real full page (on request).
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const CountryFilterPage(),
                    ),
                  ).whenComplete(() => isFirstTapDone = false);
                }
              }
            },
            indicator: MDIndicator(
              indicatorColor: ColorManager.headerColor,
              indicatorWidth: 17.0.w,
              indicatorHeight: 4.h,
              radius: 20.r,
            ),
            labelPadding: context.paddingOnly(end: 15),
            unselectedLabelStyle: context.bodyLarge.w400
                .colorExt(ColorManager.textPrimary.withValues(alpha: (0.4)))
                .size(16),
            labelStyle: context.bodyLarge.w600
                .colorExt(ColorManager.textPrimary)
                .size(20),
            tabs: [
              if (ConstantsManager.isAudioRoomsEnabled) ...[
                Text(StringManager.follow.tr()),
                Text(StringManager.popular.tr()),
                BlocBuilder<CountriesBloc, CountriesState>(
                  bloc: di<CountriesBloc>(),
                  buildWhen: (prev, curr) =>
                  prev.countryEntity != curr.countryEntity,
                  builder: (context, countryState) {
                    return BlocBuilder<FetchUserDataBloc, FetchUserDataState>(
                      bloc: di<FetchUserDataBloc>(),
                      buildWhen: (prev, curr) => prev.reqState != curr.reqState,
                      builder: (context, state) {
                        if (state.reqState.isLoaded) {
                          return Row(
                            children: [
                              Text(
                                Methods.getLang() == "ar"
                                    ? Methods.safeText(
                                    countryState.countryEntity?.name) ??
                                    Methods.safeText(
                                        MyDataModel.getInstance()
                                            .country
                                            ?.name) ??
                                    StringManager.country_.tr()
                                    : Methods.safeText(countryState
                                    .countryEntity?.nameEn) ??
                                    Methods.safeText(
                                        MyDataModel.getInstance()
                                            .country
                                            ?.nameEn) ??
                                    StringManager.country_.tr(),
                              ),
                              Padding(
                                padding:
                                context.paddingOnly(top: 2.0, start: 3.0),
                                child: ValueListenableBuilder<int>(
                                  valueListenable: _currentIndex,
                                  builder: (context, idx, _) => ImageWidget(
                                    height: 12.5,
                                    width: 12.5,
                                    image: idx == 2
                                        ? AssetsManager
                                        .icHomeMagicIndicatorArrowSelect
                                        : AssetsManager
                                        .icHomeMagicIndicatorArrowNormal,
                                    color: ColorManager.darkPink,
                                  ),
                                ),
                              )
                            ],
                          );
                        }
                        return Text(StringManager.country_.tr());
                      },
                    );
                  },
                ),
              ],
              Text(StringManager.discover.tr()),
            ],
          ),
        ),
        // Matches the default theme's header row: audio (go-live), search,
        // filter — replacing the old rank/game icon + search pair. Plain
        // GestureDetector + Padding (not IconButton) so there's no leftover
        // Material minimum-tap-target padding widening the gap between icons.
        if (ConstantsManager.isAudioRoomsEnabled || ConstantsManager.isShowLive)
          BlocBuilder<FetchMyRoomDataBloc, FetchMyRoomDataState>(
            bloc: di<FetchMyRoomDataBloc>(),
            buildWhen: (prev, curr) => prev.requestState != curr.requestState,
            builder: (context, state) {
              return state.requestState.isLoaded
                  ? GestureDetector(
                      onTap: () => _handleRoomEntry(context, state),
                      child: Padding(
                        padding: context.paddingSymmetric(horizontal: 5),
                        child: ImageWidget(
                          // Same asset as the bottom nav's Home tab, per request.
                          image: AssetsManager.homeIcon,
                          height: 23.5.h,
                          width: 23.5.w,
                          // Single source of truth for the "light black" tint —
                          // change ColorManager.lightBlack and all three icons
                          // below follow, on request.
                          color: ColorManager.lightBlack,
                        ),
                      ),
                    )
                  : const SizedBox.shrink();
            },
          ),
        GestureDetector(
          onTap: () => Navigator.pushNamed(context, Routes.searchScreen),
          child: Padding(
            padding: context.paddingSymmetric(horizontal: 5),
            child: ImageWidget(
              image: AssetsManager.icHomeSearch,
              height: 23.5.h,
              width: 23.5.w,
              color: ColorManager.lightBlack,
            ),
          ),
        ),
        GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CountryFilterPage()),
          ),
          child: Padding(
            padding: context.paddingSymmetric(horizontal: 5),
            child: ImageWidget(
              image: AssetsManager.filterIcon,
              height: 23.5.h,
              width: 23.5.w,
              color: ColorManager.lightBlack,
            ),
          ),
        ),
        8.wBox,
      ],
      ),
    );
  }

  // Theme 1's header icon is an AUDIO-ONLY entry point — no audio/video
  // chooser sheet. Unlike the default theme's camera button (which can offer
  // "Live Video" via GoLiveFlow.showStartDialog when isShowLive is on), this
  // icon always goes straight into the audio room.
  Future<void> _handleRoomEntry(
      BuildContext context, FetchMyRoomDataState state) async {
    if (RoomData.instance.utdController?.minimize.isMinimizing ?? false) {
      final navContext = SafeNavigator.context;
      if (navContext == null) return;
      await di<RoomStateManager>().exitRoom(navContext);
    }

    Methods.handleRoomEntry(context, state.rooms?.audio);
  }
}

class RankingsWidget extends StatelessWidget {
  const RankingsWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FetchTopUserImageBloc, FetchTopRankingState>(
      bloc: di<FetchTopUserImageBloc>(),
      buildWhen: (previous, current) =>
      previous.rankingEntity != current.rankingEntity ||
          previous.requestState != current.requestState,
      builder: (context, state) {
        return Row(
          children: [
            10.wBox,
            // Wealth Rankings Card
            Expanded(
              child: GestureDetector(
                onTap: () {
                  // Theme 2's ranking design (RankScreen), not the
                  // theme1-default OldRankScreen the named route would
                  // otherwise resolve to (see ConstantsManager.isOldRankingUI).
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const RankScreen(initialIndex: 1),
                    ),
                  );
                },
                child: _RankingCardWidget(
                  title: StringManager.wealthRankings,
                  backgroundImage: AssetsManager.icWrBg,
                  crownImages: [
                    AssetsManager.icWrCrown1,
                    AssetsManager.icWrCrown2,
                    AssetsManager.icWrCrown3,
                  ],
                  data: state.rankingEntity?.sender ?? [],
                ),
              ),
            ),
            5.wBox,
            // Charm Rankings Card
            Expanded(
              child: GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const RankScreen(initialIndex: 2),
                    ),
                  );
                },
                child: _RankingCardWidget(
                  title: StringManager.charmRankings,
                  backgroundImage: AssetsManager.icCrBg,
                  crownImages: [
                    AssetsManager.icCrCrown1,
                    AssetsManager.icCrCrown2,
                    AssetsManager.icCrCrown3,
                  ],
                  data: state.rankingEntity?.receiver ?? [],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _RankingCardWidget extends StatelessWidget {
  final String title;
  final String backgroundImage;
  final List<String> crownImages;
  final List<String?> data;

  const _RankingCardWidget({
    required this.title,
    required this.backgroundImage,
    required this.crownImages,
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    final isArabic = Methods.getLang() == "ar";
    return Directionality(
      textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Container(
        height: 65.h,
        width: ScreenUtil().screenWidth,
        decoration: BoxDecoration(
          image: DecorationImage(
            fit: BoxFit.fill,
            image: AssetImage(backgroundImage),
            matchTextDirection: true,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextWidget(
              title,
              textAlign: TextAlign.start,
              padding: context.paddingOnly(start: 12.5, top: 7.5, end: 12.5),
              style: context.bodyMedium.copyWith(
                color: ColorManager.white,
                fontSize: 11.sp,
                fontWeight: FontWeight.w700,
                shadows: [
                  const Shadow(
                    color: Color(0x42000000),
                    offset: Offset(0, 1),
                    blurRadius: 2,
                  ),
                ],
              ),
            ),
            const Spacer(),
            Padding(
              padding: context.paddingOnly(start: 7.5),
              child: SizedBox(
                height: 40.h,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    if (data.length > 1 && data[1]?.isNotEmpty == true)
                      PositionedDirectional(
                        start: 0,
                        bottom: 0,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            ImageViewWidget(
                              url: data[1] ?? "",
                              height: 25.h,
                              width: 25.h,
                              shape: BoxShape.circle,
                            ),
                            ImageWidget(
                              image: crownImages[1],
                              height: 32.5.h,
                              width: 32.5.h,
                              boxFit: BoxFit.contain,
                            ),
                          ],
                        ),
                      ),
                    if (data.length > 2 && data[2]?.isNotEmpty == true)
                      PositionedDirectional(
                        start: 55.w,
                        bottom: 0,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            ImageViewWidget(
                              url: data[2] ?? "",
                              height: 25.h,
                              width: 25.h,
                              shape: BoxShape.circle,
                            ),
                            ImageWidget(
                              image: crownImages[2],
                              height: 32.5.h,
                              width: 32.5.h,
                              boxFit: BoxFit.contain,
                            ),
                          ],
                        ),
                      ),
                    if (data.isNotEmpty && data[0]?.isNotEmpty == true)
                      PositionedDirectional(
                        start: 25.w,
                        bottom: 0,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            ImageViewWidget(
                              url: data[0] ?? "",
                              height: 30.h,
                              width: 30.h,
                              shape: BoxShape.circle,
                            ),
                            ImageWidget(
                              image: crownImages[0],
                              height: 37.5.h,
                              width: 37.5.h,
                              boxFit: BoxFit.scaleDown,
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StickyTabBarBody extends StatefulWidget {
  final TabController controller;

  const _StickyTabBarBody({required this.controller});

  @override
  State<_StickyTabBarBody> createState() => _StickyTabBarBodyState();
}

class _StickyTabBarBodyState extends State<_StickyTabBarBody> {
  final List<String> titles = [
    StringManager.recommend_.tr(),
    if (ConstantsManager.isShowLive) StringManager.stream.tr(),
    StringManager.friends_.tr(),
    StringManager.multiPk.tr(),
  ];

  // Performance fix: use ValueNotifier instead of setState to avoid
  // rebuilding the entire TabBar on every animation frame during swipe.
  late final ValueNotifier<int> _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = ValueNotifier(0);

    widget.controller.animation?.addListener(_animationListener);
    widget.controller.addListener(_addListener);
  }

  void _animationListener() {
    final value = widget.controller.animation?.value ?? 0;
    final newIndex = value.round();
    if (newIndex != _currentIndex.value && (value - newIndex).abs() < 0.2) {
      _currentIndex.value = newIndex;
    }
  }

  void _addListener() {
    final friendsIndex = ConstantsManager.isShowLive ? 2 : 1;
    if (widget.controller.index == friendsIndex) {
      if (!di<HomeBloc>().state.reqStateFriends.isLoaded) {
        di<HomeBloc>().add(const FetchFriendsRoomsEvent());
        di<HomeBloc>().add(const FriendsAddListenerEvent());
      }
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_animationListener);
    widget.controller.removeListener(_addListener);
    _currentIndex.dispose();
    di<HomeBloc>().add(const FriendsRemoveListenerEvent());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: context.paddingOnly(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: TabBar(
              onTap: (value) => _currentIndex.value = value,
              controller: widget.controller,
              overlayColor: WidgetStateColor.transparent,
              indicatorSize: TabBarIndicatorSize.label,
              // Pill style now matches the country filter chips
              // (CountryWidget): brand-gradient pill + shadow when selected,
              // soft translucent-white pill when not.
              indicator: BoxDecoration(
                gradient: ColorManager.brandGradient,
                borderRadius: 18.radius,
              ),
              tabAlignment: TabAlignment.start,
              isScrollable: true,
              dividerHeight: 0,
              indicatorWeight: 0.0,
              padding: context.paddingZero(),
              labelPadding: context.paddingSymmetric(horizontal: 7.5),
              unselectedLabelStyle: context.bodySmall.copyWith(
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
                color: ColorManager.homeHeaderTextColor,
              ),
              labelStyle: context.bodySmall.copyWith(
                fontSize: 12.sp,
                fontWeight: FontWeight.w800,
                color: ColorManager.onBrandGradient,
              ),
              tabs: List.generate(
                titles.length,
                    (index) {
                  // Performance fix: only rebuild the tab that changes
                  return ValueListenableBuilder<int>(
                    valueListenable: _currentIndex,
                    builder: (context, selectedIndex, _) {
                      final isSelected = selectedIndex == index;
                      return Container(
                        height: 34.h,
                        padding: context.paddingSymmetric(horizontal: 14),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          borderRadius: 18.radius,
                          gradient: isSelected ? ColorManager.brandGradient : null,
                          color: isSelected
                              ? null
                              : ColorManager.white.withValues(alpha: 0.78),
                          border: Border.all(
                            color: isSelected
                                ? ColorManager.white.withValues(alpha: 0.72)
                                : ColorManager.white.withValues(alpha: 0.92),
                            width: 1.0,
                          ),
                          boxShadow: isSelected
                              ? [
                            BoxShadow(
                              color: ColorManager.brandGradientColors.first
                                  .withValues(alpha: 0.18),
                              blurRadius: 7,
                              offset: const Offset(0, 2),
                            ),
                          ]
                              : null,
                        ),
                        child: Text(
                          titles[index],
                          style: context.bodySmall.copyWith(
                            fontSize: 12.sp,
                            fontWeight:
                            isSelected ? FontWeight.w800 : FontWeight.w600,
                            color: isSelected
                                ? ColorManager.onBrandGradient
                                : ColorManager.homeHeaderTextColor,
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
          5.wBox,
        ],
      ),
    );
  }
}

class _RoomsWithCarouselGrid extends StatelessWidget {
  final List<RoomEntity> rooms;
  final RequestState reqState;
  final VoidCallback onTap;
  final bool scrollable;
  final ScrollController? controller;
  final String? type;
  final bool isPaginating;

  const _RoomsWithCarouselGrid({
    super.key,
    required this.rooms,
    required this.reqState,
    required this.onTap,
    this.scrollable = false,
    this.controller,
    this.type,
    this.isPaginating = false,
  });

  @override
  Widget build(BuildContext context) {
    final count = rooms.length;
    const firstGridCount = 3;
    final firstItemCount = count >= firstGridCount ? firstGridCount : count;
    final secondItemCount = count > firstGridCount ? count - firstGridCount : 0;

    // Use single BlocBuilder wrapping all room cards instead of per-item
    return BlocBuilder<FetchUserDataBloc, FetchUserDataState>(
      bloc: di<FetchUserDataBloc>(),
      buildWhen: (previous, current) => previous.reqState != current.reqState,
      builder: (context, userState) {
        final isLoaded = userState.reqState.isLoaded;

        // Performance fix: Use CustomScrollView with Slivers instead of
        // GridView.builder(shrinkWrap: true) inside SingleChildScrollView.
        // Slivers lazily build only visible children, reducing memory & build time.
        return CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          controller: scrollable ? controller : null,
          slivers: [
            if (scrollable)
              SliverPadding(
                padding: context.paddingOnly(top: 10),
                sliver: const SliverToBoxAdapter(child: SizedBox.shrink()),
              ),

            // Handling data state (loading/error/empty)
            if (reqState.isLoading || reqState.isError || count == 0)
              SliverToBoxAdapter(
                child: Padding(
                  padding: context.paddingSymmetric(horizontal: 10),
                  child: HandlingDataWidget(
                    reqState: reqState,
                    title: StringManager.noRooms.tr(),
                    subTitle: StringManager.noRoomsMsg.tr(),
                    onTap: onTap,
                    childEmpty: const SizedBox(),
                    child: const SizedBox.shrink(),
                  ),
                ),
              ),

            // im party layout: the top room big on the left, the next two
            // stacked on the right, then every other room as a list row.
            if (firstItemCount > 0 && reqState.isLoaded)
              SliverToBoxAdapter(
                child: TopThreeRoomBody(
                  rooms: rooms.take(firstItemCount).toList(),
                ),
              ),

            if (reqState.isLoading) SliverToBoxAdapter(child: 10.hBox),

            if (firstItemCount > 0 && secondItemCount > 0)
              SliverToBoxAdapter(child: 10.hBox),

            if (secondItemCount > 0)
              SliverPadding(
                padding: context.paddingOnly(bottom: 70),
                sliver: SliverList.separated(
                  itemCount: secondItemCount,
                  separatorBuilder: (context, index) => 10.hBox,
                  itemBuilder: (context, index) {
                    final roomIndex = index + firstGridCount;
                    final room = rooms[roomIndex];
                    return RepaintBoundary(
                      key: ValueKey('audio_room_${room.id}'),
                      child: MultiTapCard(
                        onTap: () {
                          if (isLoaded) {
                            di<RoomStateManager>().navigateToRoom(
                              RoomEntryRequest(
                                context: context,
                                roomData: room,
                                isLive: room.streamType == "live",
                              ),
                            );
                          }
                        },
                        child: CardLiveWidget(
                          roomEntity: room,
                          index: roomIndex,
                          forceBlackText: true,
                        ),
                      ),
                    );
                  },
                ),
              ),

            if (isPaginating)
              const SliverToBoxAdapter(
                child: CircleLoadingWidget(),
              ),
          ],
        );
      },
    );
  }
}