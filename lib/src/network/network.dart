import 'dart:convert';

import 'package:flutter/foundation.dart';
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

  String get user => value["user"] ?? "";
  set user(String v) => value["user"] = v;

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
  Future<void> networkSync(NetworkSyncData data) => throw UnimplementedError();
}

enum NetworkState {
  connecting,
  ready,
  closing,
  closed,
  error,
}

mixin NetworkCallback {
  Future<void> onNetworkState(Set<NetworkConnection> all, NetworkConnection conn, NetworkState state, {Object? info});
  Future<NetworkCallResult> onNetworkCall(NetworkConnection conn, NetworkCallArg arg);
  Future<void> onNetworkSync(NetworkConnection conn, NetworkSyncData data);
}

mixin NetworkTransport {
  NetworkSession session = NetworkSession.create();
  Duration keepalive = const Duration(seconds: 3);
  Duration timeout = const Duration(seconds: 10);
  late NetworkCallback callback;
  bool isServer = false;
  bool isClient = false;
  bool get standalone => isServer && isClient;
  set standalone(bool v) => isServer = isClient = v;
  Future<void> networkSync(NetworkSyncData data);
  Future<NetworkCallResult> networkCall(NetworkCallArg arg);
}

mixin NetworkEvent {
  Future<void> onNetworkState(Set<NetworkConnection> all, NetworkConnection conn, NetworkState state, {Object? info}) async {
    var user = conn.session?.user ?? "";
    if (user.isNotEmpty && state == NetworkState.ready && all.length == 1) {
      await onNetworkUserConnected(conn, user, info: info);
    }
    if (user.isNotEmpty && (state == NetworkState.closed || state == NetworkState.error) && all.isEmpty) {
      await onNetworkUserDisconnected(conn, user, info: info);
    }
  }

  Future<void> onNetworkUserConnected(NetworkConnection conn, String user, {Object? info}) async {}
  Future<void> onNetworkUserDisconnected(NetworkConnection conn, String user, {Object? info}) async {}
  void unregisterFromNetworkManager() => NetworkManager.global.unregisterNetworkEvent(this);
}

abstract class NetworkManager with NetworkTransport, NetworkCallback {
  static NetworkManager? _global;

  static NetworkManager get global {
    if (_global == null) {
      throw UnimplementedError("NetworkManager is not configured or extend from NetworkManager");
    }
    return _global!;
  }

  Duration minSync = const Duration(milliseconds: 30);
  DateTime _lastSync = DateTime.fromMillisecondsSinceEpoch(0);

  String? get user => session.user;
  final Map<NetworkEvent, String> _events = {};

  NetworkManager() {
    _global = this;
    callback = this;
  }

  Future<bool> sync(String group) async {
    var now = DateTime.now();
    if (now.difference(_lastSync) < minSync) {
      return false;
    }
    var updated = false;
    if (isServer) {
      var data = NetworkSyncData.syncSend(group);
      if (data.isUpdated) {
        networkSync(data);
        updated = true;
        _lastSync = now;
      }
    }
    return updated;
  }

  @override
  @mustCallSuper
  Future<void> onNetworkState(Set<NetworkConnection> all, NetworkConnection conn, NetworkState state, {Object? info}) async {
    var group = conn.session?.group ?? "";
    if (isServer && conn.isServer && state == NetworkState.ready) {
      var data = NetworkSyncData.syncSend(group, force: true);
      if (data.isUpdated) {
        await conn.networkSync(data);
      }
    }
    await Future.forEach(_events.keys, (event) async {
      var g = _events[event];
      if (g == group || g == "*") {
        await event.onNetworkState(all, conn, state, info: info);
      }
    });
  }

  @override
  @mustCallSuper
  Future<NetworkCallResult> onNetworkCall(NetworkConnection conn, NetworkCallArg arg) async => NetworkComponent.callNetworkCall(conn.session, arg);

  @override
  @mustCallSuper
  Future<void> onNetworkSync(NetworkConnection conn, NetworkSyncData data) async => NetworkComponent.syncRecv(data.group, data.components);

  void registerNetworkEvent({required NetworkEvent event, String? group}) => _events[event] = group ?? "*";

  void unregisterNetworkEvent(NetworkEvent event) => _events.remove(event);
}

class NetworkCallArg {
  String uuid;
  String nCID;
  String nName;
  String nArg;

  NetworkCallArg({required this.uuid, required this.nCID, required this.nName, required this.nArg});

  @override
  String toString() {
    return "NetworkCallArg(uuid:$uuid,nCID:$nCID,nName:$nName,nArg:$nArg)";
  }
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
  String? nOwner;
  bool? nRemoved;
  Map<String, dynamic>? nProps = {};

  NetworkSyncDataComponent({required this.nFactory, required this.nCID, this.nOwner, this.nRemoved, this.nProps});
}

class NetworkSyncData {
  String uuid;
  String group = "*";

  List<NetworkSyncDataComponent> components;

  bool get isUpdated => components.isNotEmpty;

  NetworkSyncData({required this.uuid, required this.group, required this.components});

  factory NetworkSyncData.create({List<NetworkSyncDataComponent>? components}) => NetworkSyncData(uuid: const Uuid().v1(), group: "*", components: components ?? List.empty(growable: true));

  factory NetworkSyncData.syncSend(group, {bool? force}) => NetworkSyncData(uuid: const Uuid().v1(), group: group, components: NetworkComponent.syncSend(group, force: force));
}

mixin NetworkValue {
  dynamic encode();
  void decode(dynamic v);
}

typedef NetworkCallFunction<R, S> = Future<R> Function(NetworkSession? ctx, String uuid, S);

class NetworkCall<R, S> {
  String name;
  NetworkCallFunction<R, S>? exec;
  NetworkValue Function()? argNew;
  NetworkValue Function()? retNew;
  NetworkCall(this.name, {this.exec, this.argNew, this.retNew});

  Future<String> run(NetworkSession? ctx, String uuid, String arg) async {
    var a = (argNew?.call()?..decode(arg)) ?? decode(arg);
    var r = await exec!(ctx, uuid, a);
    return encode(r);
  }

  Future<R> call(NetworkComponent c, S arg) async {
    var a = NetworkCallArg(uuid: const Uuid().v1(), nCID: c.nCID, nName: name, nArg: encode(arg));
    var r = await NetworkManager.global.networkCall(a);
    return (retNew?.call()?..decode(r.nResult)) ?? decode(r.nResult);
  }

  dynamic decode(String v) {
    return jsonDecode(v);
  }

  String encode(dynamic v) {
    if (v is NetworkValue) {
      return v.encode();
    }
    return jsonEncode(v);
  }
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

  dynamic encode() {
    if (value is NetworkValue) {
      return (value as NetworkValue).encode();
    }
    return jsonEncode(value);
  }

  void decode(dynamic v) {
    if (value is NetworkValue) {
      return (value as NetworkValue).decode(v);
    }
    value = jsonDecode(v);
  }
}

typedef NetworkComponentFactory = NetworkComponent Function(String key, String group, String cid);

mixin NetworkComponent {
  static final Map<String, NetworkComponentFactory> _factoryAll = {};
  static final Map<String, NetworkComponent> _componentAll = {};
  static final Map<String, Map<String, NetworkComponent>> _componentGroup = {};
  bool _updated = true; //default is updagted to sync
  final Map<String, NetworkProp<dynamic>> _props = {};
  final Map<String, NetworkCall<dynamic, dynamic>> _calls = {};

  String? nOwner;
  String get nFactory;
  String get nGroup => "";
  String get nCID;
  bool get nRemoved;
  bool get nUpdated => _updated;
  bool get isServer => NetworkManager.global.isServer;
  bool get isClient => NetworkManager.global.isClient;
  bool get isOwner => nOwner != null && nOwner == NetworkManager.global.user;

  //--------------------------//
  //------ NetworkComponent -------//

  static void registerFactory({String? key, String? group, required NetworkComponentFactory creator}) {
    if (group != null) {
      _factoryAll["$group-*"] = creator;
    }
    if (key != null) {
      _factoryAll[key] = creator;
    }
  }

  static NetworkComponent createComponent(String key, String group, String cid) {
    var creator = _factoryAll[key] ?? _factoryAll["$group-*"] ?? _factoryAll["*"];
    if (creator == null) {
      throw Exception("NetworkComponentFactory by $key is not supported");
    }
    var c = creator(key, group, cid);
    _addComponent(c);
    return c;
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

  //--------------------------//
  //------ NetworkEvent -------//

  void registerNetworkEvent({required NetworkEvent event, String? group}) => NetworkManager.global.registerNetworkEvent(event: event, group: group ?? nGroup);

  void unregisterNetworkEvent(NetworkEvent event) => NetworkManager.global.unregisterNetworkEvent(event);

  void onNetworkRemove();

  //--------------------------//
  //------ NetworkProp -------//

  void registerNetworkProp<T>(NetworkProp<T> prop, {T Function()? getter, void Function(T v)? setter}) {
    if (_props.containsKey(prop.name)) {
      throw Exception("NetworkProp ${prop.name} is registered");
    }
    prop.getter = getter;
    prop.setter = setter;
    prop.onChanged = (v) => _updated = true;
    if (setter != null) {
      setter(prop.value);
    }
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

  Map<String, dynamic> checkNetworkProp({bool? force}) {
    if (!nUpdated && !(force ?? false)) {
      return {};
    }
    Map<String, dynamic> updated = {};
    for (var prop in _props.values) {
      if (prop.updated || (force ?? false)) {
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

  static List<NetworkSyncDataComponent> syncSend(String group, {bool? force}) {
    List<NetworkSyncDataComponent> components = [];
    List<NetworkComponent> willRemove = [];
    for (var c in listGroupComponent(group).values) {
      var removed = c.nRemoved;
      if (removed) {
        willRemove.add(c);
        continue;
      }
      var props = c.checkNetworkProp(force: force);
      if (props.isNotEmpty) {
        components.add(NetworkSyncDataComponent(nFactory: c.nFactory, nCID: c.nCID, nOwner: c.nOwner, nProps: props));
        continue;
      }
    }
    for (var c in willRemove) {
      _removeComponent(c);
      components.add(NetworkSyncDataComponent(nFactory: c.nFactory, nCID: c.nCID, nOwner: c.nOwner, nRemoved: true));
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
      component ??= createComponent(c.nFactory, group, c.nCID);
      component.nOwner = c.nOwner;
      if (c.nProps?.isNotEmpty ?? false) {
        component.updateNetworkProp(c.nProps ?? {});
      }
    }
  }

  //--------------------------//
  //------ NetworkCall -------//

  void registerNetworkCall<R, S>(NetworkCall<R, S> call, NetworkCallFunction<R, S> exec) {
    if (_calls.containsKey(call.name)) {
      throw Exception("NetworkCall ${call.name} is registered");
    }
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

  static Future<NetworkCallResult> callNetworkCall(NetworkSession? ctx, NetworkCallArg arg) async {
    var c = findComponent(arg.nCID);
    if (c == null) {
      throw Exception("NetworkComponent(${arg.nCID}) is not exists");
    }
    var call = c._calls[arg.nName];
    if (call == null) {
      throw Exception("NetworkComponent(${arg.nCID}) call ${arg.nName} is not exists");
    }
    var result = await call.run(ctx, arg.uuid, arg.nArg);
    return NetworkCallResult(uuid: arg.uuid, nCID: arg.nCID, nName: arg.nName, nResult: result);
  }
}
