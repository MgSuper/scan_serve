import 'package:dio/dio.dart';

class AuthInterceptor extends Interceptor {
  final Dio dio;

  AuthInterceptor(this.dio);

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    const accessToken = '';

    if (accessToken.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $accessToken';
    }

    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode == 401) {
      try {
        // TODO call refresh token endpoint

        const newToken = '';

        final request = err.requestOptions;

        request.headers['Authorization'] = 'Bearer $newToken';

        final response = await dio.fetch(request);

        handler.resolve(response);
        return;
      } catch (_) {}
    }

    handler.next(err);
  }
}
