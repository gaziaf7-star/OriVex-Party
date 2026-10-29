import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:general/src/core/index.dart';
import 'package:general/src/features/profile/data/model/wallet_withdraw_models.dart';
import 'package:general/src/features/profile/presentation/wallet_withdraw/bloc/wallet_withdraw_bloc.dart';
import 'package:general/src/features/auth/auth.dart';
import 'package:general/src/features/auth/domain/entities/profile_room_entity.dart';

/// Wallet "Coin Seller" list: one compact white card per seller with a
/// WhatsApp button and an in-app Message button. Replaces the old
/// "Shipping from the agency" bottom sheet.
class CoinSellersSection extends StatefulWidget {
  const CoinSellersSection({super.key});

  @override
  State<CoinSellersSection> createState() => _CoinSellersSectionState();
}

class _CoinSellersSectionState extends State<CoinSellersSection> {
  // The app's coin-seller (reseller) list -- the same one the Reseller
  // directory page shows.
  final _bloc = di<WalletWithdrawBloc>();

  @override
  void initState() {
    super.initState();
    if (_bloc.state.resellers.isEmpty) {
      _bloc.add(const LoadResellersEvent());
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<WalletWithdrawBloc, WalletWithdrawState>(
      bloc: _bloc,
      buildWhen: (prev, curr) =>
          prev.resellers != curr.resellers ||
          prev.resellerState != curr.resellerState,
      builder: (context, state) {
        final sellers = state.resellers;
        final loading = state.resellerState.isLoading ||
            state.resellerState == RequestState.idle;
        if (!loading && sellers.isEmpty) {
          return const SizedBox.shrink();
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: context.paddingOnly(top: 14, bottom: 6, start: 2),
              child: TextWidget(
                StringManager.coinSeller.tr(),
                style: context.bodyMedium.size(13).w600
                    .colorExt(ColorManager.black),
              ),
            ),
            if (loading && sellers.isEmpty)
              const Center(child: CircleLoadingWidget())
            else
              ...sellers.map((s) => _CoinSellerCard(data: s)),
          ],
        );
      },
    );
  }
}

class _CoinSellerCard extends StatelessWidget {
  final WithdrawReseller data;

  const _CoinSellerCard({required this.data});

  String get _displayName => data.name;

  String get _avatar => data.image;

  /// wa.me wants digits only (country code included, no "+").
  String get _whatsappDigits =>
      data.whatsappNumber.replaceAll(RegExp(r'[^0-9]'), '');

  void _openWhatsapp(BuildContext context) {
    final digits = _whatsappDigits;
    if (digits.isEmpty) {
      Methods.showToast(
        context,
        message: 'WhatsApp number not available',
        isError: true,
      );
      return;
    }
    Methods.openUrl('https://wa.me/$digits');
  }

  void _openChat(BuildContext context) {
    Methods().isFriends(
      userEntity: UserEntity(
        name: _displayName,
        id: data.id,
        isFriend: true,
        profile: ProfileRoomEntity(image: _avatar),
      ),
      context: context,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: context.paddingSymmetric(vertical: 4),
      padding: context.paddingSymmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: 12.radius,
        border: Border.all(color: ColorManager.grey2.withValues(alpha: 0.25)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6.r,
            offset: Offset(0, 2.h),
          ),
        ],
      ),
      child: Row(
        children: [
          ClipOval(
            child: ImageViewWidget(
              url: _avatar,
              width: 38.w,
              height: 38.w,
              boxFit: BoxFit.cover,
              displayName: _displayName,
            ),
          ),
          10.wBox,
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextWidget(
                  _displayName,
                  isTranslate: false,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.bodyMedium.size(12.5).w600
                      .colorExt(Colors.black),
                ),
                2.hBox,
                TextWidget(
                  'ID: ${data.publicId.isNotEmpty ? data.publicId : data.id}',
                  isTranslate: false,
                  maxLines: 1,
                  style: context.bodySmall.size(10)
                      .colorExt(Colors.black.withValues(alpha: 0.5)),
                ),
              ],
            ),
          ),
          8.wBox,
          _ActionChip(
            icon: FaIcon(
              FontAwesomeIcons.whatsapp,
              size: 16.w,
              color: const Color(0xFF25D366),
            ),
            color: const Color(0xFF25D366),
            onTap: () => _openWhatsapp(context),
          ),
          6.wBox,
          _ActionChip(
            icon: Icon(
              Icons.chat_bubble_rounded,
              size: 16.w,
              color: ColorManager.primary,
            ),
            color: ColorManager.primary,
            onTap: () => _openChat(context),
          ),
        ],
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  /// Ready-made icon widget: Font Awesome v11 icons are not [IconData], so
  /// they have to be drawn with [FaIcon] rather than [Icon].
  final Widget icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionChip({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.12),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(7.w),
          child: SizedBox(
            width: 16.w,
            height: 16.w,
            child: Center(child: icon),
          ),
        ),
      ),
    );
  }
}
