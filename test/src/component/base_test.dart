import 'package:flame_network/flame_network.dart';
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
  Future<void> networkSync(NetworkSyncData data, {List<NetworkConnection>? excluded}) {
    throw Exception("abc");
  }

  @override
  Future<void> ready() async => isReady = true;

  @override
  Future<void> pause() async => isReady = false;
}

class TestValue with NetworkValue {
  Map<String, dynamic> value = {};

  TestValue({Map<String, dynamic>? value}) : value = value ?? {};

  @override
  void decode(dynamic v) => value = v;

  @override
  dynamic encode() => value;
}

class TestObject with NetworkObject {
  Map<String, dynamic> value = {};

  TestObject({Map<String, dynamic>? value}) : value = value ?? {};

  @override
  void fromMap(Map<String, dynamic> v) => value = v;

  @override
  Map<String, dynamic> toMap() => value;
}

void main() {
  test('NetworkPropObject', () {
    var v = NetworkPropObject("objc", TestObject());
    v.decode(v.encode());
  });
  test('NetworkAccessProp.Int', () {
    var src = NetworkAccessProp<int>("abc", 1);
    var dst = NetworkAccessProp<int>("abc", 0);
    var srcVal = src.encode() as NetworkValue;
    assert(srcVal.access(DefaultNetworkSession.create()));
    dst.decode(srcVal.encode());
    assert(dst.value == 1);

    var acc = NetworkAccessProp<int>("abc", 1, onAccess: (s) => false);
    var accVal = acc.encode() as NetworkValue;
    assert(!accVal.access(DefaultNetworkSession.create()));
  });
  test('NetworkAccessProp.Value', () {
    var src = NetworkAccessProp<TestValue>("abc", TestValue(value: {"a": 1}));
    var dst = NetworkAccessProp<TestValue>("abc", TestValue());
    var srcVal = src.encode() as NetworkValue;
    assert(srcVal.access(DefaultNetworkSession.create()));
    dst.decode(srcVal.encode());
    assert(dst.value.value["a"] == 1);
  });
  test('NetworkAccessProp.Object', () {
    var src = NetworkAccessProp<TestObject>("abc", TestObject(value: {"a": 1}));
    var dst = NetworkAccessProp<TestObject>("abc", TestObject());
    var srcVal = src.encode() as NetworkValue;
    assert(srcVal.access(DefaultNetworkSession.create()));
    dst.decode(srcVal.encode());
    assert(dst.value.value["a"] == 1);
  });
  test('NetworkAccessTrigger', () {
    TestNetworkManager();
    var src = NetworkAccessTrigger<int>("abc", 0);
    var dst = NetworkAccessTrigger<int>("abc", 0);
    dst.onRecv = (p0) {
      assert(p0 == 1);
    };
    src.add(1);
    dst.syncRecv(src.syncSend());
  });
  test('NetworkPropList', () {
    var src = NetworkPropList<int>("abc", [1]);
    var dst = NetworkPropList<int>("abc", []);
    var srcVal = src.encode() as NetworkValue;
    assert(srcVal.access(DefaultNetworkSession.create()));
    dst.decode(srcVal.encode());
    assert(dst.value[0] == 1);
  });
}
