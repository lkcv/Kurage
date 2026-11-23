import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:kurage/screens/login_screen.dart';
import 'package:kurage/widgets/desktop_shortcuts_overlay.dart';
import 'package:kurage/widgets/linux_gamepad_input.dart';
import 'package:isar_community/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:kurage/models/app_settings.dart';
import 'package:kurage/models/download_queue_record.dart';
import 'package:kurage/models/pending_progress_record.dart';
import 'package:kurage/models/entry.dart';
import 'package:kurage/models/folder.dart';
import 'package:kurage/models/login.dart';
import 'package:kurage/providers/app_settings_store.dart';
import 'package:kurage/providers/session_store.dart';
import 'package:kurage/providers/pass_secure_storage.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:kurage/screens/home_screen.dart';
import 'package:kurage/providers/connection_manager.dart';
import 'package:kurage/providers/download_queue.dart';
import 'dart:io';

import 'package:provider/provider.dart';
import 'package:kurage/providers/theme_provider.dart';
import 'widgets/floating_snackbar.dart';
import 'package:kurage/variables.dart';

final _navigatorKey = GlobalKey<NavigatorState>();

Future<String> get _localPath async {
  // get the directory that normally is located at /storage/emulated/0/Documents/
  Directory directory;
  if (Platform.isAndroid) {
    directory =
        await getExternalStorageDirectory() ??
        await getApplicationDocumentsDirectory();
  } else {
    directory = await getApplicationDocumentsDirectory();
  }
  return directory.path;
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  PaintingBinding.instance.imageCache.maximumSizeBytes = 300 << 20;
  if (Platform.isLinux) {
    FlutterSecureStoragePlatform.instance = PassSecureStorage();
  }

  // Keep system bars hidden; edge swipes reveal them temporarily.
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarBrightness: Brightness.dark,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // dio allow self signed certificates
  HttpOverrides.global = MyHttpOverrides();

  // path for isar database
  Directory dir = await getApplicationDocumentsDirectory();

  final isar = await Isar.open([
    AppSettingsSchema,
    DownloadQueueRecordSchema,
    PendingProgressRecordSchema,
    EntrySchema,
    FolderSchema,
    LoginSchema,
  ], directory: dir.path);
  await AppSettingsStore.initialize(isar);
  await SessionStore.initialize(isar);

  // set the localPath variable
  localPath = await _localPath;
  // check if localPath file exists
  if (!await File("$localPath/kurage.log").exists()) {
    // create the file
    await File("$localPath/kurage.log").create();
  }
  debugPrint("localPath: $localPath");

  final loggedIn = (await isar.logins.count()) > 0;
  runApp(MyApp(loggedIn: loggedIn));
}

class MyApp extends StatelessWidget {
  final bool loggedIn;

  const MyApp({super.key, this.loggedIn = false});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<ThemeChangeNotifier>(
          create: (context) => ThemeChangeNotifier(AppSettingsStore.current),
        ),
        ChangeNotifierProvider<ConnectionManager>(
          create: (context) {
            final manager = ConnectionManager();
            // Resume queued transfers only after this provider verifies Jellyfin.
            DownloadQueue.instance.bindConnectionManager(manager);
            // Start monitoring after creation
            WidgetsBinding.instance.addPostFrameCallback((_) {
              manager.startMonitoring();
            });
            return manager;
          },
        ),
      ],
      builder: (context, _) {
        return _SystemThemeFollower(
          child: Consumer<ThemeChangeNotifier>(
            builder: (context, themeChangeNotifier, _) {
              ThemeData themeData = themeChangeNotifier.getTheme;
              return MaterialApp(
                navigatorKey: _navigatorKey,
                builder: (context, child) => Platform.isLinux
                    ? _LinuxShortcutBindings(child: child!)
                    : child!,
                title: 'Kurage',
                debugShowCheckedModeBanner: false,
                locale: const Locale('en'),
                // Use one consistent floating snackbar style for Light, Dark,
                // AMOLED and the OS-resolved System theme.
                theme: themeData.copyWith(
                  snackBarTheme: floatingSnackBarTheme(themeData),
                ),
                home: loggedIn ? const HomeScreen() : const LoginScreen(),
              );
            },
          ),
        );
      },
    );
  }
}

// Keep desktop shortcuts above every Navigator route, including the reader.
class _LinuxShortcutBindings extends StatefulWidget {
  const _LinuxShortcutBindings({required this.child});

  final Widget child;

  @override
  State<_LinuxShortcutBindings> createState() => _LinuxShortcutBindingsState();
}

class _LinuxShortcutBindingsState extends State<_LinuxShortcutBindings> {
  DialogRoute<void>? _shortcutsRoute;

  @override
  void initState() {
    super.initState();
    LinuxGamepadInput.instance.addListener(_onGamepad);
  }

  @override
  void dispose() {
    LinuxGamepadInput.instance.removeListener(_onGamepad);
    LinuxGamepadInput.instance.removeListener(_onShortcutDialogGamepad);
    super.dispose();
  }

  void _goBack() => _navigatorKey.currentState?.maybePop();

  // Fallback after the active reader/grid has had a chance to handle Back.
  bool _onGamepad(String action, bool pressed) {
    if (!pressed || action != 'back') return false;
    _goBack();
    return true;
  }

  // The F1 dialog sits above nested reader routes; don't pass input behind it.
  bool _onShortcutDialogGamepad(String action, bool pressed) {
    if (_shortcutsRoute?.isCurrent != true) return false;
    if (pressed && action == 'back') _goBack();
    return true;
  }

  void _toggleShortcuts() {
    final navigator = _navigatorKey.currentState;
    final context = _navigatorKey.currentContext;
    if (navigator == null || context == null) return;

    final existing = _shortcutsRoute;
    if (existing != null) {
      if (existing.isCurrent) navigator.pop();
      return;
    }

    final route = DialogRoute<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.18),
      builder: (_) => const DesktopShortcutsOverlay(),
    );
    _shortcutsRoute = route;
    LinuxGamepadInput.instance.addListener(_onShortcutDialogGamepad);
    unawaited(
      navigator.push(route).whenComplete(() {
        LinuxGamepadInput.instance.removeListener(_onShortcutDialogGamepad);
        if (mounted && identical(_shortcutsRoute, route)) {
          _shortcutsRoute = null;
        }
      }),
    );
  }

  @override
  Widget build(BuildContext context) => CallbackShortcuts(
    bindings: {
      const SingleActivator(LogicalKeyboardKey.f1, includeRepeats: false):
          _toggleShortcuts,
      const SingleActivator(
        LogicalKeyboardKey.arrowLeft,
        alt: true,
        includeRepeats: false,
      ): _goBack,
      const SingleActivator(LogicalKeyboardKey.escape, includeRepeats: false):
          _goBack,
    },
    child: Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (event) {
        if (event.kind == PointerDeviceKind.mouse &&
            (event.buttons & kBackMouseButton) != 0) {
          _goBack();
        }
      },
      child: widget.child,
    ),
  );
}

// Keep the effective System theme in memory; only the user's selection is saved.
class _SystemThemeFollower extends StatefulWidget {
  const _SystemThemeFollower({required this.child});

  final Widget child;

  @override
  State<_SystemThemeFollower> createState() => _SystemThemeFollowerState();
}

class _SystemThemeFollowerState extends State<_SystemThemeFollower>
    with WidgetsBindingObserver {
  ThemeChangeNotifier? _themeNotifier;
  bool _updateScheduled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final notifier = Provider.of<ThemeChangeNotifier>(context, listen: false);
    if (!identical(notifier, _themeNotifier)) {
      _themeNotifier?.removeListener(_syncSystemTheme);
      _themeNotifier = notifier;
      notifier.addListener(_syncSystemTheme);
    }
    _syncSystemTheme();
  }

  @override
  void didChangePlatformBrightness() {
    _syncSystemTheme();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _syncSystemTheme();
  }

  void _syncSystemTheme() {
    if (!mounted ||
        _themeNotifier?.selectedTheme != 'system' ||
        _updateScheduled) {
      return;
    }

    // The provider can notify listeners during a Settings rebuild.
    _updateScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateScheduled = false;
      if (!mounted) return;
      _themeNotifier?.syncSystemTheme();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _themeNotifier?.removeListener(_syncSystemTheme);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    HttpClient client = super.createHttpClient(context);
    client.badCertificateCallback =
        (X509Certificate cert, String host, int port) => true;
    return client;
  }
}
