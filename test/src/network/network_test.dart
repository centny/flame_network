import 'dart:collection';
import 'dart:convert';

import 'package:flame_network/src/common/log.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flame_network/flame_network.dart';
import 'package:uuid/uuid.dart';

class TestNetworkValue with NetworkValue {
  Map<String, dynamic> value = {};

  @override
  void decode(v) {
    value = jsonDecode(v);
  }

  @override
  dynamic encode() {
    return jsonEncode(value);
  }
}

class TestNetworkComponent with NetworkComponent, NetworkEvent {
  bool removed = false;
  @override
  String get nFactory => "test";
  @override
  String get nCID => "123";
  @override
  bool get nRemoved => removed;

  int intValue = 0;
  double doubleValue = 0.0;
  String stringValue = "";
  Map<String, dynamic> mapValue = {};
  List<int> intList = [];
  List<double> doubleList = [];
  List<String> stringList = [];

  NetworkProp<int> sInt = NetworkProp<int>("int", 0);
  NetworkProp<int> sInt2 = NetworkProp<int>("int2", 0);
  NetworkProp<double> sDouble = NetworkProp<double>("double", 0);
  NetworkProp<String> sString = NetworkProp<String>("string", "");
  NetworkProp<Map<String, dynamic>> sMap = NetworkProp<Map<String, dynamic>>("map", {});
  NetworkProp<TestNetworkValue> sNet = NetworkProp("net", TestNetworkValue());

  NetworkCall<void, int> cUpdate = NetworkCall("update");
  NetworkCall<String, int> cParse = NetworkCall("parse");
  NetworkCall<void, TestNetworkValue> cNet0 = NetworkCall("net0", argNew: TestNetworkValue.new);
  NetworkCall<TestNetworkValue, int> cNet1 = NetworkCall("net1", retNew: TestNetworkValue.new);
  NetworkCall<TestNetworkValue, TestNetworkValue> cNet2 = NetworkCall("net2", argNew: TestNetworkValue.new, retNew: TestNetworkValue.new);

  TestNetworkComponent() {
    registerNetworkProp(sInt, getter: () => intValue, setter: (v) => intValue = v);
    registerNetworkProp(sInt2);
    registerNetworkProp(sDouble, getter: () => doubleValue, setter: (v) => doubleValue = v);
    registerNetworkProp(sString, getter: () => stringValue, setter: (v) => stringValue = v);
    registerNetworkProp(sMap, getter: () => mapValue, setter: (v) => mapValue = v);
    registerNetworkProp(sNet);
    registerNetworkCall(cUpdate, updateInt);
    registerNetworkCall(cParse, parseInt);
    registerNetworkCall(cNet0, callNet0);
    registerNetworkCall(cNet1, callNet1);
    registerNetworkCall(cNet2, callNet2);
    registerNetworkEvent(event: this, group: "*");
    try {
      registerNetworkProp(sInt);
    } catch (_) {}
    try {
      registerNetworkCall(cUpdate, updateInt);
    } catch (_) {}
  }

  void unregister() {
    unregisterNetworkProp(sInt);
    unregisterNetworkProp(sInt2);
    unregisterNetworkProp(sDouble);
    unregisterNetworkProp(sString);
    unregisterNetworkProp(sMap);
    unregisterNetworkProp(sNet);
    unregisterNetworkCall(cUpdate);
    unregisterNetworkCall(cParse);
    unregisterNetworkCall(cNet0);
    unregisterNetworkCall(cNet1);
    unregisterNetworkCall(cNet2);
    unregisterNetworkEvent(this);
    unregisterFromNetworkManager();
    clearNetworkProp();
    clearNetworkCall();
  }

  Future<void> updateInt(NetworkSession? ctx, String uuid, int v) async {
    L.i("${ctx?.user} call $uuid set sInt=>$v");
    sInt.value = v;
  }

  Future<String> parseInt(NetworkSession? ctx, String uuid, int v) async {
    L.i("${ctx?.user} call $uuid parse int=>$v");
    return "$v";
  }

  Future<void> callNet0(NetworkSession? ctx, String uuid, TestNetworkValue v) async {
    L.i("${ctx?.user} call $uuid net0=>$v");
  }

  Future<TestNetworkValue> callNet1(NetworkSession? ctx, String uuid, int v) async {
    L.i("${ctx?.user} call $uuid net1=>$v");
    return TestNetworkValue()..value = {"a": 123};
  }

  Future<TestNetworkValue> callNet2(NetworkSession? ctx, String uuid, TestNetworkValue v) async {
    L.i("${ctx?.user} call $uuid net2=>$v");
    return v;
  }

  @override
  void onNetworkRemove() {
    removed = true;
  }
}

class TestNetworkConnection with NetworkConnection {
  bool syncError = false;
  @override
  bool get isClient => true;

  @override
  bool get isServer => true;

  @override
  Future<void> networkSync(NetworkSyncData data) async {
    if (syncError) {
      await super.networkSync(data);
    }
  }
}

class TestNetworkManager extends NetworkManager with NetworkCallback {
  TestNetworkConnection conn = TestNetworkConnection();

  TestNetworkManager() {
    standalone = true;
    conn.session = session;
  }

  @override
  Future<NetworkCallResult> networkCall(NetworkCallArg arg) {
    return onNetworkCall(conn, arg);
  }

  @override
  Future<void> networkSync(NetworkSyncData data) {
    return onNetworkSync(conn, data);
  }
}

void main() {
  test('NetworkSession', () async {
    var session0 = NetworkSession.from({});
    session0.session = "123";
    session0.group = "123";
    var session1 = NetworkSession.session("123");
    assert(session0.session == "123");
    assert(session0.group == "123");
    assert(session1.session == "123");
    assert(session0.hashCode == session1.hashCode);
    assert(session0 == session1);
  });
  test('NetworkManager.create', () async {
    try {
      var _ = NetworkManager.global;
      assert(false);
    } catch (_) {}
    var m = TestNetworkManager();
    assert(NetworkManager.global == m);
    assert(m.standalone);

    var nc = TestNetworkComponent();
    assert(nc.isServer);
    assert(nc.isClient);
  });
  test('NetworkManager.state', () async {
    var m = TestNetworkManager();
    var nc = TestNetworkComponent();
    await m.onNetworkState(HashSet.from([m.conn]), m.conn, NetworkState.ready);
    try {
      m.conn.syncError = true;
      await m.onNetworkState(HashSet.from([m.conn]), m.conn, NetworkState.ready);
    } catch (_) {}
    nc.unregister();
  });
  test('NetworkEvent.event', () async {
    var m = TestNetworkManager();
    m.session.user = "123";
    var nc = TestNetworkComponent();
    await m.onNetworkState(HashSet.from([m.conn]), m.conn, NetworkState.ready);
    await m.onNetworkState(HashSet(), m.conn, NetworkState.closed);
    nc.unregister();
  });
  test('NetworkCall.call', () async {
    var m = TestNetworkManager();
    m.session.user = "u123";
    var nc = TestNetworkComponent();

    await nc.networkCall(nc.cUpdate, 100);
    assert(nc.intValue == 100);

    var result1 = await nc.networkCall(nc.cParse, 200);
    assert(result1 == "200");

    await nc.networkCall(nc.cNet0, TestNetworkValue()..value = {"a": 123});
    var result2 = await nc.networkCall(nc.cNet1, 1);
    assert(result2.value["a"] == 123);
    var result3 = await nc.networkCall(nc.cNet2, TestNetworkValue()..value = {"a": 123});
    assert(result3.value["a"] == 123);

    //cover
    try {
      await NetworkComponent.callNetworkCall(null, NetworkCallArg(uuid: const Uuid().v1(), nCID: "none", nName: nc.cUpdate.name, nArg: "100"));
      assert(false); //not reach
    } catch (_) {}
    try {
      await NetworkComponent.callNetworkCall(null, NetworkCallArg(uuid: const Uuid().v1(), nCID: nc.nCID, nName: "none", nArg: "100"));
      assert(false); //not reach
    } catch (_) {}

    nc.unregister();
  });
  test('NetworkComponent.create', () async {
    NetworkComponent.onAdd = (p0) => L.i("add ->${p0.nCID}");
    NetworkComponent.onRemove = (p0) => L.i("remove ->${p0.nCID}");
    var nc = TestNetworkComponent();
    assert(NetworkComponent.findComponent(nc.nCID) != null);
    nc.unregister();
    assert(NetworkComponent.findComponent(nc.nCID) == null);
  });
  test('NetworkComponent.prop', () async {
    var nc = TestNetworkComponent();

    var props = nc.checkNetworkProp();
    assert(props.isNotEmpty);
    L.i("props is $props");

    var props1 = nc.checkNetworkProp();
    assert(props1.isEmpty);

    nc.sInt.value = 1;
    var props2 = nc.checkNetworkProp();
    assert(props2.length == 1);

    props["none"] = 1;
    nc.updateNetworkProp(props);

    nc.unregister();
  });
  test('NetworkComponent.sync', () async {
    var cb = TestNetworkManager();
    var nc = TestNetworkComponent();

    var cs1 = NetworkComponent.syncSend("*");
    assert(cs1.length == 1);
    var cs2 = NetworkComponent.syncSend("*");
    assert(cs2.isEmpty);
    NetworkComponent.syncRecv("*", cs1);

    cb.sync("*");

    nc.unregister();
  });
  test('NetworkComponent.remove', () async {
    var nc1 = TestNetworkComponent();
    nc1.removed = true;
    var cs1 = NetworkComponent.syncSend("*");
    assert(cs1.length == 1);
    assert(NetworkComponent.findComponent(nc1.nCID) == null);
    NetworkComponent.syncRecv("*", cs1);
    nc1.unregister();

    var nc2 = TestNetworkComponent();
    var cs2 = NetworkComponent.syncSend("*");
    assert(cs2.length == 1);
    assert(NetworkComponent.findComponent(nc1.nCID) != null);
    cs2[0].nRemoved = true;
    NetworkComponent.syncRecv("*", cs2);
    assert(NetworkComponent.findComponent(nc1.nCID) == null);
    nc2.unregister();
  });
  test('NetworkComponent.factory', () async {
    NetworkComponent.registerFactory(key: "test", creator: (key, group, id) => TestNetworkComponent());
    NetworkComponent.registerFactory(group: "abc", creator: (key, group, id) => TestNetworkComponent());
    assert(NetworkComponent.findComponent("123") == null);
    var cs1 = [NetworkSyncDataComponent(nFactory: "test", nCID: "123")];
    NetworkComponent.syncRecv("*", cs1);
    assert(NetworkComponent.findComponent("123") != null);

    var cs2 = [NetworkSyncDataComponent(nFactory: "test", nCID: "123", nRemoved: true)];
    NetworkComponent.syncRecv("*", cs2);
    assert(NetworkComponent.findComponent("123") == null);

    try {
      NetworkComponent.createComponent("none", "*", "123456");
      assert(false);
    } catch (_) {}
  });
  test('NetworkComponent.owner', () async {
    var m = TestNetworkManager();
    m.session.user = "u123";
    var nc = TestNetworkComponent();
    assert(!nc.isOwner);
    nc.nOwner = m.session.user;
    assert(nc.isOwner);
    nc.unregister();
  });
  test('Network.cover', () async {
    var conn = TestNetworkConnection();
    var cb = TestNetworkManager();
    cb.onNetworkState(HashSet.from([conn]), conn, NetworkState.ready);
  });
}
