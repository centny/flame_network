import 'package:flame/game.dart';
import 'package:flame_network/flame_network.dart';
import 'package:flame_network/src/common/log.dart';
import 'package:flame_test/flame_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class TestNetworkGame extends FlameGame with NetworkGame {}

void main() {
  testWithGame<TestNetworkGame>('NetworkGame.sync', TestNetworkGame.new, (game) async {
    await game.ready();
  });
  test('NetworkPropVector', () {
    var v2 = NetworkPropVector2("v2", Vector2.zero());
    L.i("v2 ecnode is ${v2.encode()}");
    v2.decode("[1.0,1.0]");
    assert(v2.value.x == 1);
    assert(v2.value.y == 1);

    var v3 = NetworkPropVector3("v3", Vector3.zero());
    L.i("v3 ecnode is ${v3.encode()}");
    v3.decode("[1.0,1.0,1.0]");
    assert(v3.value.x == 1);
    assert(v3.value.y == 1);
    assert(v3.value.z == 1);
  });
  test('NetworkPropColor', () {
    var c = NetworkPropColor("c", Colors.red);
    L.i("c value is ${c.value.value}");
    L.i("c ecnode is ${c.encode()}");
    c.decode("${Colors.green.value}");
    L.i("s value is ${Colors.green.value}");
    L.i("c value is ${c.value.value}");
    assert(c.value.value == Colors.green.value);
  });
}
