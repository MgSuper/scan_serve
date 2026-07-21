// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get appName => 'スタートアップ・ランチャー';

  @override
  String get homeTitle => 'ホーム';

  @override
  String get settings => '設定';

  @override
  String get changeLanguage => '言語切替';

  @override
  String get appearance => '外観モード';

  @override
  String get light => 'ライト';

  @override
  String get dark => 'ダーク';

  @override
  String get auto => '自動';

  @override
  String get skip => 'スキップ';

  @override
  String get next => '次へ';

  @override
  String get getStarted => '始める';

  @override
  String get onboardingTitle1 => 'アイデアをより早く公開';

  @override
  String get onboardingDesc1 =>
      '本番対応アーキテクチャ、テーマ、ルーティング、多言語対応付きで次のFlutterアプリを始められます。';

  @override
  String get onboardingTitle2 => '本気のスタートアップ向け';

  @override
  String get onboardingDesc2 => 'クリーン構成、拡張しやすい状態管理、ネットワーク、CI/CD を初日から利用できます。';

  @override
  String get onboardingTitle3 => '数週間分の設定時間を節約';

  @override
  String get onboardingDesc3 =>
      '新規プロジェクトごとに flavor、名前変更、テスト、アイコン、定型コードを繰り返す必要はありません。';

  @override
  String get onboardingTitle4 => '作る。公開する。成長する。';

  @override
  String get onboardingDesc4 => 'Startup Launch で本当に重要な課題解決と素早いリリースに集中できます。';
}
