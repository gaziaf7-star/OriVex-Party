import '../index.dart';

class GenderWidget extends StatelessWidget {
  final int age;
  final int gender;
  final int? widthSize;
  const GenderWidget(
      {super.key, required this.age, required this.gender, this.widthSize});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: widthSize != null ? 7.w : 0,
        vertical: 1.h,
      ),
      // Minimum (not fixed) width so a 2-3 digit age can never overflow.
      constraints: BoxConstraints(minWidth: widthSize?.w ?? 0),
      decoration: BoxDecoration(
        borderRadius: 12.radius,
        color: gender == 1 ? Colors.blue : Colors.pink,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            gender == 1 ? Icons.male : Icons.female,
            color: ColorManager.white,
            size: 12.r,
          ),
          1.wBox,
          TextWidget(
            age.toString(),
            style: context.bodyMedium.size(9).colorExt(ColorManager.onDark),
          ),
        ],
      ),
    );
  }
}
