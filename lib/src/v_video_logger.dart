/// Configurable logging system for V Video Compressor
library;

import 'dart:developer' as developer;

/// Log levels for V Video Compressor
enum VVideoLogLevel {
  none(0, 'NONE'),
  error(1, 'ERROR'),
  warning(2, 'WARNING'),
  info(3, 'INFO'),
  debug(4, 'DEBUG'),
  verbose(5, 'VERBOSE');

  const VVideoLogLevel(this.level, this.name);

  final int level;
  final String name;
}

/// Configuration for V Video Compressor logging
class VVideoLogConfig {
  /// Enable or disable logging
  final bool enabled;

  /// Log level threshold
  final VVideoLogLevel level;

  /// Show stack traces for errors
  final bool showStackTrace;

  /// Show method parameters in logs
  final bool showParameters;

  /// Show progress logs
  final bool showProgress;

  /// Show success logs
  final bool showSuccess;

  /// Custom log prefix
  final String? customPrefix;

  /// Log to console (print) instead of developer log
  final bool useConsoleLog;

  const VVideoLogConfig({
    this.enabled = true,
    this.level = VVideoLogLevel.info,
    this.showStackTrace = true,
    this.showParameters = false,
    this.showProgress = false,
    this.showSuccess = true,
    this.customPrefix,
    this.useConsoleLog = false,
  });

  /// Create a config for production (minimal logging)
  const VVideoLogConfig.production()
    : enabled = true,
      level = VVideoLogLevel.error,
      showStackTrace = false,
      showParameters = false,
      showProgress = false,
      showSuccess = false,
      customPrefix = null,
      useConsoleLog = false;

  /// Create a config for development (verbose logging)
  const VVideoLogConfig.development()
    : enabled = true,
      level = VVideoLogLevel.verbose,
      showStackTrace = true,
      showParameters = true,
      showProgress = true,
      showSuccess = true,
      customPrefix = null,
      useConsoleLog = false;

  /// Create a config for debugging (all logs)
  const VVideoLogConfig.debug()
    : enabled = true,
      level = VVideoLogLevel.debug,
      showStackTrace = true,
      showParameters = true,
      showProgress = true,
      showSuccess = true,
      customPrefix = '[V_VIDEO_DEBUG]',
      useConsoleLog = true;

  /// Disable all logging
  const VVideoLogConfig.disabled()
    : enabled = false,
      level = VVideoLogLevel.none,
      showStackTrace = false,
      showParameters = false,
      showProgress = false,
      showSuccess = false,
      customPrefix = null,
      useConsoleLog = false;
}

/// Internal logging utility for V Video Compressor with configurable options
class VVideoLogger {
  static VVideoLogConfig _config = const VVideoLogConfig();
  static const String _defaultTag = 'VVideoCompressor';

  /// Configure the logger
  static void configure(VVideoLogConfig config) {
    _config = config;
  }

  /// Get current configuration
  static VVideoLogConfig get config => _config;

  /// Log error messages
  static void error(String message, [Object? error, StackTrace? stackTrace]) {
    if (!_config.enabled || _config.level.level < VVideoLogLevel.error.level) {
      return;
    }

    _log(
      message,
      VVideoLogLevel.error,
      error: error,
      stackTrace: _config.showStackTrace ? stackTrace : null,
    );
  }

  /// Log warning messages
  static void warning(String message, [Object? error, StackTrace? stackTrace]) {
    if (!_config.enabled ||
        _config.level.level < VVideoLogLevel.warning.level) {
      return;
    }

    _log(
      message,
      VVideoLogLevel.warning,
      error: error,
      stackTrace: _config.showStackTrace ? stackTrace : null,
    );
  }

  /// Log info messages
  static void info(String message, [Object? error, StackTrace? stackTrace]) {
    if (!_config.enabled || _config.level.level < VVideoLogLevel.info.level) {
      return;
    }

    _log(message, VVideoLogLevel.info, error: error, stackTrace: stackTrace);
  }

  /// Log debug messages
  static void debug(String message, [Object? error, StackTrace? stackTrace]) {
    if (!_config.enabled || _config.level.level < VVideoLogLevel.debug.level) {
      return;
    }

    _log(message, VVideoLogLevel.debug, error: error, stackTrace: stackTrace);
  }

  /// Log verbose messages
  static void verbose(String message, [Object? error, StackTrace? stackTrace]) {
    if (!_config.enabled ||
        _config.level.level < VVideoLogLevel.verbose.level) {
      return;
    }

    _log(message, VVideoLogLevel.verbose, error: error, stackTrace: stackTrace);
  }

  /// Log method calls for debugging
  static void methodCall(String methodName, Map<String, dynamic>? params) {
    if (!_config.enabled || _config.level.level < VVideoLogLevel.debug.level) {
      return;
    }

    String message = 'Method: $methodName';
    if (_config.showParameters && params != null && params.isNotEmpty) {
      final paramsStr = params.entries
          .map((e) => '${e.key}: ${e.value}')
          .join(', ');
      message += '($paramsStr)';
    } else {
      message += '()';
    }

    _log(message, VVideoLogLevel.debug);
  }

  /// Log compression progress
  static void progress(String operation, double progress, [String? details]) {
    if (!_config.enabled ||
        !_config.showProgress ||
        _config.level.level < VVideoLogLevel.info.level) {
      return;
    }

    final progressPercent = (progress * 100).toStringAsFixed(1);
    final message = details != null
        ? '$operation: $progressPercent% - $details'
        : '$operation: $progressPercent%';

    _log(message, VVideoLogLevel.info);
  }

  /// Log successful operations
  static void success(String operation, [Map<String, dynamic>? details]) {
    if (!_config.enabled ||
        !_config.showSuccess ||
        _config.level.level < VVideoLogLevel.info.level) {
      return;
    }

    String message = '✅ $operation completed successfully';
    if (details != null && details.isNotEmpty) {
      final detailsStr = details.entries
          .map((e) => '${e.key}: ${e.value}')
          .join(', ');
      message += ' - $detailsStr';
    }

    _log(message, VVideoLogLevel.info);
  }

  /// Internal logging method
  static void _log(
    String message,
    VVideoLogLevel level, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    final prefix = _config.customPrefix ?? _defaultTag;
    final fullMessage = '[$prefix] ${level.name}: $message';

    if (_config.useConsoleLog) {
      // Use print for console output (intentional for debug logging)
      // ignore: avoid_print
      print(fullMessage);
      if (error != null) {
        // ignore: avoid_print
        print('[$prefix] Error: $error');
      }
      if (stackTrace != null) {
        // ignore: avoid_print
        print('[$prefix] StackTrace: $stackTrace');
      }
    } else {
      // Use developer.log for structured logging
      final logLevel = switch (level) {
        VVideoLogLevel.error => 1000,
        VVideoLogLevel.warning => 900,
        VVideoLogLevel.info => 800,
        VVideoLogLevel.debug => 700,
        VVideoLogLevel.verbose => 600,
        VVideoLogLevel.none => 0,
      };

      developer.log(
        message,
        name: prefix,
        level: logLevel,
        error: error,
        stackTrace: stackTrace,
      );
    }
  }
}
