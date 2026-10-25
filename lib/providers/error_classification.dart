import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:kurage/providers/download_exceptions.dart';

enum AppErrorKind {
  unreachable,
  connectionTimeout,
  timeout,
  httpResponse,
  network,
  invalidData,
  storage,
  unsupported,
  certificate,
  canceled,
  unknown,
}

class ClassifiedError {
  const ClassifiedError(this.kind, {this.httpStatus});

  final AppErrorKind kind;
  final int? httpStatus;
}

ClassifiedError classifyError(Object? error) => switch (error) {
      SocketException() ||
      DioException(type: DioExceptionType.connectionError) ||
      DioException(error: SocketException()) =>
        const ClassifiedError(AppErrorKind.unreachable),
      DioException(type: DioExceptionType.connectionTimeout) =>
        const ClassifiedError(AppErrorKind.connectionTimeout),
      DioException(response: final response)
          when response?.statusCode != null =>
        ClassifiedError(
          AppErrorKind.httpResponse,
          httpStatus: response!.statusCode,
        ),
      DioException(error: FileSystemException()) ||
      FileSystemException() =>
        const ClassifiedError(AppErrorKind.storage),
      DioException(error: FormatException()) ||
      FormatException() =>
        const ClassifiedError(AppErrorKind.invalidData),
      DioException(
        type: DioExceptionType.receiveTimeout || DioExceptionType.sendTimeout,
      ) ||
      TimeoutException() =>
        const ClassifiedError(AppErrorKind.timeout),
      DioException(
        type: DioExceptionType.badResponse || DioExceptionType.unknown,
      ) ||
      HttpException() ||
      HandshakeException() ||
      InterruptedDownload() =>
        const ClassifiedError(AppErrorKind.network),
      DioException(type: DioExceptionType.badCertificate) =>
        const ClassifiedError(AppErrorKind.certificate),
      DioException(type: DioExceptionType.cancel) =>
        const ClassifiedError(AppErrorKind.canceled),
      UnsupportedError() => const ClassifiedError(AppErrorKind.unsupported),
      _ => const ClassifiedError(AppErrorKind.unknown),
    };
