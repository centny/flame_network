import 'dart:io';
import 'package:flame/game.dart';
import 'package:flame_network/flame_network.dart';
import 'package:flutter/material.dart';

import 'log.dart';
import 'game.dart';
import 'menu.dart';

String environment(String key) {
  var v = String.fromEnvironment(key);
  if (v.isEmpty) {
    v = Platform.environment[key] ?? "";
  }
  return v;
}

void main() async {
  var mode = environment("MODE");
  if (mode == "server") {
    var grpcAddr = environment("GRPC_ADDR");
    if (grpcAddr.isEmpty) {
      grpcAddr = "grpc://0.0.0.0:50051";
    }
    var webAddr = environment("WEB_ADDR");
    if (webAddr.isEmpty) {
      webAddr = "ws://0.0.0.0:50052";
    }
    L.i("server is starting by grpc:$grpcAddr,web:$webAddr");
    NetworkManagerGRPC.shared.grpcAddress = Uri.parse(grpcAddr);
    NetworkManagerGRPC.shared.webAddress = Uri.parse(webAddr);
    NetworkManagerGRPC.shared.isClient = false;
    NetworkManagerGRPC.shared.isServer = true;
    WidgetsFlutterBinding.ensureInitialized();
    FlameGame game = FireGame();
    game.onGameResize(Vector2(1280, 720));
    await game.onLoad();
    // ignore: invalid_use_of_internal_member
    game.mount();
    game.resumeEngine();
    var loop = GameLoop(game.update);
    loop.start();
    await NetworkManagerGRPC.shared.start();
    await ProcessSignal.sigint.watch().first;
    loop.stop();
    await NetworkManagerGRPC.shared.stop();
    return;
  }
  switch (mode) {
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
      NetworkManagerGRPC.shared.isServer = false;
      break;
  }
  runApp(
    GameWidget<FireGame>.controlled(
      gameFactory: () => FireGame(),
      overlayBuilderMap: {
        'LoginMenu': (_, game) => AppMenu(body: LoginMenu(game: game)),
      },
      initialActiveOverlays: const ['LoginMenu'],
    ),
  );
}
