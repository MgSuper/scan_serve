import 'package:get_it/get_it.dart';
import 'package:scan_serve/app/localization/locale_cubit.dart';
import 'package:scan_serve/app/theme/theme_cubit.dart';
import 'package:scan_serve/core/config/app_config.dart';
import 'package:scan_serve/core/network/api_client.dart';
import 'package:scan_serve/core/network/dio_factory.dart';
import 'package:scan_serve/features/onboarding/data/onboarding_storage.dart';
import 'package:scan_serve/features/customer/data/demo_customer_repository.dart';
import 'package:scan_serve/features/customer/domain/customer_repository.dart';

final sl = GetIt.instance;

Future<void> setupLocator(AppConfig config) async {
  // 1. Config first
  sl.registerSingleton<AppConfig>(config);

  // 2. Network layer
  final dio = DioFactory.create();
  sl.registerSingleton(dio);
  sl.registerLazySingleton(() => ApiClient(sl()));

  // 3. UI State (Theme & Locale)
  // Use registerSingleton instead of Lazy if you plan to init them immediately
  sl.registerSingleton(ThemeCubit());
  sl.registerSingleton(LocaleCubit());

  if (!sl.isRegistered<OnboardingStorage>()) {
    sl.registerLazySingleton<OnboardingStorage>(
      SharedPrefsOnboardingStorage.new,
    );
  }

  if (!sl.isRegistered<CustomerRepository>()) {
    sl.registerLazySingleton<CustomerRepository>(DemoCustomerRepository.new);
  }
}
