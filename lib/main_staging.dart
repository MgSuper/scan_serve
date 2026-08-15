import 'package:scan_serve/core/config/environment.dart';
import 'package:scan_serve/main_common.dart';

void main() async {
  await bootstrap(Environment.staging);
}
