// This Files purpose is to have a login screen where the user can login into the server
import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:kurage/providers/login.dart';
import 'package:kurage/providers/connection_manager.dart';
import 'package:provider/provider.dart';
import 'package:kurage/screens/home_screen.dart';

import 'package:kurage/variables.dart';
import 'package:isar_community/isar.dart';
import 'package:kurage/models/login.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _url = TextEditingController();
  final _username = TextEditingController();
  final _password = TextEditingController();
  bool _passwordVisible = false;
  String _error = '';
  bool _isConnecting = false;
  QuickConnectSession? _quickConnect;

  static const _quickConnectPollInterval = Duration(seconds: 5);
  // Consecutive network failures tolerated while waiting for authorization.
  static const _quickConnectMaxPollFailures = 3;

  @override
  void initState() {
    super.initState();
    _passwordVisible = false;

    // Prefill fields from saved login if available
    _prefillFromSavedLogin();
  }

  Future<void> _prefillFromSavedLogin() async {
    final isar = Isar.getInstance();
    final savedLogin = await isar?.logins.where().findFirst();

    if (savedLogin != null && mounted) {
      setState(() {
        _url.text = savedLogin.serverUrl;
        _username.text = savedLogin.username;
        // Don't prefill password for security
      });
    }
  }

  final FocusNode _focusNode1 = FocusNode();
  final FocusNode _focusNode2 = FocusNode();
  final FocusNode _focusNode3 = FocusNode();
  final FocusNode _focusNode4 = FocusNode();

  @override
  void dispose() {
    _focusNode1.dispose();
    _focusNode2.dispose();
    _focusNode3.dispose();
    _focusNode4.dispose();
    _url.dispose();
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  void _openHome() {
    unawaited(context.read<ConnectionManager>().validateNewSession());
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const HomeScreen()),
    );
  }

  Future<void> _startQuickConnect() async {
    if (_isConnecting || _quickConnect != null) return;
    if (_url.text.trim().isEmpty) {
      setState(() => _error = 'Enter your server address.');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _isConnecting = true;
      _error = '';
    });
    try {
      final session = await LoginProvider.initiateQuickConnect(_url.text);
      if (!mounted) return;
      setState(() => _quickConnect = session);
      unawaited(_pollQuickConnect(session));
    } catch (error) {
      if (mounted) {
        setState(() => _error = LoginProvider.quickConnectError(error));
      }
    } finally {
      if (mounted) setState(() => _isConnecting = false);
    }
  }

  Future<void> _pollQuickConnect(QuickConnectSession session) async {
    var failures = 0;
    while (mounted && identical(_quickConnect, session)) {
      await Future<void>.delayed(_quickConnectPollInterval);
      if (!mounted || !identical(_quickConnect, session)) return;
      try {
        if (!await session.isAuthorized()) {
          failures = 0;
          continue;
        }
      } on DioException catch (error) {
        // Ride out brief network drops instead of discarding the code.
        if (++failures < _quickConnectMaxPollFailures) continue;
        _failQuickConnect(session, error);
        return;
      } catch (error) {
        _failQuickConnect(session, error);
        return;
      }
      if (!mounted || !identical(_quickConnect, session)) return;
      setState(() => _isConnecting = true);
      try {
        await session.authenticate();
        if (!mounted) return;
        _openHome();
      } catch (error) {
        _failQuickConnect(session, error);
      }
      return;
    }
  }

  void _failQuickConnect(QuickConnectSession session, Object error) {
    if (!mounted || !identical(_quickConnect, session)) return;
    setState(() {
      _quickConnect = null;
      _error = LoginProvider.quickConnectError(error);
      _isConnecting = false;
    });
  }

  void _cancelQuickConnect() {
    setState(() {
      _quickConnect = null;
      _error = '';
    });
  }

  Future<void> _connect() async {
    if (_isConnecting) return;
    final address = _url.text.trim();
    final username = _username.text.trim();
    if (address.isEmpty || username.isEmpty) {
      setState(() {
        _error = address.isEmpty
            ? 'Enter your server address.'
            : 'Enter your username.';
      });
      return;
    }

    setState(() {
      _isConnecting = true;
      _error = '';
    });
    try {
      final result = await LoginProvider.loginStatic(
        address,
        username,
        _password.text,
      );
      if (!mounted) return;
      if (result == 'true') {
        _openHome();
      } else {
        setState(() => _error = result);
      }
    } catch (e) {
      logger.e('Unexpected login screen failure (${e.runtimeType})');
      if (!mounted) return;
      setState(() => _error = 'Could not sign in. Please try again.');
    } finally {
      if (mounted) setState(() => _isConnecting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Form(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                "クラゲ",
                style: TextStyle(fontSize: 50, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 50),
              Padding(
                padding: const EdgeInsets.fromLTRB(25, 8, 25, 8),
                child: TextFormField(
                  key: const Key('urlField'),
                  controller: _url,
                  focusNode: _focusNode1,
                  keyboardType: TextInputType.url,
                  enabled: !_isConnecting && _quickConnect == null,
                  decoration: InputDecoration(
                    labelText: "Web Address",
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(height: 5),
              if (_quickConnect == null) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(25, 8, 25, 8),
                  child: TextFormField(
                    key: const Key('usernameField'),
                    controller: _username,
                    focusNode: _focusNode2,
                    autofillHints: const [],
                    enableSuggestions: false,
                    decoration: InputDecoration(
                      labelText: "Username",
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(height: 5),
                Padding(
                  padding: const EdgeInsets.fromLTRB(25, 8, 25, 8),
                  child: TextFormField(
                    key: const Key('passwordField'),
                    controller: _password,
                    focusNode: _focusNode3,
                    obscureText: !_passwordVisible,
                    decoration: InputDecoration(
                      labelText: "Password",
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _passwordVisible
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                        onPressed: () {
                          setState(() {
                            _passwordVisible = !_passwordVisible;
                          });
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: MediaQuery.of(context).size.width - 50,
                  height: 50,
                  child: ElevatedButton(
                    key: const Key('connectButton'),
                    focusNode: _focusNode4,
                    onPressed: _isConnecting ? null : _connect,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.login),
                        const SizedBox(width: 10),
                        Text("Connect", style: const TextStyle(fontSize: 20)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: MediaQuery.of(context).size.width - 50,
                  height: 50,
                  child: OutlinedButton.icon(
                    onPressed: _isConnecting ? null : _startQuickConnect,
                    icon: const Icon(Icons.devices_rounded),
                    label: const Text(
                      'Quick Connect',
                      style: TextStyle(fontSize: 20),
                    ),
                  ),
                ),
              ] else ...[
                const SizedBox(height: 16),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 25),
                  child: Text(
                    'Enter this code in Jellyfin under Settings → Quick Connect.',
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 12),
                SelectableText(
                  _quickConnect!.code,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      _isConnecting
                          ? 'Signing in…'
                          : 'Waiting for authorization…',
                    ),
                  ],
                ),
                TextButton(
                  onPressed: _isConnecting ? null : _cancelQuickConnect,
                  child: const Text('Cancel'),
                ),
              ],
              const SizedBox(height: 15),
              Padding(
                padding: const EdgeInsets.fromLTRB(25, 8, 25, 8),
                child: Text(_error, style: const TextStyle(color: Colors.red)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
