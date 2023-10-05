import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:uuid/uuid.dart';

class NetworkPool {}

class NetworkSession {
  Map<String, String> value;

  String get session => value["session"] ?? "";
  set session(String v) => value["session"] = v;

  String get room => value["room"] ?? "";
  set room(String v) => value["room"] = v;

  NetworkSession(this.value);

  factory NetworkSession.create() => NetworkSession({});

  factory NetworkSession.from(Map<String, String> value) => NetworkSession(value);
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
  void onNetworkState(NetworkConnection conn, NetworkState state, {Object? info});
  void onNetworkSync(NetworkConnection conn, NetworkSyncData data);
}

mixin NetworkTransport {
  NetworkSession session = NetworkSession.create();
  Duration timeout = const Duration(seconds: 10);
  NetworkCallback? callback;
  bool isServer = false;
  bool isClient = false;
  String host = "127.0.0.1";
  int port = 50051;
  void networkSync(NetworkSyncData data);
}

class NetworkSyncComponent {
  String type;
  String uuid;
  bool? removed;
  Vector2? position;
  Vector2? size;
  Vector2? scale;
  double? angle;

  NetworkSyncComponent({required this.type, required this.uuid, this.removed, this.position, this.size, this.scale, this.angle});
}

class NetworkSyncData {
  String uuid;

  List<NetworkSyncComponent> components;

  NetworkSyncData({required this.uuid, required this.components});

  factory NetworkSyncData.create({List<NetworkSyncComponent>? components}) => NetworkSyncData(uuid: const Uuid().v1(), components: components ?? List.empty(growable: true));
}
