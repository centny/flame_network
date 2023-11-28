import 'package:flame_network/flame_network.dart';
import 'package:flutter/material.dart';

import 'game.dart';
import 'log.dart';

class AppMenu extends StatelessWidget {
  final Widget body;

  const AppMenu({required this.body, super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      color: Colors.transparent,
      title: "Test",
      home: Scaffold(
        // backgroundColor: const Color.fromARGB(30, 255, 255, 255),
        body: body,
      ),
    );
  }
}

class LoginMenu extends StatefulWidget {
  final FireGame game;

  const LoginMenu({required this.game, super.key});

  @override
  State<StatefulWidget> createState() => LoginMenuState();
}

class LoginMenuState extends State<LoginMenu> {
  final TextEditingController username = TextEditingController();
  String message = "";

  void showMessage() {
    var snackBar = SnackBar(
      content: Text(message),
    );
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  void onStart() async {
    try {
      await NetworkManagerGRPC.shared.start();

      if (NetworkManagerGRPC.shared.isClient) {
        var name = username.text;
        L.i("Game(${widget.game.nGroup}) $name start join to game");
        var res = await widget.game.join(username.text);
        if (res != "OK") {
          L.w("Game(${widget.game.nGroup}) $name join to game fail with $res");
          setState(() {
            message = res;
            showMessage();
          });
          return;
        }
        L.i("Game(${widget.game.nGroup}) $name join to game success");
      }

      widget.game.overlays.remove('LoginMenu');
    } catch (e, s) {
      L.e("Game(${widget.game.nGroup}) join to game fail with $e\n$s");
      setState(() {
        message = "connect to server fail";
        showMessage();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    var startText = "Play";
    if (NetworkManager.global.isServer && !NetworkManager.global.isClient) {
      startText = "Start";
    }
    List<Widget> loginItems = [];
    if (NetworkManager.global.isClient) {
      loginItems = [
        TextField(
          controller: username,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: 'Enter a username',
          ),
        ),
      ];
    }
    return Center(
      child: Container(
        padding: const EdgeInsets.all(10.0),
        height: 800,
        width: 400,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Flame Network Example Fire',
              style: TextStyle(
                fontSize: 24,
              ),
            ),
            const SizedBox(height: 40),
            Column(mainAxisAlignment: MainAxisAlignment.center, children: loginItems),
            const SizedBox(height: 40),
            SizedBox(
              width: 200,
              height: 75,
              child: ElevatedButton(
                onPressed: onStart,
                child: Text(
                  startText,
                  style: const TextStyle(
                    fontSize: 40.0,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              '''Click to fire.
Use W Keys for change weapon.''',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: Colors.red),
            ),
          ],
        ),
      ),
    );
  }
}
