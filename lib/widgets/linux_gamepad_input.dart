import 'dart:io';

import 'package:flutter/services.dart';

typedef GamepadListener = bool Function(String action, bool pressed);

/// Receives normalized button transitions from the eLinux Wayland embedder.
class LinuxGamepadInput {
  LinuxGamepadInput._() {
    if (!Platform.isLinux) return;
    const BasicMessageChannel<String>(
      'elinux/gamepad',
      StringCodec(),
    ).setMessageHandler((message) async {
      if (message == null) return '';
      final separator = message.lastIndexOf(':');
      if (separator < 0) return '';
      final action = message.substring(0, separator);
      final pressed = message.substring(separator + 1) == 'down';
      // Newest (usually most deeply nested) listeners handle events first.
      for (final listener in List<GamepadListener>.of(_listeners).reversed) {
        if (listener(action, pressed)) break;
      }
      return '';
    });
  }

  static final instance = LinuxGamepadInput._();
  final List<GamepadListener> _listeners = [];

  void addListener(GamepadListener listener) => _listeners.add(listener);
  void removeListener(GamepadListener listener) => _listeners.remove(listener);
}
