import 'package:general/src/core/index.dart';
import 'package:general/src/features/profile/domain/profile_use_case/get_my_data_use_case.dart';

bool _opening = false;

/// Opens the agency center: the agency page for an agency owner/admin, the
/// agency search otherwise.
///
/// The owner/admin flags ([StringManager.userType]) come from the last
/// my-data load. After an agency is deleted they stay set until my-data is
/// fetched again, so the app kept opening the deleted agency's page ("No
/// Agency Data Now"). Re-fetch my-data first so the choice is current; if
/// that fails (offline), fall back to the cached flags.
Future<void> openAgencyCenter() async {
  if (_opening) return;
  _opening = true;
  try {
    // MyDataModel.fromJson refreshes StringManager.userType as a side effect.
    await di<FetchMyDataUseCase>()().timeout(const Duration(seconds: 6));
  } catch (_) {
    // Keep the cached flags.
  } finally {
    _opening = false;
  }
  final isAgencyMember =
      StringManager.userType[2]! || StringManager.userType[1]!;
  navKey.currentContext?.pushNamedRoute(
    isAgencyMember ? Routes.newAgencyScreen : Routes.searchForAgencyScreen,
  );
}
