import 'dart:async';

import 'package:flame/game.dart';
import 'package:flame_network/src/component/game.dart';
import 'package:flame_test/flame_test.dart';
import 'package:flutter_test/flutter_test.dart';

class TestNetworkGame extends FlameGame with NetworkGame {}

void main() {
  testWithGame<TestNetworkGame>('NetworkGame.sync', TestNetworkGame.new, (game) async {
    await game.ready();
  });
  test('GameLoop', () async {
    var c = Completer();
    var loop = GameLoop((dt) {
      if (!c.isCompleted) {
        c.complete();
      }
    });
    loop.start();
    await c.future;
    loop.step(0);
    loop.stop();
    loop.dispose();
  });
}
