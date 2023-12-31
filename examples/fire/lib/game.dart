import 'dart:async';
import 'dart:math' as math;

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flame/extensions.dart';
import 'package:flame/input.dart';
import 'package:flame/palette.dart';
import 'package:flame_network/flame_network.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

import 'log.dart';

class FactoryType {
  static const String player = "Player";
  static const String bullet = "Bullet";
  static const String boss = "Boss";
}

class FireGame extends FlameGame with PanDetector, TapCallbacks, KeyboardEvents, HasCollisionDetection, NetworkGame, NetworkComponent, NetworkEvent {
  final List<bool> seatUsed = List.filled(8, false);
  final List<Vector2> seatPosition = List.filled(8, Vector2.zero());
  final List<double> seatAngle = [0, 0, 0, math.pi, math.pi, math.pi, math.pi / 2, -math.pi / 2];
  final List<Color> seatColors = [
    const Color(0xffdd7230),
    const Color(0xfff4c95d),
    const Color(0xffe7e393),
    const Color(0xff854d27),
    const Color(0xff2e1f27),
    const Color(0xff5dfdcb),
    const Color(0xff7cc6fe),
    const Color(0xff8789c0),
  ];
  final Map<String, Player> players = {};

  final NetworkCall<String, String> nJoin = NetworkCall("join");

  bool autoZoom = true;
  bool _reconnecting = false;
  String? _enterName;

  final TextComponent _pingShow = TextComponent(text: "-");
  final TextComponent _reconnectShow = TextComponent(
    anchor: Anchor.center,
    text: "reconnecting...",
    size: Vector2(200, 20),
    textRenderer: TextPaint(style: const TextStyle(color: Colors.yellow, fontSize: 16)),
    priority: 100,
  );

  FireGame({World? world, bool? autoZoom})
      : autoZoom = autoZoom ?? true,
        super(world: world ?? FireWorld()) {
    NetworkComponent.registerFactory(group: nGroup, creator: onNetworkCreate);
    registerNetworkCall(nJoin, onPlayerJoin);
    registerNetworkEvent(event: this);
  }

  @override
  String get nGroup => "group-0";

  @override
  String get nCID => nGroup;

  @override
  String get nFactory => "";

  @override
  bool get nRemoved => false;

  @override
  Vector2 get size => Vector2(1280, 720);

  Vector2 _scale = Vector2(1, 1);

  Vector2 get scale => _scale;

  void initSeat() {
    for (var i = 0; i < 3; i++) {
      var gap = (size.x - 3 * 100) / 4;
      seatPosition[i] = Vector2(-size.x / 2 + (i + 1) * (gap + 50), size.y / 2);
    }
    for (var i = 0; i < 3; i++) {
      var gap = (size.x - 3 * 100) / 4;
      seatPosition[3 + i] = Vector2(-size.x / 2 + (i + 1) * (gap + 50), -size.y / 2);
    }
    seatPosition[6] = Vector2(-size.x / 2, 0);
    seatPosition[7] = Vector2(-size.x / 2, 0);
  }

  int requestSeat() {
    for (var i = 0; i < 8; i++) {
      if (!seatUsed[i]) {
        seatUsed[i] = true;
        return i;
      }
    }
    return -1;
  }

  void releaseSeat(int seat) {
    seatUsed[seat] = false;
  }

  Future<String> onPlayerJoin(NetworkSession ctx, String uuid, String name) async {
    if (name.isEmpty) {
      return "name is required";
    }
    var owner = name;
    if (players.containsKey(owner)) {
      ctx.group = nGroup;
      ctx.user = name;
      return "OK";
    }
    var seat = requestSeat();
    if (seat < 0) {
      return "Seat Full";
    }
    ctx.group = nGroup;
    ctx.user = name;
    var player = Player(group: nGroup, owner: owner, cid: const Uuid().v1())
      ..nName.value = name
      ..nSeat.value = seat;
    players[owner] = player;
    world.add(player);
    L.i("Game($nGroup) player $owner/$name join game on $nGroup");
    return "OK";
  }

  Future<String> enter(String name) async {
    assert(isClient);

    var res = await networkCall(nJoin, name);
    if (res == "OK") {
      NetworkManager.global.session.group = nGroup;
      NetworkManager.global.session.user = name;
      _enterName = name;
      await NetworkManager.global.ready(); //read to sync
      L.i("$this player enter room");
    }

    return res;
  }

  Future<void> leave() async {
    assert(isClient);

    //mark pause to sync
    await NetworkManager.global.pause();

    _enterName = null;

    L.i("$this player leave room");
  }

  @override
  Future<void> onNetworkPing(NetworkConnection conn, Duration ping) async {
    var ms = ping.inMilliseconds;
    if (ms <= 0) {
      _pingShow.text = ".....";
    } else {
      _pingShow.text = "${ping.inMilliseconds} ms";
    }
  }

  @override
  Future<void> onNetworkState(Set<NetworkConnection> all, NetworkConnection conn, NetworkState state, {Object? info}) async {
    await super.onNetworkState(all, conn, state, info: info);
    var user = conn.session.user ?? "";
    L.i("Game($nGroup) $user 1/${all.length} connect state to $state");
  }

  @override
  Future<void> onNetworkUserConnected(NetworkConnection conn, String user, {Object? info}) async {
    L.i("Game($nGroup) user $user connection is connect by $info");
    await super.onNetworkUserConnected(conn, user, info: info);
    if (isClient) {
      if (_reconnecting && _enterName != null) {
        await enter(_enterName!);
      }
      _reconnecting = false;
      _reconnectShow.removeFromParent();
    }
  }

  @override
  Future<void> onNetworkUserDisconnected(NetworkConnection conn, String user, {Object? info}) async {
    L.i("Game($nGroup) user $user connection is disconnected by $info");
    if (isServer) {
      var player = players.remove(user);
      if (player != null) {
        L.i("Game($nGroup) player $user/${player.nName.value} leave game on $nGroup");
        player.removeFromParent();
        releaseSeat(player.nSeat.value);
      }
    }
    if (isClient) {
      _reconnecting = true;
      _reconnectShow.removeFromParent();
      camera.viewport.add(_reconnectShow);
    }
  }

  NetworkComponent onNetworkCreate(String key, String group, String owner, String id) {
    L.i("Game($group) network create $key by $id");
    switch (key) {
      case FactoryType.player:
        var player = Player(group: group, owner: owner, cid: id);
        world.add(player);
        return player;
      case FactoryType.bullet:
        var bullet = Bullet(group: group, cid: id);
        world.add(bullet);
        return bullet;
      case FactoryType.boss:
        var boss = Boss(group: group, cid: id);
        world.add(boss);
        return boss;
      default:
        throw Exception("onNetworkCreate $group.$key is not supported");
    }
  }

  @override
  void onNetworkRemove() {}

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    if (autoZoom) {
      _scale = Vector2(camera.visibleWorldRect.width / size.x, camera.visibleWorldRect.height / size.y);
    }
    camera.viewport.add(FpsTextComponent());
    _pingShow.position = Vector2(8, camera.visibleWorldRect.height - 30);
    camera.viewport.add(_pingShow);
    _reconnectShow.position = Vector2(camera.visibleWorldRect.width / 2, camera.visibleWorldRect.height / 2);

    initSeat();

    var backgroud = RectangleComponent(size: size, anchor: Anchor.center);
    backgroud.paint.color = const Color.fromARGB(255, 100, 100, 100);
    world.add(backgroud);
    if (isServer) {
      var boss = Boss(group: nGroup);
      world.add(boss);
    }
    world.addAll(createWalls());
  }

  @override
  void onRemove() {
    super.onRemove();
    unregisterFromNetworkManager();
  }

  List<Component> createWalls() {
    var view = size;
    double wallOffset = -16;
    double wallSize = 1000;
    double x = view.x / 2 + wallSize / 2 - wallOffset;
    double y = view.y / 2 + wallSize / 2 - wallOffset;
    return [
      Wall(direct: Vector2(1, 0), position: Vector2(-x, 0), size: Vector2(wallSize, view.y + 2 * wallSize)), //left
      Wall(direct: Vector2(0, -1), position: Vector2(0, -y), size: Vector2(view.x + 2 * wallSize, wallSize)), //top
      Wall(direct: Vector2(-1, 0), position: Vector2(x, 0), size: Vector2(wallSize, view.y + 2 * wallSize)), //right
      Wall(direct: Vector2(0, 1), position: Vector2(0, y), size: Vector2(view.x + 2 * wallSize, wallSize)), //bottom
    ];
  }

  @override
  void onPanUpdate(DragUpdateInfo info) async {
    var p = camera.globalToLocal(info.eventPosition.global);
    p = Vector2(p.x / scale.x, p.y / scale.y);
    await Player.current?.turnTo(p);
  }

  @override
  void onTapDown(TapDownEvent event) async {
    var p = camera.globalToLocal(event.canvasPosition);
    p = Vector2(p.x / scale.x, p.y / scale.y);
    await Player.current?.fireTo(p);
  }

  @override
  KeyEventResult onKeyEvent(RawKeyEvent event, Set<LogicalKeyboardKey> keysPressed) {
    if (event.isKeyPressed(LogicalKeyboardKey.keyW)) {
      Player.current?.switchWeapon();
    }
    return super.onKeyEvent(event, keysPressed);
  }
}

class FireWorld extends World with HasGameReference<FireGame> {
  @override
  void render(Canvas canvas) {
    if (game.autoZoom) {
      canvas.scale(game.scale.x, game.scale.y);
    }
    super.render(canvas);
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

class Boss extends CircleComponent with NetworkComponent {
  final String cid;
  final String group;

  @override
  String get nCID => cid;

  @override
  String get nFactory => FactoryType.boss;

  @override
  bool get nRemoved => isRemoved;

  @override
  String get nGroup => group;

  NetworkProp<int> nHealthy = NetworkProp("healthy", 100);

  final TextComponent _show = TextComponent(anchor: Anchor.center);

  Boss({required this.group, String? cid, super.position})
      : cid = cid ?? const Uuid().v1(),
        super(radius: 160, anchor: Anchor.center) {
    registerNetworkProp(nHealthy, setter: (v) => _show.text = "$v");
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    anchor = Anchor.center;
    paint.color = Colors.deepOrange;
    _show.position = size / 2;
    add(CircleHitbox());
    add(_show);
  }

  @override
  void onNetworkRemove() => removeFromParent();
}

class NetworkPropColor extends NetworkProp<Color> {
  NetworkPropColor(super.name, super.defaultValue);

  @override
  dynamic encode() => value.value;

  @override
  void decode(v) => value = Color(v);
}

class Bullet extends CircleComponent with CollisionCallbacks, NetworkComponent {
  final String cid;
  final String? playerID;
  final String group;
  final int power;
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

  Bullet({required this.group, this.playerID, String? cid, int? power})
      : cid = cid ?? const Uuid().v1(),
        power = power ?? 1,
        super(anchor: Anchor.center, radius: 16) {
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
    add(CircleHitbox(anchor: Anchor.center, position: size / 2, radius: radius * 1));
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

  void _sendReward() {
    if (playerID == null) {
      return;
    }
    var player = NetworkComponent.findComponent(playerID!) as Player?;
    if (player == null) {
      return;
    }
    player.sendReward(1000);
  }

  @override
  void onCollisionStart(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollisionStart(intersectionPoints, other);
    if (isServer) {
      if (other is Wall) {
        nDirect.value = nDirect.value.reflected(other.direct);
      }
      if (other is Boss) {
        other.nHealthy.value -= power;
        if (other.nHealthy.value <= 0) {
          other.removeFromParent();
          _sendReward();
        }
        removeFromParent();
      }
    }
  }
}

class Player extends RectangleComponent with HasGameReference<FireGame>, NetworkComponent {
  static Player? current;
  static List<int> weaponColors = [0xFFFF4B91, 0xFFFFCD4B, 0xFFD6D46D, 0xFFF4DFB6, 0xFFDE8F5F, 0xFF9A4444];

  String group;
  String owner;
  String cid;

  @override
  String get nGroup => group;

  @override
  String get nOwner => owner;

  @override
  String get nCID => cid;

  @override
  String get nFactory => FactoryType.player;

  @override
  bool get nRemoved => isRemoved;

  RectangleComponent weaponView = RectangleComponent(size: Vector2(16, 50), anchor: Anchor.bottomCenter);
  CircleComponent seatView = CircleComponent(radius: 32, anchor: Anchor.center, paint: BasicPalette.white.paint());

  final NetworkProp<String> nName = NetworkProp("name", "");
  final NetworkProp<int> nSeat = NetworkProp("seat", 0);
  final NetworkProp<int> nWeaponUsing = NetworkProp("weapon.using", 0);
  final NetworkProp<double> nWeaponAngle = NetworkProp("weapon.angle", 0);
  final NetworkPropVector2 nWeaponDirect = NetworkPropVector2("weapon.direct", Vector2(0, 1));
  final NetworkTrigger<double> nReward = NetworkTrigger("reward");
  final NetworkCall<void, NetworkVector2> nTurn = NetworkCall("turn", argNew: NetworkVector2.zero);
  final NetworkCall<void, NetworkVector2> nFire = NetworkCall("fire", argNew: NetworkVector2.zero);
  final NetworkCall<void, int> nSwitch = NetworkCall("switch");

  @override
  String toString() => "Player($nGroup/$nOwner/$nCID/${nSeat.value}/${nName.value})";

  Player({required this.group, required this.owner, required this.cid}) {
    registerNetworkProp(nName);
    registerNetworkProp(nSeat, setter: (v) => syncSeat(false));
    registerNetworkProp(nWeaponUsing, setter: (v) => weaponView.paint.color = Color(weaponColors[v]));
    registerNetworkProp(nWeaponAngle, setter: (v) => weaponView.angle = v);
    registerNetworkProp(nWeaponDirect);
    registerNetworkTrigger(nReward, _onReward);
    registerNetworkCall(nTurn, (ctx, uuid, p) => _turnTo(p));
    registerNetworkCall(nFire, (ctx, uuid, p) => _fireTo(p));
    registerNetworkCall(nSwitch, (ctx, uuid, p) => _switchWeapon());
  }

  @override
  void onNetworkRemove() => removeFromParent();

  void syncSeat(bool force) {
    if (force || isLoading || isLoaded) {
      seatView.paint.color = game.seatColors[nSeat.value];
      position = game.seatPosition[nSeat.value];
      angle = game.seatAngle[nSeat.value];
    }
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    syncSeat(true);
    paint.color = Colors.transparent;
    anchor = Anchor.center;
    width = 100;
    height = 100;
    // position = Vector2(80 - game.size.x / 2, game.size.y / 2);
    weaponView.position = seatView.position = Vector2(width / 2, height / 2);
    add(weaponView);
    add(seatView);
    L.i("$this is loaded");
    if (isOwner) {
      current = this;
    }
  }

  @override
  void onRemove() {
    super.onRemove();
    if (current == this) {
      current = null;
    }
  }

  void _onReward(double v) {
    L.i("$this reward $v");
  }

  Bullet _createBullet() {
    var b = Bullet(group: game.nGroup, playerID: nCID, power: nWeaponUsing.value + 1);
    b.nPosition.value = position + nWeaponDirect.value * weaponView.height;
    b.nDirect.value = nWeaponDirect.value;
    b.nColor.value = weaponView.paint.color;
    return b;
  }

  void sendReward(double v) {
    nReward.add(v);
  }

  Future<void> _turnTo(Vector2 p) async {
    var direct = (p - position).normalized();
    var r = direct.angleToSigned(Vector2(0, 1));
    var angle = math.pi - r;
    nWeaponAngle.value = angle;
    nWeaponDirect.value = direct;
  }

  Future<void> _fireTo(Vector2 p) async {
    await _turnTo(p);
    game.world.add(_createBullet());
  }

  Future<void> _switchWeapon() async {
    nWeaponUsing.value = (nWeaponUsing.value + 1) % weaponColors.length;
  }

  Future<void> turnTo(Vector2 p) async {
    if (isOwner) {
      L.i("$this turn to $p");
      await networkCall(nTurn, p.asNetwork());
    }
  }

  Future<void> fireTo(Vector2 p) async {
    if (isOwner) {
      L.i("$this fire to $p");
      await networkCall(nFire, p.asNetwork());
    }
  }

  Future<void> switchWeapon() async {
    if (isOwner) {
      L.i("$this switch weapon");
      await networkCall(nSwitch, 0);
    }
  }
}
