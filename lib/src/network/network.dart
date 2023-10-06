import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../common/log.dart';

class NetworkPool {}

class NetworkSession {
  Map<String, String> value;

  DateTime last = DateTime.now();

  String get session => value["session"] ?? "";
  set session(String v) => value["session"] = v;

  String get group => value["group"] ?? "";
  set group(String v) => value["group"] = v;

  NetworkSession(this.value);

  factory NetworkSession.create() => NetworkSession({});

  factory NetworkSession.from(Map<String, String> value) => NetworkSession(value);

  factory NetworkSession.session(String session) => NetworkSession({"session": session});

  @override
  int get hashCode => session.hashCode;

  @override
  bool operator ==(Object other) {
    return other is NetworkSession && session == other.session;
  }
}

mixin NetworkConnection {
  NetworkSession? session;
  NetworkState? state;
  bool get isServer;
  bool get isClient;
}

enum NetworkState {
  connecting,
  ready,
  closing,
  closed,
  error,
}

mixin NetworkCallback {
  void onNetworkState(NetworkConnection conn, NetworkState state, {Object? info}) {}
  Future<NetworkCallResult> onNetworkCall(NetworkConnection conn, NetworkCallArg arg) async => NetworkComponent.callNetworkCall(arg);
  Future<void> onNetworkSync(NetworkConnection conn, NetworkSyncData data) async => NetworkComponent.syncRecv(data.group, data.components);
}

mixin NetworkTransport {
  NetworkSession session = NetworkSession.create();
  Duration keepalive = const Duration(seconds: 3);
  Duration timeout = const Duration(seconds: 10);
  late NetworkCallback callback;
  bool isServer = false;
  bool isClient = false;
  String host = "127.0.0.1";
  int port = 50051;
  Future<void> networkSync(NetworkSyncData data);
  Future<NetworkCallResult> networkCall(NetworkCallArg arg);
}

abstract class NetworkManager with NetworkTransport, NetworkCallback {
  static NetworkManager? _global;

  static NetworkManager get global {
    if (_global == null) {
      throw UnimplementedError("NetworkManager is not configured or extend from NetworkManager");
    }
    return _global!;
  }

  NetworkManager() {
    _global = this;
    callback = this;
  }
}

class NetworkCallArg {
  String uuid;
  String nCID;
  String nName;
  String nArg;

  NetworkCallArg({required this.uuid, required this.nCID, required this.nName, required this.nArg});
}

class NetworkCallResult {
  String uuid;
  String nCID;
  String nName;
  String nResult;

  NetworkCallResult({required this.uuid, required this.nCID, required this.nName, required this.nResult});
}

class NetworkSyncDataComponent {
  String nFactory;
  String nCID;
  bool? nRemoved;
  Map<String, dynamic>? nProps = {};

  NetworkSyncDataComponent({required this.nFactory, required this.nCID, this.nRemoved, this.nProps});
}

class NetworkSyncData {
  String uuid;
  String group = "*";

  List<NetworkSyncDataComponent> components;

  NetworkSyncData({required this.uuid, required this.group, required this.components});

  factory NetworkSyncData.create({List<NetworkSyncDataComponent>? components}) => NetworkSyncData(uuid: const Uuid().v1(), group: "*", components: components ?? List.empty(growable: true));

  factory NetworkSyncData.syncSend(group) => NetworkSyncData(uuid: const Uuid().v1(), group: group, components: NetworkComponent.syncSend(group));
}

typedef NetworkCallFunction<R, S> = Future<R> Function(String uuid, S);

class NetworkCall<R, S> {
  String name;
  NetworkCallFunction<R, S>? exec;
  NetworkCall(this.name, {this.exec});

  Future<String> run(String uuid, String arg) async {
    var a = decode(arg);
    var r = await exec!(uuid, a);
    return encode(r);
  }

  Future<R> call(NetworkComponent c, S arg) async {
    var a = NetworkCallArg(uuid: const Uuid().v1(), nCID: c.nCID, nName: name, nArg: encode(arg));
    var r = await NetworkManager.global.networkCall(a);
    return decode(r.nResult);
  }

  dynamic decode(String v) => jsonDecode(v);

  String encode(dynamic v) => jsonEncode(v);
}

class NetworkProp<T> {
  bool _updated = true; //default is updated to sync
  T _value;

  bool get updated => _updated;
  String name;
  T get value {
    if (getter == null) {
      return _value;
    } else {
      return getter!();
    }
  }

  set value(T v) {
    _updated = true;
    _value = v;
    if (setter != null) {
      setter!(v);
    }
    if (onChanged != null) {
      onChanged!(v);
    }
  }

  void Function(T v)? setter;
  T Function()? getter;

  void Function(T v)? onChanged;

  NetworkProp(this.name, this._value);

  dynamic encode() => jsonEncode(value);

  void decode(dynamic v) => value = jsonDecode(v);
}

class NetworkPropList<T> extends NetworkProp<List<T>> {
  NetworkPropList(super.name, super.value);

  @override
  void decode(v) => value = (jsonDecode(v) as List<dynamic>).map((e) => e as T).toList();
}

typedef NetworkComponentFactory = NetworkComponent Function(String key, String group, String id);

mixin NetworkComponent {
  static final Map<String, NetworkComponentFactory> _factoryAll = {};
  static final Map<String, NetworkComponent> _componentAll = {};
  static final Map<String, Map<String, NetworkComponent>> _componentGroup = {};
  bool _updated = true; //default is updagted to sync
  final Map<String, NetworkProp<dynamic>> _props = {};
  final Map<String, NetworkCall<dynamic, dynamic>> _calls = {};

  String get nFactory;
  String get nGroup => "";
  String get nCID;
  bool get nRemoved;
  bool get nUpdated => _updated;

  //--------------------------//
  //------ NetworkComponent -------//

  static void registerFactory(String key, NetworkComponentFactory creator) => _factoryAll[key] = creator;

  static NetworkComponent createComponent(String key, String group) {
    var creator = _factoryAll[key] ?? _factoryAll["$group-*"] ?? _factoryAll["*"];
    if (creator == null) {
      throw Exception("NetworkComponentFactory by $key is not supported");
    }
    return creator(key, group, const Uuid().v1());
  }

  static void Function(NetworkComponent)? onAdd;
  static void Function(NetworkComponent)? onRemove;

  static NetworkComponent? findComponent(String nCID) => _componentAll[nCID];

  static Map<String, NetworkComponent> listGroupComponent(String group) {
    var componentGroup = _componentGroup[group];
    if (componentGroup == null) {
      componentGroup = {};
      _componentGroup[group] = componentGroup;
    }
    return componentGroup;
  }

  static void _addComponent(NetworkComponent c) {
    if (_componentAll.containsKey(c.nCID)) {
      return;
    }
    _componentAll[c.nCID] = c;
    listGroupComponent(c.nGroup)[c.nCID] = c;
    listGroupComponent("*")[c.nCID] = c;
    if (onAdd != null) {
      onAdd!(c);
    }
  }

  static void _removeComponent(NetworkComponent c) {
    if (!_componentAll.containsKey(c.nCID)) {
      return;
    }
    _componentAll.remove(c.nCID);
    listGroupComponent(c.nGroup).remove(c.nCID);
    listGroupComponent("*").remove(c.nCID);
    c.onNetworkRemove();
    if (onRemove != null) {
      onRemove!(c);
    }
  }

  void _removeComponentCheck() {
    if (_props.isEmpty && _calls.isEmpty) {
      _removeComponent(this);
    }
  }

  void onNetworkRemove();

  //--------------------------//
  //------ NetworkProp -------//

  void registerNetworkProp<T>(NetworkProp<T> prop, {T Function()? getter, void Function(T v)? setter}) {
    prop.getter = getter;
    prop.setter = setter;
    prop.onChanged = (v) => _updated = true;
    _props[prop.name] = prop;
    _addComponent(this);
  }

  void unregisterNetworkProp<T>(NetworkProp<T> prop) {
    _props.remove(prop.name);
    _removeComponentCheck();
  }

  void clearNetworkProp() {
    _props.clear();
    _removeComponentCheck();
  }

  Map<String, dynamic> checkNetworkProp() {
    if (!nUpdated) {
      return {};
    }
    Map<String, dynamic> updated = {};
    for (var prop in _props.values) {
      if (prop.updated) {
        updated[prop.name] = prop.encode();
        prop._updated = false;
      }
    }
    _updated = false;
    return updated;
  }

  void updateNetworkProp(Map<String, dynamic> updated) {
    for (var name in updated.keys) {
      var prop = _props[name];
      if (prop == null) {
        L.w("NetworkComponent($nFactory,$nCID) prop $name is not exists");
        continue;
      }
      prop.decode(updated[name]);
    }
  }

  static List<NetworkSyncDataComponent> syncSend(String group) {
    List<NetworkSyncDataComponent> components = [];
    List<NetworkComponent> willRemove = [];
    for (var c in listGroupComponent(group).values) {
      var removed = c.nRemoved;
      if (removed) {
        willRemove.add(c);
        continue;
      }
      var props = c.checkNetworkProp();
      if (props.isNotEmpty) {
        components.add(NetworkSyncDataComponent(nFactory: c.nFactory, nCID: c.nCID, nProps: props));
        continue;
      }
    }
    for (var c in willRemove) {
      _removeComponent(c);
      components.add(NetworkSyncDataComponent(nFactory: c.nFactory, nCID: c.nCID, nRemoved: true));
    }
    return components;
  }

  static void syncRecv(String group, List<NetworkSyncDataComponent> components) {
    for (var c in components) {
      var component = findComponent(c.nCID);
      if (c.nRemoved ?? false) {
        if (component != null) {
          _removeComponent(component);
        }
        continue;
      }
      component ??= createComponent(c.nFactory, group);
      if (c.nProps?.isNotEmpty ?? false) {
        component.updateNetworkProp(c.nProps ?? {});
      }
    }
  }

  //--------------------------//
  //------ NetworkCall -------//

  void registerNetworkCall<R, S>(NetworkCall<R, S> call, NetworkCallFunction<R, S> exec) {
    call.exec = exec;
    _calls[call.name] = call;
    _addComponent(this);
  }

  void unregisterNetworkCall<R, S>(NetworkCall<R, S> call) {
    _calls.remove(call.name);
    _removeComponentCheck();
  }

  void clearNetworkCall() {
    _calls.clear();
    _removeComponentCheck();
  }

  Future<R> networkCall<R, S>(NetworkCall<R, S> call, S arg) {
    return call.call(this, arg);
  }

  static Future<NetworkCallResult> callNetworkCall(NetworkCallArg arg) async {
    var c = findComponent(arg.nCID);
    if (c == null) {
      throw Exception("NetworkComponent(${arg.nCID}) is not exists");
    }
    var call = c._calls[arg.nName];
    if (call == null) {
      throw Exception("NetworkComponent(${arg.nCID}) call ${arg.nName} is not exists");
    }
    var result = await call.run(arg.uuid, arg.nArg);
    return NetworkCallResult(uuid: arg.uuid, nCID: arg.nCID, nName: arg.nName, nResult: result);
  }
}
