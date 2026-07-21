import 'package:dio/dio.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';

Interceptor loggerInterceptor() {
  return PrettyDioLogger(
    requestBody: true,
    requestHeader: true,
    responseBody: true,
  );
}
