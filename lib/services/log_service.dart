import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';

class LogService {
  static final LogService _instance = LogService._internal();
  factory LogService() => _instance;
  LogService._internal();

  File? _logFile;
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    try {
      final dir = await getApplicationSupportDirectory();
      final logDir = Directory('${dir.path}/logs');
      if (!await logDir.exists()) {
        await logDir.create(recursive: true);
      }
      final now = DateTime.now();
      final fileName = 'nowrss_${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}.log';
      _logFile = File('${logDir.path}/$fileName');
      _initialized = true;
      await _write('LogService initialized. Log file: ${_logFile?.path}');
    } catch (e) {
      // If logging fails, silently fail — don't crash the app
      stderr.writeln('LogService init failed: $e');
    }
  }

  Future<void> _write(String line) async {
    if (_logFile == null) return;
    try {
      final ts = DateFormat('yyyy-MM-dd HH:mm:ss.SSS').format(DateTime.now());
      await _logFile!.writeAsString('$ts $line\n', mode: FileMode.append);
    } catch (_) {
      // Silent fail
    }
  }

  /// Log a general info message
  Future<void> info(String message) async {
    await _write('[INFO] ${_obfuscate(message)}');
  }

  /// Log a debug message
  Future<void> debug(String message) async {
    await _write('[DEBUG] ${_obfuscate(message)}');
  }

  /// Log a warning
  Future<void> warning(String message) async {
    await _write('[WARN] ${_obfuscate(message)}');
  }

  /// Log an error with optional stack trace
  Future<void> error(String message, {Object? error, StackTrace? stackTrace}) async {
    var line = '[ERROR] ${_obfuscate(message)}';
    if (error != null) {
      line += ' | Exception: ${_obfuscate(error.toString())}';
    }
    await _write(line);
    if (stackTrace != null) {
      await _write('[STACK] ${_obfuscate(stackTrace.toString())}');
    }
  }

  /// Log an API request (obfuscates sensitive data)
  Future<void> apiRequest(String method, String url, {Map<String, dynamic>? body}) async {
    final obfuscatedUrl = _obfuscate(url);
    var line = '[API-REQ] $method $obfuscatedUrl';
    if (body != null) {
      line += ' | Body: ${_obfuscateJson(body)}';
    }
    await _write(line);
  }

  /// Log an API response
  Future<void> apiResponse(String method, String url, int statusCode, {String? bodyPreview}) async {
    final obfuscatedUrl = _obfuscate(url);
    var line = '[API-RES] $method $obfuscatedUrl | Status: $statusCode';
    if (bodyPreview != null && bodyPreview.isNotEmpty) {
      final preview = bodyPreview.length > 200 ? '${bodyPreview.substring(0, 200)}...' : bodyPreview;
      line += ' | Body: ${_obfuscate(preview)}';
    }
    await _write(line);
  }

  /// Log AI provider interaction
  Future<void> aiRequest(String provider, String model, String operation) async {
    await _write('[AI-REQ] Provider: $provider | Model: $model | Op: $operation');
  }

  Future<void> aiResponse(String provider, String model, String operation, {bool success = true, String? error}) async {
    final status = success ? 'SUCCESS' : 'FAILED';
    var line = '[AI-RES] Provider: $provider | Model: $model | Op: $operation | Status: $status';
    if (error != null) {
      line += ' | Error: ${_obfuscate(error)}';
    }
    await _write(line);
  }

  /// Log sync operations
  Future<void> syncStart(String type) async {
    await _write('[SYNC-START] Type: $type');
  }

  Future<void> syncComplete(String type, int count, {String? error}) async {
    if (error != null) {
      await _write('[SYNC-FAIL] Type: $type | Error: ${_obfuscate(error)}');
    } else {
      await _write('[SYNC-COMPLETE] Type: $type | Articles: $count');
    }
  }

  /// Get log file path for viewing/exporting
  String? get logFilePath => _logFile?.path;

  /// Obfuscate sensitive strings (API keys, passwords, tokens, session IDs)
  static String _obfuscate(String input) {
    var result = input;

    // Obfuscate API keys
    result = result.replaceAllMapped(
      RegExp(r'api[_-]?key\s*[:=]\s*\S+', caseSensitive: false),
      (m) => 'api_key=[REDACTED-API-KEY]',
    );

    // Obfuscate Bearer tokens
    result = result.replaceAllMapped(
      RegExp(r'Bearer\s+\S+', caseSensitive: false),
      (m) => 'Bearer [REDACTED-TOKEN]',
    );

    // Obfuscate Basic auth credentials in URLs
    result = result.replaceAllMapped(
      RegExp(r'https?://[^\s@]+:[^\s@]+@'),
      (m) => 'https://[REDACTED-CREDS]@',
    );

    // Obfuscate password fields
    result = result.replaceAllMapped(
      RegExp(r'password\s*[:=]\s*\S+', caseSensitive: false),
      (m) => 'password=[REDACTED-PASSWORD]',
    );

    // Obfuscate session IDs
    result = result.replaceAllMapped(
      RegExp(r'session[_-]?id\s*[:=]\s*\S+', caseSensitive: false),
      (m) => 'session_id=[REDACTED-SESSION]',
    );

    // Obfuscate long hex tokens
    result = result.replaceAllMapped(
      RegExp(r'\b[a-f0-9]{32,}\b', caseSensitive: false),
      (m) => '[REDACTED-TOKEN]',
    );

    return result;
  }

  static String _obfuscateJson(Map<String, dynamic> json) {
    final redacted = Map<String, dynamic>.from(json);
    final sensitiveKeys = ['api_key', 'apikey', 'apiKey', 'password', 'token', 'secret', 'session_id', 'auth'];
    for (final key in sensitiveKeys) {
      if (redacted.containsKey(key)) {
        redacted[key] = '[REDACTED]';
      }
    }
    return redacted.toString();
  }
}
