import 'package:socket_client_dart/socket_flutter.dart';
import 'dart:async';
import 'dart:isolate';

main() async {
  var receivePort = new ReceivePort();
  await Isolate.spawn(echo, receivePort.sendPort);
  var sendPort = await receivePort.first;
  new Timer.periodic(const Duration(seconds: 1), (_) {
    var response = new ReceivePort();
    sendPort.send(["aaa", response.sendPort]);
  });
}

echo(SendPort sendPort) async {
  var port = new ReceivePort();
  sendPort.send(port.sendPort);
  await for (var msg in port) {
    var data = msg[0];
    print("Hello " + data);
  }
}