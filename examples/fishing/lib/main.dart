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
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  maxTranslation = 50;
  runApp(const GameWidget.controlled(gameFactory: FinshingGame.new));
}

class MySpecialHitbox extends RectangleHitbox {
  MySpecialHitbox() {
    triggersParentCollision = false;
  }

// hitbox specific onCollision* functions
}

class FinshingGame extends FlameGame with PanDetector, TapCallbacks, KeyboardEvents, HasCollisionDetection {
  late Player player;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    player = Player();
    var box = RectangleComponent(position: size / 2, size: Vector2(100, 100));
    box.add(RectangleHitbox());
    camera.viewport.add(FpsTextComponent());
    world.add(player);
    world.add(box);
    world.addAll(createWalls());
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
    player.turnTo(p);
  }

  @override
  void onTapDown(TapDownEvent event) {
    var p = camera.globalToLocal(event.canvasPosition);
    player.turnTo(p);
    player.fire();
  }

  @override
  KeyEventResult onKeyEvent(RawKeyEvent event, Set<LogicalKeyboardKey> keysPressed) {
    if (event.isKeyPressed(LogicalKeyboardKey.keyW)) {
      player.nextWeapon();
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

class Bullet extends CircleComponent with CollisionCallbacks {
  final Vector2 direct;
  final double speed;
  final Color color;

  Bullet({super.position, Vector2? direct, double? speed, Color? color})
      : direct = direct ?? Vector2(0, 1),
        speed = speed ?? 1000,
        color = color ?? Colors.white;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    anchor = Anchor.center;
    paint.color = color;
    radius = 16;
    add(CircleHitbox(radius: radius * 1.5));
  }

  @override
  void update(double dt) {
    position += direct * speed * dt;
    super.update(dt);
  }

  @override
  void onCollisionStart(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollisionStart(intersectionPoints, other);
    if (other is Wall) {
      direct.reflect(other.direct);
    }
    // removeFromParent();
  }
}

class Weapon extends RectangleComponent {
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
    var p = position + direct * height;
    // log("new bullet on $p");
    return Bullet(position: p, direct: direct, color: paint.color);
  }
}

class Player extends RectangleComponent with HasGameReference<FinshingGame> {
  Weapon weapon = Weapon();

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
  }

  void move(Vector2 delta) {
    position.add(delta);
  }

  void turnTo(Vector2 point) {
    weapon.turn(point - position);
  }

  void nextWeapon() {
    weapon.next();
  }

  void fire() {
    game.world.add(weapon.createBullet(position));
  }
}
