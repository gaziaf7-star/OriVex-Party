import 'package:general/src/core/index.dart';
import 'package:general/src/features/home/presentation/home/view/home_page.dart'
    show CountriesBody;

/// Country tab row on the Theme 2 home (Trending tab): the user's login
/// country first, then Popular, then the other countries — the same row the
/// default home uses. Replaces the old globe button + "Recommend" label.
class Theme2FilterRow extends StatelessWidget {
  final VoidCallback? onViewToggled;
  const Theme2FilterRow({super.key, this.onViewToggled});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: context.paddingOnly(top: 6, bottom: 2),
      child: const CountriesBody(),
    );
  }
}
