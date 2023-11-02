import 'package:flame_network/flame_network.dart';
import 'package:flame_network/src/common/log.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('NetworkSequencedProp', () {
    var setted = 0;
    var srv = NetworkSequencedProp<int>("abc", 0);
    srv.value = 2;
    var data = (srv.encode() as NetworkValue).encode();
    L.i("data is $data");
    var loc = NetworkSequencedProp<int>("abc", 0);
    loc.setter = (v) => setted++;
    loc.decode(data);
    assert(loc.value == 2);
    assert(setted == 1);

    loc.decode(data);
    assert(setted == 1);
    assert(srv.sequence > 0);

    var srv2 = NetworkSequencedProp<NetworkVector2>("abc", NetworkVector2.zero());
    srv2.value = NetworkVector2(1, 1);
    var data2 = (srv2.encode() as NetworkValue).encode();
    var loc2 = NetworkSequencedProp<NetworkVector2>("abc", NetworkVector2.zero());
    loc2.decode(data2);
    assert(loc2.value.x == 1);

    //cover
    (srv.encode() as NetworkValue).access(DefaultNetworkSession.create());
  });
}
