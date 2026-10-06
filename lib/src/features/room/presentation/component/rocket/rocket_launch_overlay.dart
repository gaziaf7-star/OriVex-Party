import 'dart:async';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:general/src/core/index.dart';

import 'rocket_realtime_controller.dart';

/// Full-screen realtime rocket launch overlay.
///
/// Current app realtime/reward flow is preserved, while the launch scene uses
/// a more cinematic countdown -> powered launch -> reward transition.
class RocketLaunchOverlay extends StatelessWidget {
  const RocketLaunchOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Map<String, dynamic>?>(
      valueListenable: RocketRealtimeController.instance.launchEvent,
      builder: (context, data, _) {
        if (data == null) return const SizedBox.shrink();

        return Positioned.fill(
          child: IgnorePointer(
            ignoring: false,
            child: _LaunchScene(
              key: ValueKey(data['event_id'] ?? data['launch_id']),
              data: data,
            ),
          ),
        );
      },
    );
  }
}

class _LaunchScene extends StatefulWidget {
  final Map<String, dynamic> data;

  const _LaunchScene({super.key, required this.data});

  @override
  State<_LaunchScene> createState() => _LaunchSceneState();
}

class _LaunchSceneState extends State<_LaunchScene>
    with TickerProviderStateMixin {
  static const int _countdownStart = 7;
  static const Duration _flightDuration = Duration(milliseconds: 1750);
  static const Duration _rewardDuration = Duration(seconds: 6);

  late final AnimationController _flightController;
  late final AnimationController _ambientController;
  late final Animation<double> _flightCurve;

  Timer? _countdownTimer;
  Timer? _launchDelayTimer;
  Timer? _rewardTimer;

  AudioPlayer? _launchSoundPlayer;

  int _countdown = _countdownStart;
  bool _launchStarted = false;
  bool _showReward = false;
  bool _soundStarted = false;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();

    _flightController = AnimationController(
      vsync: this,
      duration: _flightDuration,
    );

    _ambientController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();

    _flightCurve = CurvedAnimation(
      parent: _flightController,
      curve: Curves.easeInCubic,
    );

    _flightController.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted && !_showReward) {
        setState(() => _showReward = true);
        _rewardTimer?.cancel();
        _rewardTimer = Timer(_rewardDuration, () {
          if (mounted) RocketRealtimeController.instance.finishLaunch();
        });
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _startCountdown();
    });
  }

  Map<String, dynamic>? _asMap(dynamic value) =>
      value is Map ? Map<String, dynamic>.from(value) : null;

  List<Map<String, dynamic>> _asMapList(dynamic value) => value is List
      ? value
      .whereType<Map>()
      .map((e) => Map<String, dynamic>.from(e))
      .toList()
      : <Map<String, dynamic>>[];

  String _text(dynamic value) {
    final text = value?.toString().trim() ?? '';
    return text.toLowerCase() == 'null' ? '' : text;
  }

  String get _levelNo {
    final level = _asMap(widget.data['level']);
    return _text(
      widget.data['level_no'] ?? level?['level_no'] ?? level?['level'],
    );
  }

  String get _rocketImage {
    final level = _asMap(widget.data['level']);
    return _text(
      widget.data['rocket_image'] ??
          widget.data['rocket_image_url'] ??
          level?['rocket_image'] ??
          level?['rocket_image_url'] ??
          level?['platform_image'] ??
          level?['image'],
    );
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdown = _countdownStart;

    // Same timing style as the supplied reference overlay: sound starts with
    // the launch scene/countdown and carries through the actual take-off.
    unawaited(_playLaunchSound());

    if (mounted) setState(() {});

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _launchStarted) {
        timer.cancel();
        return;
      }

      final next = _countdown - 1;
      if (next <= 1) {
        timer.cancel();
        setState(() => _countdown = 1);

        _launchDelayTimer?.cancel();
        _launchDelayTimer = Timer(
          const Duration(milliseconds: 520),
          _startRocketLaunch,
        );
        return;
      }

      setState(() => _countdown = next);
    });
  }

  Future<void> _playLaunchSound() async {
    if (_soundStarted || _disposed) return;
    _soundStarted = true;

    try {
      final player = AudioPlayer();
      _launchSoundPlayer = player;
      await player.setReleaseMode(ReleaseMode.stop);
      await player.setVolume(1.0);
      await player.play(
        AssetSource('sounds/roketSound.mp3'),
        volume: 1.0,
      );
      Methods.printLog('✅ [Rocket] launch sound started');
    } catch (e) {
      Methods.printLog('⚠️ [Rocket] launch sound failed: $e');
    }
  }

  void _startRocketLaunch() {
    if (_launchStarted || !mounted) return;
    setState(() => _launchStarted = true);
    _flightController.forward(from: 0);
  }

  Future<void> _disposeSound() async {
    final player = _launchSoundPlayer;
    _launchSoundPlayer = null;
    if (player == null) return;

    try {
      await player.dispose();
    } catch (_) {}
  }

  @override
  void dispose() {
    _disposed = true;
    _countdownTimer?.cancel();
    _launchDelayTimer?.cancel();
    _rewardTimer?.cancel();
    _ambientController.dispose();
    _flightController.dispose();
    unawaited(_disposeSound());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _showReward
          ? () => RocketRealtimeController.instance.finishLaunch()
          : null,
      child: Stack(
        fit: StackFit.expand,
        children: [
          AnimatedOpacity(
            duration: const Duration(milliseconds: 220),
            opacity: _showReward ? 0 : 1,
            child: Container(color: Colors.black.withValues(alpha: .18)),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 320),
            child: _showReward
                ? _RewardBoard(
              key: const ValueKey('reward'),
              levelNo: _levelNo,
              data: widget.data,
            )
                : _GorgeousFlightScene(
              key: const ValueKey('flight'),
              levelNo: _levelNo,
              rocketImage: _rocketImage,
              countdown: _countdown,
              launchStarted: _launchStarted,
              flightController: _flightController,
              flightCurve: _flightCurve,
              ambientController: _ambientController,
            ),
          ),
        ],
      ),
    );
  }
}

class _GorgeousFlightScene extends StatelessWidget {
  final String levelNo;
  final String rocketImage;
  final int countdown;
  final bool launchStarted;
  final AnimationController flightController;
  final Animation<double> flightCurve;
  final AnimationController ambientController;

  const _GorgeousFlightScene({
    super.key,
    required this.levelNo,
    required this.rocketImage,
    required this.countdown,
    required this.launchStarted,
    required this.flightController,
    required this.flightCurve,
    required this.ambientController,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        final rocketWidth = (width * 1.02).clamp(340.0, 620.0).toDouble();
        final rocketHeight = (height * .78).clamp(510.0, 900.0).toDouble();

        return Stack(
          fit: StackFit.expand,
          alignment: Alignment.center,
          children: [
            RepaintBoundary(
              child: CustomPaint(
                painter: _RocketLaunchEnergyPainter(
                  animation: ambientController,
                  intensity: launchStarted ? 1 : .82,
                  launching: launchStarted,
                ),
              ),
            ),

            // Main rocket movement.
            AnimatedBuilder(
              animation: flightController,
              builder: (context, child) {
                final t = flightCurve.value;
                final y = launchStarted ? -(height * .90 * t) : 0.0;
                final scale = launchStarted
                    ? 1 +
                    (.12 *
                        (1 - (t - .28).abs())
                            .clamp(0.0, 1.0)
                            .toDouble())
                    : 1.0;
                final opacity = t < .82
                    ? 1.0
                    : (1 - ((t - .82) / .18))
                    .clamp(0.0, 1.0)
                    .toDouble();

                return Transform.translate(
                  offset: Offset(0, y),
                  child: Transform.scale(
                    scale: scale,
                    child: Opacity(opacity: opacity, child: child),
                  ),
                );
              },
              child: Align(
                alignment: const Alignment(0, .83),
                child: SizedBox(
                  width: rocketWidth,
                  height: rocketHeight,
                  child: Stack(
                    fit: StackFit.expand,
                    alignment: Alignment.center,
                    children: [
                      _StaticRocketImage(rocketImage: rocketImage),
                      if (launchStarted)
                        const Positioned(
                          bottom: 7,
                          child: _RocketEngineFlame(),
                        ),
                    ],
                  ),
                ),
              ),
            ),

            // Large countdown stays above the rocket until launch starts.
            Positioned(
              top: height * .27,
              left: 0,
              right: 0,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 180),
                opacity: launchStarted ? 0 : 1,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 420),
                      switchInCurve: Curves.linear,
                      switchOutCurve: Curves.linear,
                      transitionBuilder: (child, animation) {
                        final fade = CurvedAnimation(
                          parent: animation,
                          curve: Curves.easeOutCubic,
                          reverseCurve: Curves.easeInCubic,
                        );
                        final scale = Tween<double>(begin: .68, end: 1).animate(
                          CurvedAnimation(
                            parent: animation,
                            curve: Curves.easeOutBack,
                            reverseCurve: Curves.easeInCubic,
                          ),
                        );
                        return FadeTransition(
                          opacity: fade,
                          child: ScaleTransition(scale: scale, child: child),
                        );
                      },
                      child: _BigRocketCountdownNumber(
                        key: ValueKey(countdown),
                        value: countdown,
                        fontSize: (width * .27).clamp(100.0, 158.0).toDouble(),
                      ),
                    ),
                    2.hBox,
                    TextWidget(
                      levelNo.isNotEmpty
                          ? 'LV.$levelNo Launching'
                          : 'Rocket Launching',
                      style: context.bodyMedium
                          .size(15)
                          .w900
                          .colorExt(ColorManager.white),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _StaticRocketImage extends StatelessWidget {
  final String rocketImage;

  const _StaticRocketImage({required this.rocketImage});

  @override
  Widget build(BuildContext context) {
    if (rocketImage.isEmpty) {
      return Icon(
        Icons.rocket_launch_rounded,
        color: ColorManager.white,
        size: 190.sp,
        shadows: const [
          Shadow(color: Color(0xFF00E5FF), blurRadius: 26),
        ],
      );
    }

    return ImageViewWidget(
      url: rocketImage,
      boxFit: BoxFit.contain,
    );
  }
}

class _RocketEngineFlame extends StatefulWidget {
  const _RocketEngineFlame();

  @override
  State<_RocketEngineFlame> createState() => _RocketEngineFlameState();
}

class _RocketEngineFlameState extends State<_RocketEngineFlame> {
  bool _large = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 90), (_) {
      if (mounted) setState(() => _large = !_large);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 85),
      width: _large ? 56.w : 44.w,
      height: _large ? 130.h : 108.h,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(28.r),
          bottom: Radius.circular(50.r),
        ),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFFFFFFF),
            Color(0xFF7FFFFF),
            Color(0xFF16D8FF),
            Color(0xFF1377FF),
            Color(0x001377FF),
          ],
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0xFF4BF4FF),
            blurRadius: 28,
            spreadRadius: 4,
          ),
          BoxShadow(
            color: Color(0xFF176DFF),
            blurRadius: 42,
            spreadRadius: 7,
          ),
        ],
      ),
    );
  }
}

class _BigRocketCountdownNumber extends StatelessWidget {
  final int value;
  final double fontSize;

  const _BigRocketCountdownNumber({
    super.key,
    required this.value,
    required this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    final base = TextStyle(
      fontSize: fontSize,
      height: .80,
      fontWeight: FontWeight.w900,
      letterSpacing: -4,
    );

    return RepaintBoundary(
      child: Stack(
        alignment: Alignment.center,
        children: [
          Text(
            '$value',
            style: base.copyWith(
              foreground: Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 17
                ..color = const Color(0x8800DFFF),
              shadows: const [
                Shadow(color: Color(0xFF00EAFF), blurRadius: 30),
                Shadow(color: Color(0xFF006DFF), blurRadius: 42),
              ],
            ),
          ),
          Text(
            '$value',
            style: base.copyWith(
              foreground: Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 9
                ..color = const Color(0xFF15336F),
              shadows: const [
                Shadow(
                  color: Colors.black87,
                  blurRadius: 11,
                  offset: Offset(0, 5),
                ),
              ],
            ),
          ),
          Text(
            '$value',
            style: base.copyWith(
              foreground: Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 4.5
                ..color = const Color(0xFFFFFFF2),
              shadows: const [
                Shadow(color: Color(0xFFFFC400), blurRadius: 18),
              ],
            ),
          ),
          ShaderMask(
            blendMode: BlendMode.srcIn,
            shaderCallback: (bounds) => const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFFFFFFFF),
                Color(0xFFFFF891),
                Color(0xFFFFC400),
                Color(0xFFFF7900),
              ],
              stops: [0, .28, .68, 1],
            ).createShader(bounds),
            child: Text('$value', style: base.copyWith(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class _RocketLaunchEnergyPainter extends CustomPainter {
  _RocketLaunchEnergyPainter({
    required this.animation,
    required this.intensity,
    required this.launching,
  }) : super(repaint: animation);

  final Animation<double> animation;
  final double intensity;
  final bool launching;

  double _noise(int seed) {
    final value = math.sin(seed * 12.9898) * 43758.5453;
    return value - value.floorToDouble();
  }

  void _drawLightning(
      Canvas canvas,
      Size size, {
        required double baseX,
        required double startY,
        required double endY,
        required int seed,
        required double direction,
        required double alpha,
      }) {
    final path = Path()..moveTo(baseX, startY);
    const points = 10;

    for (int i = 1; i <= points; i++) {
      final progress = i / points;
      final y = startY + ((endY - startY) * progress);
      final spread = (10 + (_noise(seed + i) * 35)) * direction;
      final centerPull = (size.width * .5 - baseX) * progress * .22;
      path.lineTo(baseX + spread + centerPull, y);
    }

    final outer = Paint()
      ..color = const Color(0xFF008CFF).withValues(alpha: alpha * .45)
      ..strokeWidth = 7
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7);
    canvas.drawPath(path, outer);

    final core = Paint()
      ..color = const Color(0xFFD9FFFF).withValues(alpha: alpha)
      ..strokeWidth = 1.7
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, core);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final t = animation.value;
    final full = Offset.zero & size;
    final pulse = .82 + (math.sin(t * math.pi * 2) * .10);

    final backdrop = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFF03165C).withValues(alpha: .46 * intensity),
          const Color(0xFF041B65).withValues(alpha: .34 * intensity),
          const Color(0xFF031444).withValues(alpha: .45 * intensity),
          const Color(0xFF010817).withValues(alpha: .66 * intensity),
        ],
      ).createShader(full);
    canvas.drawRect(full, backdrop);

    final haloCenter = Offset(size.width * .5, size.height * .48);
    final halo = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFD7FFFF)
              .withValues(alpha: .18 * intensity * pulse),
          const Color(0xFF00DFFF)
              .withValues(alpha: .27 * intensity * pulse),
          const Color(0xFF005EFF).withValues(alpha: .18 * intensity),
          Colors.transparent,
        ],
        stops: const [0, .25, .60, 1],
      ).createShader(
        Rect.fromCircle(center: haloCenter, radius: size.width * .76),
      );
    canvas.drawCircle(haloCenter, size.width * .76, halo);

    // Moving vertical energy rails.
    for (int i = 0; i < 42; i++) {
      final x = size.width * _noise(i + 3);
      final speed = .30 + (_noise(i + 90) * 1.10);
      final length = 100 + (_noise(i + 170) * 330);
      final y = ((t * size.height * speed) +
          (_noise(i + 44) * size.height * 1.5)) %
          (size.height + length) -
          length;
      final alpha = (.07 + (_noise(i + 210) * .30)) * intensity;
      final railWidth = .65 + (_noise(i + 260) * 2.2);

      final rail = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            const Color(0xFFB7FFFF).withValues(alpha: alpha),
            const Color(0xFF00D9FF).withValues(alpha: alpha),
            const Color(0xFF2169FF).withValues(alpha: alpha * .9),
            Colors.transparent,
          ],
        ).createShader(Rect.fromLTWH(x, y, railWidth + 3, length))
        ..strokeWidth = railWidth
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(Offset(x, y), Offset(x, y + length), rail);
    }

    // Central blue launch beam.
    final beamRect = Rect.fromLTWH(
      size.width * .15,
      0,
      size.width * .70,
      size.height,
    );
    final beam = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.transparent,
          const Color(0xFFAAFFFF)
              .withValues(alpha: .12 * intensity * pulse),
          const Color(0xFF00EAFF)
              .withValues(alpha: .36 * intensity * pulse),
          const Color(0xFF006DFF)
              .withValues(alpha: .24 * intensity * pulse),
          Colors.transparent,
        ],
      ).createShader(beamRect);
    canvas.drawRect(beamRect, beam);

    // Exhaust pillars visible under the rocket.
    final engineY = size.height * .73;
    for (int i = -2; i <= 2; i++) {
      final x = size.width * .5 + (i * size.width * .082);
      final pillarWidth = size.width * (i == 0 ? .08 : .052);
      final sway = math.sin((t * math.pi * 2) + i) * 9;
      final rect = Rect.fromLTWH(
        x - (pillarWidth / 2),
        engineY + sway,
        pillarWidth,
        size.height - engineY + 70,
      );

      final exhaust = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFFFFFFFF).withValues(alpha: .90 * intensity),
            const Color(0xFFB8FFFF).withValues(alpha: .84 * intensity),
            const Color(0xFF00DFFF).withValues(alpha: .58 * intensity),
            const Color(0xFF006DFF).withValues(alpha: .16 * intensity),
            Colors.transparent,
          ],
        ).createShader(rect)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(pillarWidth)),
        exhaust,
      );
    }

    // Floating electric particles.
    for (int i = 0; i < 48; i++) {
      final x = size.width * _noise(i + 400);
      final speed = .22 + (_noise(i + 470) * .82);
      final y = size.height -
          (((t * size.height * speed) + (_noise(i + 520) * size.height)) %
              size.height);
      final radius = .65 + (_noise(i + 590) * 2.3);
      final color = i.isEven
          ? const Color(0xFFB9FFFF)
          : const Color(0xFF4B9CFF);
      final particle = Paint()
        ..color = color.withValues(
          alpha: (.15 + (_noise(i + 630) * .54)) * intensity,
        )
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.2);
      canvas.drawCircle(Offset(x, y), radius, particle);
    }

    // Expanding launch-pad rings.
    final pad = Offset(size.width * .5, size.height * .81);
    for (int i = 0; i < 5; i++) {
      final local = (t + (i * .19)) % 1;
      final radius = size.width * (.15 + (.44 * local));
      final ring = Paint()
        ..color = const Color(0xFFA7FFFF)
            .withValues(alpha: (1 - local) * .46 * intensity)
        ..strokeWidth = 1.2 + ((1 - local) * 2.4)
        ..style = PaintingStyle.stroke;
      canvas.drawOval(
        Rect.fromCenter(
          center: pad,
          width: radius * 2,
          height: radius * .34,
        ),
        ring,
      );
    }

    // Lightning on both sides.
    final boltAlpha = (launching ? .98 : .60) * intensity;
    _drawLightning(
      canvas,
      size,
      baseX: size.width * .06,
      startY: size.height * .22,
      endY: size.height * .94,
      seed: 1200 + (t * 100).floor(),
      direction: 1,
      alpha: boltAlpha,
    );
    _drawLightning(
      canvas,
      size,
      baseX: size.width * .94,
      startY: size.height * .17,
      endY: size.height * .91,
      seed: 1400 + (t * 100).floor(),
      direction: -1,
      alpha: boltAlpha,
    );

    // Extra flash during actual take-off.
    if (launching) {
      final flash = (math.sin(t * math.pi * 4).abs() * .12) + .04;
      canvas.drawRect(
        full,
        Paint()
          ..color = const Color(0xFFC5FFFF)
              .withValues(alpha: flash * intensity),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RocketLaunchEnergyPainter oldDelegate) {
    return oldDelegate.intensity != intensity ||
        oldDelegate.launching != launching;
  }
}


class _RewardBoard extends StatelessWidget {
  final String levelNo;
  final Map<String, dynamic> data;

  const _RewardBoard({
    super.key,
    required this.levelNo,
    required this.data,
  });

  Map<String, dynamic> _asMap(dynamic value) =>
      value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

  List<Map<String, dynamic>> _asMapList(dynamic value) => value is List
      ? value
      .whereType<Map>()
      .map((e) => Map<String, dynamic>.from(e))
      .toList()
      : <Map<String, dynamic>>[];

  String _text(dynamic value, [String fallback = '']) {
    final text = value?.toString().trim() ?? '';
    if (text.isEmpty || text.toLowerCase() == 'null') return fallback;
    return text;
  }

  int _int(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ??
        double.tryParse(value?.toString() ?? '')?.toInt() ??
        0;
  }

  Map<String, dynamic> _userFrom(dynamic raw) {
    final row = _asMap(raw);
    if (row.isEmpty) return <String, dynamic>{};
    final nested = _asMap(
      row['user'] ??
          row['winner'] ??
          row['receiver'] ??
          row['sender'] ??
          row['member'] ??
          row['profile'],
    );
    return nested.isEmpty ? row : <String, dynamic>{...row, ...nested};
  }

  int _userId(Map<String, dynamic> row) {
    final user = _userFrom(row);
    return _int(
      row['user_id'] ??
          row['winner_user_id'] ??
          row['receiver_id'] ??
          user['id'] ??
          user['user_id'],
    );
  }

  String _groupKey(dynamic value, {int rank = 0}) {
    String key = _text(value).toLowerCase().replaceAll(' ', '');
    key = key.replaceAll('-', '').replaceAll('_', '');
    if (key == 'top1' || key == '1' || rank == 1) return 'top1';
    if (key == 'top2' || key == '2' || rank == 2) return 'top2';
    if (key == 'top3' || key == '3' || rank == 3) return 'top3';
    if (key == 'inroom' || key == 'room' || key == 'in') return 'in_room';
    return key;
  }

  Map<String, dynamic> _normalizeReward(Map<String, dynamic> raw) {
    final reward = _asMap(
      raw['reward'] ??
          raw['rocket_reward'] ??
          raw['gift'] ??
          raw['asset'] ??
          raw['vip_package'],
    );
    final reference = _asMap(reward['reference'] ?? raw['reference']);
    return <String, dynamic>{
      ...reward,
      ...raw,
      'reference': reference,
      'title': raw['reward_title'] ?? raw['title'] ?? reward['title'] ?? reward['name'],
      'image': raw['reward_image'] ??
          raw['image'] ??
          raw['show_image'] ??
          reward['image'] ??
          reward['show_image'] ??
          reward['badge_image'] ??
          reference['asset'] ??
          reference['image'],
      'amount': raw['amount'] ?? raw['quantity'] ?? reward['amount'] ?? reward['quantity'],
      'duration_days': raw['duration_days'] ?? raw['days'] ?? reward['duration_days'] ?? reward['days'],
      'reward_type': raw['reward_type'] ?? raw['type'] ?? reward['reward_type'] ?? reward['type'],
    };
  }

  String _rewardImage(Map<String, dynamic> item) {
    final reward = _asMap(item['reward']);
    final reference = _asMap(item['reference'] ?? reward['reference']);
    return _text(
      item['reward_image'] ??
          item['image'] ??
          item['show_image'] ??
          item['badge_image'] ??
          reward['image'] ??
          reward['show_image'] ??
          reference['asset'] ??
          reference['image'],
    );
  }

  String _rewardTitle(Map<String, dynamic> item) {
    return _text(
      item['reward_title'] ??
          item['title'] ??
          item['name'] ??
          item['reward_name'] ??
          item['reward_type'],
      'Reward',
    );
  }

  String _compactAmount(int value) {
    if (value >= 1000000000) {
      final amount = value / 1000000000;
      return '${amount.toStringAsFixed(value % 1000000000 == 0 ? 0 : 1)}B';
    }
    if (value >= 1000000) {
      final amount = value / 1000000;
      return '${amount.toStringAsFixed(value % 1000000 == 0 ? 0 : 1)}M';
    }
    if (value >= 1000) {
      final amount = value / 1000;
      return '${amount.toStringAsFixed(value % 1000 == 0 ? 0 : 1)}K';
    }
    return '$value';
  }

  String _rewardAmountText(Map<String, dynamic> item) {
    final type = _text(item['reward_type'] ?? item['type']).toLowerCase();
    final amount = _int(item['amount'] ?? item['quantity'] ?? item['coin'] ?? item['coins']);
    final days = _int(item['duration_days'] ?? item['days'] ?? item['validity']);

    if (days > 0 &&
        (type.contains('asset') ||
            type.contains('frame') ||
            type.contains('vip') ||
            type.contains('title') ||
            type.contains('badge'))) {
      return 'X $days Days';
    }
    if (amount > 0) {
      return type.contains('coin') ? _compactAmount(amount) : 'X ${_compactAmount(amount)}';
    }
    return days > 0 ? 'X $days Days' : 'X 1';
  }

  Color _groupBadgeColor(String group) {
    switch (group) {
      case 'top1':
        return const Color(0xFFFFCF4A);
      case 'top2':
        return const Color(0xFFC7ECFF);
      case 'top3':
        return const Color(0xFFFFB58F);
      default:
        return const Color(0xFF78EFF7);
    }
  }

  String _groupLabel(String group) {
    switch (group) {
      case 'top1':
        return 'TOP1';
      case 'top2':
        return 'TOP2';
      case 'top3':
        return 'TOP3';
      default:
        return 'IN ROOM';
    }
  }

  List<_RewardWinnerRow> _buildRows() {
    final winners = _asMapList(
      data['winners'] ?? data['winner_rows'] ?? data['reward_winners'],
    );
    List<Map<String, dynamic>> logs = _asMapList(
      data['delivered_reward_logs'] ??
          data['reward_logs'] ??
          data['rewards_logs'] ??
          data['reward_results'],
    );

    if (logs.isEmpty && data['reward_results'] is Map) {
      final rewardResults = _asMap(data['reward_results']);
      logs = _asMapList(rewardResults['items'] ?? rewardResults['winners']);
    }

    final List<_RewardWinnerRow> rows = [];
    final Set<String> added = <String>{};

    void addFromSource(Map<String, dynamic> source, {String? forcedGroup, int? forcedRank}) {
      final user = _userFrom(source);
      if (user.isEmpty) return;
      final uid = _userId(source);
      final name = _text(user['name'] ?? user['username'] ?? user['user_name'], 'User');
      final rank = forcedRank ?? _int(source['rank'] ?? source['position']);
      final group = forcedGroup ?? _groupKey(
        source['winner_group'] ?? source['group'] ?? source['slot'] ?? source['rank_title'],
        rank: rank,
      );
      final identity = uid > 0 ? '$uid-$group' : '$name-$group';
      if (!added.add(identity)) return;

      List<Map<String, dynamic>> rewards = [];

      final embeddedRewards = _asMapList(source['rewards'] ?? source['items']);
      if (embeddedRewards.isNotEmpty) {
        rewards = embeddedRewards.map(_normalizeReward).toList();
      }

      if (rewards.isEmpty) {
        final directReward = _normalizeReward(source);
        final directImage = _rewardImage(directReward);
        if (directImage.isNotEmpty || _text(directReward['title']).isNotEmpty) {
          rewards = [directReward];
        }
      }

      if (logs.isNotEmpty) {
        final matched = logs.where((row) {
          final logUid = _userId(row);
          final logRank = _int(row['rank'] ?? row['position']);
          final logGroup = _groupKey(
            row['winner_group'] ?? row['group'] ?? row['slot'] ?? row['rank_title'],
            rank: logRank,
          );
          if (uid > 0 && logUid > 0) return uid == logUid;
          if (group.isNotEmpty && logGroup == group) return true;
          return false;
        }).map(_normalizeReward).toList();
        if (matched.isNotEmpty) rewards = matched;
      }

      rows.add(_RewardWinnerRow(
        group: group,
        rank: rank,
        user: user,
        rewards: rewards,
      ));
    }

    for (final winner in winners) {
      addFromSource(winner);
    }

    if (rows.isEmpty) {
      for (final log in logs) {
        addFromSource(log);
      }
    }

    if (rows.isEmpty) {
      const groups = ['top1', 'top2', 'top3', 'in_room'];
      for (final g in groups) {
        final raw = data[g] ?? data[g.replaceAll('_', '')];
        for (final item in _asMapList(raw)) {
          addFromSource(item, forcedGroup: g);
        }
      }
    }

    rows.sort((a, b) {
      int weight(String g) {
        switch (g) {
          case 'top1':
            return 1;
          case 'top2':
            return 2;
          case 'top3':
            return 3;
          default:
            return 99;
        }
      }
      final aw = weight(a.group);
      final bw = weight(b.group);
      if (aw != bw) return aw.compareTo(bw);
      if (a.rank != b.rank && a.rank > 0 && b.rank > 0) return a.rank.compareTo(b.rank);
      return 0;
    });

    return rows;
  }

  @override
  Widget build(BuildContext context) {
    final rows = _buildRows();
    return Center(
      child: Container(
        margin: context.paddingSymmetric(horizontal: 16),
        padding: context.paddingSymmetric(horizontal: 14, vertical: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18.r),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1A46A8), Color(0xFF0F2B7A), Color(0xFF081C52)],
          ),
          border: Border.all(color: const Color(0xFF6FE3FF), width: 1.6),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1EDCFF).withValues(alpha: .25),
              blurRadius: 24,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.rocket_launch_rounded,
              color: const Color(0xFFFFD748),
              size: 34.sp,
            ),
            8.hBox,
            TextWidget(
              levelNo.isNotEmpty ? 'LV.$levelNo Reward' : 'Rocket Reward',
              style: context.titleLarge.w900.colorExt(ColorManager.white),
            ),
            6.hBox,
            TextWidget(
              'Winner profile and reward',
              style: context.bodySmall.colorExt(
                ColorManager.white.withValues(alpha: 0.75),
              ),
            ),
            14.hBox,
            if (rows.isEmpty)
              Padding(
                padding: context.paddingSymmetric(vertical: 14),
                child: TextWidget(
                  StringManager.noDataYet.tr(),
                  style: context.bodySmall.colorExt(
                    ColorManager.white.withValues(alpha: 0.7),
                  ),
                ),
              )
            else
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: 360.h),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: rows.length,
                  separatorBuilder: (_, __) => 10.hBox,
                  itemBuilder: (context, i) => _WinnerRewardTile(
                    row: rows[i],
                    groupBadgeColor: _groupBadgeColor(rows[i].group),
                    groupLabel: _groupLabel(rows[i].group),
                    rewardTitle: _rewardTitle,
                    rewardImage: _rewardImage,
                    rewardAmountText: _rewardAmountText,
                  ),
                ),
              ),
            16.hBox,
            GestureDetector(
              onTap: () => RocketRealtimeController.instance.finishLaunch(),
              child: Container(
                padding: context.paddingSymmetric(horizontal: 24, vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20.r),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF31D7D7), Color(0xFF087984)],
                  ),
                ),
                child: TextWidget(
                  'OK',
                  style: context.bodyMedium.w800.colorExt(ColorManager.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RewardWinnerRow {
  final String group;
  final int rank;
  final Map<String, dynamic> user;
  final List<Map<String, dynamic>> rewards;

  const _RewardWinnerRow({
    required this.group,
    required this.rank,
    required this.user,
    required this.rewards,
  });
}

class _WinnerRewardTile extends StatelessWidget {
  final _RewardWinnerRow row;
  final Color groupBadgeColor;
  final String groupLabel;
  final String Function(Map<String, dynamic>) rewardTitle;
  final String Function(Map<String, dynamic>) rewardImage;
  final String Function(Map<String, dynamic>) rewardAmountText;

  const _WinnerRewardTile({
    required this.row,
    required this.groupBadgeColor,
    required this.groupLabel,
    required this.rewardTitle,
    required this.rewardImage,
    required this.rewardAmountText,
  });

  @override
  Widget build(BuildContext context) {
    final name = (row.user['name'] ?? row.user['username'] ?? row.user['user_name'] ?? 'User').toString();
    final avatar = (row.user['profile_image'] ?? row.user['avatar'] ?? row.user['image'] ?? '').toString();

    return Container(
      padding: context.paddingAll(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14.r),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x1A6FE3FF), Color(0x10244C9A)],
        ),
        border: Border.all(
          color: const Color(0xFF6FE3FF).withValues(alpha: 0.55),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90.w,
            child: Column(
              children: [
                UserImage(
                  image: avatar,
                  displayName: name,
                  imageSize: 46.w,
                  uniquId: '${row.user['id'] ?? row.user['user_id'] ?? name}',
                ),
                6.hBox,
                TextWidget(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: context.bodySmall.w800.colorExt(ColorManager.white),
                ),
                5.hBox,
                Container(
                  padding: context.paddingSymmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: groupBadgeColor,
                    borderRadius: BorderRadius.circular(5.r),
                  ),
                  child: TextWidget(
                    groupLabel,
                    style: context.bodySmall.size(9).w900.colorExt(const Color(0xFF443100)),
                  ),
                ),
              ],
            ),
          ),
          10.wBox,
          Expanded(
            child: row.rewards.isEmpty
                ? Container(
              height: 84.h,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10.r),
                color: const Color(0x22000000),
                border: Border.all(
                  color: const Color(0xFF54DCE3).withValues(alpha: .24),
                ),
              ),
              child: TextWidget(
                'No reward data',
                style: context.bodySmall.colorExt(
                  ColorManager.white.withValues(alpha: 0.55),
                ),
              ),
            )
                : SizedBox(
              height: 102.h,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: row.rewards.length,
                separatorBuilder: (_, __) => 8.wBox,
                itemBuilder: (context, index) => _WinnerRewardCard(
                  item: row.rewards[index],
                  featured: row.group == 'top1' && index == 0,
                  rewardTitle: rewardTitle,
                  rewardImage: rewardImage,
                  rewardAmountText: rewardAmountText,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WinnerRewardCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final bool featured;
  final String Function(Map<String, dynamic>) rewardTitle;
  final String Function(Map<String, dynamic>) rewardImage;
  final String Function(Map<String, dynamic>) rewardAmountText;

  const _WinnerRewardCard({
    required this.item,
    required this.featured,
    required this.rewardTitle,
    required this.rewardImage,
    required this.rewardAmountText,
  });

  @override
  Widget build(BuildContext context) {
    final image = rewardImage(item);
    return Container(
      width: 84.w,
      padding: EdgeInsets.fromLTRB(6.w, 6.h, 6.w, 6.h),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10.r),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: featured
              ? const [Color(0xFF7739EA), Color(0xFF4F23C8), Color(0xFF241668)]
              : const [Color(0xFF144DDF), Color(0xFF173B96), Color(0xFF0A246A)],
        ),
        border: Border.all(
          color: featured ? const Color(0xFFFF62F5) : const Color(0xFF6FE3FF),
          width: featured ? 1.6 : 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: (featured ? const Color(0xFFFF62F5) : const Color(0xFF19D7FF))
                .withValues(alpha: 0.20),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        children: [
          Expanded(
            child: Padding(
              padding: EdgeInsets.all(2.w),
              child: image.isEmpty
                  ? Icon(
                Icons.card_giftcard_rounded,
                color: featured ? const Color(0xFFFFD85D) : const Color(0xFFA6F8FF),
                size: 34.sp,
              )
                  : ImageViewWidget(url: image, boxFit: BoxFit.contain),
            ),
          ),
          4.hBox,
          TextWidget(
            rewardTitle(item),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: context.bodySmall.size(8.5).w700.colorExt(ColorManager.white),
          ),
          4.hBox,
          Container(
            width: double.infinity,
            height: 20.h,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4.r),
              gradient: const LinearGradient(
                colors: [Color(0xFF47E6FF), Color(0xFF208DFF)],
              ),
            ),
            child: TextWidget(
              rewardAmountText(item),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.bodySmall.size(9).w900.colorExt(ColorManager.white),
            ),
          ),
        ],
      ),
    );
  }
}
