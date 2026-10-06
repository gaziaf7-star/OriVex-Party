import 'package:flutter/material.dart';
import 'package:general/src/core/constants/color_manager.dart';

/// Renders the first letter (or two for compound names) of a person/group name
/// on a deterministic background color. Used instead of the app logo whenever
/// a user/group has no picture, so the placeholder reads as theirs.
///
/// The background color is picked from a fixed palette by hashing the name, so
/// the same name always renders the same color across the app.
class InitialsAvatar extends StatelessWidget {
  const InitialsAvatar({
    super.key,
    required this.name,
    required this.size,
    this.borderRadius,
    this.fontSize,
  });

  final String name;
  final double size;
  final BorderRadius? borderRadius;
  final double? fontSize;

  /// Deliberately fixed rather than panel-driven: the point is that one person
  /// keeps the same colour everywhere, which a palette that can change under
  /// them cannot give. It IS however held to the palette's rules — the previous
  /// list shipped a hot pink (0xFFEC407A) and an amber (0xFFFFA726, 0xFFFF7043)
  /// that landed on the owner's own profile header, and both are banned brand
  /// colours. These are cool/green hues in the Aurora range, all dark enough for
  /// the white [ColorManager.onDark] initials to stay legible.
  static const List<Color> _palette = <Color>[
    Color(0xFF0F9D8F),
    Color(0xFF0B8457),
    Color(0xFF1F6FB2),
    Color(0xFF4A55C7),
    Color(0xFF6D4AC4),
    Color(0xFF0E8AA8),
    Color(0xFF3D8B4A),
    Color(0xFF4E5D7E),
    Color(0xFF7A4FB5),
    Color(0xFF157A6E),
  ];

  String _initials() {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '?';

    final parts = trimmed.split(RegExp(r'\s+'));
    final first = parts.first.characters.isEmpty
        ? ''
        : parts.first.characters.first;

    if (parts.length >= 2) {
      final second = parts[1].characters.isEmpty
          ? ''
          : parts[1].characters.first;
      return (first + second).toUpperCase();
    }

    return first.toUpperCase();
  }

  Color _backgroundFor(String key) {
    if (key.isEmpty) return _palette.first;

    var hash = 0;
    for (final code in key.codeUnits) {
      hash = (hash * 31 + code) & 0x7fffffff;
    }

    return _palette[hash % _palette.length];
  }

  double _availableSize(BoxConstraints constraints) {
    final hasWidth = constraints.maxWidth.isFinite && constraints.maxWidth > 0;
    final hasHeight = constraints.maxHeight.isFinite && constraints.maxHeight > 0;

    if (hasWidth && hasHeight) {
      return constraints.maxWidth < constraints.maxHeight
          ? constraints.maxWidth
          : constraints.maxHeight;
    }

    if (hasWidth) return constraints.maxWidth;
    if (hasHeight) return constraints.maxHeight;

    return 48.0;
  }

  @override
  Widget build(BuildContext context) {
    final initials = _initials();
    final bg = _backgroundFor(name);

    return LayoutBuilder(
      builder: (context, constraints) {
        // `size` can occasionally be double.infinity when this avatar is used
        // inside an expanding card. Never allow that value to reach TextStyle,
        // because Flutter requires fontSize to be finite.
        final effectiveSize = size.isFinite && size > 0
            ? size
            : _availableSize(constraints);

        final requestedFontSize = fontSize;
        final effectiveFontSize =
        requestedFontSize != null &&
            requestedFontSize.isFinite &&
            requestedFontSize > 0
            ? requestedFontSize
            : (effectiveSize * 0.42).clamp(10.0, 96.0).toDouble();

        return Container(
          width: effectiveSize,
          height: effectiveSize,
          decoration: BoxDecoration(
            color: bg,
            borderRadius:
            borderRadius ?? BorderRadius.circular(effectiveSize / 2),
          ),
          alignment: Alignment.center,
          child: Text(
            initials,
            maxLines: 1,
            overflow: TextOverflow.clip,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: ColorManager.onDark,
              fontWeight: FontWeight.w600,
              fontSize: effectiveFontSize,
              height: 1,
            ),
          ),
        );
      },
    );
  }
}
