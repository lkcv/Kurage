import 'dart:async';
import 'dart:io';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

/// Preserve standard scrolling on mobile; smooth stepped mouse wheels on Linux.
ScrollController createGridScrollController() =>
    Platform.isLinux ? _SmoothWheelScrollController() : ScrollController();

/// Let desktop arrow keys use the same easing as mouse-wheel scrolling.
class GridKeyboardScroll extends StatefulWidget {
  const GridKeyboardScroll({
    super.key,
    required this.controller,
    required this.child,
    this.autofocus = false,
  });

  final ScrollController controller;
  final Widget child;
  final bool autofocus;

  @override
  State<GridKeyboardScroll> createState() => _GridKeyboardScrollState();
}

class _GridKeyboardScrollState extends State<GridKeyboardScroll> {
  Timer? _holdTimer;
  int? _heldDirection;

  void _scroll(double delta) {
    if (widget.controller.hasClients) {
      widget.controller.position.pointerScroll(delta);
    }
  }

  void _stop() {
    _holdTimer?.cancel();
    _holdTimer = null;
    _heldDirection = null;
  }

  @override
  void didUpdateWidget(GridKeyboardScroll oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) _stop();
  }

  @override
  void dispose() {
    _stop();
    super.dispose();
  }

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    final direction = switch (event.logicalKey) {
      LogicalKeyboardKey.arrowUp => -1,
      LogicalKeyboardKey.arrowDown => 1,
      _ => 0,
    };
    if (direction == 0) return KeyEventResult.ignored;

    if (event is KeyUpEvent) {
      if (_heldDirection == direction) _stop();
      return KeyEventResult.handled;
    }
    if (event is KeyRepeatEvent) return KeyEventResult.handled;
    if (event is! KeyDownEvent ||
        HardwareKeyboard.instance.isShiftPressed ||
        HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isAltPressed ||
        HardwareKeyboard.instance.isMetaPressed ||
        !widget.controller.hasClients) {
      return KeyEventResult.ignored;
    }

    if (_heldDirection != direction) {
      _stop();
      _heldDirection = direction;
      _scroll(direction * 50);
      // The Wayland embedder doesn't synthesize keyboard repeat events.
      _holdTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
        _scroll(direction * 25);
      });
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    if (!Platform.isLinux) return widget.child;
    return Focus(
      autofocus: widget.autofocus,
      canRequestFocus: widget.autofocus,
      skipTraversal: !widget.autofocus,
      onKeyEvent: _onKeyEvent,
      onFocusChange: (focused) {
        if (!focused) _stop();
      },
      child: widget.child,
    );
  }
}

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
