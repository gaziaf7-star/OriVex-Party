import 'dart:io';

import 'package:general/src/core/index.dart';
import 'package:general/src/features/home/presentation/home/bloc/fetch_my_room_data_manager/fetch_my_room_data_bloc.dart';
import 'package:general/src/features/home/presentation/home/bloc/fetch_my_room_data_manager/fetch_my_room_data_event.dart';
import 'package:general/src/features/profile/presentation/coins/bloc/my_store_bloc/my_store_bloc.dart';
import 'package:general/src/features/room/room.dart';

part 'components/form_add_info_body.dart';
part 'components/pick_image_body.dart';

class CreateRoomPage extends StatelessWidget {
  /// When true, creates a LIVE show (sends `type: 'live'`) and enters the live
  /// room as host on success; otherwise creates an audio room (default).
  final bool isLive;

  const CreateRoomPage({super.key, this.isLive = false});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: true,
      body: BlocConsumer<CreateRoomBloc, CreateRoomStates>(
        bloc: di<CreateRoomBloc>(),
        listener: (_, state) {
          if (state.reqState.isLoaded) {
            di<FetchMyRoomDataBloc>().add(const FetchMyRoomDataEvent());
            RoomData.instance.room = EnterRoomModel(
              ownerId: MyDataModel.getInstance().id,
              id: state.createRoomData?.id??0,
              roomName: state.createRoomData?.name ?? "",
              roomCover: state.createRoomData?.cover ?? "",
              roomBackground:
                  state.createRoomData?.background ?? "",
              mode: state.createRoomData?.mode.toString() ?? '',
              uuidOwnerRoom: MyDataModel.getInstance().uuid ?? "",
              giftPrice: state.createRoomData?.giftPrice ?? "",
            );

            Navigator.pop(context);
            final navContext = SafeNavigator.context;
            if (navContext == null) return;
            if (isLive) {
              // Live: enter the new live room as host via RoomStateManager so
              // room state, background service and wakelock stay consistent with
              // the normal live-entry path.
              di<RoomStateManager>().navigateToRoom(
                RoomEntryRequest(
                  context: navContext,
                  roomData: RoomEntity(
                    ownerId: MyDataModel.getInstance().id,
                    id: state.createRoomData?.id,
                    name: state.createRoomData?.name,
                    cover: state.createRoomData?.cover,
                    roomBackground: state.createRoomData?.background,
                    mode: state.createRoomData?.mode.toString(),
                    uuidOwnerRoom: MyDataModel.getInstance().uuid ?? "",
                    giftPrice: state.createRoomData?.giftPrice,
                    ownerSpecialId: MyDataModel.getInstance().specialIdImage,
                    ownerImageColor: MyDataModel.getInstance().imageColorEntity,
                    streamType: "live",
                    isLive: true,
                  ),
                  isLive: true,
                ),
              );
            } else {
              Navigator.pushNamed(
                navContext,
                Routes.roomScreen,
                arguments: RoomParameter(
                  myDataModel: MyDataModel.getInstance(),
                  roomId: '${state.createRoomData?.id}',
                  ownerId: '${MyDataModel.getInstance().id}',
                  isHost: true,
                  isLocked: false,
                ),
              );
            }
          }
        },
        builder: (context, state) {
          final mq = MediaQuery.of(context);
          final headerH = (mq.size.height * 0.26).clamp(170.0, 260.0);
          const pickerSize = 112.0;
          final overlap = 30.r;
          return Stack(
            children: [
              // Banner
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: headerH,
                child: DecoratedBox(
                  decoration: BoxDecoration(gradient: ColorManager.brandGradient),
                  child: Stack(
                    children: [
                      Positioned(
                        right: -40,
                        top: -30,
                        child: CircleAvatar(
                          radius: 90,
                          backgroundColor: Colors.white.withValues(alpha: 0.10),
                        ),
                      ),
                      Positioned(
                        left: -50,
                        bottom: 10,
                        child: CircleAvatar(
                          radius: 70,
                          backgroundColor: Colors.white.withValues(alpha: 0.08),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // White card
              Positioned.fill(
                top: headerH - overlap,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(30.r),
                    ),
                  ),
                  padding: EdgeInsets.only(top: pickerSize.r / 2 + 22.h),
                  child: _FormAddInfoBody(isLive: isLive),
                ),
              ),
              // Cover picker straddling the banner / card edge. Lives in the
              // outer Stack so its whole area (not just the half inside the
              // card) is tappable.
              Positioned(
                top: headerH - overlap - pickerSize.r / 2,
                left: 0,
                right: 0,
                child: const Center(child: PickImageBody(size: pickerSize)),
              ),
              // App bar (back + title) over the banner
              Positioned(
                top: mq.padding.top,
                left: 0,
                right: 0,
                height: 56,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Text(
                      isLive
                          ? StringManager.goLive.tr()
                          : StringManager.createRoom.tr(),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: IconButton(
                        icon: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: Colors.white,
                        ),
                        onPressed: () => Navigator.maybePop(context),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
