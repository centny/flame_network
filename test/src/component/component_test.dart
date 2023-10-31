import 'package:flame/game.dart';
import 'package:flame_network/flame_network.dart';
import 'package:flame_network/src/common/log.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class TestNetworkManager extends NetworkManager with NetworkCallback {
  TestNetworkManager() {
    standalone = true;
  }

  @override
  Future<NetworkCallResult> networkCall(NetworkCallArg arg) {
    throw Exception("abc");
  }

  @override
  Future<void> networkSync(NetworkSyncData data) {
    throw Exception("abc");
  }

  @override
  Future<void> ready() async => isReady = true;

  @override
  Future<void> pause() async => isReady = false;
}

void main() {
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
  test('NetworkAccessValue', () {
    var v = NetworkAccessValue<int>(1, (s) => true);
    assert(v.access(DefaultNetworkSession.create()));
    v.decode("2");
    assert(v.value == 2);
    v.encode();
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
  test('NetworkAccessProp', () {
    var v = NetworkAccessProp<int>("abc", 1, (s) => true);
    v.decode("2");
    assert(v.raw == 2);
    v.encode();
    v.raw = 2;
  });
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

    var srv2 = NetworkSequencedProp<NetworkVector2>("abc", NetworkVector2.zero());
    srv2.value = NetworkVector2(1, 1);
    var data2 = (srv2.encode() as NetworkValue).encode();
    var loc2 = NetworkSequencedProp<NetworkVector2>("abc", NetworkVector2.zero());
    loc2.decode(data2);
    assert(loc2.value.x == 1);

    //cover
    (srv.encode() as NetworkValue).access(DefaultNetworkSession.create());
  });
  test('NetworkAccessTrigger', () {
    TestNetworkManager();
    var v = NetworkAccessTrigger<int>("abc", 1, (s) => true);
    v.syncRecv(["2"]);
  });
}
