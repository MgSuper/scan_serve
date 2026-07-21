import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';

class ConnectivityInterceptor extends Interceptor {
  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // result is now a List<ConnectivityResult>
    final List<ConnectivityResult> result = await Connectivity()
        .checkConnectivity();

    // Check if the list contains 'none'
    if (result.contains(ConnectivityResult.none)) {
      handler.reject(
        DioException(
          requestOptions: options,
          error: 'No internet connection',
          type:
              DioExceptionType.connectionError, // Good practice to set the type
        ),
      );
      return;
    }

    handler.next(options);
  }
}
