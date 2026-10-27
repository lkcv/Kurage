import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/scheduler.dart';

/// Paints a transformed reader page. Raw pointers are tracked by the reader,
/// *above* PageView, so a second finger can be detected even if the first
/// finger is already dragging a different page.
class ReaderPinchZoom extends StatefulWidget {
  const ReaderPinchZoom({
    super.key,
    required this.child,
    this.scaleNotifier,
  });

  final Widget child;
  final ValueNotifier<double>? scaleNotifier;

  @override
  State<ReaderPinchZoom> createState() => ReaderPinchZoomState();
}

/// Imperative, pointer-level transformation API used by the reader's Listener.
/// No gesture recognizer is involved, so one-finger paging stays immediate.
class ReaderPinchZoomState extends State<ReaderPinchZoom> {
  static const double _maxScale = 5;
  static const double _friction = 0.0000135;
  final TransformationController _transform = TransformationController();
  late final Ticker _inertiaTicker = Ticker(_onInertiaTick);
  FrictionSimulation? _inertiaX;
  FrictionSimulation? _inertiaY;

  double _startScale = 1;
  double _startDistance = 1;
  Offset _sceneFocalPoint = Offset.zero;

  bool get isZoomed => _transform.value.getMaxScaleOnAxis() > 1.001;

  // A NEW, single-finger swipe may turn a page only when the enlarged image
  // was already at the corresponding edge when that finger touched down.
  // A positive movement drags the content right/down; a negative one left/up.
  bool atPanBoundary({required bool vertical, required bool positive}) {
    if (!isZoomed) return false;
    final size = _box?.size;
    if (size == null) return false;
    final matrix = _transform.value;
    final scale = matrix.getMaxScaleOnAxis();
    final translation = vertical ? matrix.storage[13] : matrix.storage[12];
    final length = vertical ? size.height : size.width;
    final minTranslation = length * (1 - scale);
    const tolerance = 1.0;
    return positive
        ? translation >= -tolerance
        : translation <= minTranslation + tolerance;
  }

  void reset() {
    stopInertia();
    _transform.value = Matrix4.identity();
    widget.scaleNotifier?.value = 1.0;
  }

  @override
  void dispose() {
    _inertiaTicker.dispose();
    _transform.dispose();
    super.dispose();
  }

  RenderBox? get _box {
    final renderObject = context.findRenderObject();
    return renderObject is RenderBox && renderObject.hasSize
        ? renderObject
        : null;
  }

  bool containsGlobalPoint(Offset point) {
    final box = _box;
    return box != null &&
        (Offset.zero & box.size).contains(box.globalToLocal(point));
  }

  Offset _toLocal(Offset point) => _box?.globalToLocal(point) ?? point;

  void beginPinch(Offset firstGlobal, Offset secondGlobal) {
    stopInertia();
    final a = _toLocal(firstGlobal);
    final b = _toLocal(secondGlobal);
    final midpoint = (a + b) / 2;
    _startDistance = math.max(1, (a - b).distance);
    _startScale = _transform.value.getMaxScaleOnAxis();
    _sceneFocalPoint = _transform.toScene(midpoint);
  }

  void updatePinch(Offset firstGlobal, Offset secondGlobal) {
    final a = _toLocal(firstGlobal);
    final b = _toLocal(secondGlobal);
    final midpoint = (a + b) / 2;
    final distance = (a - b).distance;
    final scale = (_startScale * distance / _startDistance)
        .clamp(1.0, _maxScale)
        .toDouble();
    _setTransform(scale, midpoint - _sceneFocalPoint * scale);
  }

  void pan(Offset delta) {
    if (!isZoomed) return;
    final matrix = _transform.value;
    _setTransform(
      matrix.getMaxScaleOnAxis(),
      Offset(matrix.storage[12], matrix.storage[13]) + delta,
    );
  }

  void startInertia(Offset velocity) {
    stopInertia();
    if (!isZoomed || velocity.distance < 75) return;
    final matrix = _transform.value;
    _inertiaX = FrictionSimulation(
      _friction,
      matrix.storage[12],
      velocity.dx,
      tolerance: const Tolerance(velocity: 10),
    );
    _inertiaY = FrictionSimulation(
      _friction,
      matrix.storage[13],
      velocity.dy,
      tolerance: const Tolerance(velocity: 10),
    );
    _inertiaTicker.start();
  }

  void stopInertia() {
    _inertiaTicker.stop();
    _inertiaX = null;
    _inertiaY = null;
  }

  void _onInertiaTick(Duration elapsed) {
    final horizontal = _inertiaX;
    final vertical = _inertiaY;
    if (horizontal == null || vertical == null) return;
    final time = elapsed.inMicroseconds / Duration.microsecondsPerSecond;
    final next = Offset(horizontal.x(time), vertical.x(time));
    _setTransform(_transform.value.getMaxScaleOnAxis(), next);

    // Stop once both axes have slowed down or reached their hard limits.
    final matrix = _transform.value;
    final xDone = horizontal.isDone(time) ||
        (matrix.storage[12] - next.dx).abs() > 0.01;
    final yDone = vertical.isDone(time) ||
        (matrix.storage[13] - next.dy).abs() > 0.01;
    if (xDone && yDone) stopInertia();
  }

  void _setTransform(double scale, Offset translation) {
    final size = _box?.size ?? Size.zero;
    // Keep the enlarged page covering its original viewport.
    final minX = size.width * (1 - scale);
    final minY = size.height * (1 - scale);
    final dx = translation.dx.clamp(minX, 0.0).toDouble();
    final dy = translation.dy.clamp(minY, 0.0).toDouble();
    _transform.value = Matrix4.identity()
      ..translateByDouble(dx, dy, 0.0, 1.0)
      ..scaleByDouble(scale, scale, scale, 1.0);
    widget.scaleNotifier?.value = scale;
  }

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: AnimatedBuilder(
        animation: _transform,
        child: widget.child,
        builder: (context, child) => Transform(
          alignment: Alignment.topLeft,
          transform: _transform.value,
          child: child,
        ),
      ),
    );
  }
}
