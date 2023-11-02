import 'package:flame/game.dart';
import 'package:flame_network/flame_network.dart';

class NetworkVector2 extends Vector2 with NetworkValue {
  NetworkVector2.zero() : super.zero();
  factory NetworkVector2(double x, double y) => NetworkVector2.zero()..setValues(x, y);

  @override
  void decode(dynamic v) {
    List<dynamic> data = v;
    setValues(data[0], data[1]);
  }

  @override
  dynamic encode() => [x, y];
}

extension Vector2Extension on Vector2 {
  NetworkVector2 asNetwork() => NetworkVector2(x, y);
}

class NetworkVector3 extends Vector3 with NetworkValue {
  NetworkVector3.zero() : super.zero();
  factory NetworkVector3(double x, double y, double z) => NetworkVector3.zero()..setValues(x, y, z);

  @override
  void decode(dynamic v) {
    List<dynamic> data = v;
    setValues(data[0], data[1], data[2]);
  }

  @override
  dynamic encode() => [x, y, z];
}

extension Vector3Extension on Vector3 {
  NetworkVector3 asNetwork() => NetworkVector3(x, y, z);
}

class NetworkPropVector2 extends NetworkProp<Vector2> {
  NetworkPropVector2(super.name, super.defaultValue);

  @override
  dynamic encode() => [value.x, value.y];

  @override
  void decode(dynamic v) {
    List<dynamic> data = v;
    value = Vector2(data[0], data[1]);
  }
}

class NetworkPropVector3 extends NetworkProp<Vector3> {
  NetworkPropVector3(super.name, super.defaultValue);

  @override
  dynamic encode() => [value.x, value.y, value.z];

  @override
  void decode(dynamic v) {
    List<dynamic> data = v;
    value = Vector3(data[0], data[1], data[2]);
  }
}
