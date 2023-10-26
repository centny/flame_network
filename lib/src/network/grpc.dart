import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:fixnum/fixnum.dart';
import 'package:flame_network/flame_network.dart';
import 'package:flame_network/src/common/common.dart';
import 'package:flame_network/src/network/grpc/server.pbgrpc.dart';
import 'package:flutter/foundation.dart';
import 'package:grpc/grpc.dart';
import 'package:grpc/grpc_connection_interface.dart';
import 'package:http2/transport.dart';
import 'package:uuid/uuid.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../common/log.dart';

RequestID newRequestID() => RequestID(uuid: const Uuid().v1());

extension on NetworkSyncDataComponent {
  SyncDataComponent wrap() {
    return SyncDataComponent(
      factoryType: nFactory,
      cid: nCID,
      owner: nOwner,
      removed: nRemoved,
      props: jsonEncode(nProps),
      triggers: jsonEncode(nTriggers),
    );
  }
}

extension on SyncDataComponent {
  NetworkSyncDataComponent wrap() {
    return NetworkSyncDataComponent(
      nFactory: factoryType,
      nCID: cid,
      nOwner: owner,
      nRemoved: removed,
      nProps: jsonDecode(props),
      nTriggers: (jsonDecode(triggers) as Map<String, dynamic>).map((key, value) => MapEntry(key, value as List<dynamic>)),
    );
  }
}

extension on SyncData {
  NetworkSyncData wrap() {
    return NetworkSyncData(
      uuid: id.uuid,
      group: group,
      whole: whole,
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

class NetworkServerConnGRPC with NetworkConnection, NetworkSession {
  NetworkState mState = NetworkState.none;
  Map<String, String> mContext = {};
  Map<String, String> mMeta = {};

  @override
  Map<String, String> get context => mContext;

  @override
  Map<String, String> get meta => mMeta;

  @override
  NetworkSession get session => this;

  @override
  NetworkState get state => mState;

  @override
  bool get isClient => false;

  @override
  bool get isServer => true;

  NetworkServerConnGRPC({NetworkState? state, Map<String, String>? context, Map<String, String>? meta})
      : mState = state ?? NetworkState.none,
        mContext = context ?? {},
        mMeta = meta ?? {};
}

class _NetworkSyncStream extends NetworkServerConnGRPC {
  StreamController<SyncData> controller = StreamController<SyncData>();

  Stream<SyncData> get stream => controller.stream;

  _NetworkSyncStream({super.state, super.context, super.meta});

  void add(SyncData data) {
    controller.sink.add(data);
  }

  @override
  Future<void> close() async {
    mState = NetworkState.closed;
    await super.close();
    await controller.sink.close();
  }

  @override
  Future<void> networkSync(NetworkSyncData data) async {
    List<SyncDataComponent> components = [];
    for (var e in data.components) {
      var c = e.encode(this);
      if (c.nRemoved ?? false || (c.nProps?.isNotEmpty ?? false) || (c.nTriggers?.isNotEmpty ?? false)) {
        components.add(c.wrap());
      }
    }
    if (components.isNotEmpty) {
      var syncData = SyncData(id: newRequestID(), group: data.group, whole: data.whole, components: components);
      controller.sink.add(syncData);
    }
  }
}

class NetworkServerGRPC extends ServerServiceBase {
  final NetworkCallback callback;
  final Map<String, HashSet<_NetworkSyncStream>> _connAll = {};
  final Map<String, HashSet<_NetworkSyncStream>> _connGroup = {};
  final Map<String, NetworkConnection> _sessionAll = {};

  NetworkServerGRPC(this.callback);

  NetworkConnection _keepSession(NetworkSession session) {
    var having = _sessionAll[session.key];
    if (having == null) {
      having = NetworkServerConnGRPC(state: NetworkState.ready, meta: session.meta);
      _sessionAll[session.key] = having;
    }
    having.session.last = DateTime.now();
    return having;
  }

  NetworkConnection _keepSessionByMeta(Map<String, String>? meta) {
    return _keepSession(DefaultNetworkSession.meta(meta ?? {}));
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

  void _networkState(NetworkServerConnGRPC conn, NetworkState state, {Object? info}) {
    callback.onNetworkState(_sessionConnAll(conn.session.key), conn, state, info: info);
  }

  void _addStream(_NetworkSyncStream conn) {
    _networkState(conn, NetworkState.ready);
    if (conn.state == NetworkState.ready) {
      _sessionConnAll(conn.session.key).add(conn);
      _sessionConnGroup(conn.session.group ?? "").add(conn);
      _sessionConnGroup("*").add(conn);
      L.d("[GRPC] add one network sync stream on ${conn.session.group}/${conn.session.user}/${conn.session.key}");
    } else {
      L.d("[GRPC] remove one network sync stream on ${conn.session.group}/${conn.session.user}/${conn.session.key}");
    }
  }

  void _cancleStream(_NetworkSyncStream conn) {
    _sessionConnAll(conn.session.key).remove(conn);
    _sessionConnGroup(conn.session.group ?? "").remove(conn);
    _sessionConnGroup("*").remove(conn);
    L.d("[GRPC] remove network sync stream on ${conn.session.group}/${conn.session.user}/${conn.session.key}");
    _networkState(conn, NetworkState.closed);
  }

  Future<void> close() async {
    for (var conn in _sessionConnGroup("*").toSet()) {
      await conn.close();
    }
  }

  void networkSync(NetworkSyncData data) {
    for (var conn in _sessionConnGroup(data.group)) {
      List<SyncDataComponent> components = [];
      for (var e in data.components) {
        var c = e.encode(conn);
        if (c.nRemoved ?? false || (c.nProps?.isNotEmpty ?? false) || (c.nTriggers?.isNotEmpty ?? false)) {
          components.add(c.wrap());
        }
      }
      if (components.isEmpty) {
        continue;
      }
      var syncData = SyncData(id: newRequestID(), group: conn.session.group ?? data.group, whole: data.whole, components: components);
      conn.add(syncData);
    }
  }

  Future<void> timeout(Duration max) async {
    List<String> keys = [];
    var now = DateTime.now();
    _sessionAll.forEach((k, v) {
      if (now.difference(v.session.last) >= max * 2) {
        keys.add(k);
      }
    });
    for (var key in keys) {
      L.i("[GRPC] remove timeout session $key");
      _sessionAll.remove(key);
      for (var conn in _sessionConnAll(key).toSet()) {
        await conn.close();
      }
    }
  }

  @override
  Future<PingResult> remotePing(ServiceCall call, PingArg request) async {
    _keepSessionByMeta(call.clientMetadata);
    return PingResult(id: request.id, serverTime: Int64(DateTime.now().millisecondsSinceEpoch));
  }

  @override
  Stream<SyncData> remoteSync(ServiceCall call, SyncArg request) {
    var conn = _keepSessionByMeta(call.clientMetadata);
    var syncStream = _NetworkSyncStream(state: NetworkState.ready, context: conn.session.context, meta: conn.session.meta);
    syncStream.controller.onCancel = () => _cancleStream(syncStream);
    _addStream(syncStream);
    return syncStream.stream;
  }

  @override
  Future<CallResult> remoteCall(ServiceCall call, CallArg request) async {
    var conn = _keepSessionByMeta(call.clientMetadata);
    var arg = request.wrap();
    try {
      var result = await callback.onNetworkCall(conn, arg);
      return result.wrap();
    } catch (e, s) {
      if (e is! NetworkException) {
        L.w("[GRPC] network call by $arg throw error $e\n$s");
      }
      return CallResult(id: request.id, cid: request.cid, name: request.name, error: "$e");
    }
  }
}

class NetworkClientGRPC extends ServerClient with NetworkConnection {
  ClientChannelBase mChannel;
  NetworkCallback mCallback;
  Duration mTimeout = const Duration(seconds: 10);
  ResponseStream<SyncData>? mMonitor;
  NetworkState mState = NetworkState.none;

  CallOptions get callOptions => CallOptions(metadata: session.meta, timeout: mTimeout);

  @override
  NetworkSession get session => NetworkManager.global.session;

  @override
  NetworkState get state => mState;

  @override
  bool get isClient => true;

  @override
  bool get isServer => false;

  NetworkClientGRPC(this.mChannel, this.mCallback) : super(mChannel) {
    mChannel.onConnectionStateChanged.listen(onConnectionStateChanged);
  }

  void onConnectionStateChanged(ConnectionState state) {
    switch (state) {
      case ConnectionState.connecting:
        L.i("[GRPC] client connection is connecting");
        mState = NetworkState.connecting;
        mCallback.onNetworkState(HashSet.from([this]), this, NetworkState.connecting);
        break;
      case ConnectionState.ready:
        L.i("[GRPC] client connection is ready");
        mState = NetworkState.ready;
        mCallback.onNetworkState(HashSet.from([this]), this, NetworkState.ready);
        break;
      case ConnectionState.transientFailure:
        L.i("[GRPC] client connection is reconnecting");
        mState = NetworkState.connecting;
        mCallback.onNetworkState(HashSet.from([this]), this, NetworkState.connecting);
        break;
      case ConnectionState.idle:
        break;
      case ConnectionState.shutdown:
        L.i("[GRPC] client connection is closed");
        mState = NetworkState.closed;
        mCallback.onNetworkState(HashSet.from([this]), this, NetworkState.closed);
        break;
    }
  }

  Future<DateTime> ping(Duration timeout) async {
    var result = await super.remotePing(PingArg(id: newRequestID()), options: CallOptions(metadata: session.meta, timeout: timeout));
    return DateTime.fromMillisecondsSinceEpoch(result.serverTime.toInt());
  }

  Future<void> onNetworkSync(NetworkConnection conn, NetworkSyncData data) async {
    try {
      await mCallback.onNetworkSync(conn, data);
    } catch (e, s) {
      L.e("[GRPC] network sync throw error $e\n$s");
    }
  }

  void startMonitorSync() async {
    var request = SyncArg(id: newRequestID());
    mMonitor = super.remoteSync(request, options: CallOptions(metadata: session.meta));
    mMonitor?.listen(
      (data) => onNetworkSync(this, data.wrap()),
      onError: (e) => mCallback.onNetworkState(HashSet.from([this]), this, NetworkState.error, info: e),
      cancelOnError: true,
    );
  }

  Future<void> stopMonitorSync() async {
    await mMonitor?.cancel();
    mMonitor = null;
  }

  Future<NetworkCallResult> networkCall(NetworkCallArg arg) async {
    var result = await super.remoteCall(arg.wrap(), options: callOptions);
    if (result.error.isNotEmpty) {
      throw Exception(result.error);
    }
    return result.wrap();
  }

  Future<void> shutdown() => mChannel.shutdown();
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

class CastStreamSinkGRPC implements StreamSink<List<int>> {
  StreamSink<dynamic> base;

  CastStreamSinkGRPC(this.base);

  @override
  void add(List<int> event) => base.add(event);

  @override
  void addError(Object error, [StackTrace? stackTrace]) => base.addError(error, stackTrace);

  @override
  Future addStream(Stream<List<int>> stream) async {
    var c = Completer();
    stream.listen(add, onDone: () => c.complete(), onError: (e) => c.complete());
    return c.future;
  }

  @override
  Future close() => base.close();

  @override
  Future get done => base.done;
}

List<int> caseStreamEventGRPC(dynamic v) {
  if (v is List<int>) {
    return v;
  }
  if (v is String) {
    List<int> all = [];
    for (var s in v.split(",")) {
      all.add(int.parse(s));
    }
    return all;
  }
  throw Exception("not supported type ${v.runtimeType}");
}

class HandledServerGRPC extends Server {
  final _connections = <ServerTransportConnection>[];
  HttpServer? _webServer;

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

  Future<void> web({
    dynamic address,
    int? port,
    ServerCredentials? security,
    ServerSettings? http2ServerSettings,
  }) async {
    final securityContext = security?.securityContext;
    if (securityContext != null) {
      _webServer = await HttpServer.bindSecure(address, port ?? 443, securityContext);
    } else {
      _webServer = await HttpServer.bind(address, port ?? 80);
    }
    _webServer!.listen((request) async {
      L.i("[WEB] receive request ${request.uri} from ${request.connectionInfo?.remoteAddress.address}:${request.connectionInfo?.remotePort}");
      request.response.headers.contentType = ContentType.binary;
      var socket = await WebSocketTransformer.upgrade(request);
      var stream = socket.map(caseStreamEventGRPC);
      var sink = CastStreamSinkGRPC(socket);
      final connection = ServerTransportConnection.viaStreams(stream, sink, settings: http2ServerSettings);
      await serveConnection(
        connection: connection,
        clientCertificate: request.certificate,
        remoteAddress: request.connectionInfo?.remoteAddress,
      );
    });
  }

  @override
  Future<void> shutdown() async {
    for (var conn in _connections.toList()) {
      await conn.terminate();
    }
    await super.shutdown();
    await _webServer?.close(force: true);
  }
}

class WebSocketChannelConnector extends ClientTransportConnector {
  Uri address;
  ClientSettings? settings;
  late WebSocketChannel channel;

  WebSocketChannelConnector(this.address, {this.settings}) {}

  @override
  String get authority => "";

  @override
  Future<ClientTransportConnection> connect() async {
    channel = WebSocketChannel.connect(address);
    var stream = channel.stream.map(caseStreamEventGRPC);
    var sink = CastStreamSinkGRPC(channel.sink);
    return ClientTransportConnection.viaStreams(stream, sink, settings: settings);
  }

  @override
  Future get done => channel.sink.done;

  @override
  void shutdown() => channel.sink.close();
}

class NetworkManagerGRPC extends NetworkManager {
  static NetworkManagerGRPC? _instance;

  static NetworkManagerGRPC get shared {
    _instance ??= NetworkManagerGRPC();
    return _instance!;
  }

  bool running = false;
  //
  bool grpcOn = !kIsWeb;
  bool webOn = true;
  Uri grpcAddress = Uri(scheme: "grpc", host: "127.0.0.1", port: 50051);
  Uri webAddress = Uri(scheme: "ws", host: "127.0.0.1", port: 50052);
  ServerCredentials? security;
  //
  ChannelCredentials credentials = const ChannelCredentials.insecure();
  ClientChannelBase? channel;
  Timer? timer;
  HandledServerGRPC? server;
  NetworkServerGRPC? service;
  NetworkClientGRPC? client;
  bool _keeping = false;

  //
  DateTime _pingShow = DateTime.fromMillisecondsSinceEpoch(0);
  int _pingCount = 0;
  Duration _pingSpeed = const Duration();
  @override
  Duration get pingSpeed => _pingSpeed;

  NetworkManagerGRPC();

  @override
  Future<void> onNetworkState(Set<NetworkConnection> all, NetworkConnection conn, NetworkState state, {Object? info}) async {
    super.onNetworkState(all, conn, state);
    if (isClient) {
      L.i("[GRPC] connection status to $state, info is $info");
    }
  }

  void onErrorHandler(GrpcError error, StackTrace? trace) {
    L.e("[GRPC] server handler error $error\n$trace");
  }

  Future<void> _listen() async {
    service = NetworkServerGRPC(callback);
    server = HandledServerGRPC.create(
      services: [service!],
      errorHandler: onErrorHandler,
    );
    if (grpcOn) {
      L.i("[GRPC] start grpc server on $grpcAddress");
      await server?.serve(address: grpcAddress.host, port: grpcAddress.port, security: security);
    }
    if (webOn) {
      L.i("[GRPC] start web server on $webAddress");
      await server?.web(address: webAddress.host, port: webAddress.port, security: security);
    }
  }

  Future<void> reconnect() async {
    if (!running) {
      return;
    }
    if (grpcOn) {
      L.i("[GRPC] start connect to $grpcAddress");
      channel = ClientChannel(
        grpcAddress.host,
        port: grpcAddress.port,
        options: ChannelOptions(credentials: credentials, connectTimeout: timeout),
      );
    } else if (webOn) {
      var connector = WebSocketChannelConnector(webAddress, settings: const ClientSettings(allowServerPushes: true));
      channel = ClientTransportConnectorChannel(connector);
    } else {
      L.e("grpc/web at least one must be configured");
      throw Exception("not configured");
    }
    client = NetworkClientGRPC(channel!, callback);
    if (isReady) {
      client?.startMonitorSync();
    }
  }

  Future<void> _ticker() async {
    timer = Timer.periodic(const Duration(seconds: 3), (t) => onTicker());
  }

  Future<void> onTicker() async {
    try {
      if (isServer) {
        await service!.timeout(keepalive * 2);
      }
      if (isClient) {
        await keep();
      }
    } catch (e) {
      L.e("[GRPC] ticker proc throw error with $e");
    }
  }

  Future<void> keep() async {
    if (_keeping) {
      return;
    }
    _keeping = true;
    var pingOld = _pingSpeed;
    try {
      DateTime startTime = DateTime.now();
      await client!.ping(keepalive);
      _pingSpeed = DateTime.now().difference(startTime);
      _pingCount++;

      //
      if (DateTime.now().difference(_pingShow) > const Duration(seconds: 60)) {
        L.i("[GRPC] ping to server $_pingCount count success, last spedd $_pingSpeed");
        _pingCount = 0;
        _pingShow = DateTime.now();
      }

      //
      if (_pingSpeed != pingOld) {
        onNetworkPing(client!, _pingSpeed);
      }
    } catch (e) {
      _pingSpeed = const Duration(milliseconds: -1);
      if (_pingSpeed != pingOld) {
        onNetworkPing(client!, _pingSpeed);
      }

      L.w("[GRPC] ping to $channel throw error with $e");
      try {
        await client?.stopMonitorSync();
        await channel?.shutdown();
      } catch (_) {}
      try {
        await reconnect();
      } catch (_) {}
    }
    _keeping = false;
  }

  Future<void> start() async {
    if (running) {
      return;
    }
    L.i("[GRPC] network start by server:$isServer,client:$isClient");
    running = true;
    if (isServer && server == null) {
      await _listen();
    }
    if (isClient && channel == null) {
      await reconnect();
    }
    await _ticker();
    if (isServer && !isClient) {
      await ready();
    }
  }

  Future<void> stop() async {
    running = false;
    isReady = false;
    timer?.cancel();
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
      await client?.shutdown();
      channel = null;
      client = null;
    }
  }

  @override
  Future<void> ready() async {
    isReady = true;
    if (isClient) {
      client?.startMonitorSync();
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
