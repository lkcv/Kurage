import 'dart:async';
import 'dart:io';
import 'package:kurage/widgets/linux_gamepad_input.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:kurage/widgets/cover_grid_layout.dart';

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:material_ui/material_ui.dart' show Theme;

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

/// Preserve standard scrolling on mobile; smooth stepped mouse wheels on Linux.
ScrollController createGridScrollController() =>
    Platform.isLinux ? _SmoothWheelScrollController() : ScrollController();

/// Navigate Linux cover grids with the keyboard; mouse wheels scroll freely.
enum _GridDirection { left, right, up, down }

class GridKeyboardScroll extends StatefulWidget {
  const GridKeyboardScroll({
    super.key,
    required this.controller,
    required this.child,
    this.autofocus = false,
    this.focusNode,
    this.selection,
    this.itemCount = 0,
    this.columns = 1,
    this.rowExtent = 0,
    this.contentStart = 0,
    this.topOcclusion = 0,
    this.bottomOcclusion = 0,
    this.onActivate,
    this.gamepadFocusAllowed,
  });

  final ScrollController controller;
  final Widget child;
  final bool autofocus;
  final FocusNode? focusNode;
  final ValueNotifier<int?>? selection;
  final int itemCount;
  final int columns;
  final double rowExtent;
  final double contentStart;
  final double topOcclusion;
  final double bottomOcclusion;
  final ValueChanged<int>? onActivate;
  final bool Function()? gamepadFocusAllowed;

  @override
  State<GridKeyboardScroll> createState() => _GridKeyboardScrollState();
}

class _GridKeyboardScrollState extends State<GridKeyboardScroll> {
  final FocusNode _ownedFocusNode = FocusNode();
  Timer? _holdTimer;
  _GridDirection? _heldDirection;

  static const _initialRepeatDelay = Duration(milliseconds: 330);
  static const _repeatInterval = Duration(milliseconds: 120);

  bool get _canSelect =>
      widget.selection != null &&
      widget.itemCount > 0 &&
      widget.columns > 0 &&
      widget.rowExtent > 0;

  void _stop() {
    _holdTimer?.cancel();
    _holdTimer = null;
    _heldDirection = null;
  }

  CoverGridViewport get _viewport => CoverGridViewport(
    metrics: widget.controller.position,
    itemCount: widget.itemCount,
    columns: widget.columns,
    rowExtent: widget.rowExtent,
    contentStart: widget.contentStart,
    topOcclusion: widget.topOcclusion,
    bottomOcclusion: widget.bottomOcclusion,
  );

  int _firstVisibleIndex() {
    if (!widget.controller.hasClients ||
        widget.controller.offset <= 0 ||
        !widget.controller.position.hasContentDimensions) {
      return 0;
    }
    return _viewport.firstVisibleIndex();
  }

  Future<void> _ensureVisible(int index) async {
    if (!widget.controller.hasClients) return;
    final position = widget.controller.position;
    final row = index ~/ widget.columns;
    final viewport = _viewport;
    final top = viewport.rowTop(index);
    final bottom = viewport.rowBottom(index);
    final offset = position.pixels;
    double? target;

    final origin = position.minScrollExtent;
    final topLimit = top - widget.topOcclusion;
    final bottomLimit =
        bottom - position.viewportDimension + widget.bottomOcclusion;
    // Snap only when navigation needs to scroll. All aligned positions
    // preserve the original grid gap and row rhythm.
    if (row == 0) {
      target = origin;
    } else if (topLimit < offset - 1) {
      target =
          origin +
          ((topLimit - origin) / widget.rowExtent).floor() * widget.rowExtent;
    } else if (bottomLimit > offset + 1) {
      final aligned =
          origin +
          ((bottomLimit - origin) / widget.rowExtent).ceil() * widget.rowExtent;
      // A short viewport may not admit a fully visible, aligned row.
      // Prefer visibility over alignment in that case.
      target = aligned <= topLimit
          ? aligned
          : (bottomLimit <= topLimit ? bottomLimit : topLimit);
    }

    if (target == null) return;
    final bounded = target
        .clamp(position.minScrollExtent, position.maxScrollExtent)
        .toDouble();

    if (bounded == offset || (row != 0 && (bounded - offset).abs() < 1)) {
      return;
    }

    await widget.controller.animateTo(
      bounded,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
    );
  }

  void _moveSelection(_GridDirection direction) {
    if (!_canSelect) return;
    final selection = widget.selection!;
    final selected = selection.value;
    if (selected == null) {
      final first = _firstVisibleIndex();
      selection.value = first;
      unawaited(_ensureVisible(first));
      return;
    }
    final current = selected.clamp(0, widget.itemCount - 1).toInt();
    final next = switch (direction) {
      _GridDirection.left =>
        current % widget.columns == 0 ? current : current - 1,
      _GridDirection.right =>
        current % widget.columns == widget.columns - 1
            ? current
            : (current + 1).clamp(0, widget.itemCount - 1).toInt(),
      _GridDirection.up =>
        (current - widget.columns).clamp(0, widget.itemCount - 1).toInt(),
      _GridDirection.down =>
        (current + widget.columns).clamp(0, widget.itemCount - 1).toInt(),
    };
    if (next == current) return;
    selection.value = next;
    unawaited(_ensureVisible(next));
  }

  void _startHold(_GridDirection direction) {
    if (_heldDirection == direction) return;
    _stop();
    _heldDirection = direction;
    _moveSelection(direction);
    // Repeat independently of OS keyboard repeat (absent in the embedder).
    _holdTimer = Timer(_initialRepeatDelay, () {
      if (!mounted || !_canSelect || _heldDirection != direction) {
        _stop();
        return;
      }
      _moveSelection(direction);
      _holdTimer = Timer.periodic(_repeatInterval, (_) {
        if (!mounted || !_canSelect || _heldDirection != direction) {
          _stop();
          return;
        }
        _moveSelection(direction);
      });
    });
  }

  Future<void> _activate(int index) async {
    final controller = widget.controller;
    await _ensureVisible(index);
    if (!mounted ||
        controller != widget.controller ||
        index >= widget.itemCount ||
        widget.selection?.value != index) {
      return;
    }
    widget.onActivate?.call(index);
  }

  @override
  void didUpdateWidget(GridKeyboardScroll oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) _stop();
    if (Platform.isLinux && widget.autofocus && !oldWidget.autofocus) {
      // A retained grid needs focus again when its tab becomes active.
      // Wait until Focus has updated canRequestFocus in this frame.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted &&
            widget.autofocus &&
            ModalRoute.of(context)?.isCurrent == true) {
          (widget.focusNode ?? _ownedFocusNode).requestFocus();
        }
      });
    }
  }

  @override
  void initState() {
    super.initState();
    if (Platform.isLinux) LinuxGamepadInput.instance.addListener(_onGamepad);
  }

  @override
  void dispose() {
    if (Platform.isLinux) LinuxGamepadInput.instance.removeListener(_onGamepad);
    _stop();
    _ownedFocusNode.dispose();
    super.dispose();
  }

  bool _onGamepad(String action, bool pressed) {
    if (!mounted ||
        !_canSelect ||
        ModalRoute.of(context)?.isCurrent != true ||
        (widget.gamepadFocusAllowed != null &&
            !widget.gamepadFocusAllowed!())) {
      return false;
    }
    // Back navigates immediately; the highlight is retained on return.
    if (action == 'back') {
      if (pressed) _stop();
      return false;
    }
    final focus = widget.focusNode ?? _ownedFocusNode;
    if (!focus.hasPrimaryFocus) {
      if (!pressed || widget.gamepadFocusAllowed?.call() != true) return false;
      focus.requestFocus();
    }
    final direction = switch (action) {
      'left' => _GridDirection.left,
      'right' => _GridDirection.right,
      'up' => _GridDirection.up,
      'down' => _GridDirection.down,
      _ => null,
    };
    if (direction != null) {
      if (pressed) {
        _startHold(direction);
      } else if (_heldDirection == direction) {
        _stop();
      }
      return true;
    }
    if (!pressed) return false;
    if (action == 'confirm') {
      final selected = widget.selection!.value;
      if (selected != null) {
        unawaited(_activate(selected));
        return true;
      }
    }
    return false;
  }

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (!node.hasPrimaryFocus) return KeyEventResult.ignored;
    final direction = switch (event.logicalKey) {
      LogicalKeyboardKey.arrowLeft => _GridDirection.left,
      LogicalKeyboardKey.arrowRight => _GridDirection.right,
      LogicalKeyboardKey.arrowUp => _GridDirection.up,
      LogicalKeyboardKey.arrowDown => _GridDirection.down,
      _ => null,
    };
    if (event is KeyUpEvent) {
      if (direction == _heldDirection) _stop();
      return direction != null && _canSelect
          ? KeyEventResult.handled
          : KeyEventResult.ignored;
    }
    if (event is KeyRepeatEvent) {
      return direction != null && _canSelect
          ? KeyEventResult.handled
          : KeyEventResult.ignored;
    }
    if (event is! KeyDownEvent ||
        HardwareKeyboard.instance.isShiftPressed ||
        HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isAltPressed ||
        HardwareKeyboard.instance.isMetaPressed) {
      return KeyEventResult.ignored;
    }

    if (event.logicalKey == LogicalKeyboardKey.escape) {
      _stop();
      return KeyEventResult.ignored;
    }

    if (!_canSelect) return KeyEventResult.ignored;
    if (direction != null) {
      _startHold(direction);
      return KeyEventResult.handled;
    }

    if (widget.selection!.value case final int selected) {
      if (event.logicalKey == LogicalKeyboardKey.enter ||
          event.logicalKey == LogicalKeyboardKey.numpadEnter) {
        unawaited(_activate(selected));
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    if (!Platform.isLinux) return widget.child;
    return Focus(
      focusNode: widget.focusNode ?? _ownedFocusNode,
      autofocus: widget.autofocus,
      canRequestFocus: widget.autofocus || widget.focusNode != null,
      skipTraversal: !widget.autofocus && widget.focusNode == null,
      onKeyEvent: _onKeyEvent,
      onFocusChange: (focused) {
        if (!focused) _stop();
      },
      child: widget.selection == null
          ? widget.child
          : Listener(
              behavior: HitTestBehavior.translucent,
              onPointerDown: (event) {
                if (event.kind == PointerDeviceKind.mouse) {
                  _stop();
                  widget.selection!.value = null;
                }
              },
              onPointerSignal: (event) {
                if (event is PointerScrollEvent) {
                  _stop();
                  widget.selection!.value = null;
                }
              },
              child: widget.child,
            ),
    );
  }
}

/// Paint a selection outline without rebuilding the cover or changing its size.
class GridSelectionIndicator extends StatelessWidget {
  const GridSelectionIndicator({
    super.key,
    required this.selection,
    required this.index,
    required this.child,
  });

  final ValueListenable<int?> selection;
  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!Platform.isLinux) return child;
    return ValueListenableBuilder<int?>(
      valueListenable: selection,
      child: child,
      builder: (context, selected, child) => DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(17),
          border: selected == index
              ? Border.all(
                  color: Theme.of(context).colorScheme.primary,
                  width: 3,
                )
              : null,
        ),
        child: child!,
      ),
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
    final target = (from + delta)
        .clamp(minScrollExtent, maxScrollExtent)
        .toDouble();
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
    unawaited(
      activity.done.then((_) {
        if (sequence == _sequence) _wheelTarget = null;
      }),
    );
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
