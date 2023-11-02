import 'dart:convert';

import 'package:flame/game.dart';
import 'package:flame_network/flame_network.dart';
import 'package:flame_network/src/common/log.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('NetworkVector', () {
    var v2 = NetworkVector2(0, 0);
    L.i("v2 ecnode is ${v2.encode()}");
    v2.decode(v2.encode());
    v2.decode(jsonDecode("[1.0,1.0]"));
    assert(v2.x == 1);
    assert(v2.y == 1);
    Vector2.zero().asNetwork();

    var v3 = NetworkVector3(0, 0, 0);
    L.i("v3 ecnode is ${v3.encode()}");
    v3.decode(v3.encode());
    v3.decode(jsonDecode("[1.0,1.0,1.0]"));
    assert(v3.x == 1);
    assert(v3.y == 1);
    assert(v3.z == 1);
    Vector3.zero().asNetwork();
  });
  test('NetworkPropVector', () {
    var v2 = NetworkPropVector2("v2", Vector2.zero());
    L.i("v2 ecnode is ${v2.encode()}");
    v2.decode(v2.encode());
    v2.decode(jsonDecode("[1.0,1.0]"));
    assert(v2.value.x == 1);
    assert(v2.value.y == 1);

    var v3 = NetworkPropVector3("v3", Vector3.zero());
    L.i("v3 ecnode is ${v3.encode()}");
    v3.decode(v3.encode());
    v3.decode(jsonDecode("[1.0,1.0,1.0]"));
    assert(v3.value.x == 1);
    assert(v3.value.y == 1);
    assert(v3.value.z == 1);
  });
}
