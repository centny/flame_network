
flutter test --coverage $1
genhtml coverage/lcov.info -o coverage/web
