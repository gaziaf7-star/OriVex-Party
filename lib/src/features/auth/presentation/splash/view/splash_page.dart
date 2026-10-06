import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:general/src/core/index.dart';
import 'package:general/src/features/auth/auth.dart';
import 'package:general/src/features/auth/presentation/splash/config_app/config_app_bloc.dart';
import 'package:ipapi/ipapi.dart';
import 'package:ipapi/models/geo_data.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with TickerProviderStateMixin {
  bool _hasNavigated = false;
  StreamSubscription<ConfigAppState>? _configSubscription;

  // Drives the one-shot staggered entrance: logo -> name -> tagline -> loader.
  late final AnimationController _introController;
  late final Animation<double> _logoScale;
  late final Animation<double> _logoOpacity;
  late final Animation<Offset> _nameSlide;
  late final Animation<double> _nameOpacity;
  late final Animation<double> _loaderOpacity;

  // Slow ambient breathing glow behind the logo, loops for as long as the
  // splash is on screen so it never feels static while config loads.
  late final AnimationController _glowController;

  @override
  void initState() {
    super.initState();

    _introController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1700),
    );

    _logoScale = CurvedAnimation(
      parent: _introController,
      curve: const Interval(0.0, 0.55, curve: Curves.easeOutBack),
    );

    _logoOpacity = CurvedAnimation(
      parent: _introController,
      curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
    );

    _nameSlide = Tween<Offset>(
      begin: const Offset(0, 0.18),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _introController,
        curve: const Interval(0.32, 0.68, curve: Curves.easeOutCubic),
      ),
    );

    _nameOpacity = CurvedAnimation(
      parent: _introController,
      curve: const Interval(0.32, 0.68, curve: Curves.easeOut),
    );

    _loaderOpacity = CurvedAnimation(
      parent: _introController,
      curve: const Interval(0.75, 1.0, curve: Curves.easeOut),
    );

    _introController.forward();

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat(reverse: true);

    if (Platform.isAndroid) {
      ConstantsManager.devicePlatform = StringManager.android;
    } else if (Platform.isIOS) {
      ConstantsManager.devicePlatform = StringManager.ios;
    }

    di<ConfigAppBloc>().add(
      ConfigAppEvent(
        devicePLATFORM: ConstantsManager.devicePlatform,
        versionApp: ConstantsManager.appVersionCode.toString(),
      ),
    );

    // Keep the existing splash navigation flow unchanged.
    _listenToConfigAndNavigate();

    // Keep the existing location bootstrap unchanged.
    _initLocation();
  }

  void _listenToConfigAndNavigate() {
    final configBloc = di<ConfigAppBloc>();

    if (configBloc.state.requestState.isLoaded ||
        configBloc.state.requestState.isEmpty ||
        configBloc.state.requestState.isError) {
      if (!_hasNavigated) {
        _hasNavigated = true;
        context.read<SplashBloc>().add(const SplashNavigationEvent());
      }
      return;
    }

    _configSubscription = configBloc.stream.listen((state) {
      if (state.requestState.isLoaded ||
          state.requestState.isEmpty ||
          state.requestState.isError) {
        if (!_hasNavigated) {
          _hasNavigated = true;
          context.read<SplashBloc>().add(const SplashNavigationEvent());
        }
        _configSubscription?.cancel();
      }
    });
  }

  Future<void> _initLocation() async {
    try {
      GeoData? geoData;
      geoData = await IpApi.getData();

      ConstantsManager.updateLocation(
        latitude: geoData?.lat ?? 0.0,
        longitude: geoData?.lon ?? 0.0,
        isoCode: geoData?.countryCode ?? "unknown",
      );
    } catch (e) {
      debugPrint('Error fetching location data: $e');
      ConstantsManager.updateLocation(
        latitude: 0.0,
        longitude: 0.0,
        isoCode: "unknown",
      );
    }
  }

  @override
  void dispose() {
    _configSubscription?.cancel();
    _introController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SplashBloc, SplashState>(
      buildWhen: (prev, curr) => prev != curr,
      builder: (context, state) {
        return Scaffold(
          backgroundColor: Colors.white,
          body: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final height = constraints.maxHeight;

              final logoSize = (width * 0.24).clamp(84.0, 118.0);
              final nameSize = (width * 0.068).clamp(20.0, 30.0);
              final centerTop = (height * 0.30).clamp(180.0, 310.0);

              return Stack(
                fit: StackFit.expand,
                children: [
                  // White background with a light-pink dotted party pattern
                  // -- no text over it, on request.
                  const ColoredBox(color: Colors.white),

                  const IgnorePointer(
                    child: CustomPaint(
                      painter: _ImPartySplashPatternPainter(),
                    ),
                  ),

                  // Soft central glow behind the app logo, breathing gently
                  // so the splash still feels alive while config loads.
                  Positioned(
                    top: centerTop - 54,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: AnimatedBuilder(
                        animation: _glowController,
                        builder: (context, child) {
                          final t = Curves.easeInOut.transform(
                            _glowController.value,
                          );
                          final glowSize = logoSize + 100 + (t * 22);
                          final glowStrength = 0.85 + (t * 0.3);

                          return Container(
                            width: glowSize,
                            height: glowSize,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  const Color(0xFFFF4BC8).withValues(
                                    alpha: 0.075 * glowStrength,
                                  ),
                                  const Color(0xFF7F5BFF).withValues(
                                    alpha: 0.045 * glowStrength,
                                  ),
                                  const Color(0xFF22C7FF).withValues(
                                    alpha: 0.015 * glowStrength,
                                  ),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),

                  SafeArea(
                    child: Column(
                      children: [
                        SizedBox(height: centerTop),

                        FadeTransition(
                          opacity: _logoOpacity,
                          child: ScaleTransition(
                            scale: _logoScale,
                            child: Container(
                              width: logoSize,
                              height: logoSize,
                              padding: EdgeInsets.all((logoSize * 0.025)),
                              decoration: BoxDecoration(
                                borderRadius:
                                BorderRadius.circular(logoSize * 0.24),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF7A3DF0)
                                        .withValues(alpha: 0.16),
                                    blurRadius: 34,
                                    spreadRadius: 2,
                                    offset: const Offset(0, 12),
                                  ),
                                  BoxShadow(
                                    color: const Color(0xFF24C7FF)
                                        .withValues(alpha: 0.10),
                                    blurRadius: 28,
                                    spreadRadius: 1,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius:
                                BorderRadius.circular(logoSize * 0.22),
                                child: Image.asset(
                                  AssetsManager.logo,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                          ),
                        ),

                        SizedBox(height: (height * 0.025).clamp(18.0, 28.0)),

                        FadeTransition(
                          opacity: _nameOpacity,
                          child: SlideTransition(
                            position: _nameSlide,
                            child: Text(
                              'Hello Party',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: nameSize,
                                height: 1,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -1.1,
                                color: const Color(0xFF3A3A3C),
                              ),
                            ),
                          ),
                        ),

                        const Spacer(),

                        // Small loading indicator only at the very bottom --
                        // no caption text underneath, on request.
                        FadeTransition(
                          opacity: _loaderOpacity,
                          child: Padding(
                            padding: EdgeInsets.only(
                              bottom: (height * 0.055).clamp(32.0, 58.0),
                            ),
                            child: LoadingAnimationWidget.threeArchedCircle(
                              color: const Color(0xFFFF7EB6),
                              size: (width * 0.07).clamp(22.0, 30.0),
                            ),
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
      },
    );
  }
}

// Plain light-pink dot scatter over the white background -- replaced the
// star/sparkle/ring shapes with simple dots, on request.
class _ImPartySplashPatternPainter extends CustomPainter {
  const _ImPartySplashPatternPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(27);
    final dotPaint = Paint()
      ..color = const Color(0xFFFF7EB6).withValues(alpha: 0.16)
      ..style = PaintingStyle.fill;

    final cellW = size.width / 6;
    final cellH = size.height / 12;

    for (int row = 0; row < 13; row++) {
      for (int col = 0; col < 7; col++) {
        final dx = col * cellW +
            (row.isOdd ? cellW * 0.5 : 0) +
            random.nextDouble() * 10;
        final dy = row * cellH + random.nextDouble() * 10;

        if (dx > size.width || dy > size.height) continue;

        final radius = 2.0 + random.nextDouble() * 3.0;
        canvas.drawCircle(Offset(dx, dy), radius, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}