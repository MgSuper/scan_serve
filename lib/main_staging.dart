import 'package:startup_launch/core/config/environment.dart';
import 'package:startup_launch/main_common.dart';

void main() async {
  await bootstrap(Environment.staging);
}
