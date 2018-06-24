import 'dart:async';
import 'package:socket_client_dart/src/client.dart';
import 'package:socket_client_dart/flutter_socket_client.dart';

void main() async {
  var client = new FlutterSocketClient('ws://localhost:3000');
  client.debug = true;
  client.onConnection(() async {
    client.on("UserAuthSignIn", (Message message) async {
      print(message.serialize());
    });
    client.onDisconnection(() async {
      print('disconnected');
    });
    await client.emit("UserAuthSignIn", {});
  });
  await client.connect();
}