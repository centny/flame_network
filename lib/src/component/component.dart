import 'dart:convert';
import 'dart:ui';

import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';
import '../common/log.dart';
import '../network/network.dart';

mixin NetworkGame on FlameGame {
  String get group => "*";

  @override
  @mustCallSuper
  void update(double dt) async {
    super.update(dt);
    try {
      await NetworkManager.global.sync(group);
    } catch (e, s) {
      L.w("NetworkGame($group) sync fail with $e\n$s");
    }
  }
}

class NetworkPropVector2 extends NetworkProp<Vector2> {
  NetworkPropVector2(super.name, super.value);

  @override
  dynamic encode() => jsonEncode(value.storage);

  @override
  void decode(v) {
    List<dynamic> data = jsonDecode(v);
    value = Vector2(data[0], data[1]);
  }
}

class NetworkPropVector3 extends NetworkProp<Vector3> {
  NetworkPropVector3(super.name, super.value);

  @override
  dynamic encode() => jsonEncode(value.storage);

  @override
  void decode(v) {
    List<dynamic> data = jsonDecode(v);
    value = Vector3(data[0], data[1], data[2]);
  }
}

class NetworkPropColor extends NetworkProp<Color> {
  NetworkPropColor(super.name, super.value);

  @override
  dynamic encode() => jsonEncode(value.value);

  @override
  void decode(v) => value = Color(jsonDecode(v));
}
