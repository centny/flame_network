import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:fixnum/fixnum.dart';
import 'package:flame_network/flame_network.dart';
import 'package:flame_network/src/common/common.dart';
import 'package:flame_network/src/network/grpc/server.pbgrpc.dart';
import 'package:grpc/grpc.dart';
import 'package:http2/transport.dart';
import 'package:uuid/uuid.dart';

import '../common/log.dart';

RequestID newRequestID() => RequestID(uuid: const Uuid().v1());

extension on NetworkSyncDataComponent {
  SyncDataComponent wrap() {
    return SyncDataComponent(
      factory: nFactory,
      cid: nCID,
      removed: nRemoved,
      props: jsonEncode(nProps),
    );
  }
}

extension on SyncDataComponent {
  NetworkSyncDataComponent wrap() {
    return NetworkSyncDataComponent(
      nFactory: factory,
      nCID: cid,
      nRemoved: removed,
      nProps: jsonDecode(props),
    );
  }
}

extension on SyncData {
  NetworkSyncData wrap() {
    return NetworkSyncData(
      uuid: id.uuid,
      group: groupd,
      components: components.map((e) => e.wrap()).toList(),
    );
  }
}

extension on CallArg {
  NetworkCallArg wrap() {
    return NetworkCallArg(
      uuid: id.uuid,
      nCID: cid,
      nName: name,
      nArg: arg,
    );
  }
}

extension on NetworkCallArg {
  CallArg wrap() {
    return CallArg(
      id: RequestID(uuid: uuid),
      cid: nCID,
      name: nName,
      arg: nArg,
    );
  }
}

extension on CallResult {
  NetworkCallResult wrap() {
    return NetworkCallResult(
      uuid: id.uuid,
      nCID: cid,
      nName: name,
      nResult: result,
    );
  }
}

extension on NetworkCallResult {
  CallResult wrap() {
    return CallResult(
      id: RequestID(uuid: uuid),
      cid: nCID,
      name: nName,
      result: nResult,
    );
  }
}

class NetworkServerConnGRPC with NetworkConnection {
  @override
  bool get isClient => false;

  @override
  bool get isServer => true;

  NetworkServerConnGRPC({NetworkSession? session, NetworkState? state}) {
    this.session = session;
    this.state = state;
  }
}

class _NetworkSyncStream extends NetworkServerConnGRPC {
  StreamController<SyncData> controller = StreamController<SyncData>();

  Stream<SyncData> get stream => controller.stream;

  _NetworkSyncStream({super.session, super.state});

  void add(SyncData data) {
    controller.sink.add(data);
  }

  Future<void> close() async {
    await controller.sink.close();
  }
}

class NetworkServerGRPC extends ServerServiceBase {
  final NetworkCallback callback;
  final Map<String, HashSet<_NetworkSyncStream>> _connAll = {};
  final Map<String, HashSet<_NetworkSyncStream>> _connGroup = {};
  final Map<String, NetworkConnection> _sessionAll = {};

  NetworkServerGRPC(this.callback);

  NetworkConnection _keepSession(NetworkSession session) {
    var having = _sessionAll[session.session];
    if (having == null) {
      having = NetworkServerConnGRPC(session: session);
      _sessionAll[session.session] = having;
    }
    having.session?.last = DateTime.now();
    return having;
  }

  HashSet<_NetworkSyncStream> _sessionConnAll(String session) {
    var connSession = _connAll[session];
    if (connSession == null) {
      connSession = HashSet();
      _connAll[session] = connSession;
    }
    return connSession;
  }

  HashSet<_NetworkSyncStream> _sessionConnGroup(String group) {
    var connGroup = _connGroup[group];
    if (connGroup == null) {
      connGroup = HashSet();
      _connGroup[group] = connGroup;
    }
    return connGroup;
  }

  void _addStream(_NetworkSyncStream conn) {
    _sessionConnAll(conn.session?.session ?? "").add(conn);
    _sessionConnGroup(conn.session?.group ?? "").add(conn);
    _sessionConnGroup("*").add(conn);
    callback.onNetworkState(conn, NetworkState.ready);
  }

  void _cancleStream(_NetworkSyncStream conn) {
    _sessionConnAll(conn.session?.session ?? "").remove(conn);
    _sessionConnGroup(conn.session?.group ?? "").remove(conn);
    _sessionConnGroup("*").remove(conn);
    callback.onNetworkState(conn, NetworkState.closed);
  }

  Future<void> close() async {
    for (var conn in _sessionConnGroup("*").toSet()) {
      await conn.close();
    }
  }

  void networkSync(NetworkSyncData data) {
    var components = data.components.map((e) => e.wrap());
    for (var conn in _sessionConnGroup(data.group)) {
      var syncData = SyncData(id: newRequestID(), components: components);
      conn.add(syncData);
    }
  }

  Future<void> timeout(Duration max) async {
    List<String> keys = [];
    var now = DateTime.now();
    _sessionAll.forEach((k, v) {
      if (now.difference(v.session?.last ?? DateTime.fromMillisecondsSinceEpoch(0)) >= max * 2) {
        keys.add(k);
      }
    });
    for (var key in keys) {
      _sessionAll.remove(key);
      for (var conn in _sessionConnAll(key).toSet()) {
        await conn.close();
      }
    }
  }

  @override
  Future<PingResult> remotePing(ServiceCall call, PingArg request) async {
    var session = NetworkSession.from(call.clientMetadata ?? {});
    _keepSession(session);
    return PingResult(id: request.id, serverTime: Int64(DateTime.now().millisecondsSinceEpoch));
  }

  @override
  Stream<SyncData> remoteSync(ServiceCall call, SyncArg request) {
    var session = NetworkSession.from(call.clientMetadata ?? {});
    var syncStream = _NetworkSyncStream(session: session, state: NetworkState.ready);
    syncStream.controller.onCancel = () => _cancleStream(syncStream);
    _addStream(syncStream);
    _keepSession(session);
    return syncStream.stream;
  }

  @override
  Future<CallResult> remoteCall(ServiceCall call, CallArg request) async {
    var session = NetworkSession.from(call.clientMetadata ?? {});
    var conn = _keepSession(session);
    try {
      var result = await callback.onNetworkCall(conn, request.wrap());
      return result.wrap();
    } catch (e) {
      return CallResult(id: request.id, cid: request.cid, name: request.name, error: "$e");
    }
  }
}

class NetworkClientGRPC extends ServerClient with NetworkConnection {
  NetworkCallback callback;
  Duration timeout = const Duration(seconds: 10);
  ResponseStream<SyncData>? _syncMonitor;

  CallOptions get callOptions => CallOptions(metadata: session?.value, timeout: timeout);

  @override
  bool get isClient => true;

  @override
  bool get isServer => false;

  NetworkClientGRPC(ClientChannel channel, this.callback) : super(channel) {
    channel.onConnectionStateChanged.listen(onConnectionStateChanged);
  }

  void onConnectionStateChanged(ConnectionState state) {
    switch (state) {
      case ConnectionState.connecting:
        L.i("[GRPC] client connection is connecting");
        this.state = NetworkState.connecting;
        callback.onNetworkState(this, NetworkState.connecting);
        break;
      case ConnectionState.ready:
        L.i("[GRPC] client connection is ready");
        this.state = NetworkState.ready;
        callback.onNetworkState(this, NetworkState.ready);
        break;
      case ConnectionState.transientFailure:
        L.i("[GRPC] client connection is reconnecting");
        this.state = NetworkState.connecting;
        callback.onNetworkState(this, NetworkState.connecting);
        break;
      case ConnectionState.idle:
        break;
      case ConnectionState.shutdown:
        L.i("[GRPC] client connection is closed");
        this.state = NetworkState.closed;
        callback.onNetworkState(this, NetworkState.closed);
        break;
    }
  }

  Future<DateTime> ping(Duration timeout) async {
    var result = await super.remotePing(PingArg(id: newRequestID()), options: CallOptions(metadata: session?.value, timeout: timeout));
    return DateTime.fromMillisecondsSinceEpoch(result.serverTime.toInt());
  }

  Future<void> onNetworkSync(NetworkConnection conn, NetworkSyncData data) async {
    try {
      await callback.onNetworkSync(conn, data);
    } catch (e, s) {
      L.e("[GRPC] network sync fail with $e\n$s");
    }
  }

  void startMonitorSync() async {
    var request = SyncArg(id: newRequestID());
    _syncMonitor = super.remoteSync(request, options: CallOptions(metadata: session?.value));
    _syncMonitor?.listen((value) async => await onNetworkSync(this, value.wrap())).onError((e) => callback.onNetworkState(this, NetworkState.error, info: e));
  }

  Future<void> stopMonitorSync() async {
    await _syncMonitor?.cancel();
    _syncMonitor = null;
  }

  Future<NetworkCallResult> networkCall(NetworkCallArg arg) async {
    var result = await super.remoteCall(arg.wrap(), options: callOptions);
    if (result.error.isNotEmpty) {
      throw Exception(result.error);
    }
    return result.wrap();
  }
}

class HandledServerConnectionGRPC implements ServerTransportConnection {
  ServerTransportConnection conn;
  Function? onError;
  void Function()? onDone;

  HandledServerConnectionGRPC({required this.conn, this.onError, this.onDone});

  @override
  Future ping() => conn.ping();

  @override
  set onActiveStateChanged(ActiveStateHandler callback) => conn.onActiveStateChanged = callback;

  @override
  Future<void> get onInitialPeerSettingsReceived => conn.onInitialPeerSettingsReceived;

  @override
  Stream<int> get onPingReceived => conn.onPingReceived;

  @override
  Stream<void> get onFrameReceived => conn.onFrameReceived;

  @override
  Future finish() => conn.finish();

  @override
  Future terminate([int? errorCode]) => conn.terminate(errorCode);

  @override
  Stream<ServerTransportStream> get incomingStreams => HandleableStream(stream: conn.incomingStreams, onError: onError, onDone: onDone);
}

class HandledServerGRPC extends Server {
  final _connections = <ServerTransportConnection>[];

  HandledServerGRPC.create({required super.services, super.keepAliveOptions, super.interceptors, super.codecRegistry, super.errorHandler}) : super.create();

  List<ServerTransportConnection> get connections => _connections.toList();

  void _addConnection(ServerTransportConnection conn) {
    _connections.add(conn);
  }

  void _removeConnection(ServerTransportConnection conn) {
    _connections.remove(conn);
  }

  @override
  Future<void> serveConnection({required ServerTransportConnection connection, X509Certificate? clientCertificate, InternetAddress? remoteAddress}) {
    var handled = HandledServerConnectionGRPC(conn: connection);
    _addConnection(handled);
    handled.onError = (e) => _removeConnection(handled);
    handled.onDone = () => _removeConnection(handled);
    return super.serveConnection(connection: handled, clientCertificate: clientCertificate, remoteAddress: remoteAddress);
  }

  @override
  Future<void> shutdown() async {
    for (var conn in _connections.toList()) {
      await conn.terminate();
    }
    await super.shutdown();
  }
}

class NetworkManagerGRPC extends NetworkManager {
  static NetworkManagerGRPC? _instance;

  static NetworkManagerGRPC get shared {
    _instance ??= NetworkManagerGRPC();
    return _instance!;
  }

  bool running = false;
  ChannelCredentials credentials = const ChannelCredentials.insecure();
  ServerCredentials? security;
  ClientChannel? channel;
  Timer? timer;
  HandledServerGRPC? server;
  NetworkServerGRPC? service;
  NetworkClientGRPC? client;

  NetworkManagerGRPC();

  @override
  void onNetworkState(NetworkConnection conn, NetworkState state, {Object? info}) {
    if (isClient) {
      L.i("[GRPC] connection status to $state, info is $info");
    }
  }

  void onErrorHandler(GrpcError error, StackTrace? trace) {
    L.e("[GRPC] server handler error $error\n$trace");
  }

  Future<void> ticker() async {
    try {
      if (isServer) {
        await service!.timeout(keepalive * 2);
      }
      if (isClient) {
        await _keep();
      }
    } catch (e) {
      L.e("[GRPC] ticker proc fail with $e");
    }
  }

  Future<void> _listen() async {
    L.i("[GRPC] start server on $host:$port");
    service = NetworkServerGRPC(callback);
    server = HandledServerGRPC.create(
      services: [service!],
      codecRegistry: CodecRegistry(codecs: const [GzipCodec(), IdentityCodec()]),
      errorHandler: onErrorHandler,
    );
    await server?.serve(address: host, port: port, security: security);
    timer = Timer.periodic(const Duration(seconds: 1), (t) => ticker());
  }

  Future<void> _reconnect() async {
    if (!running) {
      return;
    }
    L.i("[GRPC] start connect to $host:$port");
    channel = ClientChannel(
      host,
      port: port,
      options: ChannelOptions(
        credentials: credentials,
        codecRegistry: CodecRegistry(codecs: const [GzipCodec(), IdentityCodec()]),
        connectTimeout: timeout,
      ),
      channelShutdownHandler: () {
        if (running) {
          _reconnect();
        }
      },
    );
    client = NetworkClientGRPC(channel!, callback);
    client?.session = session;
    client?.startMonitorSync();
  }

  Future<void> _keep() async {
    try {
      await client!.ping(keepalive);
    } catch (e) {
      L.w("[GRPC] ping to $host:$port fail with $e");
      try {
        await client?.stopMonitorSync();
        await channel?.shutdown();
      } catch (_) {}
      try {
        _reconnect();
      } catch (_) {}
    }
  }

  Future<void> start() async {
    running = true;
    if (isServer && server == null) {
      await _listen();
    }
    if (isClient && channel == null) {
      await _reconnect();
    }
  }

  Future<void> stop() async {
    running = false;
    if (isServer && server != null) {
      L.i("[GRPC] server is stopping");
      timer?.cancel();
      await service?.close();
      await server?.shutdown();
      server = null;
    }
    if (isClient && channel != null) {
      L.i("[GRPC] connection is stopping");
      await client?.stopMonitorSync();
      await channel?.shutdown();
      channel = null;
      client = null;
    }
  }

  Future<DateTime> ping(Duration timeout) async {
    return client!.ping(timeout);
  }

  @override
  Future<void> networkSync(NetworkSyncData data) async {
    if (isServer) {
      service?.networkSync(data);
    }
  }

  @override
  Future<NetworkCallResult> networkCall(NetworkCallArg arg) {
    return client!.networkCall(arg);
  }
}
