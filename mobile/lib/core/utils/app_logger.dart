import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

class AppLogger {
  AppLogger._();

  static final Logger _logger = Logger(
    level: kDebugMode ? Level.all : Level.warning,
    printer: PrettyPrinter(methodCount: 0, noBoxingByDefault: true),
    output: kDebugMode ? ConsoleOutput() : null,
  );

  static void d(String message, {dynamic error, StackTrace? stackTrace}) =>
      _logger.d(message, error: error, stackTrace: stackTrace);

  static void i(String message, {dynamic error, StackTrace? stackTrace}) =>
      _logger.i(message, error: error, stackTrace: stackTrace);

  static void w(String message, {dynamic error, StackTrace? stackTrace}) =>
      _logger.w(message, error: error, stackTrace: stackTrace);

  static void e(String message, {dynamic error, StackTrace? stackTrace}) =>
      _logger.e(message, error: error, stackTrace: stackTrace);
}
