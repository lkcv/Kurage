// The purpose of this file is to have a screen where the users
// can see all their comics and manage them

import 'package:material_ui/material_ui.dart';
import 'dart:io';
import 'package:flutter/services.dart'
    show
        HapticFeedback,
        HardwareKeyboard,
        KeyDownEvent,
        KeyEvent,
        LogicalKeyboardKey;
import 'package:kurage/models/login.dart';
import 'package:isar_community/isar.dart';
import 'package:google_nav_bar/google_nav_bar.dart';
import 'package:provider/provider.dart';

// Screens imports
import 'package:kurage/screens/library_screen.dart';
import 'package:kurage/screens/settings_screen.dart';
import 'package:kurage/cache/cache_usage_snapshot.dart';
import 'package:kurage/screens/search_screen.dart';
import 'package:kurage/screens/login_screen.dart';
import 'package:kurage/variables.dart';
import 'package:kurage/providers/connection_manager.dart';
import 'package:kurage/providers/theme_provider.dart';
import 'package:kurage/themes/accent_palette.dart';
import 'package:kurage/widgets/linux_gamepad_input.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    if (Platform.isLinux) {
      HardwareKeyboard.instance.addHandler(_onDesktopKey);
      LinuxGamepadInput.instance.addListener(_onGamepad);
    }
  }

  @override
  void dispose() {
    if (Platform.isLinux) {
      HardwareKeyboard.instance.removeHandler(_onDesktopKey);
      LinuxGamepadInput.instance.removeListener(_onGamepad);
    }
    super.dispose();
  }

  Future<void> logout() async {
    final isar = Isar.getInstance();
    var logins = await isar!.logins.where().findAll();
    var loginIds = logins.map((e) => e.isarId).toList();
    await isar.writeTxn(() async {
      isar.logins.deleteAll(loginIds);
      logger.d('deleted ${loginIds.length} logins');
    });
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }

  final _libraryKey = GlobalKey<LibraryScreenState>();
  int _selectedIndex = 0;
  // Last non-search tab so Search can return to wherever the user was
  int _previousIndex = 0;
  int _tabRequest = 0;
  CacheUsageSnapshot? _settingsUsage;

  static const int _searchIndex = 1;
  static const Duration _tabAnimationDuration = Duration(milliseconds: 200);

  void _goBackFromSearch() {
    _tabRequest++;
    setState(() {
      _selectedIndex = _previousIndex;
    });
  }

  Future<void> _onTabChange(int index) async {
    final request = ++_tabRequest;
    if (index == 2 && _selectedIndex != 2) {
      final usage = await CacheUsageSnapshot.load();
      if (!mounted || request != _tabRequest) return;
      _settingsUsage = usage;
    }
    setState(() {
      // Remember where we were when entering Search
      if (index == _searchIndex && _selectedIndex != _searchIndex) {
        _previousIndex = _selectedIndex;
      }
      _selectedIndex = index;
    });
  }

  bool _onGamepad(String action, bool pressed) {
    if (!mounted || !pressed || ModalRoute.of(context)?.isCurrent != true) {
      return false;
    }
    switch (action) {
      case 'west':
        _onTabChange(0);
        return true;
      case 'search':
        _onTabChange(_searchIndex);
        return true;
      case 'menu':
        _onTabChange(2);
        return true;
      case 'l1':
        if (_selectedIndex != 0) return false;
        _libraryKey.currentState?.toggleDownloadedFilter(keepSelection: true);
        return true;
      case 'r1':
        if (_selectedIndex != 0) return false;
        _libraryKey.currentState?.toggleReadingFilter(keepSelection: true);
        return true;
    }
    return false;
  }

  // Route-scoped shortcuts don't alter focus or intercept text entry.
  bool _onDesktopKey(KeyEvent event) {
    if (!mounted ||
        event is! KeyDownEvent ||
        ModalRoute.of(context)?.isCurrent != true ||
        HardwareKeyboard.instance.isShiftPressed ||
        HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isAltPressed ||
        HardwareKeyboard.instance.isMetaPressed) {
      return false;
    }

    final focused = FocusManager.instance.primaryFocus?.context;
    if (focused?.widget is EditableText ||
        focused?.findAncestorStateOfType<EditableTextState>() != null) {
      return false;
    }

    switch (event.logicalKey) {
      case LogicalKeyboardKey.keyL:
        _onTabChange(0);
      case LogicalKeyboardKey.space:
        _onTabChange(_searchIndex);
      case LogicalKeyboardKey.keyS:
        _onTabChange(2);
      case LogicalKeyboardKey.keyD:
        if (_selectedIndex != 0) return false;
        _libraryKey.currentState?.toggleDownloadedFilter(keepSelection: true);
      case LogicalKeyboardKey.keyR:
        if (_selectedIndex != 0) return false;
        _libraryKey.currentState?.toggleReadingFilter(keepSelection: true);
      default:
        return false;
    }
    return true;
  }

  // Give each tab an equal third of the bar and allow immediate selection.
  // GNav animates the visual change using its existing 200ms duration.
  void _onWideTabTap(int index) {
    if (index == _selectedIndex) return;
    HapticFeedback.selectionClick();
    _onTabChange(index);
  }

  // Keep the Library mounted to retain its image listeners and scroll state.
  // Other tabs are still disposed when they are no longer selected.
  Widget _otherTab() {
    switch (_selectedIndex) {
      case 1:
        return SearchScreen(onBack: _goBackFromSearch);
      case 2:
        return SettingsScreen(
          cacheUsage: _settingsUsage!,
          onBack: () => _onTabChange(0),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Watch the ConnectionManager from the provider
    final connectionManager = Provider.of<ConnectionManager>(context);
    final accent = context.watch<ThemeChangeNotifier>().accentColor;
    final gradientEnd =
        AccentPalette.forColor(accent)?.gradientEnd ??
        AccentPalette.defaultGradientEnd;

    // If auth failed, redirect to login
    if (connectionManager.status == ConnectionStatus.authFailed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const LoginScreen()),
          );
        }
      });
    }

    // Keep Android's current bar height unchanged. On iPhone, extend the same
    // colored bar below its tappable content to clear the home indicator.
    final iosBottomInset = Theme.of(context).platform == TargetPlatform.iOS
        ? MediaQuery.paddingOf(context).bottom
        : 0.0;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      extendBody: true,
      body: IndexedStack(
        index: _selectedIndex == 0 ? 0 : 1,
        children: [
          LibraryScreen(key: _libraryKey, isActive: _selectedIndex == 0),
          _otherTab(),
        ],
      ),
      bottomNavigationBar: Container(
        // Reserve space beneath the bar for the keyboard so GNav stays
        // visible and tappable directly above it.
        margin: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        height: 70 + iosBottomInset,
        padding: EdgeInsets.only(bottom: iosBottomInset),
        decoration: BoxDecoration(
          color:
              accent != null && Theme.of(context).brightness == Brightness.light
              ? accent
              : Theme.of(context).primaryColor,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        // Retain the original GNav as the visual/animation layer.
        // A full-width hit layer assigns every point to one of 3 tabs.
        child: Stack(
          fit: StackFit.expand,
          children: [
            ExcludeSemantics(
              child: IgnorePointer(
                child: Padding(
                  padding: const EdgeInsets.only(
                    left: 15.0,
                    right: 15.0,
                    top: 8,
                    bottom: 15,
                  ),
                  child: GNav(
                    rippleColor: Theme.of(context).colorScheme.secondary,
                    hoverColor: Theme.of(context).colorScheme.secondary,
                    activeColor: Colors.white,
                    tabBorderRadius: 15,
                    tabBackgroundGradient: LinearGradient(
                      colors: [
                        (accent ?? ThemeChangeNotifier.defaultAccent)
                            .withValues(alpha: 0.75),
                        gradientEnd.withValues(alpha: 0.75),
                      ],
                    ),
                    tabActiveBorder:
                        Theme.of(context).brightness == Brightness.dark
                        ? Border.all(color: Colors.transparent, width: 0)
                        : Border.all(color: Colors.white, width: 1),
                    haptic: true,
                    iconSize: 24,
                    gap: 7,
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                    duration: _tabAnimationDuration,
                    tabBackgroundColor: Theme.of(context).primaryColor,
                    color: Colors.white,
                    tabs: [
                      GButton(
                        icon: Icons.local_library_outlined,
                        text: "Library",
                      ),
                      GButton(icon: Icons.search, text: "Search"),
                      GButton(icon: Icons.settings, text: "Settings"),
                    ],
                    selectedIndex: _selectedIndex,
                    onTabChange: _onTabChange,
                  ),
                ),
              ),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var index = 0; index < 3; index++)
                  Expanded(
                    child: Semantics(
                      label: ["Library", "Search", "Settings"][index],
                      button: true,
                      selected: _selectedIndex == index,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => _onWideTabTap(index),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
