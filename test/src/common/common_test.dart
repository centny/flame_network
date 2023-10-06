import 'package:flame_network/src/common/common.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('asListInt', () {
    asListInt("abc");
    asListInt([1]);
    try {
      asListInt(1);
    } catch (_) {}
  });
}
