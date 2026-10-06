part of '../create_room_page.dart';

/// Rounded-square cover picker (gold border, "+" when empty, camera badge once
/// a photo is chosen). Tapping it opens the gallery picker.
class PickImageBody extends StatelessWidget {
  final String? image;
  final double size;

  const PickImageBody({super.key, this.image, this.size = 112});

  static const Color _gold = Color(0xFFFFC107);

  @override
  Widget build(BuildContext context) {
    final box = size.r;
    return BlocBuilder<CreateRoomBloc, CreateRoomStates>(
      bloc: di<CreateRoomBloc>(),
      buildWhen: (prev, curr) => prev.image != curr.image,
      builder: (context, state) {
        final hasFile = state.image != null;
        final hasUrl = image != null && image != '';

        Widget content;
        if (hasFile) {
          content = Image.file(state.image ?? File(''), fit: BoxFit.cover);
        } else if (hasUrl) {
          content = ImageViewWidget(
            url: image ?? '',
            boxFit: BoxFit.cover,
            width: box,
            height: box,
          );
        } else {
          content = Center(
            child: Icon(Icons.add_rounded, color: _gold, size: box * 0.55),
          );
        }

        return GestureDetector(
          onTap: () => di<CreateRoomBloc>().add(PickRoomImage(state.image)),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: box,
                height: box,
                decoration: BoxDecoration(
                  color: const Color(0xFF5A2410),
                  borderRadius: BorderRadius.circular(26.r),
                  border: Border.all(color: _gold, width: 3.r),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.18),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: content,
              ),
              if (hasFile || hasUrl)
                Positioned(
                  right: -4.r,
                  bottom: -4.r,
                  child: Container(
                    padding: EdgeInsets.all(6.r),
                    decoration: BoxDecoration(
                      color: _gold,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: Icon(
                      Icons.camera_alt_rounded,
                      size: 14.r,
                      color: Colors.black,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
