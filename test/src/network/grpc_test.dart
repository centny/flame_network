import 'dart:async';

import 'package:flame/components.dart';
import 'package:flame_network/src/common/log.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flame_network/flame_network.dart';
import 'package:grpc/grpc.dart';

class TestNetworkCallback with NetworkCallback {
  StreamController<String> connWaiter = StreamController<String>();
  StreamController<String> dataWaiter = StreamController<String>();

  @override
  void onNetworkState(NetworkConnection conn, NetworkState state, {Object? info}) async {
    L.i("[Test] connection to $state,server:${conn.isServer},client:${conn.isClient}");
    if (conn.isServer && state == NetworkState.ready) {
      connWaiter.add("$state");
    }
  }

  @override
  void onNetworkSync(NetworkConnection conn, NetworkSyncData data) {
    L.i("[Test] sync data $data");
    dataWaiter.add(data.uuid);
  }
}

void main() {
  test('NetworkSession', () async {
    var session = NetworkSession.from({});
    session.session = "123";
    session.room = "123";
    assert(session.session == "123");
    assert(session.room == "123");
  });
  test('NetworkManagerGRPC', () async {
    var callback = TestNetworkCallback();
    NetworkManagerGRPC.shared.isServer = true;
    NetworkManagerGRPC.shared.isClient = true;
    NetworkManagerGRPC.shared.callback = callback;
    await NetworkManagerGRPC.shared.start();
    var connected = await callback.connWaiter.stream.first;
    var client = NetworkManagerGRPC.shared.client;
    L.i("conn is $connected");
    var connections = NetworkManagerGRPC.shared.server?.connections ?? [];
    NetworkManagerGRPC.shared.networkSync(NetworkSyncData.create(components: [NetworkSyncComponent(type: "type", uuid: "uuid", removed: false, position: Vector2(1, 2), size: Vector2(10, 10), scale: Vector2(1, 1), angle: 0)]));
    var received = await callback.dataWaiter.stream.first;
    L.i("data is $received");
    await NetworkManagerGRPC.shared.stop();
    await Future.delayed(const Duration(microseconds: 100));

    //test for cover
    for (var c in connections) {
      c.onActiveStateChanged = (v) => L.i("$v");
      try {
        await c.ping();
      } catch (e) {
        L.i("$e");
      }
      await c.finish();
      await c.terminate();
      L.i("${c.onInitialPeerSettingsReceived}");
      L.i("${c.onPingReceived}");
      L.i("${c.onFrameReceived}");
    }
    client?.onConnectionStateChanged(ConnectionState.transientFailure);
  });
}
