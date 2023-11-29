import 'dart:io';
import 'package:flame/game.dart';
import 'package:flame_network/flame_network.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'log.dart';
import 'game.dart';
import 'menu.dart';

String environment(String key) {
  if (kIsWeb) {
    return "";
  }
  var v = String.fromEnvironment(key);
  if (v.isEmpty) {
    v = Platform.environment[key] ?? "";
  }
  return v;
}

void main() async {
  var mode = environment("MODE");
  NetworkManagerGRPC.shared.verbose = environment("VERBOSE") == "1";
  if (mode == "service") {
    var grpcAddr = environment("GRPC_ADDR");
    if (grpcAddr.isEmpty) {
      grpcAddr = "grpc://0.0.0.0:50051";
    }
    var webAddr = environment("WEB_ADDR");
    if (webAddr.isEmpty) {
      webAddr = "ws://0.0.0.0:50052/ws/fire";
    }
    L.i("FireGame is starting by mode:$mode,grpc:$grpcAddr,web:$webAddr");
    NetworkManagerGRPC.shared.grpcAddress = Uri.parse(grpcAddr);
    NetworkManagerGRPC.shared.webAddress = Uri.parse(webAddr);
    NetworkManagerGRPC.shared.webDir = "www";
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
    runApp(
      const AppMenu(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text(
                'Server is running',
              ),
            ],
          ),
        ),
      ),
    );
    return;
  }
  var grpcAddr = environment("GRPC_ADDR");
  if (grpcAddr.isEmpty) {
    grpcAddr = "grpc://127.0.0.1:50051";
  }
  var webAddr = environment("WEB_ADDR");
  if (webAddr.isEmpty) {
    webAddr = "ws://127.0.0.1:50052/ws/fire";
    if (kIsWeb && kReleaseMode) {
      if (Uri.base.scheme == "https") {
        webAddr = "wss://${Uri.base.host}:${Uri.base.port}/ws/fire";
      } else {
        webAddr = "ws://${Uri.base.host}:${Uri.base.port}/ws/fire";
      }
    }
  }
  L.i("FireGame is starting by mode:$mode,grpc:$grpcAddr,web:$webAddr");
  NetworkManagerGRPC.shared.grpcAddress = Uri.parse(grpcAddr);
  NetworkManagerGRPC.shared.webAddress = Uri.parse(webAddr);
  NetworkManagerGRPC.shared.webDir = "www";
  switch (mode) {
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
