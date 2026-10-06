import 'package:general/src/core/index.dart';
import 'package:general/src/core/widgets/md_indicator.dart';

import 'event_page.dart';
import 'moment_page.dart';

/// Event and Moment behind ONE bottom-bar destination.
///
/// Reels and Following used to be two more tabs here, sharing a single
/// [ReelsScreen] instance behind the IndexedStack -- hidden on request,
/// leaving just `Event | Moment` across the top.
class MomentsHubPage extends StatefulWidget {
  const MomentsHubPage({super.key});

  @override
  State<MomentsHubPage> createState() => _MomentsHubPageState();
}

class _MomentsHubPageState extends State<MomentsHubPage>
    with SingleTickerProviderStateMixin {
  static const int _event = 0;

  late final TabController _controller;

  int _index = _event;

  @override
  void initState() {
    super.initState();
    _controller = TabController(length: 2, vsync: this);
    _controller.addListener(_onTabChanged);
  }

  void _onTabChanged() {
    if (_controller.indexIsChanging) return;
    final next = _controller.index;
    if (next == _index) return;

    setState(() => _index = next);
  }

  @override
  void dispose() {
    _controller.removeListener(_onTabChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Same fixed purple->blue->white band as HomePage
    // (ColorManager.homeBackgroundGradient via BackgroundImgWidget), per
    // owner request that Moment match Home's background. This page had no
    // Scaffold/background of its own before — it just sat on whatever
    // LayoutPage's own Scaffold painted behind it (plain white) — so this
    // wraps the existing Column exactly as HomePage wraps its own body,
    // rather than changing anything else about the page.
    return BackgroundImgWidget(
      backgroundGradient: ColorManager.homeBackgroundGradient,
      child: Column(
        children: [
          SafeArea(
            bottom: false,
            // A little breathing room from the very top edge — owner asked
            // for this main Event/Moment/Reels/Following bar to come down
            // slightly (it sat flush against the top before).
            child: Padding(
              padding: EdgeInsets.only(top: 8.h),
              child: _HubTabBar(controller: _controller),
            ),
          ),
          Expanded(
            // IndexedStack (not TabBarView) so a scrolling Moment feed keeps
            // its scroll position when switching back from Event.
            child: IndexedStack(
              index: _index,
              children: const [
                EventPage(),
                MomentPage(showOwnTabBar: false),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HubTabBar extends StatelessWidget {
  const _HubTabBar({required this.controller});

  final TabController controller;

  @override
  Widget build(BuildContext context) {
    // Leading gap matches the Home tab bar's own 16.wBox — was flush against
    // the screen edge with no gap at all, out of step with Home's bar sitting
    // just to the right of the edge.
    return Row(
      children: [
        16.wBox,
        Expanded(child: _buildTabBar(context)),
      ],
    );
  }

  Widget _buildTabBar(BuildContext context) {
    return TabBar(
      controller: controller,
      isScrollable: true,
      tabAlignment: TabAlignment.start,
      overlayColor: WidgetStateColor.transparent,
      indicatorSize: TabBarIndicatorSize.label,
      // Fixed white here instead of the panel-driven ColorManager.textPrimary
      // — this tab bar now always sits on the fixed home-style gradient
      // (see MomentsHubPage), so it needs the same fixed-white treatment the
      // Home tab bar already got, not whatever the panel's textPrimary is.
      indicator: MDIndicator(
        indicatorColor: ColorManager.homeHeaderTextColor,
        indicatorWidth: 17.w,
        indicatorHeight: 4.h,
        radius: 20,
      ),
      indicatorPadding: EdgeInsets.symmetric(vertical: -2.5.h),
      dividerHeight: 0,
      labelPadding: context.paddingOnly(start: 14),
      // Light black (was a near-white muted tone that barely read against
      // the light gradient background), on request.
      unselectedLabelStyle: context.bodyMedium
          .colorExt(ColorManager.lightBlack)
          .size(18),
      labelStyle: context.bodyMedium.w600
          .size(18)
          .colorExt(ColorManager.homeHeaderTextColor),
      tabs: [
        Text(StringManager.event.tr()),
        Text(StringManager.moment.tr()),
      ],
    );
  }
}