import 'dart:io';

import 'package:flame_network/src/common/log.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart';
import 'package:shelf_static/shelf_static.dart';

class WebHandler {
  late Handler handler;

  WebHandler(String? dir) {
    if (dir == null) {
      handler = (r) => Response.notFound("Not found");
    } else {
      var directory = Directory(dir).absolute;
      if (directory.existsSync()) {
        L.i("WebHandler create static file handler on $directory");
        handler = createStaticHandler(directory.path, listDirectories: true, defaultDocument: 'index.html');
      } else {
        L.w("WebHandler create static file handler on $directory is not exists");
        handler = (r) => Response.notFound("Not found");
      }
    }
  }

  Future<void> handle(HttpRequest request) => handleRequest(request, handler, poweredByHeader: "Flame Network");
}
