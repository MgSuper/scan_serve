# ScanServe Observability and Remote Configuration Implementation Guide

**Audience:** Engineers maintaining the ScanServe Flutter customer PWA, Angular Admin Dashboard, and Firebase-backed local/production environments.

**Scope:** Google Analytics, Firebase Crashlytics, and Firebase Remote Config, including exact dependency changes, source-file placement, local/offline behavior, production behavior, and Git checkpoints.

> **Important platform constraint:** Firebase Crashlytics is not available for Flutter Web/PWA in the same way it is for Android and iOS. The customer application is a PWA, so Crashlytics must be treated as a native-platform capability with a no-op or alternate web error reporter. Do not import a web-incompatible Crashlytics implementation into a web compilation unit without a conditional wrapper. Google Analytics and Remote Config are web-capable, but Analytics has no Firebase emulator and Remote Config emulator support must be verified against the exact Firebase CLI and SDK versions pinned by the project.[1] [2] [3]

## Architecture decisions before implementation

The integration should follow the existing feature-first/Clean Architecture composition boundaries rather than placing Firebase calls inside widgets or feature BLoCs. Firebase initialization remains in the Flutter bootstrap and Angular `app.config.ts`; small wrapper services own Analytics and Remote Config behavior; Crashlytics is hidden behind a platform-aware error-reporting bridge; and route/session metadata is supplied from the existing `SessionContext` rather than parsed independently in UI code.

| Capability | Flutter PWA | Angular Admin | Local emulator behavior | Production behavior |
|---|---|---|---|---|
| Google Analytics | `firebase_analytics` wrapper | AngularFire `Analytics` wrapper | Log to console; do not expect Firebase Analytics emulator data. | Send page views and funnel events to the configured Firebase project, subject to consent. |
| Crashlytics | Native-only bridge; web uses a no-op or web error sink. | Not normally used for browser JavaScript; use browser error reporting if required. | Disabled by default. | Enabled only after consent and on supported native builds. |
| Remote Config | `firebase_remote_config` service with defaults and short development interval. | AngularFire `RemoteConfig` provider and service. | Prefer deterministic local overrides. Use port `9098` only if the pinned toolchain exposes a working Remote Config emulator. | Fetch and activate from the Firebase Remote Config service. |

The following implementation is intentionally additive. It does not modify `lib/firebase_options.dart`; Firebase app configuration continues to come from the existing generated options and Angular environment files.

---

## Section 1: Dependencies and configuration setup

### 1.1 Flutter dependencies

From the repository root, add the Analytics and Remote Config plugins. Add Crashlytics for native Flutter targets, but keep all direct Crashlytics references behind a conditional platform bridge because this application also builds for Web.

```bash
flutter pub add firebase_analytics
flutter pub add firebase_remote_config
flutter pub add firebase_crashlytics
```

The resulting `pubspec.yaml` dependency block should contain versions compatible with the existing Firebase stack. Do not blindly copy versions from another project; align them with the current `firebase_core` major version and run `flutter pub get` once the versions are selected.

```yaml
# pubspec.yaml
# Existing Firebase dependencies remain unchanged.
firebase_core: ^4.13.0
cloud_firestore: ^6.8.0
cloud_functions: ^6.3.6

# Add these capabilities.
firebase_analytics: ^12.5.0
firebase_remote_config: ^6.6.0
firebase_crashlytics: ^5.3.0
```

The exact compatible versions may move with FlutterFire releases. The important contract is that the three packages are added to the same dependency graph as `firebase_core`, not initialized from an unrelated Firebase app. After changing `pubspec.yaml`, commit only the dependency/configuration step:

```bash
git status --short
git add pubspec.yaml pubspec.lock
git commit -m "chore(flutter): add Firebase observability dependencies"
git push origin feat/implement-architecture-specifications
```

If the project uses a generated lockfile policy, include `pubspec.lock` only if it is tracked and the team expects dependency locks to be committed.

### 1.2 Angular dependencies

The Angular dashboard already depends on `@angular/fire` and the modular Firebase JavaScript SDK. Analytics and Remote Config are AngularFire provider capabilities, so no separate third-party analytics package is required.

The relevant `apps/dashboard/package.json` dependency set is:

```json
{
  "dependencies": {
    "@angular/fire": "20.0.1",
    "firebase": "12.17.1",
    "rxjs": "~7.8.0"
  }
}
```

If the installed AngularFire version does not expose the provider paths used below, upgrade AngularFire and Firebase together rather than mixing major versions:

```bash
cd apps/dashboard
npm install @angular/fire@20 firebase@12
cd ../..
git add apps/dashboard/package.json apps/dashboard/package-lock.json
 git commit -m "chore(dashboard): align Firebase SDKs for observability"
git push origin feat/implement-architecture-specifications
```

Remove the accidental leading space before `git commit` if copying the command literally; the canonical command is:

```bash
git commit -m "chore(dashboard): align Firebase SDKs for observability"
```

### 1.3 `firebase.json` emulator configuration

The existing root `firebase.json` already configures Functions, Firestore, Auth, and the Emulator UI. Add the Remote Config entry beside those emulator services:

```json
{
  "functions": {
    "source": "backend"
  },
  "firestore": {
    "rules": "firestore.rules",
    "indexes": "firestore.indexes.json"
  },
  "emulators": {
    "auth": {
      "port": 9099
    },
    "firestore": {
      "port": 8080
    },
    "functions": {
      "port": 5001
    },
    "remoteconfig": {
      "port": 9098
    },
    "ui": {
      "enabled": true,
      "port": 4000
    }
  }
}
```

> **Compatibility check:** The `remoteconfig` emulator block and Flutter `useRemoteConfigEmulator(...)` call must be validated against the Firebase CLI and FlutterFire versions actually installed in the repository. If `firebase emulators:start` reports that `remoteconfig` is unsupported, remove the unsupported emulator entry from the runnable local configuration and use the local override strategy in Section 4. Do not make the application fail to boot because a local Remote Config emulator is unavailable.

Commit the Firebase configuration independently:

```bash
git add firebase.json
git diff --cached --check
git commit -m "chore(firebase): configure remote config emulator port"
git push origin feat/implement-architecture-specifications
```

### 1.4 Configuration keys and privacy

Use stable, non-sensitive parameter names such as `customer_menu_enabled`, `show_assistance_buttons`, `admin_queue_refresh_seconds`, and `minimum_supported_app_version`. Remote Config is client-readable; never put credentials, secret QR tokens, private API keys, or authorization decisions in Analytics parameters or Remote Config values.[2]

Analytics event names and parameter keys should be lowercase snake case and bounded in cardinality. Do not send the raw QR `token`, email address, full order contents, or free-form customer notes. The approved session context fields are `tenant_id`, `branch_id`, and `table_id`; these are operational dimensions and should still be reviewed against the project’s privacy/consent policy.

---

## Section 2: Flutter Customer PWA implementation

### 2.1 Where Firebase initialization currently lives

The customer app initializes Firebase in [`lib/main_common.dart`](../lib/main_common.dart), not in `lib/main_dev.dart`. `main_dev.dart` delegates to `bootstrap(Environment.dev)`. Preserve that structure:

1. `WidgetsFlutterBinding.ensureInitialized()` runs first.
2. Firebase initializes with `DefaultFirebaseOptions.currentPlatform`.
3. Firestore and Functions connect to local emulators in non-release builds.
4. GetIt registration runs through `setupLocator(config)`.
5. The app starts through `runApp(const App())`.

Register Analytics, Remote Config, and the platform-aware error reporter in the same composition root. Do not create a new Firebase app instance inside a feature.

### 2.2 Crashlytics: platform-aware error handling

#### Why a bridge is required

Crashlytics is a native Android/iOS reporting SDK. The PWA build must not assume that `FirebaseCrashlytics.instance` exists on Web. Use conditional imports so the web compiler never links the native implementation.

Create this public bridge:

```dart
// lib/core/services/crash_reporting_service.dart
export 'crash_reporting_service_stub.dart'
    if (dart.library.io) 'crash_reporting_service_native.dart';
```

Create the Web/stub implementation:

```dart
// lib/core/services/crash_reporting_service_stub.dart
import 'package:flutter/foundation.dart';

class CrashReportingService {
  const CrashReportingService._();

  static Future<void> initialize({required bool enabled}) async {
    debugPrint('[CrashReporting] Web/stub implementation; enabled=$enabled');
  }

  static void recordFlutterError(FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('[CrashReporting][Flutter] ${details.exception}');
    debugPrintStack(stackTrace: details.stack);
  }

  static bool recordPlatformError(Object error, StackTrace stack) {
    debugPrint('[CrashReporting][Async] $error');
    debugPrintStack(stackTrace: stack);
    return true;
  }

  static Future<void> recordError(
    Object error,
    StackTrace stack, {
    bool fatal = false,
  }) async {
    debugPrint('[CrashReporting][Error][fatal=$fatal] $error');
    debugPrintStack(stackTrace: stack);
  }
}
```

Create the native implementation. The local switch is intentionally disabled when the app is connected to emulators. Use `setCrashlyticsCollectionEnabled(false)` rather than relying only on an environment variable so the runtime state is explicit.

```dart
// lib/core/services/crash_reporting_service_native.dart
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

class CrashReportingService {
  const CrashReportingService._();

  static FirebaseCrashlytics get _crashlytics =>
      FirebaseCrashlytics.instance;

  static Future<void> initialize({required bool enabled}) async {
    // `enabled` is false for local emulator/dev sessions and true only for
    // supported production native builds after consent/policy checks.
    await _crashlytics.setCrashlyticsCollectionEnabled(enabled);
  }

  static void recordFlutterError(FlutterErrorDetails details) {
    _crashlytics.recordFlutterFatalError(details);
  }

  static bool recordPlatformError(Object error, StackTrace stack) {
    _crashlytics.recordError(error, stack, fatal: true);
    return true;
  }

  static Future<void> recordError(
    Object error,
    StackTrace stack, {
    bool fatal = false,
  }) {
    return _crashlytics.recordError(error, stack, fatal: fatal);
  }
}
```

The `dart.library.io` condition selects the native implementation for Android/iOS and the stub for Web. If the application later targets another platform, verify the plugin’s platform support before changing the condition.

#### Exact bootstrap placement

Add the bridge import and error handlers in `lib/main_common.dart`. The handlers must be installed after Firebase initialization and before `runApp`, while `CrashReportingService.initialize` must be called before an error can be recorded:

```dart
// lib/main_common.dart
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:scan_serve/core/services/crash_reporting_service.dart';

Future<void> bootstrap(Environment env) async {
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();

  if (!kIsWeb) {
    FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
  }

  final config = AppConfig.from(env);
  await _initializeFirebase();

  final crashlyticsEnabled =
      !kIsWeb && kReleaseMode && env == Environment.prod;
  await CrashReportingService.initialize(enabled: crashlyticsEnabled);

  FlutterError.onError = CrashReportingService.recordFlutterError;
  PlatformDispatcher.instance.onError =
      CrashReportingService.recordPlatformError;

  await setupLocator(config);
  await sl<LocaleCubit>().init();
  Bloc.observer = AppBlocObserver();

  runApp(const App());

  if (!kIsWeb) {
    try {
      FlutterNativeSplash.remove();
    } catch (_) {
      // Best effort; never allow splash teardown to crash bootstrap.
    }
  }
}
```

If `Environment` does not yet expose `prod`, replace the expression with the project’s existing release/environment predicate. Do not enable Crashlytics merely because `kReleaseMode` is true if the build is a local native debug build.

For errors that are intentionally caught inside repositories or BLoCs, record a non-fatal error only on supported native production builds:

```dart
try {
  await repository.submitOrder(lines);
} catch (error, stack) {
  await CrashReportingService.recordError(error, stack);
  rethrow;
}
```

Do not record customer notes, tokens, credentials, or full order payloads as custom keys. If correlation is needed, use a request ID or order ID after applying the project’s privacy policy.

### 2.3 Remote Config service

Create [`lib/core/services/remote_config_service.dart`](../lib/core/services/remote_config_service.dart). The service owns defaults, fetch settings, emulator/local override selection, and typed accessors. It should be registered as a lazy singleton in `service_locator.dart` and initialized once after Firebase initialization.

```dart
// lib/core/services/remote_config_service.dart
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';

class RemoteConfigService {
  RemoteConfigService({FirebaseRemoteConfig? remoteConfig})
      : _remoteConfig = remoteConfig ?? FirebaseRemoteConfig.instance;

  final FirebaseRemoteConfig _remoteConfig;

  static const defaults = <String, Object>{
    'customer_menu_enabled': true,
    'show_assistance_buttons': true,
    'admin_queue_refresh_seconds': 5,
    'minimum_supported_app_version': '1.0.0',
  };

  Future<void> initialize({
    required bool isLocal,
    String host = '127.0.0.1',
  }) async {
    await _remoteConfig.setDefaults(defaults);

    // Keep local development responsive. Production uses the SDK default or
    // an intentionally conservative interval to avoid throttling.
    await _remoteConfig.setConfigSettings(
      RemoteConfigSettings(
        fetchTimeout: Duration(seconds: isLocal ? 5 : 30),
        minimumFetchInterval: isLocal
            ? const Duration(minutes: 1)
            : const Duration(hours: 12),
      ),
    );

    if (isLocal) {
      // Use this only when the pinned FlutterFire/Firebase CLI combination
      // exposes a working Remote Config emulator. The method name/API can
      // vary by SDK release; do not leave an unconditional call here.
      // await _remoteConfig.useRemoteConfigEmulator(host, 9098);
      debugPrint(
        '[RemoteConfig] Local mode: using defaults/local overrides; '
        'Remote Config emulator is optional.',
      );
    }

    try {
      await _remoteConfig.fetchAndActivate();
    } catch (error, stack) {
      // Defaults remain available. A local network failure must not prevent
      // the menu from rendering or the customer from opening the app.
      debugPrint('[RemoteConfig] fetch skipped: $error');
      debugPrintStack(stackTrace: stack);
    }
  }

  bool get customerMenuEnabled =>
      _remoteConfig.getBool('customer_menu_enabled');

  bool get showAssistanceButtons =>
      _remoteConfig.getBool('show_assistance_buttons');

  int get adminQueueRefreshSeconds =>
      _remoteConfig.getInt('admin_queue_refresh_seconds');

  String get minimumSupportedAppVersion =>
      _remoteConfig.getString('minimum_supported_app_version');
}
```

> **About `useRemoteConfigEmulator`:** Add the commented call only after checking the installed `firebase_remote_config` API. If it is available, uncomment it inside the `isLocal` branch and verify that the emulator responds on `localhost:9098`. If it is unavailable, do not invent an extension method or ship a build that fails compilation. The supported fallback for offline testing is `setDefaults()` plus an explicit local override map.

Register and initialize it in the existing GetIt composition root:

```dart
// lib/core/di/service_locator.dart
sl.registerLazySingleton<RemoteConfigService>(
  () => RemoteConfigService(),
);
```

Then call it from `main_common.dart` after `_initializeFirebase()` and before `runApp`:

```dart
final isLocal = !kReleaseMode;
await sl<RemoteConfigService>().initialize(
  isLocal: isLocal,
  host: const String.fromEnvironment(
    'SCAN_SERVE_FIREBASE_EMULATOR_HOST',
    defaultValue: '127.0.0.1',
  ),
);
```

Do not make Remote Config a hard dependency for the first rendered menu. The UI should use defaults if fetch fails.

### 2.4 Analytics wrapper service

Create [`lib/core/services/analytics_service.dart`](../lib/core/services/analytics_service.dart). The wrapper keeps event names and parameter schemas centralized and gives local development a visible `debugPrint` fallback. Analytics has no Firebase Emulator Suite equivalent, so local runs should not silently pretend that events were delivered to a test backend.

```dart
// lib/core/services/analytics_service.dart
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

class AnalyticsService {
  AnalyticsService({FirebaseAnalytics? analytics})
      : _analytics = analytics ?? FirebaseAnalytics.instance;

  final FirebaseAnalytics _analytics;
  bool _enabled = false;
  Map<String, Object>? _sessionParameters;

  Future<void> initialize({required bool enabled}) async {
    _enabled = enabled;
    if (!_enabled) {
      debugPrint('[Analytics] local/offline mode enabled');
      return;
    }

    await _analytics.setAnalyticsCollectionEnabled(true);
  }

  Future<void> setSessionContext({
    required String tenantId,
    required String branchId,
    required String tableId,
  }) async {
    _sessionParameters = {
      'tenant_id': tenantId,
      'branch_id': branchId,
      'table_id': tableId,
    };

    if (!_enabled) {
      debugPrint('[Analytics] session_context=$_sessionParameters');
      return;
    }

    await Future.wait([
      _analytics.setUserProperty(name: 'tenant_id', value: tenantId),
      _analytics.setUserProperty(name: 'branch_id', value: branchId),
      _analytics.setUserProperty(name: 'table_id', value: tableId),
    ]);
  }

  Future<void> logAddToCart({
    required String menuItemId,
    required String itemName,
    required int quantity,
    required int unitPrice,
  }) {
    return _log(
      'add_to_cart',
      parameters: {
        'menu_item_id': menuItemId,
        'item_name': itemName,
        'quantity': quantity,
        'value': unitPrice * quantity,
        ...?_sessionParameters,
      },
    );
  }

  Future<void> logSubmitOrder({
    required String orderId,
    required int itemCount,
    required int totalAmount,
  }) {
    return _log(
      'submit_order',
      parameters: {
        'order_id': orderId,
        'item_count': itemCount,
        'value': totalAmount,
        ...?_sessionParameters,
      },
    );
  }

  Future<void> logScreenView(String screenName) {
    return _log(
      'screen_view',
      parameters: {
        'screen_name': screenName,
        ...?_sessionParameters,
      },
    );
  }

  Future<void> _log(
    String name, {
    required Map<String, Object> parameters,
  }) async {
    if (!_enabled) {
      debugPrint('[Analytics] $name $parameters');
      return;
    }

    await _analytics.logEvent(name: name, parameters: parameters);
  }
}
```

The wrapper is deliberately the only place that knows Firebase event APIs. Register it beside the existing Firebase singletons:

```dart
// lib/core/di/service_locator.dart
sl.registerLazySingleton<AnalyticsService>(() => AnalyticsService());
```

Initialize it after `SessionContext` is available. For example, in the route-scoped landing/menu composition, call:

```dart
await analytics.setSessionContext(
  tenantId: session.restaurantId,
  branchId: session.branchId,
  tableId: session.tableId,
);
```

Call `logAddToCart` in the successful add-to-cart path, after the cart BLoC accepts the line. Call `logSubmitOrder` only after the callable returns success and the order ID is known; do not log a conversion for a failed request.

### 2.5 GoRouter/Navigator integration

The current router is created in [`lib/app/routes/router.dart`](../lib/app/routes/router.dart), while `App` passes it to `MaterialApp.router` in [`lib/app/app.dart`](../lib/app/app.dart). `GoRouter` does not use the legacy `navigatorObservers` constructor field directly in the same way as `MaterialApp`; use a `NavigatorObserver` through the router’s `observers` list if supported by the pinned `go_router` version, or log screen views from the route page builders.

A version-compatible observer pattern is:

```dart
// lib/app/routes/analytics_navigator_observer.dart
import 'package:flutter/material.dart';
import 'package:scan_serve/core/services/analytics_service.dart';

class AnalyticsNavigatorObserver extends NavigatorObserver {
  AnalyticsNavigatorObserver(this.analytics);

  final AnalyticsService analytics;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _log(route);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    if (previousRoute != null) _log(previousRoute);
  }

  void _log(Route<dynamic> route) {
    final name = route.settings.name;
    if (name != null && name.isNotEmpty) {
      analytics.logScreenView(name);
    }
  }
}
```

If the installed `go_router` exposes `observers`, add it when constructing the router:

```dart
return GoRouter(
  initialLocation: AppRoutes.home,
  observers: [
    AnalyticsNavigatorObserver(sl<AnalyticsService>()),
  ],
  routes: routes,
);
```

If `observers` is not present in the pinned API, do not force a version upgrade only for telemetry. Instead, add explicit calls in `pageBuilder`/screen entry points:

```dart
final analytics = sl<AnalyticsService>();
analytics.logScreenView(AppRoutes.menu);
return MaterialPage(child: MenuPage(...));
```

Avoid logging the QR token or full query string. Log the route name and session context fields already approved by the wrapper.

### 2.6 Flutter Git checkpoint

After the Flutter implementation is reviewed and formatted:

```bash
/home/ubuntu/flutter/bin/cache/dart-sdk/bin/dart format \
  lib/core/services \
  lib/core/di/service_locator.dart \
  lib/main_common.dart \
  lib/app/routes

/home/ubuntu/flutter/bin/flutter analyze
/home/ubuntu/flutter/bin/flutter test

git add lib/main_common.dart \
  lib/core/services \
  lib/core/di/service_locator.dart \
  lib/app/routes \
  pubspec.yaml pubspec.lock

git diff --cached --check
git commit -m "feat(flutter): add analytics crash reporting and remote config"
git push origin feat/implement-architecture-specifications
```

Do not add `lib/firebase_options.dart` to the change unless Firebase configuration generation is explicitly requested and reviewed separately.

---

## Section 3: Angular Admin Dashboard implementation

### 3.1 Provider placement in `app.config.ts`

The dashboard’s standalone composition root is [`apps/dashboard/src/app/app.config.ts`](../apps/dashboard/src/app/app.config.ts). It already provides the Firebase app, Auth, Firestore, and Functions, with localhost emulator wiring based on the browser hostname. Add Analytics and Remote Config providers beside the existing Firebase providers.

```typescript
// apps/dashboard/src/app/app.config.ts
import { ApplicationConfig } from '@angular/core';
import { provideRouter } from '@angular/router';
import { provideFirebaseApp, initializeApp } from '@angular/fire/app';
import { provideAnalytics, getAnalytics } from '@angular/fire/analytics';
import {
  provideRemoteConfig,
  getRemoteConfig,
} from '@angular/fire/remote-config';

import { environment } from '../environments/environment';
import { routes } from './app.routes';

const isLocalHost =
  location.hostname === 'localhost' ||
  location.hostname === '127.0.0.1';

export const appConfig: ApplicationConfig = {
  providers: [
    provideRouter(routes),
    provideFirebaseApp(() => initializeApp(environment.firebase)),

    // Analytics has no Firebase emulator. Keep this provider in browser
    // builds, but use the service wrapper below to suppress local delivery.
    provideAnalytics(() => getAnalytics()),

    // Remote Config uses the production service unless a supported local
    // emulator/override strategy is selected explicitly.
    provideRemoteConfig(() => getRemoteConfig()),

    // Existing Auth/Firestore/Functions providers remain here, including
    // their localhost emulator connections.
  ],
};
```

`isLocalHost` is shown to make the mode decision explicit, but do not leave an unused variable in production code. In the existing file, fold the condition into the same provider factories that already connect Auth, Firestore, and Functions to ports `9099`, `8080`, and `5001`.

AngularFire’s documented provider pattern is `provideAnalytics(() => getAnalytics())` and `provideRemoteConfig(() => getRemoteConfig())`.[3] The providers do not create Analytics or Remote Config emulators; they only register the client SDK instances.

### 3.2 Angular Analytics service wrapper

Create `apps/dashboard/src/app/core/telemetry/analytics.service.ts`:

```typescript
import { Injectable, inject } from '@angular/core';
import { Analytics, logEvent, setAnalyticsCollectionEnabled } from '@angular/fire/analytics';

@Injectable({ providedIn: 'root' })
export class AnalyticsService {
  private readonly analytics = inject(Analytics);
  private readonly local =
    location.hostname === 'localhost' || location.hostname === '127.0.0.1';

  async initialize(): Promise<void> {
    if (this.local) {
      console.debug('[Analytics] local mode; event delivery disabled');
      await setAnalyticsCollectionEnabled(this.analytics, false);
      return;
    }

    await setAnalyticsCollectionEnabled(this.analytics, true);
  }

  logSessionContext(tenantId: string, branchId: string, tableId: string): void {
    this.log('session_context', {
      tenant_id: tenantId,
      branch_id: branchId,
      table_id: tableId,
    });
  }

  logAdminEvent(name: string, parameters: Record<string, string | number>): void {
    this.log(name, parameters);
  }

  private log(
    name: string,
    parameters: Record<string, string | number>,
  ): void {
    if (this.local) {
      console.debug(`[Analytics] ${name}`, parameters);
      return;
    }

    void logEvent(this.analytics, name, parameters);
  }
}
```

The exact AngularFire modular helper signatures can vary by AngularFire version. If the installed version re-exports the Firebase JS functions from `firebase/analytics` rather than `@angular/fire/analytics`, keep the injected `Analytics` token from AngularFire but import the operation helpers consistently according to the installed API. Do not mix incompatible major-version imports.

Call `initialize()` from the root component or a bootstrap initializer, and call `logSessionContext` from any admin feature that has a resolved restaurant/branch scope. For menu/table/kitchen events, log stable IDs and status values, not full document payloads.

### 3.3 Angular Remote Config service and local overrides

Create `apps/dashboard/src/app/core/remote-config/remote-config.service.ts`:

```typescript
import { Injectable, inject } from '@angular/core';
import {
  RemoteConfig,
  fetchAndActivate,
  getBoolean,
  getNumber,
  getString,
  setConfigSettings,
  setDefaults,
} from '@angular/fire/remote-config';

@Injectable({ providedIn: 'root' })
export class RemoteConfigService {
  private readonly remoteConfig = inject(RemoteConfig);
  private readonly local =
    location.hostname === 'localhost' || location.hostname === '127.0.0.1';

  async initialize(): Promise<void> {
    await setDefaults(this.remoteConfig, {
      admin_queue_refresh_seconds: 5,
      show_table_qr_printing: true,
      enable_bulk_menu_actions: false,
    });

    await setConfigSettings(this.remoteConfig, {
      fetchTimeoutMillis: this.local ? 5000 : 30000,
      minimumFetchIntervalMillis: this.local ? 60000 : 43200000,
    });

    if (this.local) {
      console.debug('[RemoteConfig] local defaults/overrides active');
      return;
    }

    try {
      await fetchAndActivate(this.remoteConfig);
    } catch (error) {
      console.warn('[RemoteConfig] fetch failed; defaults remain active', error);
    }
  }

  get queueRefreshSeconds(): number {
    return getNumber(this.remoteConfig, 'admin_queue_refresh_seconds');
  }

  get showTableQrPrinting(): boolean {
    return getBoolean(this.remoteConfig, 'show_table_qr_printing');
  }

  get supportMessage(): string {
    return getString(this.remoteConfig, 'support_message');
  }
}
```

If AngularFire 20 does not export one of these helpers from `@angular/fire/remote-config`, use the matching modular Firebase JS import consistently and keep the injected `RemoteConfig` instance from the AngularFire provider. Confirm the API against the installed package before committing.

For deterministic local testing, add an explicit development override rather than relying on a production Remote Config network call:

```typescript
const localOverrides: Record<string, boolean | number | string> = {
  admin_queue_refresh_seconds: 1,
  show_table_qr_printing: true,
  enable_bulk_menu_actions: true,
};
```

Apply overrides only in the local service path. Never ship the override map in a production configuration or use it to bypass staff authorization.

### 3.4 Angular Git checkpoint

```bash
cd apps/dashboard
npm run lint
npm test -- --watch=false --browsers=ChromeHeadless
npm run build
cd ../..

git add apps/dashboard/src/app/app.config.ts \
  apps/dashboard/src/app/core/telemetry \
  apps/dashboard/src/app/core/remote-config \
  apps/dashboard/package.json apps/dashboard/package-lock.json

git diff --cached --check
git commit -m "feat(dashboard): add analytics and remote config services"
git push origin feat/implement-architecture-specifications
```

### 3.5 Angular feature placement

Use the wrapper from feature services/stores, not directly from templates. For example, after a successful table creation in `TableStore` or the table management component, call an analytics method with the active route-derived restaurant and branch IDs. After a successful `updateOrderStatus` callable, log the status transition using the order ID and new status. Do not log the secret QR token, full QR URL, customer notes, or staff email.

---

## Section 4: Local emulator versus production testing workflow

### 4.1 Local prerequisites

The local workflow must remain usable without a Firebase billing account. Auth, Firestore, and Functions run locally. Analytics does not have a Firebase emulator, Crashlytics is disabled, and Remote Config should use defaults/local overrides unless the installed toolchain demonstrably supports the Remote Config emulator.

Start the existing emulators from the repository root:

```bash
firebase emulators:start \
  --project scanserve-app-1010 \
  --only auth,firestore,functions,remoteconfig
```

If the Firebase CLI rejects `remoteconfig`, start the supported services instead:

```bash
firebase emulators:start \
  --project scanserve-app-1010 \
  --only auth,firestore,functions
```

The expected local endpoints are:

| Service | Host/port | Used by |
|---|---|---|
| Auth | `127.0.0.1:9099` | Angular staff login and optional customer auth tests. |
| Firestore | `127.0.0.1:8080` | Menu, categories, tables, carts, sessions, orders, and Rules tests. |
| Functions | `127.0.0.1:5001` | `submitOrder` and `updateOrderStatus`. |
| Remote Config, if supported | `127.0.0.1:9098` | Remote Config integration experiment only. |
| Emulator UI | `127.0.0.1:4000` | Data inspection and emulator logs. |

In a second terminal, seed the demo graph:

```bash
cd backend
npm run seed:menu
cd ..
```

The seed should create the demo restaurant/branch, categories, menu items, Auth staff account, staff profile, and role permission data. Verify the actual menu document IDs before testing Flutter checkout.

### 4.2 Test Flutter local behavior

Run the Flutter development entrypoint:

```bash
/home/ubuntu/flutter/bin/flutter run \
  -d chrome \
  -t lib/main_dev.dart \
  --dart-define=SCAN_SERVE_FIREBASE_EMULATOR_HOST=127.0.0.1
```

Expected behavior is:

1. Flutter connects Firestore to `127.0.0.1:8080` and Functions to `127.0.0.1:5001`.
2. Crashlytics uses the Web/stub bridge or is disabled for a native local build.
3. Analytics prints events through `debugPrint` and does not attempt to claim emulator delivery.
4. Remote Config renders from `setDefaults()` and local overrides if configured.
5. A QR URL resolves through `SessionContext` and retains `tenant`, `branch`, `table`, and `token`.
6. Menu item IDs equal the Firestore document IDs.
7. Cart writes use `carts/cart_{customerSessionId}`.
8. Successful checkout writes the top-level/nested order mirrors through the local Functions emulator.

Test a local Remote Config flag without billing by changing the local override map or defaults, restarting the app, and confirming that the target UI changes. Do not use a production Firebase Remote Config template as a substitute for a local test because it can mutate real users’ behavior.

For a supported Remote Config emulator, set the Flutter service’s local branch to:

```dart
await _remoteConfig.useRemoteConfigEmulator('localhost', 9098);
```

Only retain that line if it compiles with the pinned `firebase_remote_config` package and the emulator returns the expected template. Otherwise keep it commented and document that local defaults/overrides are the supported offline path.

### 4.3 Test Angular local behavior

Start the dashboard after the emulator seed:

```bash
cd apps/dashboard
npm start
```

The existing `prestart` script seeds Auth and Firestore. Verify that the browser is opened at `http://localhost:4200`; the dashboard’s `app.config.ts` detects localhost and connects Auth/Firestore/Functions to the emulator ports.

Verify the following sequence:

1. Visit `/menu` while signed out and confirm the auth guard redirects to `/login?redirect=%2Fmenu`.
2. Sign in with the seeded staff account.
3. Create or edit a dynamic category and menu item.
4. Confirm the document is written under `restaurants/scanserve-demo/menu/{menuItemId}` with `branchId`, category IDs, image URL, availability, archive flags, and timestamps.
5. Create a table and confirm `restaurants/scanserve-demo/tables/{tableId}` contains the QR URL and token.
6. Confirm local Analytics calls print to the browser console rather than appearing in Firebase Analytics reports.
7. Change a local Remote Config override and reload the dashboard to confirm the feature flag is read.
8. Log out and confirm the next protected navigation returns to Login.

### 4.4 Production enablement checklist

Before enabling the production path:

| Check | Required outcome |
|---|---|
| Firebase app configuration | Flutter `DefaultFirebaseOptions` and Angular `environment.firebase` point to the intended project. |
| Analytics consent | Collection is disabled until the product’s consent policy permits it. |
| Crashlytics platform | Native Android/iOS only; Web remains on the stub/web error sink. |
| Crashlytics first report | Force a controlled native test exception in a non-production test build and confirm it appears in the Crashlytics console. Remove the test trigger afterward.[1] |
| Remote Config defaults | Every flag has a safe in-app default so fetch failure does not block startup. |
| Remote Config fetch interval | Production uses a conservative interval, not the local one-minute interval. |
| Privacy | No QR tokens, credentials, free-form notes, or sensitive personal data are sent as telemetry. |
| Rollback | Every Remote Config flag has a known-safe false/default state and an owner. |
| Build modes | Local emulator connections are gated by debug/environment mode, never by a user-controlled query parameter. |

The production Flutter path should set:

```dart
await CrashReportingService.initialize(
  enabled: !kIsWeb && kReleaseMode && env == Environment.prod,
);

await analytics.initialize(enabled: kReleaseMode && !kIsWeb);

await remoteConfig.initialize(
  isLocal: false,
);
```

The production Angular path should allow `getAnalytics()` and `getRemoteConfig()` to use the configured Firebase project, while the local hostname path remains console/default based.

### 4.5 Final verification commands and Git status

For documentation-only or configuration-only reviews, run the lightweight checks below rather than long unattended builds:

```bash
cd /home/ubuntu/scan_serve

git status --short
git diff --check
git diff --stat

grep -RIn "remoteconfig\|9098\|CrashReportingService\|AnalyticsService\|RemoteConfigService" \
  firebase.json lib apps/dashboard/src/app | head -200
```

For an implementation change, use the targeted checks appropriate to the touched stack:

```bash
/home/ubuntu/flutter/bin/flutter analyze
/home/ubuntu/flutter/bin/flutter test

cd apps/dashboard
npm run lint
npm test -- --watch=false --browsers=ChromeHeadless
npm run build
cd ../..

cd backend
npm run lint
npm run build
cd ..
```

Then confirm only intended files are staged:

```bash
git status --short
git diff --cached --name-only
git diff --cached --check
git log -1 --oneline
```

Commit and push the final cross-stack integration only after the Flutter, Angular, and backend owners approve the platform caveats:

```bash
git add pubspec.yaml pubspec.lock firebase.json \
  lib/main_common.dart lib/core/services lib/core/di/service_locator.dart \
  lib/app/routes \
  apps/dashboard/package.json apps/dashboard/package-lock.json \
  apps/dashboard/src/app/app.config.ts \
  apps/dashboard/src/app/core/telemetry \
  apps/dashboard/src/app/core/remote-config

git diff --cached --check
git commit -m "feat(observability): integrate analytics crash reporting and remote config"
git push origin feat/implement-architecture-specifications

git status --short
```

A successful final state has an empty `git status --short`, a remote branch containing the commit, local Analytics/Crashlytics disabled or stubbed in emulator mode, and safe Remote Config defaults available before any network fetch.

---

## References

[1]: https://firebase.google.com/docs/crashlytics/flutter/get-started — Firebase, “Get started with Crashlytics for Flutter.”
[2]: https://firebase.google.com/docs/remote-config/flutter/get-started — Firebase, “Get started with Remote Config on Flutter.”
[3]: https://github.com/angular/angularfire/blob/main/docs/analytics.md and https://github.com/angular/angularfire/blob/main/docs/remote-config.md — AngularFire Analytics and Remote Config provider guidance.
[4]: https://firebase.google.com/docs/emulator-suite — Firebase, “Local Emulator Suite.”

## Repository references

The implementation should be reconciled with the existing project sources before merging:

- [`lib/main_common.dart`](../lib/main_common.dart)
- [`lib/core/di/service_locator.dart`](../lib/core/di/service_locator.dart)
- [`lib/app/app.dart`](../lib/app/app.dart)
- [`lib/app/routes/router.dart`](../lib/app/routes/router.dart)
- [`apps/dashboard/src/app/app.config.ts`](../apps/dashboard/src/app/app.config.ts)
- [`apps/dashboard/src/app/app.routes.ts`](../apps/dashboard/src/app/app.routes.ts)
- [`firebase.json`](../firebase.json)
- [`pubspec.yaml`](../pubspec.yaml)
- [`apps/dashboard/package.json`](../apps/dashboard/package.json)

> **Implementation status:** This guide is an implementation plan and code-placement reference. It does not claim that Analytics, Crashlytics, or Remote Config are already wired into the repository. Validate the exact SDK APIs after dependency installation, especially Remote Config emulator support and AngularFire modular helper exports.
