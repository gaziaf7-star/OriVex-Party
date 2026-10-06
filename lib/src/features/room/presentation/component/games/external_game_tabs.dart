import 'dart:async';

import 'package:general/src/core/index.dart';
import 'package:general/src/features/room/room.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

// Shared by the Live Games grid and the legacy external-game row. Keep the
// lock until the game route has finished closing, including its animation.
bool _externalGameActive = false;

/// Opens a game above the room. When launched from the game picker, dismiss
/// that popup completely before presenting the WebView on the root navigator.
Future<void> showExternalGameBottomSheet({
  required BuildContext context,
  required String url,
  required String gameName,
  double heightFactor = 0.72,
  bool replaceCurrentSheet = false,
}) async {
  if (!context.mounted || _externalGameActive) return;

  // Capture both navigators while the picker context is still valid. The
  // picker uses a RawDialogRoute, so don't assume it is a ModalBottomSheetRoute.
  final rootNavigator = Navigator.of(context, rootNavigator: true);
  final pickerRoute = ModalRoute.of(context);
  final pickerNavigator = pickerRoute?.navigator;
  if (replaceCurrentSheet &&
      (pickerRoute is! PopupRoute ||
          !pickerRoute.isCurrent ||
          pickerNavigator == null)) {
    return; // Never pop the audio-room page to open a game.
  }

  _externalGameActive = true;
  ModalRoute<void>? gameRoute;
  bool gameStateSet = false;
  try {
    if (replaceCurrentSheet && pickerRoute is PopupRoute) {
      pickerNavigator!.pop();
      // Unlike `popped`, `completed` also waits for overlay removal. No
      // arbitrary delay and no use of the disposed game-picker context.
      await pickerRoute.completed;
    }
    if (!rootNavigator.mounted) return;

    ForegroundWidget.openGames.value = true;
    gameStateSet = true;
    await showModalBottomSheet<void>(
      context: rootNavigator.context,
      useRootNavigator: true,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      useSafeArea: false,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      clipBehavior: Clip.hardEdge,
      barrierColor: Colors.black54,
      builder: (sheetContext) {
        gameRoute = ModalRoute.of<void>(sheetContext);
        final mq = MediaQuery.of(sheetContext);
        return SafeArea(
          top: false,
          child: SizedBox(
            width: double.infinity,
            height: mq.size.height * heightFactor,
            child: _ExternalGameWebView(url: url, gameName: gameName),
          ),
        );
      },
    );
    final route = gameRoute;
    if (route != null) await route.completed;
  } finally {
    if (gameStateSet) ForegroundWidget.openGames.value = false;
    _externalGameActive = false;
  }
}

class _ExternalGameWebView extends StatefulWidget {
  final String url;
  final String gameName;

  const _ExternalGameWebView({required this.url, required this.gameName});

  @override
  State<_ExternalGameWebView> createState() => _ExternalGameWebViewState();
}

class _ExternalGameWebViewState extends State<_ExternalGameWebView> {
  late final WebViewController _controller;
  bool _isLoading = true;
  int _progress = 0;
  String? _errorText;
  bool _closing = false;
  Future<void>? _pageCleanup;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (progress) {
            if (!mounted || _closing) return;
            setState(() => _progress = progress);
          },
          onPageStarted: (_) {
            if (!mounted || _closing) return;
            setState(() {
              _isLoading = true;
              _errorText = null;
            });
          },
          onPageFinished: (_) {
            if (!mounted || _closing) return;
            setState(() => _isLoading = false);
          },
          onWebResourceError: (error) {
            if (!mounted || _closing || error.isForMainFrame == false) return;
            setState(() {
              _isLoading = false;
              _errorText = error.description;
            });
          },
          onNavigationRequest: (request) => _closing && request.url != 'about:blank'
              ? NavigationDecision.prevent
              : NavigationDecision.navigate,
        ),
      )
      ..loadRequest(Uri.parse(widget.url));

    if (_controller.platform is AndroidWebViewController) {
      (_controller.platform as AndroidWebViewController)
          .setMediaPlaybackRequiresUserGesture(false);
    }
  }

  Future<void> _clearGamePage() => _pageCleanup ??= _loadBlankPage();

  Future<void> _loadBlankPage() async {
    try {
      // Unload the game document, including its audio, timers and sockets.
      // A stalled platform call must never block the close button.
      await _controller
          .loadRequest(Uri.parse('about:blank'))
          .timeout(const Duration(milliseconds: 500));
    } catch (_) {
      // The native view may already be gone during external route teardown.
    }
  }

  Future<void> _close() async {
    if (!mounted || _closing) return;
    final route = ModalRoute.of(context);
    final navigator = route?.navigator;

    // Detach the platform view before starting the route's pop animation.
    setState(() => _closing = true);
    final cleanup = _clearGamePage();
    await WidgetsBinding.instance.endOfFrame;
    await cleanup;
    if (!mounted || navigator == null || !navigator.mounted || route == null) {
      return;
    }
    if (route.isCurrent) {
      // Direct pop bypasses the PopScope veto used to intercept system Back.
      // maybePop() would ask the same veto again and leave the game stuck.
      navigator.pop<void>();
    } else if (route.isActive) {
      // If another overlay appeared while cleaning up, remove only this game.
      navigator.removeRoute(route);
    }
  }

  @override
  void dispose() {
    _closing = true;
    unawaited(_clearGamePage());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: ClipRRect(
        borderRadius: BorderRadius.zero,
        child: ColoredBox(
          color: Colors.black,
          child: Stack(
            children: [
              if (!_closing)
                Positioned.fill(child: WebViewWidget(controller: _controller)),
              if (_isLoading && !_closing)
                Positioned.fill(
                  child: ColoredBox(
                    color: Colors.black,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(color: Colors.white),
                          12.hBox,
                          TextWidget(
                            '${widget.gameName}... $_progress%',
                            style: context.bodyMedium.colorExt(ColorManager.white),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              if (_errorText != null && !_closing)
                Positioned.fill(
                  child: ColoredBox(
                    color: Colors.black,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.error_outline_rounded, color: Colors.white, size: 40),
                          12.hBox,
                          Padding(
                            padding: context.paddingSymmetric(horizontal: 24),
                            child: TextWidget(
                              _errorText!,
                              textAlign: TextAlign.center,
                              style: context.bodyMedium.colorExt(ColorManager.white),
                            ),
                          ),
                          16.hBox,
                          TextButton(
                            onPressed: _closing
                                ? null
                                : () => _controller.loadRequest(Uri.parse(widget.url)),
                            child: const TextWidget('Reload', style: TextStyle(color: Colors.white)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              Positioned(
                top: 8.h,
                right: 8.w,
                child: Material(
                  color: Colors.black54,
                  shape: const CircleBorder(),
                  child: IconButton(
                    tooltip: 'Close game',
                    onPressed: _closing ? null : _close,
                    constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                    icon: const Icon(Icons.close, color: Colors.white, size: 24),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
