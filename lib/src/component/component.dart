import 'dart:convert';
import 'dart:ui';

import 'package:flame/game.dart';
import '../network/network.dart';

class NetworkVector2 extends Vector2 with NetworkValue {
  NetworkVector2.zero() : super.zero();
  factory NetworkVector2(double x, double y) => NetworkVector2.zero()..setValues(x, y);

  @override
  void decode(dynamic v) {
    List<dynamic> data = jsonDecode(v);
    setValues(data[0], data[1]);
  }

  @override
  dynamic encode() => jsonEncode(storage);
}

extension Vector2Extension on Vector2 {
  NetworkVector2 asNetwork() => NetworkVector2(x, y);
}

class NetworkVector3 extends Vector3 with NetworkValue {
  NetworkVector3.zero() : super.zero();
  factory NetworkVector3(double x, double y, double z) => NetworkVector3.zero()..setValues(x, y, z);

  @override
  void decode(dynamic v) {
    List<dynamic> data = jsonDecode(v);
    setValues(data[0], data[1], data[2]);
  }

  @override
  dynamic encode() => jsonEncode(storage);
}

extension Vector3Extension on Vector3 {
  NetworkVector3 asNetwork() => NetworkVector3(x, y, z);
}

class NetworkPropVector2 extends NetworkProp<Vector2> {
  NetworkPropVector2(super.name, super.defaultValue);

  @override
  dynamic encode() => jsonEncode(value.storage);

  @override
  void decode(v) {
    List<dynamic> data = jsonDecode(v);
    value = Vector2(data[0], data[1]);
  }
}

class NetworkPropVector3 extends NetworkProp<Vector3> {
  NetworkPropVector3(super.name, super.defaultValue);

  @override
  dynamic encode() => jsonEncode(value.storage);

  @override
  void decode(v) {
    List<dynamic> data = jsonDecode(v);
    value = Vector3(data[0], data[1], data[2]);
  }
}

class NetworkPropColor extends NetworkProp<Color> {
  NetworkPropColor(super.name, super.defaultValue);

  @override
  dynamic encode() => jsonEncode(value.value);

  @override
  void decode(v) => value = Color(jsonDecode(v));
}

class NetworkPropList<T> extends NetworkProp<List<T>> {
  NetworkPropList(super.name, super.defaultValue);

  @override
  void decode(v) => value = (jsonDecode(v) as List<dynamic>).map((e) => e as T).toList();
}

class NetworkAccessValue<T> with NetworkValue {
  T value;
  final bool Function(NetworkSession s) _access;

  NetworkAccessValue(this.value, this._access);

  @override
  void decode(v) => value = jsonDecode(v);

  @override
  dynamic encode() => jsonEncode(value);

  @override
  bool access(NetworkSession s) => _access(s);
}
