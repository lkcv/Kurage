import 'dart:io';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:kurage/widgets/linux_gamepad_input.dart';

/// Use Flutter's own focus traversal and activation for desktop settings.
class LinuxSettingsNavigation extends StatefulWidget {
  const LinuxSettingsNavigation({
    super.key,
    required this.child,
    this.onBack,
    this.directionalTraversal = false,
  });

  final Widget child;
  final VoidCallback? onBack;
  final bool directionalTraversal;

  @override
  State<LinuxSettingsNavigation> createState() =>
      _LinuxSettingsNavigationState();
}

class _LinuxSettingsNavigationState extends State<LinuxSettingsNavigation> {
  final FocusScopeNode _scope = FocusScopeNode();
  final FocusNode _rootFocus = FocusNode(skipTraversal: true);
  bool _forward = true;
  bool _mouseActive = true;

  @override
  void initState() {
    super.initState();
    if (Platform.isLinux) LinuxGamepadInput.instance.addListener(_onGamepad);
  }

  @override
  void dispose() {
    if (Platform.isLinux) LinuxGamepadInput.instance.removeListener(_onGamepad);
    _rootFocus.dispose();
    _scope.dispose();
    super.dispose();
  }

  // Keep the focused control visible without shifting already visible rows.
  void _requestFocus(
    FocusNode node, {
    ScrollPositionAlignmentPolicy? alignmentPolicy,
    double? alignment,
    Duration? duration,
    Curve? curve,
  }) {
    FocusTraversalPolicy.defaultTraversalRequestFocusCallback(
      node,
      alignmentPolicy: _forward
          ? ScrollPositionAlignmentPolicy.keepVisibleAtEnd
          : ScrollPositionAlignmentPolicy.keepVisibleAtStart,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
    );
  }

  void _useNavigation() {
    if (_mouseActive) setState(() => _mouseActive = false);
  }

  void _move(bool forward) {
    _useNavigation();
    _forward = forward;
    if (forward) {
      _scope.nextFocus();
    } else {
      _scope.previousFocus();
    }
  }

  void _moveInDirection(TraversalDirection direction) {
    _useNavigation();
    if (!widget.directionalTraversal) {
      _move(
        direction == TraversalDirection.down ||
            direction == TraversalDirection.right,
      );
      return;
    }
    final focus = FocusManager.instance.primaryFocus;
    if (focus == null || focus == _rootFocus || !_rootFocus.hasFocus) {
      _move(true);
      return;
    }
    _forward =
        direction == TraversalDirection.down ||
        direction == TraversalDirection.right;
    focus.focusInDirection(direction);
  }

  void _activate() {
    _useNavigation();
    final focus = FocusManager.instance.primaryFocus;
    if (focus == null || focus == _rootFocus || !_rootFocus.hasFocus) {
      _scope.nextFocus();
      return;
    }
    final context = focus.context;
    if (context != null) {
      Actions.maybeInvoke<ActivateIntent>(context, const ActivateIntent());
    }
  }

  bool _onGamepad(String action, bool pressed) {
    if (!mounted || ModalRoute.of(context)?.isCurrent != true) return false;
    switch (action) {
      case 'up':
        if (pressed) _moveInDirection(TraversalDirection.up);
        return true;
      case 'left':
        if (pressed) _moveInDirection(TraversalDirection.left);
        return true;
      case 'down':
        if (pressed) _moveInDirection(TraversalDirection.down);
        return true;
      case 'right':
        if (pressed) _moveInDirection(TraversalDirection.right);
        return true;
      case 'confirm':
        if (pressed) _activate();
        return true;
      case 'back':
        if (widget.onBack == null) return false;
        if (pressed) widget.onBack!();
        return true;
      default:
        return false;
    }
  }

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (ModalRoute.of(context)?.isCurrent != true ||
        event is! KeyDownEvent ||
        HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isAltPressed ||
        HardwareKeyboard.instance.isMetaPressed) {
      return KeyEventResult.ignored;
    }
    final focused = FocusManager.instance.primaryFocus?.context;
    if (focused?.widget is EditableText ||
        focused?.findAncestorStateOfType<EditableTextState>() != null) {
      return KeyEventResult.ignored;
    }
    switch (event.logicalKey) {
      case LogicalKeyboardKey.tab:
      case LogicalKeyboardKey.enter:
      case LogicalKeyboardKey.numpadEnter:
        _useNavigation();
        return KeyEventResult.ignored;
      case LogicalKeyboardKey.arrowUp:
        _moveInDirection(TraversalDirection.up);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowLeft:
        _moveInDirection(TraversalDirection.left);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowDown:
        _moveInDirection(TraversalDirection.down);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowRight:
        _moveInDirection(TraversalDirection.right);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.escape:
        if (widget.onBack != null) {
          widget.onBack!();
          return KeyEventResult.handled;
        }
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    if (!Platform.isLinux) return widget.child;
    return FocusTraversalGroup(
      policy: WidgetOrderTraversalPolicy(requestFocusCallback: _requestFocus),
      child: FocusScope(
        node: _scope,
        autofocus: true,
        child: Focus(
          focusNode: _rootFocus,
          autofocus: true,
          onKeyEvent: _onKeyEvent,
          child: Theme(
            data: Theme.of(context).copyWith(
              focusColor: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.15),
            ),
            child: MouseRegion(
              cursor: _mouseActive
                  ? MouseCursor.defer
                  : SystemMouseCursors.none,
              onHover: (_) {
                if (!_mouseActive) setState(() => _mouseActive = true);
              },
              child: IgnorePointer(
                ignoring: !_mouseActive,
                child: widget.child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
