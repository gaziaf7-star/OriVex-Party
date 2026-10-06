import 'package:flutter/material.dart';
import 'package:general/src/core/constants/color_manager.dart';

/// Paints a user's display name (any [Text]/[TextWidget] passed as [child])
/// with the app's brand gradient. Use it for every place a USER name is shown
/// so names read the same everywhere; only the glyph shapes of [child] are
/// kept, so its own colour is irrelevant.
class GradientName extends StatelessWidget {
  const GradientName({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) =>
          ColorManager.brandGradient1.createShader(bounds),
      child: child,
    );
  }
}
