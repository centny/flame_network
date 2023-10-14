import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../common/log.dart';

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

  @override
  String toString() => jsonEncode(value);
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
  Duration timeout = const Duration(seconds: 5);
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

  Future<void> onNetworkPing(NetworkConnection conn, Duration ping) async {}

  void unregisterFromNetworkManager() => NetworkManager.global.unregisterNetworkEvent(this);
}

class NetworkSyncDataComponent {
  String nFactory;
  String nCID;
  String? nOwner;
  bool? nRemoved;
  Map<String, dynamic>? nProps = {};
  Map<String, dynamic>? nTriggers = {};

  NetworkSyncDataComponent({required this.nFactory, required this.nCID, this.nOwner, this.nRemoved, this.nProps, this.nTriggers});
}

class NetworkSyncData {
  String uuid;
  String group = "*";
  bool? whole; // if components container all NetworkComponents, if true client should remove NetworkComponents which is not in components

  List<NetworkSyncDataComponent> components;

  bool get isUpdated => components.isNotEmpty || (whole ?? false);

  NetworkSyncData({required this.uuid, required this.group, this.whole, required this.components});

  factory NetworkSyncData.create({List<NetworkSyncDataComponent>? components, bool? whole}) => NetworkSyncData(uuid: const Uuid().v1(), group: "*", whole: whole, components: components ?? List.empty(growable: true));

  factory NetworkSyncData.syncSend(group, {bool? whole}) => NetworkSyncData(uuid: const Uuid().v1(), group: group, whole: whole, components: NetworkComponent.syncSend(group, whole: whole));
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

  Duration get pingSpeed => const Duration();

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
      var data = NetworkSyncData.syncSend(group, whole: true);
      if (data.isUpdated) {
        await conn.networkSync(data);
      }
    }
    await Future.forEach(_events.keys, (event) async {
      var g = _events[event];
      if (g == group || g == "*") {
        try {
          await event.onNetworkState(all, conn, state, info: info);
        } catch (e, s) {
          L.e("NetworkManager call network event on group $g throw error $e\n$s");
        }
      }
    });
  }

  @override
  @mustCallSuper
  Future<NetworkCallResult> onNetworkCall(NetworkConnection conn, NetworkCallArg arg) async => NetworkComponent.callNetworkCall(conn.session, arg);

  @override
  @mustCallSuper
  Future<void> onNetworkSync(NetworkConnection conn, NetworkSyncData data) async => NetworkComponent.syncRecv(data.group, data.components, whole: data.whole);

  Future<void> onNetworkPing(NetworkConnection conn, Duration ping) async {
    var group = conn.session?.group ?? "";
    await Future.forEach(_events.keys, (event) async {
      var g = _events[event];
      if (g == group || g == "*") {
        try {
          await event.onNetworkPing(conn, ping);
        } catch (e, s) {
          L.e("NetworkManager call network ping on group $g throw error $e\n$s");
        }
      }
    });
  }

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
    if (onUpdate != null) {
      onUpdate!(v);
    }
  }

  void Function(T v)? setter;
  T Function()? getter;

  void Function(T v)? onUpdate;

  NetworkProp(this.name, this._value);

  dynamic syncSend() {
    _updated = false;
    return encode();
  }

  void syncRecv(dynamic v) => decode(v);

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

class NetworkTrigger<T> with Stream<T> implements StreamSink<T> {
  bool _updated = false; //default is not trigger to sync
  bool _listen = false;
  final List<T> _value = [];
  final StreamController<T> _stream = StreamController();
  final StreamController<T> _sink = StreamController();

  bool get updated => _updated;
  List<T> get value => _value;
  String name;

  void Function(T)? onRecv;
  void Function()? onDone;
  void Function(dynamic)? onError;
  void Function(T v)? onUpdate;

  NetworkTrigger(this.name) {
    _stream.onListen = () => _listen = true;
    _stream.onCancel = () => _listen = false;
    _sink.stream.listen(_onData, onDone: _onDone, onError: _onError);
  }

  void _onData(T event) {
    if (onRecv != null) {
      onRecv!(event);
    }
    if (_listen) {
      _stream.sink.add(event);
    }
    if (NetworkManager.global.isServer && !NetworkManager.global.isClient) {
      _value.add(event);
      _updated = true;
      if (onUpdate != null) {
        onUpdate!(event);
      }
    }
  }

  void _onDone() {
    if (onDone != null) {
      onDone!();
    }
    if (_listen) {
      _stream.sink.close();
    }
  }

  void _onError(e) {
    if (onError != null) {
      onError!(e);
    }
    if (_listen) {
      _stream.sink.addError(e);
    }
  }

  @override
  void add(T event) => _sink.add(event);

  @override
  void addError(Object error, [StackTrace? stackTrace]) => _sink.addError(error, stackTrace);

  @override
  Future addStream(Stream<T> stream) => _sink.addStream(stream);

  @override
  Future close() => _sink.close();

  @override
  Future get done => _sink.done;

  @override
  StreamSubscription<T> listen(void Function(T event)? onData, {Function? onError, void Function()? onDone, bool? cancelOnError}) {
    return _stream.stream.listen(onData, onDone: onDone, onError: onError, cancelOnError: cancelOnError);
  }

  dynamic syncSend() {
    _updated = false;
    var v = encode(value);
    _value.clear();
    return v;
  }

  void syncRecv(dynamic v) {
    for (var val in decode(v)) {
      add(val);
    }
  }

  dynamic encode(List<T> v) {
    return jsonEncode(v);
  }

  List<T> decode(dynamic v) {
    return (jsonDecode(v) as List<dynamic>).map((e) => e as T).toList();
  }
}

typedef NetworkComponentFactory = NetworkComponent Function(String key, String group, String cid);

mixin NetworkComponent {
  static final Map<String, NetworkComponentFactory> _factoryAll = {};
  static final Map<String, NetworkComponent> _componentAll = {};
  static final Map<String, Map<String, NetworkComponent>> _componentGroup = {};
  bool _propUpdated = true; //default is updated to sync
  bool _triggerUpdated = true; //default is not trigger
  final Map<String, NetworkProp<dynamic>> _props = {};
  final Map<String, NetworkTrigger<dynamic>> _triggers = {};
  final Map<String, NetworkCall<dynamic, dynamic>> _calls = {};

  String? nOwner;
  String get nFactory;
  String get nGroup => "";
  String get nCID;
  bool get nRemoved;
  bool get nUpdated => _propUpdated || _triggerUpdated;
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
    if (_props.isEmpty && _triggers.isEmpty && _calls.isEmpty) {
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
    prop.onUpdate = (v) => _propUpdated = true;
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

  Map<String, dynamic> sendNetworkProp({bool? whole}) {
    if (!_propUpdated && !(whole ?? false)) {
      return {};
    }
    Map<String, dynamic> updated = {};
    for (var prop in _props.values) {
      if (prop.updated || (whole ?? false)) {
        updated[prop.name] = prop.syncSend();
      }
    }
    _propUpdated = false;
    return updated;
  }

  void recvNetworkProp(Map<String, dynamic> updated) {
    for (var name in updated.keys) {
      var prop = _props[name];
      if (prop == null) {
        L.w("NetworkComponent($nFactory,$nCID) prop $name is not exists");
        continue;
      }
      try {
        prop.syncRecv(updated[name]);
      } catch (e, s) {
        L.e("NetworkComponent($nFactory,$nCID) update network prop ${prop.name} throw error $e\n$s");
      }
    }
  }

  //--------------------------//
  //------ NetworkTrigger -------//

  void registerNetworkTrigger<T>(NetworkTrigger<T> trigger, void Function(T)? recv, {void Function()? done, void Function(dynamic)? error}) {
    if (_triggers.containsKey(trigger.name)) {
      throw Exception("NetworkTrigger ${trigger.name} is registered");
    }
    trigger.onRecv = recv;
    trigger.onDone = done;
    trigger.onError = error;
    trigger.onUpdate = (v) => _triggerUpdated = true;
    _triggers[trigger.name] = trigger;
    _addComponent(this);
  }

  void unregisterNetworkTrigger<T>(NetworkTrigger<T> trigger) {
    _triggers.remove(trigger.name);
    trigger.close();
    _removeComponentCheck();
  }

  void clearNetworkTrigger() {
    _triggers.clear();
    _removeComponentCheck();
  }

  Map<String, dynamic> sendNetworkTrigger() {
    if (!_triggerUpdated) {
      return {};
    }
    Map<String, dynamic> updated = {};
    for (var trigger in _triggers.values) {
      if (trigger.updated) {
        updated[trigger.name] = trigger.syncSend();
      }
    }
    _triggerUpdated = false;
    return updated;
  }

  void recvNetworkTrigger(Map<String, dynamic> updated) {
    for (var name in updated.keys) {
      var trigger = _triggers[name];
      if (trigger == null) {
        L.w("NetworkTrigger($nFactory,$nCID) trigger $name is not exists");
        continue;
      }
      try {
        trigger.syncRecv(updated[name]);
      } catch (e, s) {
        L.e("NetworkTrigger($nFactory,$nCID) recv network trigger ${trigger.name} throw error $e\n$s");
      }
    }
  }

  static List<NetworkSyncDataComponent> syncSend(String group, {bool? whole}) {
    List<NetworkSyncDataComponent> components = [];
    List<NetworkComponent> willRemove = [];
    for (var c in listGroupComponent(group).values) {
      var removed = c.nRemoved;
      if (removed) {
        willRemove.add(c);
        continue;
      }
      var props = c.sendNetworkProp(whole: whole);
      var triggers = c.sendNetworkTrigger();
      if (props.isNotEmpty || triggers.isNotEmpty) {
        components.add(NetworkSyncDataComponent(nFactory: c.nFactory, nCID: c.nCID, nOwner: c.nOwner, nProps: props, nTriggers: triggers));
        continue;
      }
    }
    for (var c in willRemove) {
      _removeComponent(c);
      components.add(NetworkSyncDataComponent(nFactory: c.nFactory, nCID: c.nCID, nOwner: c.nOwner, nRemoved: true));
    }
    return components;
  }

  static void syncRecv(String group, List<NetworkSyncDataComponent> components, {bool? whole}) {
    var cidAll = HashSet<String>();
    for (var c in components) {
      var component = findComponent(c.nCID);
      if (c.nRemoved ?? false) {
        if (component != null) {
          _removeComponent(component);
        }
        continue;
      }
      cidAll.add(c.nCID);
      component ??= createComponent(c.nFactory, group, c.nCID);
      component.nOwner = c.nOwner;
      if (c.nProps?.isNotEmpty ?? false) {
        component.recvNetworkProp(c.nProps ?? {});
      }
      if (c.nTriggers?.isNotEmpty ?? false) {
        component.recvNetworkTrigger(c.nTriggers ?? {});
      }
    }
    if (whole ?? false) {
      var componentRemove = [];
      _componentAll.forEach((cid, c) {
        if (!cidAll.contains(cid)) {
          componentRemove.add(c);
        }
      });
      for (var c in componentRemove) {
        _removeComponent(c);
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
    try {
      var result = await call.run(ctx, arg.uuid, arg.nArg);
      return NetworkCallResult(uuid: arg.uuid, nCID: arg.nCID, nName: arg.nName, nResult: result);
    } catch (e, s) {
      L.e("NetworkComponent(${c.nFactory},${c.nCID}) call ${call.name} throw error $e\n$s");
      rethrow;
    }
  }
}
