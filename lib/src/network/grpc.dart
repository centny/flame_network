import 'dart:async';
import 'dart:io';

import 'package:flame/components.dart';
import 'package:flame_network/flame_network.dart';
import 'package:flame_network/src/common/common.dart';
import 'package:flame_network/src/network/grpc/server.pbgrpc.dart';
import 'package:grpc/grpc.dart';
import 'package:http2/transport.dart';
import 'package:uuid/uuid.dart';

import '../common/log.dart';

RequestID newRequestID() => RequestID(uuid: const Uuid().v1());

extension _NetworkSyncComponent on NetworkSyncComponent {
  SyncComponent wrap() {
    var c = this;
    List<double>? position;
    if (c.position != null) {
      position = [c.position!.x, c.position!.y];
    }
    List<double>? size;
    if (c.size != null) {
      size = [c.size!.x, c.size!.y];
    }
    List<double>? scale;
    if (c.scale != null) {
      scale = [c.scale!.x, c.scale!.y];
    }
    return SyncComponent(
      type: c.type,
      uuid: c.uuid,
      removed: c.removed,
      position: position,
      size: size,
      scale: scale,
      angle: c.angle,
    );
  }
}

extension _SyncComponent on SyncComponent {
  NetworkSyncComponent wrap() {
    var c = this;
    Vector2? position;
    if (c.position.length > 1) {
      position = Vector2(c.position[0], c.position[1]);
    }
    Vector2? size;
    if (c.size.length > 1) {
      size = Vector2(c.size[0], c.size[1]);
    }
    Vector2? scale;
    if (c.scale.length > 1) {
      scale = Vector2(c.scale[0], c.scale[1]);
    }
    return NetworkSyncComponent(
      type: c.type,
      uuid: c.uuid,
      removed: c.removed,
      position: position,
      size: size,
      scale: scale,
      angle: c.angle,
    );
  }
}

extension _SyncData on SyncData {
  NetworkSyncData wrap() {
    return NetworkSyncData(
      uuid: id.uuid,
      components: components.map((e) => e.wrap()).toList(),
    );
  }
}

class _NetworkSyncStream with NetworkConnection {
  StreamController<SyncData> controller = StreamController<SyncData>();

  Stream<SyncData> get stream => controller.stream;

  @override
  bool get isClient => false;

  @override
  bool get isServer => true;

  _NetworkSyncStream({NetworkSession? session, NetworkState? state}) {
    this.session = session;
    this.state = state;
  }

  void add(SyncData data) {
    controller.add(data);
  }

  Future<void> close() async {
    await controller.close();
  }
}

class NetworkServerGRPC extends ServerServiceBase {
  NetworkCallback? callback;
  final List<_NetworkSyncStream> _connAll = List.empty(growable: true);

  NetworkServerGRPC({this.callback});

  void _addStream(_NetworkSyncStream conn) {
    _connAll.add(conn);
    callback?.onNetworkState(conn, NetworkState.ready);
  }

  void _cancleStream(_NetworkSyncStream conn) {
    _connAll.remove(conn);
    callback?.onNetworkState(conn, NetworkState.closed);
  }

  Future<void> close() async {
    for (var conn in _connAll.toList()) {
      await conn.close();
    }
  }

  void networkSync(NetworkSyncData data) {
    var components = data.components.map((e) => e.wrap());
    for (var conn in _connAll) {
      var syncData = SyncData(id: newRequestID(), components: components);
      conn.add(syncData);
    }
  }

  @override
  Stream<SyncData> monitorSync(ServiceCall call, SyncArg request) {
    var syncStream = _NetworkSyncStream(session: NetworkSession.from(call.clientMetadata ?? {}), state: NetworkState.ready);
    syncStream.controller.onCancel = () => _cancleStream(syncStream);
    _addStream(syncStream);
    return syncStream.stream;
  }
}

class NetworkClientGRPC extends ServerClient with NetworkConnection {
  NetworkCallback? callback;
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
        callback?.onNetworkState(this, NetworkState.connecting);
        break;
      case ConnectionState.ready:
        L.i("[GRPC] client connection is ready");
        this.state = NetworkState.ready;
        callback?.onNetworkState(this, NetworkState.ready);
        break;
      case ConnectionState.transientFailure:
        L.i("[GRPC] client connection is reconnecting");
        this.state = NetworkState.connecting;
        callback?.onNetworkState(this, NetworkState.connecting);
        break;
      case ConnectionState.idle:
        break;
      case ConnectionState.shutdown:
        L.i("[GRPC] client connection is closed");
        this.state = NetworkState.closed;
        callback?.onNetworkState(this, NetworkState.closed);
        break;
    }
  }

  void startMonitorSync() async {
    var request = SyncArg(id: newRequestID());
    _syncMonitor = super.monitorSync(request, options: callOptions);
    _syncMonitor?.listen((value) => callback?.onNetworkSync(this, value.wrap())).onError((e) => callback?.onNetworkState(this, NetworkState.error, info: e));
  }

  Future<void> stopMonitorSync() async {
    await _syncMonitor?.cancel();
    _syncMonitor = null;
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

class NetworkManagerGRPC with NetworkTransport {
  static final NetworkManagerGRPC _instance = NetworkManagerGRPC._();

  static NetworkManagerGRPC get shared => _instance;

  ChannelCredentials credentials = const ChannelCredentials.insecure();
  ServerCredentials? security;
  ClientChannel? channel;
  HandledServerGRPC? server;
  NetworkServerGRPC? service;
  NetworkClientGRPC? client;

  NetworkManagerGRPC._();

  Future<void> start() async {
    if (isServer && server == null) {
      L.i("[GRPC] start server on $host:$port");
      service = NetworkServerGRPC(callback: callback);
      server = HandledServerGRPC.create(
        services: [service!],
        codecRegistry: CodecRegistry(codecs: const [GzipCodec(), IdentityCodec()]),
      );
      await server?.serve(address: host, port: port, security: security);
    }
    if (isClient && channel == null) {
      L.i("[GRPC] start connect to $host:$port");
      channel = ClientChannel(
        host,
        port: port,
        options: ChannelOptions(
          credentials: credentials,
          codecRegistry: CodecRegistry(codecs: const [GzipCodec(), IdentityCodec()]),
          connectTimeout: timeout,
        ),
      );
      client = NetworkClientGRPC(channel!, callback);
      client?.session = session;
      client?.startMonitorSync();
    }
  }

  Future<void> stop() async {
    if (isServer && server != null) {
      L.i("[GRPC] server is stopping");
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

  @override
  void networkSync(NetworkSyncData data) {
    service?.networkSync(data);
  }
}
