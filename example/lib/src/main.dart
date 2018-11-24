import 'package:socket_client_dart/src/client.dart';
import 'package:socket_client_dart/flutter_socket_client.dart';

void main() async {
  var client = new FlutterSocketClient('ws://localhost:8080');
  client.debug = true;
  client.onConnection(() async {
    client.on("UserAuthSignIn", (Package package) async {
      print(package.toString());
    });
    client.onDisconnection(() async {
      print('disconnected');
    });
    await client.emit("UserAuthSignIn", "xyz");
  });
  await client.connect();
}
