import 'dart:async';

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
  test('NetworkVector', () {
    var v2 = NetworkVector2(0, 0);
    L.i("v2 ecnode is ${v2.encode()}");
    v2.decode("[1.0,1.0]");
    assert(v2.x == 1);
    assert(v2.y == 1);
    Vector2.zero().asNetwork();

    var v3 = NetworkVector3(0, 0, 0);
    L.i("v3 ecnode is ${v3.encode()}");
    v3.decode("[1.0,1.0,1.0]");
    assert(v3.x == 1);
    assert(v3.y == 1);
    assert(v3.z == 1);
    Vector3.zero().asNetwork();
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
    var c = NetworkPropColor("c", const Color(0xfff44336));
    L.i("c value is ${c.value.value}");
    L.i("c ecnode is ${c.encode()}");
    L.i("c ecnode is ${c.value}");
    c.decode("${Colors.green.value}");
    L.i("s value is ${Colors.green.value}");
    L.i("c value is ${c.value.value}");
    L.i("c value is ${c.value}");
    assert(c.value.value == Colors.green.value);
  });
  test('NetworkPropList', () {
    var v = NetworkPropList<int>("abc", [1]);
    v.decode("[2]");
    assert(v.value[0] == 2);
  });
  test('GameLoop', () async {
    var c = Completer();
    var loop = GameLoop((dt) {
      if (!c.isCompleted) {
        c.complete();
      }
    });
    loop.start();
    await c.future;
    loop.step(0);
    loop.stop();
    loop.dispose();
  });
}
