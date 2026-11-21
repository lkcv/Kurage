import 'package:material_ui/material_ui.dart';

/// Compact, translucent reference for the Linux controls.
class DesktopShortcutsOverlay extends StatelessWidget {
  const DesktopShortcutsOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.all(20),
      child: SizedBox(
        width: 640,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.surface.withValues(alpha: 0.75),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: colors.outline.withValues(alpha: 0.5)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Keyboard shortcuts',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 22),
                const _ShortcutColumns(
                  action: 'Action',
                  keyboard: 'Keyboard',
                  mouse: 'Mouse',
                ),
                Divider(height: 22, color: colors.outlineVariant),
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
                  action: 'Scroll grids',
                  keys: [
                    ['↑'],
                    ['↓'],
                  ],
                  mouse: [_MouseControl('Wheel', _MousePart.wheel)],
                ),
                const _ShortcutRow(
                  action: 'Go back',
                  keys: [
                    ['Esc'],
                    ['Alt', '←'],
                  ],
                  separateKeys: true,
                  mouse: [_MouseControl('Back button', _MousePart.back)],
                ),
                const _ShortcutRow(
                  action: 'Show shortcuts',
                  keys: [
                    ['F1'],
                  ],
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
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
                        if (i > 0) const Padding(
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
                          Text('/', style: TextStyle(color: colors.onSurfaceVariant)),
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

class _Keycap extends StatelessWidget {
  const _Keycap(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(minWidth: 32),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: colors.onSurface.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: colors.onSurface.withValues(alpha: 0.25)),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
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
