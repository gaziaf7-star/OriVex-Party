import 'package:general/src/core/index.dart';
import 'package:general/src/features/auth/auth.dart';

class CountryWidget extends StatelessWidget {
  final CountryEntity? countryEntity;
  final bool isShowFlag;
  final bool isSelected;
  final VoidCallback onTap;

  /// Renders a globe instead of a flag, for the "no country filter" entry that
  /// leads the home row. A null [countryEntity] already meant "All" here, but
  /// only as the word -- the row needs something the eye reads as a place.
  final bool isGlobal;

  const CountryWidget({
    super.key,
    this.countryEntity,
    required this.onTap,
    this.isShowFlag = true,
    required this.isSelected,
    this.isGlobal = false,
  });

  @override
  Widget build(BuildContext context) {
    final label =
    isGlobal ? StringManager.all.tr() : (countryEntity?.name ?? '');

    // Design only:
    // - selected: same pink -> purple brand gradient used by the bottom-nav
    //   selected state (centralized in ColorManager.brandGradient)
    // - unselected: soft white pill
    // Selection/filter behavior remains unchanged.
    final Color contentColor = isSelected
        ? ColorManager.onBrandGradient
        : ColorManager.homeHeaderTextColor;

    return Container(
      height: 34.h,
      margin: context.paddingSymmetric(horizontal: 4),
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
      child: InkWell(
        onTap: onTap,
        borderRadius: 18.radius,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isGlobal) ...[
              Icon(
                Icons.public_rounded,
                size: 14.h,
                color: contentColor,
              ),
              4.wBox,
            ],
            TextWidget(
              label,
              maxLines: 1,
              style: context.bodySmall
                  .copyWith(fontSize: 12)
                  .colorExt(contentColor)
                  .copyWith(
                fontWeight:
                isSelected ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
