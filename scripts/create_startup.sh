#!/bin/bash

APP_NAME=$1
PACKAGE_NAME=$2

if [ -z "$APP_NAME" ] || [ -z "$PACKAGE_NAME" ]; then
  echo "Usage:"
  echo 'sh scripts/create_startup.sh "My App" com.company.myapp'
  exit 1
fi

echo "🚀 Creating $APP_NAME"

flutter pub get

echo "🔁 Renaming app..."
dart run rename setAppName --targets ios,android --value "$APP_NAME"

echo "📦 Changing package name..."
dart run change_app_package_name:main "$PACKAGE_NAME"

echo "🧹 Cleaning..."
flutter clean
flutter pub get

echo "✅ Done!"
echo ""
echo "Run app:"
echo "flutter run --flavor dev -t lib/main_dev.dart"