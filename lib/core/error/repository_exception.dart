import 'package:scan_serve/core/network/exceptions/app_exception.dart';

class RepositoryException extends AppException {
  RepositoryException(super.message, {super.statusCode});
}
