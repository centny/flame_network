import 'dart:async';
import 'dart:math' as math;

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flame/extensions.dart';
import 'package:flame/input.dart';
import 'package:flame/palette.dart';
import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:flame_network/flame_network.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

import 'log.dart';

void main() {
  maxTranslation = 50;
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
      NetworkManagerGRPC.shared.isClient = kIsWeb;
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
  runApp(const GameWidget.controlled(gameFactory: FireGame.new));
}

class FactoryType {
  static const String player = "Player";
  static const String bullet = "Bullet";
}

class FireGame extends FlameGame with PanDetector, TapCallbacks, KeyboardEvents, HasCollisionDetection, NetworkGame, NetworkComponent {
  @override
  String get group => "group-0";

  @override
  String get nCID => group;

  @override
  String get nFactory => "";

  @override
  bool get nRemoved => false;

  final NetworkCall<void, String> nJoin = NetworkCall("join");

  FireGame() {
    NetworkComponent.registerFactory(group: group, creator: onNetworkCreate);
    registerNetworkCall(nJoin, onPlayerJoin);
  }

  Future<void> onPlayerJoin(NetworkSession? ctx, String uuid, String name) async {
    var palyer = Player(group: group, cid: const Uuid().v1())
      ..nName.value = name
      ..nOwner = ctx?.user;
    world.add(palyer);
    L.i("Game($group) player ${ctx?.user}/$name join game on $group");
  }

  NetworkComponent onNetworkCreate(String key, String group, String id) {
    L.i("Game($group) network create $key by $id");
    switch (key) {
      case FactoryType.player:
        var player = Player(group: group, cid: id);
        world.add(player);
        return player;
      case FactoryType.bullet:
        var bullet = Bullet(group: group, cid: id);
        world.add(bullet);
        return bullet;
      default:
        throw Exception("NetworkComponent $group.$key is not supported");
    }
  }

  @override
  void onNetworkRemove() {}

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    var box = RectangleComponent(position: size / 2, size: Vector2(100, 100));
    box.add(RectangleHitbox());
    camera.viewport.add(FpsTextComponent());
    world.add(box);
    world.addAll(createWalls());
    await NetworkManagerGRPC.shared.start();
    if (isClient) {
      networkCall(nJoin, "name");
    }
  }

  List<Component> createWalls() {
    final view = camera.visibleWorldRect;
    double wallOffset = 1;
    double wallSize = 1000;
    double x = view.width / 2 + wallSize / 2 - wallOffset;
    double y = view.height / 2 + wallSize / 2 - wallOffset;
    return [
      Wall(direct: Vector2(1, 0), position: Vector2(-x, 0), size: Vector2(wallSize, view.height + 2 * wallSize)), //left
      Wall(direct: Vector2(0, -1), position: Vector2(0, -y), size: Vector2(view.width + 2 * wallSize, wallSize)), //top
      Wall(direct: Vector2(-1, 0), position: Vector2(x, 0), size: Vector2(wallSize, view.height + 2 * wallSize)), //right
      Wall(direct: Vector2(0, 1), position: Vector2(0, y), size: Vector2(view.width + 2 * wallSize, wallSize)), //bottom
    ];
  }

  @override
  void onPanUpdate(DragUpdateInfo info) {
    var p = camera.globalToLocal(info.eventPosition.game);
    Player.current?.turnTo(p);
  }

  @override
  void onTapDown(TapDownEvent event) {
    var p = camera.globalToLocal(event.canvasPosition);
    Player.current?.turnTo(p);
    Player.current?.fire();
  }

  @override
  KeyEventResult onKeyEvent(RawKeyEvent event, Set<LogicalKeyboardKey> keysPressed) {
    if (event.isKeyPressed(LogicalKeyboardKey.keyW)) {
      Player.current?.nextWeapon();
    }
    return super.onKeyEvent(event, keysPressed);
  }
}

class Wall extends RectangleComponent {
  Vector2 direct;

  Wall({required this.direct, super.position, super.size});

  @override
  FutureOr<void> onLoad() async {
    await super.onLoad();
    anchor = Anchor.center;
    paint.color = Colors.yellow;
    add(RectangleHitbox(anchor: Anchor.topLeft));
  }
}

class Bullet extends CircleComponent with CollisionCallbacks, NetworkComponent {
  final String cid;
  final String group;
  final NetworkPropVector2 nDirect = NetworkPropVector2("direct", Vector2(0, 1));
  final NetworkProp<double> nSpeed = NetworkProp("speed", 1000);
  final NetworkPropColor nColor = NetworkPropColor("color", Colors.white);
  final NetworkPropVector2 nPosition = NetworkPropVector2("position", Vector2.zero());

  final DateTime _startTime = DateTime.now();

  @override
  String get nCID => cid;

  @override
  String get nGroup => group;

  @override
  String get nFactory => FactoryType.bullet;

  @override
  bool get nRemoved => isRemoved;

  Bullet({required this.group, String? cid}) : cid = cid ?? const Uuid().v1() {
    registerNetworkProp(nDirect);
    registerNetworkProp(nSpeed);
    registerNetworkProp(nColor, getter: () => paint.color, setter: (v) => paint.color = v);
    registerNetworkProp(nPosition, getter: () => position, setter: (v) => position = v);
  }

  @override
  void onNetworkRemove() {
    removeFromParent();
    L.i("Game($group) network remove $nFactory by $cid");
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    anchor = Anchor.center;
    radius = 16;
    add(CircleHitbox(radius: radius * 1.5));
  }

  @override
  void update(double dt) {
    if (isServer) {
      nPosition.value += nDirect.value * nSpeed.value * dt;
      if (DateTime.now().difference(_startTime) > const Duration(seconds: 5)) {
        removeFromParent();
      }
    }
    super.update(dt);
  }

  @override
  void onCollisionStart(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollisionStart(intersectionPoints, other);
    if (NetworkManager.global.isServer && other is Wall) {
      nDirect.value = nDirect.value.reflected(other.direct);
    }
    // removeFromParent();
  }
}

class Weapon extends RectangleComponent with HasGameReference<FireGame> {
  static List<Color> colors = [Colors.green.shade500, Colors.green.shade800, Colors.yellow.shade500, Colors.yellow.shade800, Colors.red.shade500, Colors.red.shade800];

  int weapon = 0;
  Vector2 direct = Vector2(0, 1);

  @override
  FutureOr<void> onLoad() async {
    await super.onLoad();
    paint.color = Weapon.colors[0];
    anchor = Anchor.bottomCenter;
    width = 16;
    height = 50;
    angle = 0;
  }

  void next() {
    weapon = (weapon + 1) % Weapon.colors.length;
    paint.color = Weapon.colors[weapon];
  }

  void turn(Vector2 v) {
    var r = v.angleToSigned(Vector2(0, 1));
    angle = math.pi - r;
    direct = v.normalized();
  }

  Bullet createBullet(Vector2 position) {
    var b = Bullet(group: game.group);
    b.nPosition.value = position + direct * height;
    b.nDirect.value = direct;
    b.nColor.value = paint.color;
    return b;
  }
}

class Player extends RectangleComponent with HasGameReference<FireGame>, NetworkComponent {
  static Player? current;

  String group;
  String cid;

  @override
  String get nGroup => group;

  @override
  String get nCID => cid;

  @override
  String get nFactory => FactoryType.player;

  @override
  bool get nRemoved => isRemoved;

  final NetworkProp<String> nName = NetworkProp("name", "");

  Weapon weapon = Weapon();

  Player({required this.group, required this.cid});

  @override
  void onNetworkRemove() => removeFromParent();

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    paint.color = Colors.transparent;
    anchor = Anchor.center;
    width = 100;
    height = 100;
    position = Vector2(80 - game.size.x / 2, game.size.y / 2);
    var center = Vector2(width / 2, height / 2);
    weapon.position = center;
    add(weapon);
    add(CircleComponent(position: center, radius: 32, anchor: Anchor.center, paint: BasicPalette.white.paint()));
    if (isOwner) {
      current = this;
    }
  }

  void turnTo(Vector2 point) {
    if (isOwner) {
      weapon.turn(point - position);
    }
  }

  void nextWeapon() {
    if (isOwner) {
      weapon.next();
    }
  }

  void fire() {
    if (isOwner) {
      game.world.add(weapon.createBullet(position));
    }
  }
}
