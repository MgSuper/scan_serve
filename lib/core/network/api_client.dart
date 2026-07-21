import 'package:dio/dio.dart';
import 'package:startup_launch/core/network/exceptions/app_exception.dart';

class ApiClient {
  final Dio dio;

  ApiClient(this.dio);

  Future<Response> get(String path, {Map<String, dynamic>? query}) async {
    try {
      return await dio.get(path, queryParameters: query);
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<Response> post(String path, {dynamic data}) async {
    try {
      return await dio.post(path, data: data);
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  AppException _mapError(DioException e) {
    final code = e.response?.statusCode;

    switch (code) {
      case 401:
        return AppException('Unauthorized', statusCode: code);
      case 404:
        return AppException('Not Found', statusCode: code);
      case 500:
        return AppException('Server Error', statusCode: code);
      default:
        return AppException(e.message ?? 'Unknown Error', statusCode: code);
    }
  }
}
