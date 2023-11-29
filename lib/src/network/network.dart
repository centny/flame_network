import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../common/log.dart';

mixin NetworkSession {
  Map<String, String> get meta;

  Map<String, String> get context;

  DateTime last = DateTime.now();

  String get key => meta["key"] ?? "";
  set key(String v) => meta["key"] = v;

  String? get user => context["user"];
  set user(String? v) => context["user"] = v!;

  String? get group => context["group"];
  set group(String? v) => context["group"] = v!;

  @override
  int get hashCode => key.hashCode;

  @override
  bool operator ==(Object other) {
    return other is NetworkSession && key == other.key;
  }
}

class DefaultNetworkSession with NetworkSession {
  Map<String, String> _meta;
  Map<String, String> _context;

  @override
  Map<String, String> get meta => _meta;

  @override
  Map<String, String> get context => _context;

  DefaultNetworkSession(this._meta, this._context);

  factory DefaultNetworkSession.create() => DefaultNetworkSession({"key": const Uuid().v1()}, {});

  factory DefaultNetworkSession.meta(Map<String, String> meta) => DefaultNetworkSession(meta, {});

  factory DefaultNetworkSession.session(String session) => DefaultNetworkSession({"key": session}, {});
}

mixin NetworkConnection {
  NetworkSession get session;
  NetworkState get state;
  bool get isServer;
  bool get isClient;
  Future<void> networkSync(NetworkSyncData data) => throw UnimplementedError();
  Future<void> close() async {}
}

enum NetworkState {
  none,
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
  NetworkSession session = DefaultNetworkSession.create();
  Duration keepalive = const Duration(seconds: 3);
  Duration timeout = const Duration(seconds: 5);
  late NetworkCallback callback;
  bool isServer = false;
  bool isClient = false;
  bool isReady = false;
  bool get standalone => isServer && isClient;
  set standalone(bool v) => isServer = isClient = v;
  Future<void> ready();
  Future<void> pause();
  Future<void> networkSync(NetworkSyncData data, {List<NetworkConnection>? excluded});
  Future<NetworkCallResult> networkCall(NetworkCallArg arg);
}

mixin NetworkEvent {
  Future<void> onNetworkState(Set<NetworkConnection> all, NetworkConnection conn, NetworkState state, {Object? info}) async {
    var user = conn.session.user ?? "";
    if (user.isNotEmpty && state == NetworkState.ready && all.length == 1) {
      await onNetworkUserConnected(conn, user, info: info);
    }
    if (user.isNotEmpty && (state == NetworkState.closed || state == NetworkState.error) && (all.isEmpty || (all.length == 1 && all.contains(conn)))) {
      await onNetworkUserDisconnected(conn, user, info: info);
    }
  }

  Future<void> onNetworkUserConnected(NetworkConnection conn, String user, {Object? info}) async {}

  Future<void> onNetworkUserDisconnected(NetworkConnection conn, String user, {Object? info}) async {}

  Future<void> onNetworkPing(NetworkConnection conn, Duration ping) async {}

  Future<void> onNetworkDataSynced(NetworkConnection conn, NetworkSyncData data) async {}

  void unregisterFromNetworkManager() => NetworkManager.global.unregisterNetworkEvent(this);
}

class NetworkSyncDataComponent {
  String nFactory;
  String nCID;
  String nOwner;
  bool? nRemoved;
  Map<String, dynamic>? nProps = {};
  Map<String, List<dynamic>>? nTriggers = {};

  NetworkSyncDataComponent({required this.nFactory, required this.nCID, this.nOwner = "", this.nRemoved, this.nProps, this.nTriggers});

  static Map<String, dynamic> encodeProp(Map<String, dynamic>? props, NetworkSession session) {
    Map<String, dynamic> propAll = {};
    props?.forEach((key, value) {
      if (value is NetworkValue) {
        if (value.access(session)) {
          propAll[key] = jsonEncode(value.encode());
        }
      } else {
        propAll[key] = jsonEncode(value);
      }
    });
    return propAll;
  }

  static Map<String, dynamic> decodeProp(Map<String, dynamic>? props) => props?.map((key, value) => MapEntry(key, jsonDecode(value))) ?? {};

  static Map<String, List<dynamic>> encodeTrigger(Map<String, List<dynamic>>? triggers, NetworkSession session) {
    Map<String, List<dynamic>> triggerAll = {};
    triggers?.forEach((key, value) {
      var vals = [];
      for (var e in value) {
        if (e is NetworkValue) {
          if (e.access(session)) {
            vals.add(jsonEncode(e.encode()));
          }
        } else {
          vals.add(jsonEncode(e));
        }
      }
      if (vals.isNotEmpty) {
        triggerAll[key] = vals;
      }
    });
    return triggerAll;
  }

  static Map<String, List<dynamic>> decodeTrigger(Map<String, List<dynamic>>? triggers) =>
      triggers?.map((key, value) => MapEntry(key, value.map((e) => jsonDecode(e)).toList())) ?? {};

  NetworkSyncDataComponent encode(NetworkSession session) => NetworkSyncDataComponent(
        nFactory: nFactory,
        nCID: nCID,
        nOwner: nOwner,
        nRemoved: nRemoved,
        nProps: encodeProp(nProps, session),
        nTriggers: encodeTrigger(nTriggers, session),
      );

  NetworkSyncDataComponent decode() => NetworkSyncDataComponent(
        nFactory: nFactory,
        nCID: nCID,
        nOwner: nOwner,
        nRemoved: nRemoved,
        nProps: decodeProp(nProps),
        nTriggers: decodeTrigger(nTriggers),
      );
}

class NetworkSyncData {
  String uuid;
  String group = "*";
  bool? whole; // if components container all NetworkComponents, if true client should remove NetworkComponents which is not in components

  List<NetworkSyncDataComponent> components;

  bool get isUpdated => components.isNotEmpty || (whole ?? false);

  NetworkSyncData({required this.uuid, required this.group, this.whole, required this.components});

  factory NetworkSyncData.create({List<NetworkSyncDataComponent>? components, bool? whole}) =>
      NetworkSyncData(uuid: const Uuid().v1(), group: "*", whole: whole, components: components ?? List.empty(growable: true));

  factory NetworkSyncData.syncSend(String group, {bool? whole}) =>
      NetworkSyncData(uuid: const Uuid().v1(), group: group, whole: whole, components: NetworkComponent.syncSend(group, whole: whole));
}

abstract class NetworkManager with NetworkTransport, NetworkCallback {
  static NetworkManager? _global;

  static NetworkManager get global {
    if (_global == null) {
      throw UnimplementedError("NetworkManager is not configured or extend from NetworkManager");
    }
    return _global!;
  }

  bool verbose = false;
  Duration minSync = const Duration(milliseconds: 30);
  DateTime _lastSync = DateTime.fromMillisecondsSinceEpoch(0);

  String? get user => session.user;
  final Map<NetworkEvent, String> _events = {};

  Duration get pingSpeed => const Duration();

  NetworkManager() {
    _global = this;
    callback = this;
  }

  Future<bool> sync(String group, {NetworkConnection? whole}) async {
    var now = DateTime.now();
    if (whole == null && now.difference(_lastSync) < minSync) {
      return false;
    }
    var updated = false;
    if (isServer) {
      var updatedData = NetworkSyncData.syncSend(group);
      if (updatedData.isUpdated) {
        networkSync(updatedData, excluded: whole == null ? null : [whole]);
        updated = true;
        _lastSync = now;
      }
      if (whole != null) {
        var wholeData = NetworkSyncData.syncSend(group, whole: true);
        whole.networkSync(wholeData);
      }
    }
    return updated;
  }

  List<NetworkEvent> matchNetworkEvent(String group) {
    List<NetworkEvent> matched = [];
    _events.forEach((e, g) {
      if (g == group || g == "*") {
        matched.add(e);
      }
    });
    return matched;
  }

  @override
  @mustCallSuper
  Future<void> onNetworkState(Set<NetworkConnection> all, NetworkConnection conn, NetworkState state, {Object? info}) async {
    var group = conn.session.group ?? "";
    if (isServer && conn.isServer && state == NetworkState.ready) {
      await sync(group, whole: conn);
    }
    await Future.forEach(matchNetworkEvent(group), (event) async {
      try {
        await event.onNetworkState(all, conn, state, info: info);
      } catch (e, s) {
        L.e("NetworkManager call network event on $event throw error $e\n$s");
      }
    });
  }

  @override
  @mustCallSuper
  Future<NetworkCallResult> onNetworkCall(NetworkConnection conn, NetworkCallArg arg) async => NetworkComponent.callNetworkCall(conn.session, arg);

  @override
  @mustCallSuper
  Future<void> onNetworkSync(NetworkConnection conn, NetworkSyncData data) async {
    NetworkComponent.syncRecv(data.group, data.components, whole: data.whole);
    var group = conn.session.group ?? "";
    await Future.forEach(matchNetworkEvent(group), (event) async {
      try {
        await event.onNetworkDataSynced(conn, data);
      } catch (e, s) {
        L.e("NetworkManager call network data synced on $event throw error $e\n$s");
      }
    });
  }

  Future<void> onNetworkPing(NetworkConnection conn, Duration ping) async {
    var group = conn.session.group ?? "";
    await Future.forEach(matchNetworkEvent(group), (event) async {
      try {
        await event.onNetworkPing(conn, ping);
      } catch (e, s) {
        L.e("NetworkManager call network ping on $event throw error $e\n$s");
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

class NetworkException {
  String message;

  NetworkException(this.message);

  static void must(bool ok, String message) {
    if (!ok) {
      throw NetworkException(message);
    }
  }

  @override
  String toString() => message;
}

mixin NetworkValue {
  dynamic encode();
  void decode(dynamic v);
  bool access(NetworkSession s) => true;
}

typedef NetworkCallFunction<R, S> = Future<R> Function(NetworkSession ctx, String uuid, S);

class NetworkCall<R, S> {
  String name;
  NetworkCallFunction<R, S>? exec;
  NetworkValue Function()? argNew;
  NetworkValue Function()? retNew;
  NetworkCall(this.name, {this.exec, this.argNew, this.retNew});

  Future<String> run(NetworkSession ctx, String uuid, String arg) async {
    var a = (argNew?.call()?..decode(jsonDecode(arg))) ?? decode(arg);
    var r = await exec!(ctx, uuid, a);
    return encode(r);
  }

  Future<R> call(NetworkComponent c, S arg) async {
    var a = NetworkCallArg(uuid: const Uuid().v1(), nCID: c.nCID, nName: name, nArg: encode(arg));
    var r = await NetworkManager.global.networkCall(a);
    return (retNew?.call()?..decode(jsonDecode(r.nResult))) ?? decode(r.nResult);
  }

  dynamic decode(String v) => jsonDecode(v);

  String encode(dynamic v) => v is NetworkValue ? jsonEncode(v.encode()) : jsonEncode(v);
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

  NetworkProp(this.name, T defaultValue) : _value = defaultValue;

  dynamic syncSend() {
    _updated = false;
    return encode();
  }

  void syncRecv(dynamic v) => decode(v);

  dynamic encode() => value;

  void decode(dynamic v) => value = value is NetworkValue ? ((value as NetworkValue)..decode(v)) as T : v as T;
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

  NetworkValue Function()? valNew;
  void Function(T)? onRecv;
  void Function()? onDone;
  void Function(dynamic)? onError;
  void Function(T v)? onUpdate;

  NetworkTrigger(this.name, {this.valNew}) {
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

  List<dynamic> syncSend() {
    _updated = false;
    var v = encode(value);
    _value.clear();
    return v;
  }

  void syncRecv(List<dynamic> v) {
    for (var val in decode(v)) {
      add(val);
    }
  }

  List<dynamic> encode(List<T> v) => v.map((e) => e).toList();

  List<T> decode(List<dynamic> v) => v.map((e) => valNew != null ? (valNew!()..decode(e)) as T : e as T).toList();
}

typedef NetworkComponentFactory = NetworkComponent Function(String key, String group, String owner, String cid);

mixin NetworkComponent {
  static final Map<String, NetworkComponentFactory> _factoryAll = {};
  static final Map<String, NetworkComponent> _componentAll = {};
  static final Map<String, Map<String, NetworkComponent>> _componentGroup = {};
  static const String netCreator = "net";
  static const String locCreator = "loc";
  bool _propUpdated = true; //default is updated to sync
  bool _triggerUpdated = true; //default is not trigger
  bool _resync = false; //if whole prop resync
  String _creator = locCreator;
  final Map<String, NetworkProp<dynamic>> _props = {};
  final Map<String, NetworkTrigger<dynamic>> _triggers = {};
  final Map<String, NetworkCall<dynamic, dynamic>> _calls = {};

  String get nCreator => _creator;
  String get nFactory;
  String get nGroup => "";
  String get nOwner => "";
  String get nCID;
  bool get nRemoved;
  bool get nUpdated => _propUpdated || _triggerUpdated;
  bool get isServer => NetworkManager.global.isServer;
  bool get isClient => NetworkManager.global.isClient;
  bool get isOwner => nOwner == NetworkManager.global.user;
  bool get isResync => _resync;

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

  static void unregisterFactory({String? key, String? group}) {
    if (group != null) {
      _factoryAll.remove("$group-*");
    }
    if (key != null) {
      _factoryAll.remove(key);
    }
  }

  static NetworkComponent createComponent(String key, String group, String owner, String cid) {
    var creator = _factoryAll[key] ?? _factoryAll["$group-*"] ?? _factoryAll["*"];
    if (creator == null) {
      throw Exception("NetworkComponentFactory by $key is not supported");
    }
    var c = creator(key, group, owner, cid);
    _addComponent(c);
    return c;
  }

  static void Function(NetworkComponent)? onComponentAdd;
  static void Function(NetworkComponent)? onComponentRemove;

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
    if (onComponentAdd != null) {
      onComponentAdd!(c);
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
    if (onComponentRemove != null) {
      onComponentRemove!(c);
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

  void onNetworkSynced() async {}

  //--------------------------//
  //------ NetworkTrigger -------//

  void registerNetworkTrigger<T>(NetworkTrigger<T> trigger, void Function(T)? recv,
      {void Function()? done, void Function(dynamic)? error, NetworkValue Function()? valNew}) {
    if (_triggers.containsKey(trigger.name)) {
      throw Exception("NetworkTrigger ${trigger.name} is registered");
    }
    trigger.onRecv = recv;
    trigger.onDone = done;
    trigger.onError = error;
    if (valNew != null) {
      trigger.valNew = valNew;
    }
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

  Map<String, List<dynamic>> sendNetworkTrigger() {
    if (!_triggerUpdated) {
      return {};
    }
    Map<String, List<dynamic>> updated = {};
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
    List<NetworkComponent> componentSynced = [];
    for (var c in components) {
      var component = findComponent(c.nCID);
      if (c.nRemoved ?? false) {
        if (component != null) {
          component._resync = whole ?? false;
          _removeComponent(component);
        }
        continue;
      }
      cidAll.add(c.nCID);
      component ??= createComponent(c.nFactory, group, c.nOwner, c.nCID).._creator = netCreator;
      component._resync = whole ?? false;
      if (c.nProps?.isNotEmpty ?? false) {
        component.recvNetworkProp(c.nProps ?? {});
      }
      if (c.nTriggers?.isNotEmpty ?? false) {
        component.recvNetworkTrigger(c.nTriggers ?? {});
      }
      component._resync = false;
      componentSynced.add(component);
    }
    if (whole ?? false) {
      var componentRemove = [];
      _componentAll.forEach((cid, c) {
        if (c.nCreator == NetworkComponent.netCreator && !cidAll.contains(cid)) {
          componentRemove.add(c);
        }
      });
      for (var c in componentRemove) {
        _removeComponent(c);
      }
    }
    for (var c in componentSynced) {
      c.onNetworkSynced();
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

  static Future<NetworkCallResult> callNetworkCall(NetworkSession ctx, NetworkCallArg arg) async {
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
      if (e is! NetworkException) {
        L.e("NetworkComponent(${c.nFactory},${c.nCID}) call ${call.name} throw error $e\n$s");
      }
      rethrow;
    }
  }
}
