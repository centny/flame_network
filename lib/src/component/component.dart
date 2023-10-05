import 'dart:async';

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';

import '../common/log.dart';
import '../network/network.dart';

typedef NetworkComponentFactory<T extends NetworkComponent> = T Function(String type, String key);

mixin NetworkGame on FlameGame implements NetworkCallback {
  bool isServer = false;

  bool isClient = false;

  final Map<String, NetworkComponentFactory> _factories = {};

  final Map<String, NetworkComponent> _compenents = {};

  NetworkTransport? transport;

  FlameGame? _game;

  void register(String type, NetworkComponentFactory factory) {
    _factories[type] = factory;
  }

  void _syncNetworkComponent(NetworkSyncComponent c) {
    var component = _game!.findByKeyName(c.uuid) as NetworkComponent?;
    if (component == null) {
      var creator = _factories[c.type];
      if (creator == null) {
        L.w("component factory is not exists by ${c.type}");
        return;
      }
      component = creator(c.type, c.uuid);
      _compenents[component.uuid] = component;
      _game!.world.add(component);
    }
    component._syncRecv(c);
  }

  void _sendNetworkComponent() {
    var data = NetworkSyncData.create();
    _compenents.forEach((key, value) {
      var c = value._syncSend();
      if (c == null) {
        return;
      }
      if (c.removed ?? false) {
        _compenents.remove(c.uuid);
      }
      data.components.add(c);
    });
    transport?.networkSync(data);
  }

  @override
  FutureOr<void> onLoad() async {
    await super.onLoad();
    _game = super.findGame();
  }

  @override
  @mustCallSuper
  void update(double dt) {
    super.update(dt);
    if (isServer) {
      _sendNetworkComponent();
    }
  }

  @override
  void onNetworkSync(NetworkConnection conn, NetworkSyncData data) {
    if (isClient) {
      for (var e in data.components) {
        _syncNetworkComponent(e);
      }
    }
  }
}

mixin NetworkComponent on Component {
  String get type;
  String get uuid;
  bool isOwner = false;

  bool isServer = false;

  bool isClient = false;

  NetworkSyncComponent? _prev;

  void _syncRecv(NetworkSyncComponent c) {
    if (!isClient) {
      return;
    }
    if (this is PositionComponent) {
      var t = this as PositionComponent;
      t.position = c.position ?? t.position;
      t.size = c.size ?? t.size;
      t.scale = c.scale ?? t.scale;
      t.angle = c.angle ?? t.angle;
    }
  }

  NetworkSyncComponent? _syncSend() {
    if (!isServer) {
      return null;
    }
    if (this is PositionComponent) {
      var t = this as PositionComponent;
      if (isRemoved) {
        return NetworkSyncComponent(type: type, uuid: uuid, removed: true);
      }
      if (isLoaded) {
        if (_prev?.position == t.position && _prev?.size == t.size && _prev?.scale == t.scale && _prev?.angle == t.angle) {
          return null;
        }
        return NetworkSyncComponent(type: type, uuid: uuid, position: t.position, size: t.size, scale: t.scale, angle: t.angle);
      }
    }
    return null;
  }
}
