import 'dart:io';

import 'package:general/src/core/index.dart';
import 'package:general/src/core/widgets/update_dialog.dart';
import 'package:general/src/features/auth/presentation/auth_platform/bloc/auth_platform_bloc.dart';
import 'package:general/src/features/auth/presentation/splash/config_app/config_app_bloc.dart';
import 'package:general/src/features/setting/setting.dart';

class IntroPage extends StatefulWidget {
  final String? error;

  const IntroPage({super.key, this.error});

  @override
  State<IntroPage> createState() => _IntroPageState();
}

class _IntroPageState extends State<IntroPage> {
  bool _isAgreementAccepted = false;

  static const List<Map<String, String>> _supportedLanguages = [
    {'code': 'en', 'name': 'English'},
    {'code': 'ar', 'name': 'العربية'},
    {'code': 'tr', 'name': 'Türkçe'},
    {'code': 'ur', 'name': 'اردو'},
    {'code': 'hi', 'name': 'हिन्दी'},
    {'code': 'id', 'name': 'Bahasa Indonesia'},
  ];

  @override
  void initState() {
    super.initState();

    if (widget.error != null && (widget.error ?? '').isNotEmpty) {
      Future.delayed(
        const Duration(milliseconds: 800),
            () {
          if (!mounted) return;
          showDialog(
            context: context,
            builder: (context) => AnimatedDialog(
              title: StringManager.ban,
              description: widget.error ?? '',
              isHideConfirm: true,
            ),
          );
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<ConfigAppBloc, ConfigAppState>(
      bloc: di<ConfigAppBloc>(),
      listener: (context, state) {
        if (state.requestState.isLoaded &&
            state.config?.isLastVersion != true) {
          showDialog(
            context: context,
            barrierDismissible: !(state.config?.isForce ?? false),
            barrierColor: Colors.black.withValues(alpha: 0.5),
            builder: (_) => PopScope(
              canPop: false,
              onPopInvoked: (_) {},
              child: ForceUpdateDialog(
                description: StringManager.updatDesc.tr(),
                isOptionalUpdate: !(state.config?.isForce ?? false),
                onConfirm: () {
                  Methods.openUrl(ConstantsManager.appURL);
                },
              ),
            ),
          );
        }
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Stack(
          children: [
            // Full-bleed brand wallpaper behind the whole welcome/login
            // screen, matching the reference design.
            Positioned.fill(
              child: Image.asset(
                AssetsManager.introBg,
                fit: BoxFit.cover,
              ),
            ),
            // Flat light-black wash over the whole photo so it reads crisp
            // ("HD") and text stays legible everywhere, not just at the
            // top/bottom edges, on request.
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.24),
                ),
              ),
            ),
            // Scrim: just enough darkening top-to-bottom to keep the
            // language picker, logo and buttons legible -- the wallpaper
            // stays visible the full height of the screen instead of fading
            // to solid white partway down, on request.
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.38),
                      Colors.black.withValues(alpha: 0.06),
                      Colors.black.withValues(alpha: 0.02),
                      Colors.black.withValues(alpha: 0.45),
                    ],
                    stops: const [0.0, 0.3, 0.55, 1.0],
                  ),
                ),
              ),
            ),
            SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final screenWidth = constraints.maxWidth;
              final screenHeight = constraints.maxHeight;

              final horizontalPadding =
              (screenWidth * 0.075).clamp(22.0, 44.0);
              final heroTopGap =
              (screenHeight * 0.125).clamp(68.0, 135.0);
              final logoSize = (screenWidth * 0.28).clamp(96.0, 140.0);
              final heroBottomGap =
              (screenHeight * 0.072).clamp(38.0, 68.0);
              final buttonHeight =
              (screenHeight * 0.062).clamp(48.0, 55.0);
              final buttonGap =
              (screenHeight * 0.016).clamp(10.0, 16.0);

              return SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: screenHeight),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: horizontalPadding,
                    ),
                    child: Column(
                      children: [
                        const SizedBox(height: 14),

                        Align(
                          alignment: AlignmentDirectional.topEnd,
                          child: _languageButton(context),
                        ),

                        SizedBox(height: heroTopGap),

                        Image.asset(
                          AssetsManager.logo,
                          width: logoSize,
                          height: logoSize,
                          fit: BoxFit.contain,
                        ),

                        SizedBox(height: heroBottomGap),

                        BlocBuilder<AuthPlatformBloc, AuthPlatformState>(
                          bloc: di<AuthPlatformBloc>(),
                          buildWhen: (prev, curr) =>
                          prev.requestStateGoogle !=
                              curr.requestStateGoogle,
                          builder: (context, state) {
                            return _referenceButton(
                              iconAsset: AssetsManager.google_,
                              label: StringManager.signInWithGoogle.tr(),
                              height: buttonHeight,
                              iconSize: 22,
                              enabled: _isAgreementAccepted,
                              isLoading: state.requestStateGoogle.isLoading,
                              onTap: () {
                                di<AuthPlatformBloc>().add(
                                  SignInGoogleEvent(
                                    context: context,
                                    isAddAccount: false,
                                  ),
                                );
                              },
                            );
                          },
                        ),

                        if (ConstantsManager.devicePlatform ==
                            StringManager.huawei) ...[
                          SizedBox(height: buttonGap),
                          BlocBuilder<AuthPlatformBloc, AuthPlatformState>(
                            bloc: di<AuthPlatformBloc>(),
                            buildWhen: (prev, curr) =>
                            prev.requestStateHuawei !=
                                curr.requestStateHuawei,
                            builder: (context, state) {
                              return _referenceButton(
                                iconAsset: AssetsManager.huawei,
                                label: StringManager.signInWithHuawei.tr(),
                                height: buttonHeight,
                                iconSize: 22,
                                enabled: _isAgreementAccepted,
                                isLoading: state.requestStateHuawei.isLoading,
                                onTap: () {
                                  di<AuthPlatformBloc>().add(
                                    SignInHuaweiEvent(context: context),
                                  );
                                },
                              );
                            },
                          ),
                        ],

                        if (Platform.isIOS) ...[
                          SizedBox(height: buttonGap),
                          BlocBuilder<AuthPlatformBloc, AuthPlatformState>(
                            bloc: di<AuthPlatformBloc>(),
                            buildWhen: (prev, curr) =>
                            prev.requestStateApple !=
                                curr.requestStateApple,
                            builder: (context, state) {
                              return _referenceButton(
                                iconAsset: AssetsManager.apple,
                                label: StringManager.signInWithApple.tr(),
                                height: buttonHeight,
                                iconSize: 21,
                                enabled: _isAgreementAccepted,
                                isLoading: state.requestStateApple.isLoading,
                                onTap: () {
                                  di<AuthPlatformBloc>().add(
                                    SignInAppleEvent(context: context),
                                  );
                                },
                              );
                            },
                          ),
                        ],

                        SizedBox(height: buttonGap),

                        BlocBuilder<AuthPlatformBloc, AuthPlatformState>(
                          bloc: di<AuthPlatformBloc>(),
                          buildWhen: (prev, curr) =>
                          prev.requestStateGuest !=
                              curr.requestStateGuest,
                          builder: (context, state) {
                            return _referenceButton(
                              iconAsset: AssetsManager.userProfileIcon,
                              label: StringManager.quickLogin.tr(),
                              height: buttonHeight,
                              iconSize: 21,
                              enabled: _isAgreementAccepted,
                              isLoading: state.requestStateGuest.isLoading,
                              onTap: () {
                                di<AuthPlatformBloc>().add(
                                  SignInGuestEvent(context: context),
                                );
                              },
                            );
                          },
                        ),

                        SizedBox(
                          height: (screenHeight * 0.028).clamp(16.0, 24.0),
                        ),

                        // "OR" divider, then a plain circular phone-login
                        // icon below it -- matching the reference design --
                        // in place of the old full-width gradient CTA.
                        Row(
                          children: [
                            Expanded(
                              child: Divider(
                                color: Colors.white.withValues(alpha: 0.45),
                                thickness: 1,
                              ),
                            ),
                            Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 12.w,
                              ),
                              child: Text(
                                'OR',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.85),
                                  fontSize: 12.5.sp,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Divider(
                                color: Colors.white.withValues(alpha: 0.45),
                                thickness: 1,
                              ),
                            ),
                          ],
                        ),

                        SizedBox(
                          height: (screenHeight * 0.028).clamp(16.0, 24.0),
                        ),

                        Material(
                          color: Colors.white.withValues(alpha: 0.16),
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: () {
                              if (!_isAgreementAccepted) {
                                _showAgreementRequired();
                                return;
                              }
                              context.pushNamedRoute(Routes.login);
                            },
                            child: SizedBox(
                              width: buttonHeight,
                              height: buttonHeight,
                              child: Padding(
                                padding: EdgeInsets.all(buttonHeight * 0.28),
                                child: Image.asset(
                                  AssetsManager.introPhoneIcon,
                                  color: Colors.white,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                          ),
                        ),

                        SizedBox(
                          height: (screenHeight * 0.035).clamp(20.0, 32.0),
                        ),

                        // Terms/agreement now sits at the very bottom of the
                        // page, checkbox included, matching the reference
                        // design, on request.
                        _agreementCard(context),

                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
            ],
            ),
          ),
    );
  }

  Widget _languageButton(BuildContext context) {
    final currentCode = context.locale.languageCode;
    final currentLanguage = _supportedLanguages.firstWhere(
          (item) => item['code'] == currentCode,
      orElse: () => _supportedLanguages.first,
    );

    return Material(
      color: const Color(0xFFF7F7F8),
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: () => _showLanguagePicker(context),
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.language_rounded,
                size: 19,
                color: Color(0xFF1C1C1E),
              ),
              const SizedBox(width: 7),
              Text(
                currentLanguage['name'] ?? 'English',
                style: TextStyle(
                  color: const Color(0xFF1C1C1E),
                  fontSize: 13.5.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 18,
                color: Color(0xFF737373),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showLanguagePicker(BuildContext pageContext) async {
    final currentCode = pageContext.locale.languageCode;

    final selectedCode = await showModalBottomSheet<String>(
      context: pageContext,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.10),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 38,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD8D8DC),
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF2F3F5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.translate_rounded,
                        size: 21,
                        color: Color(0xFF111111),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _chooseLanguageTitle(currentCode),
                        style: TextStyle(
                          color: const Color(0xFF111111),
                          fontSize: 19.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                ..._supportedLanguages.map((language) {
                  final code = language['code'] ?? 'en';
                  final isSelected = code == currentCode;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 7),
                    child: Material(
                      color: isSelected
                          ? const Color(0xFFF1F1F3)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                      child: InkWell(
                        onTap: () => Navigator.of(sheetContext).pop(code),
                        borderRadius: BorderRadius.circular(16),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 13,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  language['name'] ?? '',
                                  style: TextStyle(
                                    color: const Color(0xFF1B1B1D),
                                    fontSize: 15.5.sp,
                                    fontWeight: isSelected
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                  ),
                                ),
                              ),
                              if (isSelected)
                                Container(
                                  width: 24,
                                  height: 24,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF111111),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.check_rounded,
                                    size: 16,
                                    color: Colors.white,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );

    if (selectedCode == null ||
        selectedCode == currentCode ||
        !mounted) {
      return;
    }

    await pageContext.setLocale(Locale(selectedCode));
    DioFactory().updateLanguageHeader(selectedCode);
    di<LanguageBloc>().add(ChangeLanguageEvent(selectedCode));

    if (mounted) {
      setState(() {});
    }
  }

  String _chooseLanguageTitle(String code) {
    switch (code) {
      case 'ar':
        return 'اختر اللغة';
      case 'tr':
        return 'Dil seçin';
      case 'ur':
        return 'زبان منتخب کریں';
      case 'hi':
        return 'भाषा चुनें';
      case 'id':
        return 'Pilih bahasa';
      default:
        return 'Choose language';
    }
  }

  // Plain white pill (was a colored gradient pill spanning full width),
  // narrower with side margin, dark text/icon like the reference design,
  // on request.
  Widget _referenceButton({
    required String iconAsset,
    required String label,
    required VoidCallback onTap,
    required double height,
    required bool enabled,
    double iconSize = 22,
    bool isLoading = false,
  }) {
    // Stays fully solid white regardless of the agreement toggle (was
    // dimmed to 0.6 opacity when disabled, which read as translucent/grey
    // over the photo) -- disabled taps still surface the agreement
    // reminder via onTap below, on request.
    return Padding(
        padding: EdgeInsets.symmetric(horizontal: 28.w),
        child: SizedBox(
          width: double.infinity,
          height: height,
          child: Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(height / 2),
            child: InkWell(
              onTap: isLoading
                  ? null
                  : () {
                if (!enabled) {
                  _showAgreementRequired();
                  return;
                }
                onTap();
              },
              borderRadius: BorderRadius.circular(height / 2),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 20.w),
                child: Row(
                  children: [
                    SizedBox(
                      width: 34.w,
                      child: Center(
                        child: isLoading
                            ? SizedBox(
                          width: 21,
                          height: 21,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: Colors.black54,
                          ),
                        )
                            : Image.asset(
                          iconAsset,
                          width: iconSize.w,
                          height: iconSize.w,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Center(
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 15.5.sp,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 34.w),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
  }

  // Checkbox-gated agreement row, moved back to the very bottom of the
  // page, matching the reference design, on request. Text is white/light
  // since it now sits over the dark-scrimmed photo instead of solid white.
  Widget _agreementCard(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Padding(
          // Nudged up a bit more, and the checkbox's own built-in
          // Material tap-target padding is shrunk so it actually sits
          // centered against the text's middle instead of low against its
          // baseline, on request.
          padding: const EdgeInsets.only(bottom: 7),
          child: SizedBox(
            width: 22,
            height: 22,
            child: Checkbox(
              value: _isAgreementAccepted,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
              onChanged: (value) {
                setState(() {
                  _isAgreementAccepted = value ?? false;
                });
              },
              // Explicit fill for every state (was left to the Material
              // theme default, which rendered as a solid teal/green square
              // instead of a plain white-bordered box) -- white outline,
              // transparent unchecked, white fill when checked.
              fillColor: WidgetStateProperty.resolveWith((states) {
                return states.contains(WidgetState.selected)
                    ? Colors.white
                    : Colors.transparent;
              }),
              activeColor: Colors.white,
              checkColor: Colors.black,
              side: const BorderSide(
                color: Colors.white,
                width: 1.4,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(5),
              ),
            ),
          ),
        ),
        const SizedBox(width: 7),
        Flexible(
          child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 3,
        runSpacing: 2,
        children: [
          Text(
            StringManager.haveRead.tr(),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 12.sp,
              height: 1.35,
              fontWeight: FontWeight.w400,
            ),
          ),
          InkWell(
            onTap: () => context.pushNamedRoute(Routes.privacy),
            child: Text(
              StringManager.termsAndCondition.tr(),
              style: TextStyle(
                color: const Color(0xFFFFD54A),
                fontSize: 12.sp,
                height: 1.35,
                fontWeight: FontWeight.w700,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
          Text(
            '&',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 12.sp,
              height: 1.35,
            ),
          ),
          InkWell(
            onTap: () => context.pushNamedRoute(Routes.privacy),
            child: Text(
              StringManager.privacyPolicy_.tr(),
              style: TextStyle(
                color: const Color(0xFFFFD54A),
                fontSize: 12.sp,
                height: 1.35,
                fontWeight: FontWeight.w700,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
            ],
          ),
        ),
      ],
    );
  }

  void _showAgreementRequired() {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            StringManager.acceptTerms.tr(),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF202024),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          margin: const EdgeInsets.fromLTRB(18, 0, 18, 18),
          duration: const Duration(seconds: 2),
        ),
      );
  }
}
