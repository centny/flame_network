import 'package:flame_network/flame_network.dart';

class NetworkSequencedValue<T> extends NetworkAccessValue {
  int _sequence;
  int get sequence => _sequence;

  NetworkSequencedValue(super.value, {int? sequence, super.onAccess}) : _sequence = sequence ?? 0;

  @override
  void decode(dynamic v) {
    var val = v as List<dynamic>;
    _sequence = val[0];
    super.decode(val[1]);
  }

  @override
  dynamic encode() => [_sequence, super.encode()];
}

class NetworkSequencedProp<T> extends NetworkProp<T> {
  int _sequence = 0;
  final bool Function(NetworkSession s)? onAccess;

  int get sequence => _sequence;

  @override
  set value(v) {
    _sequence++;
    super.value = v;
  }

  NetworkSequencedProp(super.name, super.defaultValue, {this.onAccess});

  @override
  dynamic encode() => NetworkSequencedValue(value, sequence: _sequence, onAccess: onAccess);

  @override
  void decode(dynamic v) {
    var val = NetworkSequencedValue<T>(value)..decode(v);
    if (val.sequence > _sequence) {
      _sequence = val.sequence;
      super.value = val.value;
    }
  }
}
