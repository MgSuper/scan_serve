#!/bin/bash

dart run rename setAppName --targets ios,android --value "$1"
dart run change_app_package_name:main "$2"