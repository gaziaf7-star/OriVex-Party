import 'package:general/src/features/payment/presentation/bloc/fetch_coins/fetch_coins_event.dart';
import 'package:general/src/features/payment/presentation/view/in_app_purchases.dart';
import 'package:general/src/features/profile/presentation/coins/bloc/my_store_bloc/my_store_bloc.dart';
import 'package:skeletonizer/skeletonizer.dart';

import 'package:general/src/core/index.dart';
import '../../bloc/buy_coins_bloc/buy_coins_bloc.dart';
import '../../bloc/buy_coins_bloc/buy_coins_event.dart';
import '../../bloc/fetch_coins/fetch_coins_bloc.dart';
import '../../bloc/fetch_coins/fetch_coins_state.dart';
import 'coin_sellers_section.dart';

class CoinsView extends StatefulWidget {
  const CoinsView({super.key});

  @override
  State<CoinsView> createState() => _CoinsViewState();
}

class _CoinsViewState extends State<CoinsView> {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FetchCoinsBloc, FetchCoinsState>(
      bloc: di<FetchCoinsBloc>(),
      buildWhen: (prev, curr) =>
      prev.reqState != curr.reqState || prev.data != curr.data,
      builder: (context, rawState) {
        // Only Google Play recharge here; coin sellers are listed below it.
        final state = rawState.copyWith(
          data: rawState.data
              ?.where((g) => g.title == 'google_pay')
              .toList(),
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            110.hBox,
            Padding(
              padding: context.paddingSymmetric(horizontal: 18),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextWidget(
                    StringManager.recharge.tr(),
                    style: context.bodyMedium.size(15).w600.colorExt(
                        ColorManager.black),
                  ),
                  InkWell(
                    onTap: () {
                      di<MyStoreBloc>().add(const GetMyStoreEvent());
                      di<FetchCoinsBloc>().add(const FetchCoinsEvent());
                    },
                    child: Image.asset(
                      AssetsManager.refreshIcon,
                      scale: 2,
                      color: ColorManager.coinsAccent,
                    ),
                  ),
                ],
              ),
            ),
            5.hBox,
            Expanded(
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: context.paddingSymmetric(horizontal: 18, vertical: 10),
                children: [
                  HandlingDataWidget(
                    isNeedLoadingWidget: true,
                    reqState: state.reqState,
                    title: StringManager.noDataYet.tr(),
                    subTitle: StringManager.pleaseTryAgine.tr(),
                    // Black empty-state text + a solid-fill retry button in
                    // our own brand color, on request ("text black hoba,
                    // button ta amardar button ar moto hoba").
                    titleStyle: context.bodyLarge.w600
                        .colorExt(ColorManager.black),
                    subTitleStyle: context.bodyMedium
                        .copyWith(color: ColorManager.black, height: 1.30),
                    buttonBackgroundColors: [
                      ColorManager.primary,
                      ColorManager.primary
                    ],
                    onTap: () {
                      di<FetchCoinsBloc>().add(const FetchCoinsEvent());
                      di<MyStoreBloc>()
                          .add(const GetMyStoreEvent(isLoading: false));
                    },
                    child: Skeletonizer(
                      enabled: state.reqState == RequestState.loading,
                      child: ListView.builder(
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: state.reqState == RequestState.loading
                            ? 5
                            : state.data?.length ?? 0,
                        shrinkWrap: true,
                        itemBuilder: (context, ind) {
                          return Container(
                            decoration: BoxDecoration(
                              color: ColorManager.white,
                              borderRadius: 12.radius,
                              border: Border.all(
                                  color: ColorManager.grey2
                                      .withValues(alpha: 0.3)),
                              boxShadow: [
                                BoxShadow(
                                  color:
                                  ColorManager.black.withValues(alpha: 0.05),
                                  blurRadius: 8.r,
                                  offset: Offset(0, 2.h),
                                ),
                              ],
                            ),
                            margin: context.paddingSymmetric(vertical: 5),
                            // Wrapped in its own transparent Material here --
                            // ExpansionTile renders a ListTile internally,
                            // and that ListTile paints its background/ink
                            // splashes on the nearest Material ancestor.
                            // Without this, the opaque white Container above
                            // (with its border/shadow) sits between the
                            // ListTile and any Material ancestor and blocks
                            // those effects, which is exactly what Flutter's
                            // "ListTile background color or ink splashes may
                            // be invisible" assertion was flagging. A
                            // transparent Material fixes it without changing
                            // how this card looks.
                            child: Material(
                              color: ColorManager.transparent,
                              child: Theme(
                                data: Theme.of(context)
                                    .copyWith(dividerColor: ColorManager.white),
                                child: state.reqState.isLoading
                                    ? Container(
                                    width: 40.w,
                                    height: 40.h,
                                    color: Colors.grey[300])
                                    : ExpansionTile(
                                  leading: ImageViewWidget(
                                    url: state.data?[ind].photo ?? "",
                                    width: 40.w,
                                    height: 40.h,
                                    boxFit: BoxFit.contain,
                                  ),
                                  title: TextWidget(
                                    state.data?[ind].title != null
                                        ? StringManager.getGateWay(
                                        gateway:
                                        state.data![ind].title!)
                                        : "",
                                    style: context.bodyMedium.bold
                                        .colorExt(ColorManager.black),
                                  ),
                                  children: [
                                    Column(
                                      children: List.generate(
                                        state.data?[ind].coins?.length ?? 0,
                                            (index) {
                                          final coin = state
                                              .data?[ind].coins?[index];
                                          return Container(
                                            padding:
                                            context.paddingSymmetric(
                                                horizontal: 15),
                                            margin:
                                            context.paddingSymmetric(
                                                vertical: 10),
                                            child: Row(
                                              crossAxisAlignment:
                                              CrossAxisAlignment.center,
                                              mainAxisAlignment:
                                              MainAxisAlignment.start,
                                              children: [
                                                Image.asset(
                                                  AssetsManager.coinsVip,
                                                  scale: 2.5,
                                                ),
                                                10.wBox,
                                                Expanded(
                                                  child: TextWidget(
                                                    coin?.coin.toString() ??
                                                        '',
                                                    style: context
                                                        .bodyMedium.bold
                                                        .colorExt(
                                                        ColorManager.black)
                                                        .size(18),
                                                  ),
                                                ),
                                                ButtonWidget(
                                                  fontWeight:
                                                  FontWeight.w500,
                                                  fontSize: 16,
                                                  backgroundColor:
                                                  ColorManager
                                                      .coinsAccent,
                                                  onPressed: () async {
                                                    if (state.data![ind]
                                                        .title ==
                                                        "google_pay" &&
                                                        di<PurchaseService>()
                                                            .result !=
                                                            null) {
                                                      final product = di<
                                                          PurchaseService>()
                                                          .findProduct(coin
                                                              ?.id
                                                              .toString() ??
                                                          '');
                                                      // `.single` threw "Bad state: No element" when the store has no
                                                      // product for this package.
                                                      if (product == null) {
                                                        Methods.showToast(
                                                          context,
                                                          message: 'This package is not available right now',
                                                          isError: true,
                                                        );
                                                        return;
                                                      }
                                                      di<PurchaseService>().buyProduct(product);
                                                    } else {
                                                      if (!di<BuyCoinsBloc>()
                                                          .state
                                                          .reqState
                                                          .isLoading) {
                                                        di<BuyCoinsBloc>()
                                                            .add(
                                                            BuyCoinsEvent(
                                                              context: context,
                                                              method: state
                                                                  .data?[
                                                              ind]
                                                                  .title ??
                                                                  '',
                                                              productId: coin
                                                                  ?.id
                                                                  .toString() ??
                                                                  "",
                                                            ));
                                                      }
                                                    }
                                                    Methods.showToast(
                                                        context,
                                                        isLoading: true);
                                                  },
                                                  height: 33.h,
                                                  width: 110.w,
                                                  title: coin?.usd != null
                                                      ? "${coin!.usd % 1 == 0 ? coin.usd.toInt() : coin.usd.toString()} \$"
                                                      : '',
                                                ),
                                              ],
                                            ),
                                          );
                                        },
                                      ),
                                    )
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  const CoinSellersSection(),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}