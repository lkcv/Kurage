import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Retains only the final staged-downsampled images for nearby pages.
/// Intermediate images are released immediately; nothing is written to disk.
class ReaderPrefilterCache extends ChangeNotifier {
  static const _maxPages = 6;
  static const _maxRecentPages = 5;
  static const _tapResizeIntervalMs = 150;
  static const _maxDecodedBytes = 72 * 1024 * 1024;
  List<int> _wanted = const [];
  Future<File> Function(int)? _load;
  int _width = 0;
  int _height = 0;
  bool _paused = true;
  bool _hardPaused = true;
  bool _allowTapFinishDuringTouch = false;
  bool _pendingReadyNotification = false;
  bool _tapActive = false;
  final Stopwatch _tapClock = Stopwatch()..start();
  int _nextTapResizeMs = 0;
  Timer? _tapRetryTimer;
  int? _tapTarget;
  bool _running = false;
  bool _closed = false;
  int _generation = 0;
  final Set<int> _attempted = {};
  final Map<int, _PinnedPage> _ready = {};
  final List<int> _recentPages = [];
  final Set<int> _capacityDeferred = {};
  int _currentIndex = -1;
  int _readingStep = 1;
  int _retainedBytes = 0;

  ui.Image? readyFor(int index, File file) {
    final page = _ready[index];
    if (page == null || page.path != file.path) return null;
    _ready.remove(index);
    _ready[index] = page;
    return page.image.clone();
  }

  void setActivity({
    required bool hardPaused,
    required bool allowTapFinishDuringTouch,
    required bool tapActive,
    int? tapTarget,
  }) {
    if (_closed) return;
    final wasPaused = _paused;
    final previousTarget = _tapTarget;
    if (!tapActive) {
      _nextTapResizeMs = 0;
      _tapRetryTimer?.cancel();
      _tapRetryTimer = null;
    }
    _hardPaused = hardPaused;
    _allowTapFinishDuringTouch = allowTapFinishDuringTouch;
    _tapActive = tapActive;
    _tapTarget = tapActive && !hardPaused ? tapTarget : null;
    _paused = hardPaused || tapActive;
    if ((wasPaused && !_paused) ||
        (!hardPaused && _pendingReadyNotification) ||
        (_tapTarget != null && previousTarget != _tapTarget)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_closed) return;
        if (!_hardPaused && _pendingReadyNotification) {
          _pendingReadyNotification = false;
          notifyListeners();
        } else if (!_paused) {
          notifyListeners();
        }
        _pump();
      });
      WidgetsBinding.instance.ensureVisualUpdate();
    }
  }

  void configure({
    required List<int> indices,
    required int currentIndex,
    required int readingStep,
    required int width,
    required int height,
    required Future<File> Function(int) load,
  }) {
    if (_closed) return;
    if (_width != width || _height != height) {
      clear();
      _width = width;
      _height = height;
    }
    final nextWanted = indices
        .where((index) => index > 0)
        .take(_maxPages)
        .toList();
    final windowChanged = !listEquals(_wanted, nextWanted);
    final pageChanged = _currentIndex != currentIndex;
    if (windowChanged || pageChanged || _readingStep != readingStep) {
      _attempted.removeAll(_capacityDeferred);
      _capacityDeferred.clear();
    }
    if (pageChanged) {
      _recentPages.remove(currentIndex);
      _recentPages.insert(0, currentIndex);
      if (_recentPages.length > _maxRecentPages) {
        _recentPages.removeLast();
      }
    }
    _currentIndex = currentIndex;
    _readingStep = readingStep;
    _wanted = nextWanted;
    _load = load;
    final keep = _wanted.toSet();
    _attempted.removeWhere((index) => !keep.contains(index));
    _pump();
  }

  void clear() {
    ++_generation;
    _tapRetryTimer?.cancel();
    _tapRetryTimer = null;
    _nextTapResizeMs = 0;
    _pendingReadyNotification = false;
    _attempted.clear();
    _capacityDeferred.clear();
    _recentPages.clear();
    _currentIndex = -1;
    for (final page in _ready.values) {
      page.release();
    }
    _ready.clear();
    _retainedBytes = 0;
    if (!_closed) notifyListeners();
  }

  void _pump() {
    if (_closed || _running || _load == null || _hardPaused) return;
    final tapJob = _tapActive;
    int? selected;
    if (tapJob) {
      final target = _tapTarget;
      if (target != null &&
          _wanted.contains(target) &&
          !_ready.containsKey(target) &&
          !_attempted.contains(target) &&
          _canRetain(target)) {
        selected = target;
      }
    } else {
      for (final index in _wanted) {
        if (_ready.containsKey(index) || _attempted.contains(index)) continue;
        if (!_canRetain(index)) {
          _attempted.add(index);
          _capacityDeferred.add(index);
          continue;
        }
        selected = index;
        break;
      }
    }
    if (selected == null) return;
    if (tapJob) {
      final remainingMs = _nextTapResizeMs - _tapClock.elapsedMilliseconds;
      if (remainingMs > 0) {
        _tapRetryTimer ??= Timer(Duration(milliseconds: remainingMs), () {
          _tapRetryTimer = null;
          _pump();
        });
        return;
      }
      _tapRetryTimer?.cancel();
      _tapRetryTimer = null;
      _nextTapResizeMs = _tapClock.elapsedMilliseconds + _tapResizeIntervalMs;
    }
    final index = selected;
    final generation = _generation;
    final width = _width;
    final height = _height;
    final load = _load!;
    _attempted.add(index);
    _running = true;

    bool canContinue() {
      final blocked =
          _hardPaused && !(tapJob && _tapActive && _allowTapFinishDuringTouch);
      return !_closed &&
          !blocked &&
          generation == _generation &&
          _wanted.contains(index) &&
          (tapJob ? (_tapActive || !_paused) : !_paused);
    }

    Future<void> work() async {
      final file = await load(index);
      if (_closed || generation != _generation || !_wanted.contains(index)) {
        return;
      }
      if (!canContinue()) {
        _attempted.remove(index);
        return;
      }
      final result = await _stagedDownsample(
        file.path,
        width,
        height,
        canContinue,
      );
      if (result == null) {
        if (!canContinue() && !_closed && generation == _generation) {
          _attempted.remove(index);
        }
        return;
      }
      if (_closed || generation != _generation || !_wanted.contains(index)) {
        result.dispose();
        return;
      }
      final bytes = result.width * result.height * 4;
      if (bytes > _maxDecodedBytes) {
        result.dispose();
        return;
      }
      _releasePage(index);
      _ready[index] = _PinnedPage(file.path, result);
      _retainedBytes += bytes;
      _trimReady();
      final notify = !_paused || (tapJob && !_hardPaused);
      if (notify) {
        _pendingReadyNotification = false;
        notifyListeners();
      } else {
        _pendingReadyNotification = true;
      }
    }

    work()
        .catchError((Object error, StackTrace stack) {
          debugPrint('Reader resize p${index + 1}: $error');
        })
        .whenComplete(() {
          _running = false;
          _pump();
        });
  }

  void _releasePage(int index) {
    final page = _ready.remove(index);
    if (page == null) return;
    _retainedBytes -= page.image.width * page.image.height * 4;
    page.release();
  }

  // A viewed page survives more readily than a speculative page. Reserve
  // the highest priority for the current page and the next likely turn.
  int _priority(int index) {
    if (index == _currentIndex) return 1000;
    if (index == _currentIndex + _readingStep) return 900;
    final recent = _recentPages.indexOf(index);
    if (recent >= 0) return 800 - recent;
    final wanted = _wanted.indexOf(index);
    if (wanted >= 0) return 100 - wanted;
    return 0;
  }

  bool _canRetain(int index) {
    if (_ready.length < _maxPages && _retainedBytes < _maxDecodedBytes) {
      return true;
    }
    if (_ready.isEmpty) return true;
    final lowest = _ready.keys.map(_priority).reduce((a, b) => a < b ? a : b);
    return _priority(index) > lowest;
  }

  void _trimReady() {
    while (_ready.length > _maxPages || _retainedBytes > _maxDecodedBytes) {
      final victim = _ready.keys.reduce(
        (a, b) => _priority(a) <= _priority(b) ? a : b,
      );
      _releasePage(victim);
    }
  }

  @override
  void dispose() {
    _closed = true;
    clear();
    super.dispose();
  }
}

class _PinnedPage {
  const _PinnedPage(this.path, this.image);

  final String path;
  final ui.Image image;

  void release() => image.dispose();
}

/// A preliminary low-pass reduction is needed even when the final page
/// is only slightly smaller than the source.
Future<ui.Image?> _stagedDownsample(
  String path,
  int maxWidth,
  int maxHeight,
  bool Function() canContinue,
) async {
  ui.ImmutableBuffer? buffer;
  ui.ImageDescriptor? descriptor;
  ui.Codec? codec;
  ui.Image? current;
  try {
    if (!canContinue()) return null;
    buffer = await ui.ImmutableBuffer.fromFilePath(path);
    descriptor = await ui.ImageDescriptor.encoded(buffer);
    final fitScale = math.min(
      maxWidth / descriptor.width,
      maxHeight / descriptor.height,
    );
    // Preserve smaller originals; near-native pages still need antialiasing.
    if (fitScale > 1.1) return null;
    final scale = math.min(1.0, fitScale);
    final targetWidth = math.max(1, (descriptor.width * scale).round());
    final targetHeight = math.max(1, (descriptor.height * scale).round());

    if (!canContinue()) return null;
    codec = await descriptor.instantiateCodec();
    current = (await codec.getNextFrame()).image;
    var image = current;
    // Step toward the output without asking the native sampler to perform
    // a large reduction at once.
    while (image.width > targetWidth * 1.5 ||
        image.height > targetHeight * 1.5) {
      if (!canContinue()) return null;
      final next = await _drawScaled(
        image,
        math.max(1, (image.width + 1) ~/ 2),
        math.max(1, (image.height + 1) ~/ 2),
      );
      image.dispose();
      current = next;
      image = next;
    }

    // These screentones alias even when shrinking only ~25%. A slightly
    // smaller intermediate acts as a low-pass stage before final sizing.
    final intermediateWidth = math.max(1, (targetWidth * 0.8).round());
    final intermediateHeight = math.max(1, (targetHeight * 0.8).round());
    if (image.width != intermediateWidth ||
        image.height != intermediateHeight) {
      if (!canContinue()) return null;
      final next = await _drawScaled(
        image,
        intermediateWidth,
        intermediateHeight,
      );
      image.dispose();
      current = next;
      image = next;
    }
    if (!canContinue()) return null;
    final finalImage = await _drawScaled(image, targetWidth, targetHeight);
    image.dispose();
    current = finalImage;
    if (!canContinue()) return null;
    current = null;
    return finalImage;
  } finally {
    current?.dispose();
    codec?.dispose();
    descriptor?.dispose();
    buffer?.dispose();
  }
}

Future<ui.Image> _drawScaled(ui.Image source, int width, int height) async {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawImageRect(
    source,
    ui.Rect.fromLTWH(0, 0, source.width.toDouble(), source.height.toDouble()),
    ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    ui.Paint()..filterQuality = ui.FilterQuality.low,
  );
  final picture = recorder.endRecording();
  try {
    return await picture.toImage(width, height);
  } finally {
    picture.dispose();
  }
}
