library flame_network;

import 'package:flame_network/src/common/log.dart';
import 'package:logger/logger.dart';

export 'src/network/grpc.dart';
export 'src/network/network.dart';
export 'src/component/base.dart';
export 'src/component/game.dart';
export 'src/component/sequence.dart';
export 'src/component/vector.dart';

Logger get networkLogger => L;
set networkLogger(Logger v) => L;
