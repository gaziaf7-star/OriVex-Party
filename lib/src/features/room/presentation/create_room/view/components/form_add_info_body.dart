part of '../create_room_page.dart';

/// White form card: labelled filled fields, grey room-type chips and a yellow
/// gradient submit button pinned to the bottom. Scrolls (and keeps the button
/// above the keyboard) on small screens.
class _FormAddInfoBody extends StatefulWidget {
  final bool isLive;

  const _FormAddInfoBody({this.isLive = false});

  @override
  State<_FormAddInfoBody> createState() => _FormAddInfoBodyState();
}

class _FormAddInfoBodyState extends State<_FormAddInfoBody> {
  static const Color _ink = Colors.black;
  static const Color _fieldFill = Color(0xFFF6F7F9);
  static const Color _chipFill = Color(0xFFD9D9D9);
  static const Color _gold = Color(0xFFFFC107);

  @override
  void initState() {
    if (di<CreateRoomBloc>().state.typesRoomState != RequestState.loaded) {
      di<CreateRoomBloc>().add(GetTypesRoomEvent());
    }
    if (di<CreateRoomBloc>().state.createPaidRoomState != RequestState.loaded) {
      di<CreateRoomBloc>().add(CreatePaidRoomEvent());
    }
    super.initState();
  }

  @override
  void dispose() {
    di<CreateRoomBloc>().add(DisposeEvent());
    super.dispose();
  }

  Widget _label(String text) => Padding(
        padding: EdgeInsets.only(bottom: 8.h),
        child: Text(
          text,
          style: TextStyle(
            color: _ink,
            fontSize: 16.sp,
            fontWeight: FontWeight.w500,
          ),
        ),
      );

  Widget _field({
    required TextEditingController controller,
    required String hint,
    required int maxLength,
    int minLines = 1,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      maxLength: maxLength,
      minLines: minLines,
      maxLines: maxLines,
      style: TextStyle(color: _ink, fontSize: 15.sp),
      cursorColor: _ink,
      validator: (value) => (value == null || value.trim().isEmpty)
          ? StringManager.requiredField.tr()
          : null,
      decoration: InputDecoration(
        filled: true,
        fillColor: _fieldFill,
        hintText: hint,
        hintStyle: TextStyle(
          color: _ink.withValues(alpha: 0.35),
          fontSize: 15.sp,
        ),
        counterStyle: TextStyle(
          color: _ink.withValues(alpha: 0.35),
          fontSize: 12.sp,
        ),
        contentPadding:
            EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14.r),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14.r),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14.r),
          borderSide: const BorderSide(color: _gold, width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14.r),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14.r),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
      ),
    );
  }

  Widget _chip(String text, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 11.h),
        decoration: BoxDecoration(
          color: selected ? _gold : _chipFill,
          borderRadius: BorderRadius.circular(14.r),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: _ink,
            fontSize: 15.sp,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  void _submit(CreateRoomStates state) {
    if (state.formKey.currentState?.validate() != true) return;
    if (state.image == null) {
      Methods.showToast(
        context,
        message: StringManager.addInfoRoomSubtitle.tr(),
        isError: true,
      );
      return;
    }
    if (state.selectedRoomTypeId == -1) {
      Methods.showToast(
        context,
        message: StringManager.selectRoomType.tr(),
        isError: true,
      );
      return;
    }
    final paid = state.createPaidRoomEntity?.isPaidRoom == true;
    if (paid &&
        int.parse(state.createPaidRoomEntity?.paidRoomAmount ?? "0") >
            di<MyStoreBloc>().state.myStore?.coins) {
      Methods.showToast(
        context,
        isError: true,
        message: StringManager.goRecharge.tr(),
      );
      Navigator.pushNamed(context, Routes.coinsPage);
      return;
    }
    di<CreateRoomBloc>().add(
      CreateAudioRoomEvent(
        roomName: state.name.text,
        roomCover: state.image,
        password: '',
        roomIntero: state.bio.text,
        roomType: state.selectedRoomTypeId.toString(),
        type: widget.isLive ? 'live' : 'audio',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<CreateRoomBloc, CreateRoomStates>(
      bloc: di<CreateRoomBloc>(),
      builder: (context, state) {
        final title = state.createPaidRoomEntity?.isPaidRoom == true
            ? StringManager.craeteRoomPaid(
                coins: state.createPaidRoomEntity?.paidRoomAmount ?? "0")
            : StringManager.createRoomDefult.tr();
        final loading = state.reqState.isLoading;

        return Form(
          key: state.formKey,
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 16.h),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _label(StringManager.enterRoomName.tr()),
                      _field(
                        controller: state.name,
                        hint: StringManager.enterRoomName.tr(),
                        maxLength: 20,
                      ),
                      SizedBox(height: 10.h),
                      _label(StringManager.enterRoomIntro.tr()),
                      _field(
                        controller: state.bio,
                        hint: StringManager.enterRoomIntro.tr(),
                        maxLength: 200,
                        minLines: 4,
                        maxLines: 6,
                      ),
                      SizedBox(height: 14.h),
                      _label(StringManager.selectRoomTyp.tr()),
                      HandlingDataWidget(
                        reqState: state.typesRoomState,
                        title: "",
                        subTitle: "",
                        child: Wrap(
                          spacing: 10.w,
                          runSpacing: 10.h,
                          children: [
                            for (final type in state.typesRoom)
                              _chip(
                                type.name,
                                state.selectedRoomTypeId == type.id,
                                () => di<CreateRoomBloc>()
                                    .add(SelectRoomTypeEvent(type.id)),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 14.h),
                  child: _GradientSubmitButton(
                    title: title,
                    isLoading: loading,
                    onPressed: loading ? null : () => _submit(state),
                  ),
                ),
              ),
            ],
          ),
        );
      },
      listener: (context, state) {
        if (state.createPaidRoomEntity?.isPaidRoom == true &&
            state.createPaidRoomState.isLoaded) {
          di<MyStoreBloc>().add(const GetMyStoreEvent());
        }
      },
    );
  }
}

/// Full-width yellow gradient pill with white bold text.
class _GradientSubmitButton extends StatelessWidget {
  final String title;
  final bool isLoading;
  final VoidCallback? onPressed;

  const _GradientSubmitButton({
    required this.title,
    required this.isLoading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Opacity(
      opacity: enabled ? 1 : 0.7,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(40.r),
          onTap: onPressed,
          child: Ink(
            height: 54.h,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(40.r),
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFFFE21A), Color(0xFFFFB300)],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFFB300).withValues(alpha: 0.35),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Center(
              child: isLoading
                  ? SizedBox(
                      width: 24.r,
                      height: 24.r,
                      child: const CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 19.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
