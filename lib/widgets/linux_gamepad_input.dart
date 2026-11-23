import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:kurage/providers/app_settings_store.dart';

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
      var action = message.substring(0, separator);
      if (action.startsWith('controller_')) {
        _lastUsed = action.substring('controller_'.length);
        _updateHelpLabel();
        return '';
      }
      if (action.startsWith('controllers_')) {
        _connected = action.substring('controllers_'.length);
        hasController.value = _connected != 'none';
        _updateHelpLabel();
        return '';
      }
      if (AppSettingsStore.current.swapGamepadConfirmBack) {
        action = switch (action) {
          'confirm' => 'back',
          'back' => 'confirm',
          _ => action,
        };
      }
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
  final ValueNotifier<String> helpButtonLabel = ValueNotifier('Share / Create');
  final ValueNotifier<bool> hasController = ValueNotifier(false);
  String? _lastUsed;
  String _connected = 'none';

  void _updateHelpLabel() {
    final model = switch (_connected) {
      'ds4' => 'ds4',
      'dualsense' => 'dualsense',
      'both' => _lastUsed,
      _ => null,
    };
    helpButtonLabel.value = switch (model) {
      'ds4' => 'Share',
      'dualsense' => 'Create',
      _ => 'Share / Create',
    };
  }

  void addListener(GamepadListener listener) => _listeners.add(listener);
  void removeListener(GamepadListener listener) => _listeners.remove(listener);
}
