import 'dart:async';

import 'package:flame_network/src/common/common.dart';
import 'package:flame_network/src/common/log.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';

void main() {
  test("HandleableStream", () {
    var ctr = StreamController();
    var stream = HandleableStream(stream: ctr.stream);
    stream.onError = (e) {};
    stream.listen((event) {}, onDone: () {}, onError: (e) {}, cancelOnError: true);
    ctr.sink.addError("error");
    ctr.sink.close();
  });
  test("LinePrinter", () {
    var p = LinePrinter();
    p.getLevel(Level.off);
  });
}
