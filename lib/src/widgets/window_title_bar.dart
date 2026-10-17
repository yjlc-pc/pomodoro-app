import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

/// Height of the self-drawn window title bar shown on desktop.
///
/// When [WindowManager] makes the OS window frameless, the app draws this bar
/// so the chrome and controls can be themed to match the M3 palette instead of
/// the default GTK look. It lives above the per-page [AppBar] as a slim strip.
const double kWindowTitleBarHeight = 38;

/// Default window title shown on the bar (matches the MaterialApp title).
const String kAppWindowTitle = '番茄钟';

/// A slim, drag-to-move window title bar with OS-style window controls.
///
/// The bar occupies the full width of the window and stays fixed above the
/// app body. In widget tests, [onMinimize]/[onMaximize]/[onClose] can be
/// injected with fakes; by default they call the real [WindowManager].
class WindowTitleBar extends StatefulWidget {
  const WindowTitleBar({
    super.key,
    this.title = kAppWindowTitle,
    this.onMinimize,
    this.onMaximize,
    this.onClose,
    this.onDoubleTapMaximize,
  });

  final String title;
  final VoidCallback? onMinimize;
  final VoidCallback? onMaximize;
  final VoidCallback? onClose;
  final VoidCallback? onDoubleTapMaximize;

  @override
  State<WindowTitleBar> createState() => _WindowTitleBarState();
}

class _WindowTitleBarState extends State<WindowTitleBar>
    with WindowListener {
  bool _maximized = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    if (_usesRealWindowManager()) {
      windowManager.addListener(this);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    if (_usesRealWindowManager()) {
      windowManager.removeListener(this);
    }
    super.dispose();
  }

  /// Whether we can call the real [WindowManager]. On web/mobile/tests the
  /// platform plugin isn't available, so default actions fall back to no-ops.
  bool _usesRealWindowManager() {
    return !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.linux ||
            defaultTargetPlatform == TargetPlatform.macOS ||
            defaultTargetPlatform == TargetPlatform.windows);
  }

  @override
  void onWindowMaximize() => setState(() => _maximized = true);

  @override
  void onWindowUnmaximize() => setState(() => _maximized = false);

  Future<void> _minimize() async {
    if (widget.onMinimize != null) {
      widget.onMinimize!();
      return;
    }
    if (_usesRealWindowManager()) await windowManager.minimize();
  }

  Future<void> _maximize() async {
    if (widget.onMaximize != null) {
      widget.onMaximize!();
      return;
    }
    if (!_usesRealWindowManager()) return;
    if (_maximized) {
      await windowManager.unmaximize();
    } else {
      await windowManager.maximize();
    }
  }

  Future<void> _close() async {
    if (widget.onClose != null) {
      widget.onClose!();
      return;
    }
    if (_usesRealWindowManager()) await windowManager.close();
  }

  /// Starts an OS-native window drag. Debounced because Flutter can fire
  /// duplicate pointer-down callbacks during the first drag frame.
  void _startDrag() {
    if (!_usesRealWindowManager()) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 200), () {
      windowManager.startDragging();
    });
  }

  static const _buttons = <_WindowAction>[
    _WindowAction(Icons.remove, Icons.remove),
    _WindowAction(Icons.crop_square, Icons.filter_none),
    _WindowAction(Icons.close, Icons.close),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerLow,
      child: SizedBox(
        height: kWindowTitleBarHeight,
        child: Row(
          children: [
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanUpdate: (_) => _startDrag(),
                onDoubleTap: widget.onDoubleTapMaximize ?? _maximize,
                child: Container(
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Icon(Icons.timer,
                          size: 18, color: scheme.onSurfaceVariant),
                      const SizedBox(width: 8),
                      Text(
                        widget.title,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            ..._buildWindowButtons(context),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildWindowButtons(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final closeColor = scheme.error;
    return [
      for (var i = 0; i < _buttons.length; i++)
        _WindowButton(
          icon: i == 1 && _maximized
              ? _buttons[i].restoreIcon
              : _buttons[i].icon,
          tooltip: switch (i) {
            0 => '最小化',
            1 => _maximized ? '还原' : '最大化',
            _ => '关闭',
          },
          color: i == 2 ? closeColor : scheme.onSurfaceVariant,
          onPressed: switch (i) {
            0 => _minimize,
            1 => _maximize,
            _ => _close,
          },
        ),
    ];
  }
}

class _WindowAction {
  const _WindowAction(this.icon, this.restoreIcon);
  final IconData icon;
  final IconData restoreIcon;
}

class _WindowButton extends StatelessWidget {
  const _WindowButton({
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: SizedBox(
        width: 46,
        height: kWindowTitleBarHeight,
        child: InkWell(
          hoverColor: scheme.surfaceContainerHighest,
          onTap: onPressed,
          child: Center(
            child: Icon(icon, size: 17, color: color),
          ),
        ),
      ),
    );
  }
}
