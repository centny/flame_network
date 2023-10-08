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
    );
  }
}

extension on SyncData {
  NetworkSyncData wrap() {
    return NetworkSyncData(
      uuid: id.uuid,
      group: group,
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

  void _networkState(NetworkServerConnGRPC conn, NetworkState state, {Object? info}) {
    callback.onNetworkState(_sessionConnAll(conn.session?.session ?? ""), conn, state, info: info);
  }

  void _addStream(_NetworkSyncStream conn) {
    _sessionConnAll(conn.session?.session ?? "").add(conn);
    _sessionConnGroup(conn.session?.group ?? "").add(conn);
    _sessionConnGroup("*").add(conn);
    _networkState(conn, NetworkState.ready);
  }

  void _cancleStream(_NetworkSyncStream conn) {
    _sessionConnAll(conn.session?.session ?? "").remove(conn);
    _sessionConnGroup(conn.session?.group ?? "").remove(conn);
    _sessionConnGroup("*").remove(conn);
    _networkState(conn, NetworkState.closed);
  }

  Future<void> close() async {
    for (var conn in _sessionConnGroup("*").toSet()) {
      await conn.close();
    }
  }

  void networkSync(NetworkSyncData data) {
    var components = data.components.map((e) => e.wrap());
    for (var conn in _sessionConnGroup(data.group)) {
      var syncData = SyncData(id: newRequestID(), group: data.group, components: components);
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

  // @override
  // Stream<SyncData> remoteSync(ServiceCall call, SyncArg request) async* {
  //   while (true) {
  //     await Future.delayed(const Duration(milliseconds: 100));
  //     yield SyncData();
  //   }
  // }

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

  NetworkClientGRPC(ClientChannelBase channel, this.callback) : super(channel) {
    channel.onConnectionStateChanged.listen(onConnectionStateChanged);
  }

  void onConnectionStateChanged(ConnectionState state) {
    switch (state) {
      case ConnectionState.connecting:
        L.i("[GRPC] client connection is connecting");
        this.state = NetworkState.connecting;
        callback.onNetworkState(HashSet.from([this]), this, NetworkState.connecting);
        break;
      case ConnectionState.ready:
        L.i("[GRPC] client connection is ready");
        this.state = NetworkState.ready;
        callback.onNetworkState(HashSet.from([this]), this, NetworkState.ready);
        break;
      case ConnectionState.transientFailure:
        L.i("[GRPC] client connection is reconnecting");
        this.state = NetworkState.connecting;
        callback.onNetworkState(HashSet.from([this]), this, NetworkState.connecting);
        break;
      case ConnectionState.idle:
        break;
      case ConnectionState.shutdown:
        L.i("[GRPC] client connection is closed");
        this.state = NetworkState.closed;
        callback.onNetworkState(HashSet.from([this]), this, NetworkState.closed);
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
    _syncMonitor?.listen(
      (data) => onNetworkSync(this, data.wrap()),
      onError: (e) => callback.onNetworkState(HashSet.from([this]), this, NetworkState.error, info: e),
      cancelOnError: true,
    );
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

class HandledWrapperStreamSink implements StreamSink<List<int>> {
  StreamSink<dynamic> base;

  HandledWrapperStreamSink(this.base);

  @override
  void add(List<int> event) => base.add(String.fromCharCodes(event));

  @override
  void addError(Object error, [StackTrace? stackTrace]) => base.addError(error, stackTrace);

  @override
  Future addStream(Stream<List<int>> stream) => base.addStream(stream.map((event) => String.fromCharCodes(event)));

  @override
  Future close() => base.close();

  @override
  Future get done => base.done;
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
      var socket = await WebSocketTransformer.upgrade(
        request,
        protocolSelector: (protocols) => "grpc",
      );
      var stream = socket.map((event) => asListInt(event));
      var sink = HandledWrapperStreamSink(socket);
      final connection = ServerTransportConnection.viaStreams(stream, sink, settings: http2ServerSettings);
      await serveConnection(
        connection: connection,
        clientCertificate: request.certificate,
        remoteAddress: request.connectionInfo?.remoteAddress,
      );
    }, onError: (error, stackTrace) {
      if (error is Error) {
        Zone.current.handleUncaughtError(error, stackTrace);
      }
    }, cancelOnError: true);
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

  WebSocketChannelConnector(this.address, {this.settings}) {
    channel = WebSocketChannel.connect(address, protocols: ["grpc"]);
  }

  @override
  String get authority => "";

  @override
  Future<ClientTransportConnection> connect() async {
    var stream = channel.stream.map((event) => asListInt(event));
    var sink = HandledWrapperStreamSink(channel.sink);
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
    timer = Timer.periodic(const Duration(seconds: 1), (t) => ticker());
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
    client?.session = session;
    client?.startMonitorSync();
  }

  Future<void> _keep() async {
    try {
      await client!.ping(keepalive);
    } catch (e) {
      L.w("[GRPC] ping to $channel fail with $e");
      try {
        await client?.stopMonitorSync();
        await channel?.shutdown();
      } catch (_) {}
      try {
        reconnect();
      } catch (_) {}
    }
  }

  Future<void> start() async {
    L.i("[GRPC] network start by server:$isServer,client:$isClient");
    running = true;
    if (isServer && server == null) {
      await _listen();
    }
    if (isClient && channel == null) {
      await reconnect();
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
