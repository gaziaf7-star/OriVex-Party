import 'dart:math' as math;

import 'package:general/src/core/index.dart';

class VisitorsCount extends StatelessWidget {
  final String count;
  final double? fontSize;
  final FontWeight? fontWeight;
  final bool isList;
  final bool isTop;
  final Color? color;
  final String? icon;

  const VisitorsCount({
    super.key,
    required this.count,
    this.fontSize,
    this.fontWeight,
    this.color,
    this.isList = false,
    this.isTop = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    if (isList) {
      return _buildListView();
    } else if (isTop) {
      return _buildWhiteIconView(context);
    } else {
      return _buildDefaultView(context);
    }
  }

  /// Animated music bars in place of the static "live" icon; a caller that
  /// passes its own [icon] keeps that image.
  Widget _viewerIcon(Color barColor) {
    if (icon != null) {
      return ImageWidget(height: 14.h, width: 14.h, image: icon!);
    }
    return MusicBars(color: barColor);
  }

  Widget _buildListView() {
    return Container(
      padding: ConstantsManager.isTheme1
          ? navKey.currentContext
              ?.paddingSymmetric(horizontal: 5.0, vertical: 1.0)
          : null,
      decoration: ConstantsManager.isTheme1
          ? BoxDecoration(
              color: ColorManager.black.withValues(alpha: 0.3),
              borderRadius: 30.radius,
            )
          : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (ConstantsManager.isTheme1 == true) ...[
            _viewerIcon(ColorManager.primary),
            3.wBox,
          ],
          if (ConstantsManager.isTheme1 == false)
            MusicBars(color: ColorManager.primary),
          TextWidget(
            count,
            style: TextStyle(
              color: color ?? ColorManager.textPrimary,
              fontSize: fontSize ?? 10,
              fontWeight: fontWeight ?? FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDefaultView(BuildContext context) {
    return Padding(
      padding: context.paddingSymmetric(horizontal: 5, vertical: 1.0),
      child: Container(
        padding: ConstantsManager.isTheme1
            ? navKey.currentContext
                ?.paddingSymmetric(horizontal: 5.0, vertical: 1.0)
            : null,
        decoration: ConstantsManager.isTheme1
            ? BoxDecoration(
                color: ColorManager.black.withValues(alpha: 0.3),
                borderRadius: 30.radius,
              )
            : null,
        child: Row(
          children: [
            if (ConstantsManager.isTheme1 == true) ...[
              _viewerIcon(ColorManager.primary),
              3.wBox,
            ],
            if (ConstantsManager.isTheme1 == false)
              MusicBars(color: ColorManager.primary),
            TextWidget(
              count,
              style: context.bodyMedium
                  .size(fontSize ?? 9)
                  .colorExt(color ?? ColorManager.textPrimary)
                  .copyWith(
                    fontWeight: fontWeight ?? FontWeight.w400,
                  ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildWhiteIconView(BuildContext context) {
    return Padding(
      padding: context.paddingSymmetric(horizontal: 5, vertical: 1),
      child: Container(
        padding: ConstantsManager.isTheme1
            ? navKey.currentContext
                ?.paddingSymmetric(horizontal: 5.0, vertical: 1.0)
            : null,
        decoration: ConstantsManager.isTheme1
            ? BoxDecoration(
                color: ColorManager.black.withValues(alpha: 0.3),
                borderRadius: 30.radius,
              )
            : null,
        child: Row(
          children: [
            if (ConstantsManager.isTheme1 == true) ...[
              _viewerIcon(Colors.white),
              3.wBox,
            ],
            if (ConstantsManager.isTheme1 == false)
              const MusicBars(color: Colors.white),
            TextWidget(
              count,
              style: context.bodyMedium
                  .colorExt(Colors.white)
                  .size(fontSize ?? 12)
                  .copyWith(
                    fontWeight: fontWeight ?? FontWeight.w600,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}


/// Small animated equalizer (bouncing bars), shown next to a room's viewer
/// count so an audio room reads as "playing".
class MusicBars extends StatefulWidget {
  final Color color;
  final double? size;

  const MusicBars({super.key, this.color = Colors.white, this.size});

  @override
  State<MusicBars> createState() => _MusicBarsState();
}

class _MusicBarsState extends State<MusicBars>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

  // Phase offsets so the bars move out of step.
  static const _phases = [0.0, 0.35, 0.7, 0.15];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size ?? 14.h;
    final barWidth = size / 6;
    return SizedBox(
      width: size,
      height: size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final phase in _phases)
                Container(
                  width: barWidth,
                  height: size *
                      (0.3 +
                          0.7 *
                              (0.5 +
                                  0.5 *
                                      math.sin(2 *
                                          math.pi *
                                          (_controller.value + phase)))),
                  decoration: BoxDecoration(
                    color: widget.color,
                    borderRadius: BorderRadius.circular(barWidth),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
