import 'dart:async';

import 'package:flame/game.dart';
import 'package:flame_network/flame_network.dart';
import 'package:flutter/foundation.dart';

import '../common/log.dart';

class GameLoop {
  GameLoop(this.callback);

  /// Function to be called on every Flutter rendering frame.
  ///
  /// This function takes a single parameter `dt`, which is the amount of time
  /// passed since the previous invocation of this function. The time is
  /// measured in seconds, with microsecond precision. The argument will be
  /// equal to 0 on first invocation of the callback.
  void Function(double dt) callback;

  /// Total amount of time passed since the game loop was started.
  ///
  /// This variable is updated on every rendering frame, just before the
  /// [callback] is invoked. It will be equal to zero while the game loop is
  /// stopped. It is also guaranteed to be equal to zero on the first invocation
  /// of the callback.
  DateTime _previous = DateTime.now();

  /// Internal object responsible for periodically calling the [callback]
  /// function.
  Timer? _ticker;

  /// This method is periodically invoked by the [_ticker].
  void _tick(Timer t) {
    final now = DateTime.now();
    final durationDelta = DateTime.now().difference(_previous);
    final dt = durationDelta.inMicroseconds / Duration.microsecondsPerSecond;
    _previous = now;
    callback(dt);
  }

  /// Start running the game loop. The game loop is created in a paused state,
  /// so this must be called once in order to make the loop running. Calling
  /// this method again when the game loop already runs is a noop.
  void start() {
    if (_ticker == null || !_ticker!.isActive) {
      _previous = DateTime.now();
      _ticker = Timer.periodic(const Duration(milliseconds: 10), _tick);
    }
  }

  /// Stop the game loop. While it is stopped, the time "freezes". When the
  /// game loop is started again, the [callback] will NOT be made aware that
  /// any amount of time has passed.
  void stop() {
    _ticker?.cancel();
  }

  /// Steps the game loop by the given amount of time while the ticker is
  /// stopped.
  void step(double stepTime) {
    if (_ticker?.isActive ?? false) {
      callback(stepTime);
    }
  }

  /// Call this before deleting the [GameLoop] object.
  ///
  /// The [GameLoop] will no longer be usable after this method is called. You
  /// do not have to stop the game loop before disposing of it.
  void dispose() {
    _ticker?.cancel();
  }
}

mixin NetworkGame on FlameGame {
  @override
  @mustCallSuper
  void update(double dt) async {
    super.update(dt);
    try {
      await NetworkManager.global.sync((this as NetworkComponent).nGroup);
    } catch (e, s) {
      L.w("NetworkGame sync throw error $e\n$s");
    }
  }
}
