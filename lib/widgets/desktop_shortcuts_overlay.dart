import 'package:material_ui/material_ui.dart';
import 'package:kurage/providers/app_settings_store.dart';
import 'package:kurage/widgets/linux_gamepad_input.dart';

const _shortcutRowHeight = 48.0;

/// Compact, translucent reference for the Linux controls.
class DesktopShortcutsOverlay extends StatefulWidget {
  const DesktopShortcutsOverlay({super.key, this.initialGamepad = false});

  final bool initialGamepad;

  @override
  State<DesktopShortcutsOverlay> createState() =>
      _DesktopShortcutsOverlayState();
}

class _DesktopShortcutsOverlayState extends State<DesktopShortcutsOverlay> {
  late bool _gamepad;

  @override
  void initState() {
    super.initState();
    _gamepad = widget.initialGamepad;
    LinuxGamepadInput.instance.addListener(_onGamepad);
    LinuxGamepadInput.instance.hasController.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    LinuxGamepadInput.instance.removeListener(_onGamepad);
    LinuxGamepadInput.instance.hasController.removeListener(
      _onControllerChanged,
    );
    super.dispose();
  }

  void _onControllerChanged() {
    setState(() {
      if (!LinuxGamepadInput.instance.hasController.value) _gamepad = false;
    });
  }

  bool _onGamepad(String action, bool pressed) {
    if (!mounted ||
        !LinuxGamepadInput.instance.hasController.value ||
        ModalRoute.of(context)?.isCurrent != true ||
        (action != 'left' && action != 'right')) {
      return false;
    }
    if (pressed) setState(() => _gamepad = action == 'right');
    return true;
  }

  Widget _viewButton(String label, bool gamepad) {
    final colors = Theme.of(context).colorScheme;
    final selected = _gamepad == gamepad;
    return TextButton(
      onPressed: () => setState(() => _gamepad = gamepad),
      style:
          TextButton.styleFrom(
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            foregroundColor: selected
                ? colors.onSurface
                : colors.onSurfaceVariant,
            backgroundColor: selected
                ? colors.onSurface.withValues(alpha: 0.10)
                : Colors.transparent,
          ).copyWith(
            overlayColor: const WidgetStatePropertyAll(Colors.transparent),
          ),
      child: Text(label, style: const TextStyle(fontSize: 12)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final swapped = AppSettingsStore.current.swapGamepadConfirmBack;
    final confirmButton = swapped ? 'Right face' : 'Bottom face';
    final backButton = swapped ? 'Bottom face' : 'Right face';
    final controllerConnected = LinuxGamepadInput.instance.hasController.value;
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.all(20),
      child: SizedBox(
        width: 640,
        height: (MediaQuery.sizeOf(context).height - 40)
            .clamp(0.0, 690.0)
            .toDouble(),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.surface.withValues(alpha: 0.75),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: colors.outline.withValues(alpha: 0.5)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 36,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Shortcuts',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      if (controllerConnected)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _viewButton('Keyboard & Mouse', false),
                            const SizedBox(width: 6),
                            _viewButton('Gamepad', true),
                          ],
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                Expanded(
                  child: SingleChildScrollView(
                    key: ValueKey(_gamepad && controllerConnected),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (!_gamepad || !controllerConnected) ...[
                          const _ShortcutColumns(
                            action: 'Action',
                            keyboard: 'Keyboard',
                            mouse: 'Mouse',
                          ),
                          Divider(height: 22, color: colors.outlineVariant),
                          const _ShortcutRow(
                            action: 'Library',
                            keys: [
                              ['L'],
                            ],
                          ),
                          const _ShortcutRow(
                            action: 'Downloaded filter',
                            keys: [
                              ['D'],
                            ],
                          ),
                          const _ShortcutRow(
                            action: 'Reading filter',
                            keys: [
                              ['R'],
                            ],
                          ),
                          const _ShortcutRow(
                            action: 'Search',
                            keys: [
                              ['Space'],
                            ],
                          ),
                          const _ShortcutRow(
                            action: 'Settings',
                            keys: [
                              ['S'],
                            ],
                          ),
                          Divider(height: 22, color: colors.outlineVariant),
                          const _ShortcutRow(
                            action: 'Browse grids',
                            keys: [
                              ['←'],
                              ['→'],
                              ['↑'],
                              ['↓'],
                            ],
                            mouse: [_MouseControl('Wheel', _MousePart.wheel)],
                          ),
                          const _ShortcutRow(
                            action: 'Confirm / open',
                            keys: [
                              ['Enter'],
                            ],
                            mouse: [
                              _MouseControl('Cover click', _MousePart.click),
                            ],
                          ),
                          const _ShortcutRow(
                            action: 'Turn pages',
                            keys: [
                              ['←'],
                              ['→'],
                            ],
                            mouse: [
                              _MouseControl('Wheel', _MousePart.wheel),
                              _MouseControl('Edge click', _MousePart.click),
                            ],
                          ),
                          const _ShortcutRow(
                            action: 'Reader overlay',
                            keys: [],
                            mouse: [
                              _MouseControl('Center click', _MousePart.click),
                            ],
                          ),
                          const _ShortcutRow(
                            action: 'Go back',
                            keys: [
                              ['Esc'],
                              ['Alt', '←'],
                            ],
                            separateKeys: true,
                            mouse: [
                              _MouseControl('Back button', _MousePart.back),
                            ],
                          ),
                          const _ShortcutRow(
                            action: 'Show shortcuts',
                            keys: [
                              ['F1'],
                            ],
                          ),
                        ] else ...[
                          const _GamepadColumns(),
                          Divider(height: 22, color: colors.outlineVariant),
                          const _GamepadRow(
                            action: 'Library',
                            buttons: ['Square'],
                          ),
                          const _GamepadRow(
                            action: 'Downloaded filter',
                            buttons: ['L1'],
                          ),
                          const _GamepadRow(
                            action: 'Reading filter',
                            buttons: ['R1'],
                          ),
                          const _GamepadRow(
                            action: 'Search',
                            buttons: ['Triangle'],
                          ),
                          const _GamepadRow(
                            action: 'Settings',
                            buttons: ['Options'],
                          ),
                          Divider(height: 22, color: colors.outlineVariant),
                          const _GamepadRow(
                            action: 'Browse grids',
                            buttons: ['D-pad', 'Left stick'],
                          ),
                          _GamepadRow(
                            action: 'Confirm / open',
                            buttons: [confirmButton],
                          ),
                          const _GamepadRow(
                            action: 'Turn pages',
                            buttons: ['D-pad / stick', 'L1 / R1'],
                          ),
                          _GamepadRow(
                            action: 'Reader overlay',
                            buttons: [confirmButton, 'Options'],
                          ),
                          _GamepadRow(action: 'Go back', buttons: [backButton]),
                          ValueListenableBuilder<String>(
                            valueListenable:
                                LinuxGamepadInput.instance.helpButtonLabel,
                            builder: (_, label, _) => _GamepadRow(
                              action: 'Show shortcuts',
                              buttons: [label],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ShortcutColumns extends StatelessWidget {
  const _ShortcutColumns({
    required this.action,
    required this.keyboard,
    required this.mouse,
  });

  final String action;
  final String keyboard;
  final String mouse;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelSmall?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );
    return Row(
      children: [
        Expanded(flex: 3, child: Text(action, style: style)),
        Expanded(flex: 4, child: Text(keyboard, style: style)),
        Expanded(flex: 4, child: Text(mouse, style: style)),
      ],
    );
  }
}

class _ShortcutRow extends StatelessWidget {
  const _ShortcutRow({
    required this.action,
    required this.keys,
    this.mouse,
    this.separateKeys = false,
  });

  final String action;
  final List<List<String>> keys;
  final List<_MouseControl>? mouse;
  final bool separateKeys;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SizedBox(
      height: _shortcutRowHeight,
      child: Row(
        children: [
          Expanded(flex: 3, child: Text(action)),
          Expanded(
            flex: 4,
            child: Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                for (var index = 0; index < keys.length; index++) ...[
                  if (index > 0 && separateKeys)
                    Text('/', style: TextStyle(color: colors.onSurfaceVariant)),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var i = 0; i < keys[index].length; i++) ...[
                        if (i > 0)
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 4),
                            child: Text('+'),
                          ),
                        _Keycap(keys[index][i]),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            flex: 4,
            child: mouse == null
                ? const SizedBox.shrink()
                : Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      for (var i = 0; i < mouse!.length; i++) ...[
                        if (i > 0)
                          Text(
                            '/',
                            style: TextStyle(color: colors.onSurfaceVariant),
                          ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _MouseGlyph(mouse![i].part),
                            const SizedBox(width: 5),
                            Text(mouse![i].label),
                          ],
                        ),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _GamepadColumns extends StatelessWidget {
  const _GamepadColumns();

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelSmall?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );
    return Row(
      children: [
        Expanded(flex: 3, child: Text('Action', style: style)),
        Expanded(flex: 6, child: Text('Gamepad', style: style)),
      ],
    );
  }
}

class _GamepadRow extends StatelessWidget {
  const _GamepadRow({required this.action, required this.buttons});

  final String action;
  final List<String> buttons;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SizedBox(
      height: _shortcutRowHeight,
      child: Row(
        children: [
          Expanded(flex: 3, child: Text(action)),
          Expanded(
            flex: 6,
            child: Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                for (var i = 0; i < buttons.length; i++) ...[
                  if (i > 0)
                    Text('/', style: TextStyle(color: colors.onSurfaceVariant)),
                  _Keycap(
                    buttons[i],
                    icon: switch (buttons[i]) {
                      'Square' => Icons.crop_square,
                      'Triangle' => Icons.change_history,
                      'Bottom face' => Icons.close,
                      'Right face' => Icons.circle_outlined,
                      _ => null,
                    },
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Keycap extends StatelessWidget {
  const _Keycap(this.label, {this.icon});

  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(minWidth: 32, minHeight: 30),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: colors.onSurface.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: colors.onSurface.withValues(alpha: 0.25)),
      ),
      child: icon == null
          ? Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            )
          : Icon(icon, size: 18),
    );
  }
}

// A small, consistent mouse silhouette with the relevant control highlighted.
enum _MousePart { wheel, click, back }

class _MouseControl {
  const _MouseControl(this.label, this.part);

  final String label;
  final _MousePart part;
}

class _MouseGlyph extends StatelessWidget {
  const _MouseGlyph(this.part);

  final _MousePart part;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return CustomPaint(
      size: const Size(20, 23),
      painter: _MouseGlyphPainter(
        part: part,
        outline: colors.onSurfaceVariant,
        highlight: colors.onSurface,
      ),
    );
  }
}

class _MouseGlyphPainter extends CustomPainter {
  const _MouseGlyphPainter({
    required this.part,
    required this.outline,
    required this.highlight,
  });

  final _MousePart part;
  final Color outline;
  final Color highlight;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = outline
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(4, 1, 13, 21),
        const Radius.circular(6.5),
      ),
      stroke,
    );
    canvas.drawLine(const Offset(4, 10), const Offset(17, 10), stroke);
    canvas.drawLine(const Offset(10.5, 1), const Offset(10.5, 10), stroke);

    final emphasis = Paint()..color = highlight;
    switch (part) {
      case _MousePart.wheel:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(9.2, 3.1, 2.6, 4.8),
            const Radius.circular(1.3),
          ),
          emphasis,
        );
      case _MousePart.click:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(5.4, 2.5, 4.1, 6.1),
            const Radius.circular(1.7),
          ),
          emphasis,
        );
      case _MousePart.back:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(1, 12, 3, 4.5),
            const Radius.circular(1),
          ),
          emphasis,
        );
    }
  }

  @override
  bool shouldRepaint(covariant _MouseGlyphPainter oldDelegate) =>
      oldDelegate.part != part ||
      oldDelegate.outline != outline ||
      oldDelegate.highlight != highlight;
}
