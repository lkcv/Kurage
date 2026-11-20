import 'dart:async';
import 'dart:io';
import 'package:flutter/rendering.dart';

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

/// Preserve standard scrolling on mobile; smooth stepped mouse wheels on Linux.
ScrollController createGridScrollController() =>
    Platform.isLinux ? _SmoothWheelScrollController() : ScrollController();

class _SmoothWheelScrollController extends ScrollController {
  @override
  ScrollPosition createScrollPosition(
    ScrollPhysics physics,
    ScrollContext context,
    ScrollPosition? oldPosition,
  ) => _SmoothWheelScrollPosition(
    physics: physics,
    context: context,
    oldPosition: oldPosition,
    initialPixels: initialScrollOffset,
    keepScrollOffset: keepScrollOffset,
    debugLabel: debugLabel,
  );
}

class _SmoothWheelScrollPosition extends ScrollPositionWithSingleContext {
  _SmoothWheelScrollPosition({
    required super.physics,
    required super.context,
    super.oldPosition,
    super.initialPixels,
    super.keepScrollOffset,
    super.debugLabel,
  });

  static const _duration = Duration(milliseconds: 180);
  double? _wheelTarget;
  int _sequence = 0;

  void _resetWheelTarget() {
    _sequence++;
    _wheelTarget = null;
  }

  @override
  void pointerScroll(double delta) {
    if (delta == 0) {
      _resetWheelTarget();
      super.pointerScroll(delta);
      return;
    }

    // Add successive notches to the destination, not the intermediate offset.
    final from = _wheelTarget ?? pixels;
    final target = (from + delta).clamp(minScrollExtent, maxScrollExtent).toDouble();
    if (target == from) return;

    _wheelTarget = target;
    final sequence = ++_sequence;
    updateUserScrollDirection(
      delta > 0 ? ScrollDirection.reverse : ScrollDirection.forward,
    );
    final activity = _SmoothWheelScrollActivity(
      this,
      from: pixels,
      to: target,
      duration: _duration,
      curve: Curves.easeOutCubic,
      vsync: context.vsync,
    );
    beginActivity(activity);
    unawaited(activity.done.then((_) {
      if (sequence == _sequence) _wheelTarget = null;
    }));
  }

  @override
  void jumpTo(double value) {
    _resetWheelTarget();
    super.jumpTo(value);
  }

  @override
  Future<void> animateTo(
    double value, {
    required Duration duration,
    required Curve curve,
  }) {
    _resetWheelTarget();
    return super.animateTo(value, duration: duration, curve: curve);
  }

  @override
  Drag drag(DragStartDetails details, VoidCallback dragCancelCallback) {
    _resetWheelTarget();
    return super.drag(details, dragCancelCallback);
  }
}

/// Unlike normal animateTo(), wheel motion must not block cover taps.
class _SmoothWheelScrollActivity extends DrivenScrollActivity {
  _SmoothWheelScrollActivity(
    super.delegate, {
    required super.from,
    required super.to,
    required super.duration,
    required super.curve,
    required super.vsync,
  });

  @override
  bool get shouldIgnorePointer => false;
}
