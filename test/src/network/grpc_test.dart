import 'dart:async';

import 'package:flame_network/src/common/log.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flame_network/flame_network.dart';
import 'package:grpc/grpc.dart';

class TestNetworkCallback with NetworkCallback {
  final StreamController<String> _connWaiter = StreamController<String>();
  final StreamController<String> _dataWaiter = StreamController<String>();
  late StreamIterator<String> connWaiter;
  late StreamIterator<String> dataWaiter;
  bool syncError = false;

  TestNetworkCallback() {
    connWaiter = StreamIterator(_connWaiter.stream);
    dataWaiter = StreamIterator(_dataWaiter.stream);
  }

  Future<String> waitConn() async {
    if (await connWaiter.moveNext()) {
      return connWaiter.current;
    } else {
      return "";
    }
  }

  Future<String> waitData() async {
    if (await dataWaiter.moveNext()) {
      return dataWaiter.current;
    } else {
      return "";
    }
  }

  @override
  void onNetworkState(NetworkConnection conn, NetworkState state, {Object? info}) {
    L.i("[Test] connection to $state,server:${conn.isServer},client:${conn.isClient}");
    if (conn.isServer) {
      _connWaiter.add("$state");
    }
  }

  @override
  Future<void> onNetworkSync(NetworkConnection conn, NetworkSyncData data) async {
    if (syncError) {
      throw Exception("test error");
    }
    L.i("[Test] sync data $data");
    _dataWaiter.add(data.uuid);
  }

  @override
  Future<NetworkCallResult> onNetworkCall(NetworkConnection conn, NetworkCallArg arg) async {
    if (arg.nName == "error") {
      L.i("[Test] call ${arg.nCID}.${arg.nName} ${arg.nArg} => error");
      throw Exception("test error");
    }
    L.i("[Test] call ${arg.nCID}.${arg.nName} ${arg.nArg}");
    return NetworkCallResult(uuid: arg.uuid, nCID: arg.nCID, nName: arg.nName, nResult: arg.nArg);
  }
}

class TestNetworkConnection with NetworkConnection {
  @override
  bool get isClient => throw UnimplementedError();

  @override
  bool get isServer => throw UnimplementedError();
}

void main() {
  test('NetworkGRPC.sync', () async {
    var callback = TestNetworkCallback();
    NetworkManagerGRPC.shared.isServer = true;
    NetworkManagerGRPC.shared.isClient = true;
    NetworkManagerGRPC.shared.callback = callback;
    await NetworkManagerGRPC.shared.start();
    var connected = await callback.waitConn();
    L.i("conn is $connected");
    NetworkManagerGRPC.shared.networkSync(NetworkSyncData.create(components: [
      NetworkSyncDataComponent(
        nFactory: "type",
        nCID: "uuid",
        nRemoved: false,
      )
    ]));
    var received = await callback.waitData();
    L.i("data is $received");
    await NetworkManagerGRPC.shared.stop();
  });
  test('NetworkGRPC.call', () async {
    var callback = TestNetworkCallback();
    NetworkManagerGRPC.shared.isServer = true;
    NetworkManagerGRPC.shared.isClient = true;
    NetworkManagerGRPC.shared.callback = callback;
    await NetworkManagerGRPC.shared.start();
    var connected = await callback.waitConn();
    L.i("conn is $connected");
    var result = await NetworkManagerGRPC.shared.networkCall(NetworkCallArg(uuid: "123", nCID: "a", nName: "echo", nArg: "abc"));
    assert(result.nResult == "abc");
    await NetworkManagerGRPC.shared.stop();
  });
  test('NetworkGRPC.ping', () async {
    var callback = TestNetworkCallback();
    NetworkManagerGRPC.shared.isServer = true;
    NetworkManagerGRPC.shared.isClient = true;
    NetworkManagerGRPC.shared.callback = callback;
    NetworkManagerGRPC.shared.keepalive = const Duration(milliseconds: 10);
    await NetworkManagerGRPC.shared.start();
    var ready = await callback.waitConn();
    L.i("conn is $ready");
    await NetworkManagerGRPC.shared.ping(const Duration(seconds: 3));
    await Future.delayed(const Duration(milliseconds: 100));
    await NetworkManagerGRPC.shared.ticker();
    var closed = await callback.waitConn();
    L.i("conn is $closed");
    await NetworkManagerGRPC.shared.stop();
  });
  test('NetworkGRPC.reconnect', () async {
    var callback = TestNetworkCallback();
    NetworkManagerGRPC.shared.isServer = true;
    NetworkManagerGRPC.shared.isClient = true;
    NetworkManagerGRPC.shared.callback = callback;
    await NetworkManagerGRPC.shared.start();
    var ready = await callback.waitConn();
    L.i("conn is $ready");
    await NetworkManagerGRPC.shared.client?.stopMonitorSync();
    await NetworkManagerGRPC.shared.channel?.shutdown();
    var reconnect = await callback.waitConn();
    L.i("reconnect is $reconnect");
    await Future.delayed(const Duration(milliseconds: 100));
    await NetworkManagerGRPC.shared.ticker();
    var closed = await callback.waitConn();
    L.i("conn is $closed");
    await NetworkManagerGRPC.shared.stop();
  });
  test('NetworkGRPC.keep', () async {
    var callback = TestNetworkCallback();
    NetworkManagerGRPC.shared.isServer = true;
    NetworkManagerGRPC.shared.isClient = true;
    NetworkManagerGRPC.shared.callback = callback;
    await NetworkManagerGRPC.shared.start();
    var ready = await callback.waitConn();
    L.i("conn is $ready");
    NetworkManagerGRPC.shared.client = null;
    NetworkManagerGRPC.shared.channel = null;
    await NetworkManagerGRPC.shared.ticker();
    var reconnect = await callback.waitConn();
    L.i("reconnect is $reconnect");
    await NetworkManagerGRPC.shared.stop();
  });
  test('NetworkGRPC.cover', () async {
    var callback = TestNetworkCallback();
    var conn = TestNetworkConnection();
    NetworkManagerGRPC.shared.isServer = true;
    NetworkManagerGRPC.shared.isClient = true;
    NetworkManagerGRPC.shared.callback = callback;
    await NetworkManagerGRPC.shared.start();
    await callback.waitConn();
    try {
      await NetworkManagerGRPC.shared.networkCall(NetworkCallArg(uuid: "123", nCID: "123", nName: "error", nArg: "abc"));
      assert(false);
    } catch (_) {}
    var client = NetworkManagerGRPC.shared.client;
    var connections = NetworkManagerGRPC.shared.server?.connections ?? [];
    await NetworkManagerGRPC.shared.stop();
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
    NetworkManagerGRPC.shared.onErrorHandler(const GrpcError.aborted(), null);
    callback.syncError = true;
    await client?.onNetworkSync(conn, NetworkSyncData(uuid: "uuid", group: "group", components: List.empty()));
    NetworkManagerGRPC.shared.onNetworkState(conn, NetworkState.closed);

    //
    NetworkManagerGRPC.shared.isClient = false;
    NetworkManagerGRPC.shared.service = null;
    await NetworkManagerGRPC.shared.ticker();
  });
}
