import 'package:flame_network/flame_network.dart';

mixin NetworkObject {
  Map<String, dynamic> toMap();
  void fromMap(Map<String, dynamic> v);
  bool access(NetworkSession s) => true;
}

class NetworkPropObject<T extends NetworkObject> extends NetworkProp<T> {
  NetworkPropObject(super.name, super.defaultValue);

  @override
  dynamic encode() => value.toMap();

  @override
  void decode(dynamic v) => value = (value..fromMap(v));
}

class NetworkAccessValue<T> with NetworkValue {
  T value;
  bool Function(NetworkSession s)? onAccess;

  NetworkAccessValue(this.value, {this.onAccess});

  @override
  dynamic encode() {
    if (value is NetworkValue) {
      return (value as NetworkValue).encode();
    } else if (value is NetworkObject) {
      return (value as NetworkObject).toMap();
    } else {
      return value;
    }
  }

  @override
  void decode(dynamic v) {
    if (value is NetworkValue) {
      (value as NetworkValue).decode(v);
    } else if (value is NetworkObject) {
      (value as NetworkObject).fromMap(v);
    } else {
      value = v as T;
    }
  }

  @override
  bool access(NetworkSession s) {
    if (onAccess != null) {
      return onAccess!(s);
    } else if (value is NetworkValue) {
      return (value as NetworkValue).access(s);
    } else if (value is NetworkObject) {
      return (value as NetworkObject).access(s);
    } else {
      return true;
    }
  }
}

class NetworkAccessProp<T> extends NetworkProp<T> {
  bool Function(NetworkSession s)? onAccess;

  NetworkAccessProp(super.name, super.defaultValue, {this.onAccess});

  @override
  dynamic encode() => NetworkAccessValue(value, onAccess: onAccess);

  @override
  void decode(dynamic v) => value = (NetworkAccessValue(value)..decode(v)).value;
}

class NetworkAccessTrigger<T> extends NetworkTrigger<T> {
  bool Function(NetworkSession s)? onAccess;

  NetworkAccessTrigger(String name, T defaultValue, {this.onAccess}) : super(name, valNew: () => NetworkAccessValue(defaultValue));

  @override
  List<dynamic> encode(List<T> v) => v.map((e) => NetworkAccessValue(e, onAccess: onAccess)).toList();
}

class NetworkListValue<T> with NetworkValue {
  List<T> value;
  bool Function(NetworkSession s)? onAccess;
  T Function()? valNew;

  NetworkListValue({List<T>? value, this.onAccess, this.valNew}) : value = value ?? [];

  @override
  dynamic encode() => value.map((e) => NetworkAccessValue(e).encode()).toList();

  @override
  void decode(dynamic v) => value = (v as List<dynamic>).map((e) => valNew == null ? e as T : (NetworkAccessValue(valNew!())..decode(e)).value).toList();

  @override
  bool access(NetworkSession s) => onAccess != null ? onAccess!(s) : true;
}

class NetworkPropList<T> extends NetworkProp<List<T>> {
  bool Function(NetworkSession s)? onAccess;
  T Function()? valNew;

  NetworkPropList(super.name, super.defaultValue, {this.onAccess, this.valNew});

  @override
  dynamic encode() => NetworkListValue(value: value, onAccess: onAccess);

  @override
  void decode(dynamic v) => value = (NetworkListValue(valNew: valNew)..decode(v)).value;
}
