import 'package:flame_network/src/common/log.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flame_network/flame_network.dart';
import 'package:uuid/uuid.dart';

class TestNetworkComponent with NetworkComponent {
  bool removed = false;
  @override
  String get nFactory => "test";
  @override
  String get nID => "123";
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
  NetworkPropList<int> sIntList = NetworkPropList<int>("int_list", []);
  NetworkPropList<double> sDoubleList = NetworkPropList<double>("double_list", []);
  NetworkPropList<String> sStringList = NetworkPropList<String>("string_list", []);

  NetworkCall<void, int> cInt = NetworkCall("int");

  TestNetworkComponent() {
    registerNetworkProp(sInt, getter: () => intValue, setter: (v) => intValue = v);
    registerNetworkProp(sInt2);
    registerNetworkProp(sDouble, getter: () => doubleValue, setter: (v) => doubleValue = v);
    registerNetworkProp(sString, getter: () => stringValue, setter: (v) => stringValue = v);
    registerNetworkProp(sMap, getter: () => mapValue, setter: (v) => mapValue = v);
    registerNetworkProp(sIntList, getter: () => intList, setter: (v) => intList = v);
    registerNetworkProp(sDoubleList, getter: () => doubleList, setter: (v) => doubleList = v);
    registerNetworkProp(sStringList, getter: () => stringList, setter: (v) => stringList = v);
    registerNetworkCall(cInt, updateInt);
  }

  void unregister() {
    unregisterNetworkProp(sInt);
    unregisterNetworkProp(sInt2);
    unregisterNetworkProp(sDouble);
    unregisterNetworkProp(sString);
    unregisterNetworkProp(sMap);
    unregisterNetworkProp(sIntList);
    unregisterNetworkProp(sDoubleList);
    unregisterNetworkProp(sStringList);
    unregisterNetworkCall(cInt);
    clearNetworkProp();
    clearNetworkCall();
  }

  Future<void> updateInt(String uuid, int v) async {
    L.i("call $uuid set sInt=>$v");
    sInt.value = v;
  }

  @override
  void onNetworkRemove() {}
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
  test('NetworkComponent.create', () async {
    NetworkComponent.onAdd = (p0) => L.i("add ->${p0.nID}");
    NetworkComponent.onRemove = (p0) => L.i("remove ->${p0.nID}");
    var nc = TestNetworkComponent();
    assert(NetworkComponent.findComponent(nc.nID) != null);
    nc.unregister();
    assert(NetworkComponent.findComponent(nc.nID) == null);
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
    var nc = TestNetworkComponent();

    var cs1 = NetworkComponent.syncSend("*");
    assert(cs1.length == 1);
    var cs2 = NetworkComponent.syncSend("*");
    assert(cs2.isEmpty);
    NetworkComponent.syncRecv("*", cs1);

    nc.removed = true;
    var cs3 = NetworkComponent.syncSend("*");
    assert(cs3.length == 1);
    NetworkComponent.syncRecv("*", cs3);

    nc.unregister();
  });
  test('NetworkComponent.call', () async {
    var nc = TestNetworkComponent();

    var result = await NetworkComponent.callNetworkCall(NetworkCallArg(uuid: const Uuid().v1(), nID: nc.nID, nName: nc.cInt.name, nArg: "100"));
    assert(result.nResult == "null");
    assert(nc.intValue == 100);

    nc.unregister();
  });
}
