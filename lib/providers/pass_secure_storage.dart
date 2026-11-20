import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';

/// GPG-encrypted Linux credentials stored using the existing `pass` CLI.
class PassSecureStorage extends FlutterSecureStoragePlatform {
  static const _entry = 'com.lkcv.kurage/secure-storage';

  String get _filePath {
    final configured = Platform.environment['PASSWORD_STORE_DIR'];
    if (configured != null) return '$configured/$_entry.gpg';
    final home = Platform.environment['HOME'];
    if (home == null) throw StateError('HOME is not set');
    return '$home/.password-store/$_entry.gpg';
  }

  Future<Map<String, String>> _load() async {
    if (!await File(_filePath).exists()) return {};
    final result = await Process.run('pass', ['show', _entry]);
    if (result.exitCode != 0) {
      throw StateError('pass show failed (exit ${result.exitCode})');
    }
    return Map<String, String>.from(jsonDecode(result.stdout as String) as Map);
  }

  Future<void> _store(Map<String, String> values) async {
    if (values.isEmpty) {
      if (!await File(_filePath).exists()) return;
      final result = await Process.run('pass', ['rm', '--force', _entry]);
      if (result.exitCode != 0) {
        throw StateError('pass rm failed (exit ${result.exitCode})');
      }
      return;
    }

    // Send credentials through stdin, never through process arguments or a shell.
    final process = await Process.start('pass', [
      'insert',
      '--multiline',
      '--force',
      _entry,
    ]);
    final stdout = process.stdout.drain<void>();
    final stderr = process.stderr.drain<void>();
    process.stdin.write(jsonEncode(values));
    await process.stdin.close();
    final exitCode = await process.exitCode;
    await Future.wait([stdout, stderr]);
    if (exitCode != 0) {
      throw StateError('pass insert failed (exit $exitCode)');
    }
  }

  @override
  Future<void> write({
    required String key,
    required String value,
    required Map<String, String> options,
  }) async {
    final values = await _load();
    values[key] = value;
    await _store(values);
  }

  @override
  Future<String?> read({
    required String key,
    required Map<String, String> options,
  }) async => (await _load())[key];

  @override
  Future<bool> containsKey({
    required String key,
    required Map<String, String> options,
  }) async => (await _load()).containsKey(key);

  @override
  Future<void> delete({
    required String key,
    required Map<String, String> options,
  }) async {
    final values = await _load();
    if (values.remove(key) != null) await _store(values);
  }

  @override
  Future<Map<String, String>> readAll({required Map<String, String> options}) =>
      _load();

  @override
  Future<void> deleteAll({required Map<String, String> options}) => _store({});
}
