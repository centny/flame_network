import 'package:flame/game.dart';
import 'package:flame_network/flame_network.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'game.dart';
import 'menu.dart';

void main() {
  switch (const String.fromEnvironment("MODE")) {
    case "server":
      NetworkManagerGRPC.shared.isClient = false;
      NetworkManagerGRPC.shared.isServer = true;
      break;
    case "client":
      NetworkManagerGRPC.shared.isClient = true;
      NetworkManagerGRPC.shared.isServer = false;
      break;
    case "standalone":
      NetworkManagerGRPC.shared.isClient = true;
      NetworkManagerGRPC.shared.isServer = true;
      break;
    default:
      NetworkManagerGRPC.shared.isClient = true;
      NetworkManagerGRPC.shared.isServer = !kIsWeb;
      break;
  }
  if (NetworkManagerGRPC.shared.isClient) {
    NetworkManagerGRPC.shared.session.user = "123";
  }
  // NetworkComponent.registerFactory(
  //   key: "*",
  //   creator: (key, group, id) {
  //     L.i("$group.$key $id");
  //     throw Exception("$group.$key");
  //   },
  // );
  runApp(
    GameWidget<FireGame>.controlled(
      gameFactory: FireGame.new,
      overlayBuilderMap: {
        'LoginMenu': (_, game) => AppMenu(body: LoginMenu(game: game)),
      },
      initialActiveOverlays: const ['LoginMenu'],
    ),
  );
}
