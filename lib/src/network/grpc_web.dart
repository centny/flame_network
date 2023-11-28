import 'dart:io';

class WebHandler {
  WebHandler(String? dir);

  Future<void> handle(HttpRequest request) async {
    request.response.statusCode = 403;
    request.response.write("Not Supported");
    request.response.close();
  }
}
