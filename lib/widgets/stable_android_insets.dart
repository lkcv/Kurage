import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Keeps immersive Android layouts independent of transient status bar visibility.
class StableAndroidInsets extends StatefulWidget {
  const StableAndroidInsets({super.key, required this.child});

  final Widget child;

  @override
  State<StableAndroidInsets> createState() => _StableAndroidInsetsState();
}

class _StableAndroidInsetsState extends State<StableAndroidInsets>
    with WidgetsBindingObserver {
  static const _channel = MethodChannel('kurage/window_insets');
  int? _physicalTop;
  bool _refreshing = false;
  bool _refreshAgain = false;

  Future<void> _refresh() async {
    if (!mounted) return;
    if (_refreshing) {
      _refreshAgain = true;
      return;
    }
    _refreshing = true;
    try {
      do {
        _refreshAgain = false;
        final top = await _channel.invokeMethod<int>('cutoutTop');
        if (!mounted) return;
        if (top != null && top >= 0 && top != _physicalTop) {
          setState(() => _physicalTop = top);
        }
      } while (_refreshAgain);
    } on PlatformException {
      // Retain the last valid inset, or use the original MediaQuery.
    } on MissingPluginException {
      // The original MediaQuery remains available without the channel.
    } finally {
      _refreshing = false;
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _refresh();
    });
  }

  @override
  void didChangeMetrics() => _refresh();

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = MediaQuery.of(context);
    final physicalTop = _physicalTop;
    final top = physicalTop == null
        ? data.viewPadding.top
        : physicalTop / data.devicePixelRatio;
    return MediaQuery(
      data: physicalTop == null
          ? data
          : data.copyWith(
              viewPadding: data.viewPadding.copyWith(top: top),
              padding: data.padding.copyWith(
                top: math.max(0.0, top - data.viewInsets.top),
              ),
            ),
      child: widget.child,
    );
  }
}
