// Copyright 2018 Food Tiny Authors. All rights reserved.
// Note that this is NOT an open source project
// Unauthorized copying of this file, via any medium is strictly prohibited
// Proprietary and confidential for the commercial

library client;

import 'dart:async';
import 'dart:isolate';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:convert/convert.dart';
import 'package:crypto/crypto.dart' as crypto;

part 'listener.dart';

part 'message.dart';

part 'socket_listener.dart';

class Client {
  String url = '';
  int heartbeatTime;
  dynamic requestAccess;
  Function onConnectionCallback;
  Function onDisconnectionCallback;
  LinkedList<SocketListener> listeners = new LinkedList();
  HashMap<String, Function> eventListeners = new HashMap();

  static bool isTerminated = false;
  static bool isDebug = false;
  bool isReplied = false;
  bool isRetry = false;
  bool isConnected = false;
  SendPort sendPort;
  Client(this.url, [this.heartbeatTime = 1000]) {}

  // Enable logging for debug mode
  static void log(String message) {
    if (isDebug) {
      print(message);
    }
  }

  Future<String> onConnection(Function onConnectionCallback) async {
    this.onConnectionCallback = onConnectionCallback;
    var receivePort = new ReceivePort();
    await Isolate.spawn(DataTransport, receivePort.sendPort);
    this.sendPort = await receivePort.first;
    return await send('hello', '');
  }

  Client onDisconnection(Function onDisconnectionCallback) {
    this.onDisconnectionCallback = onDisconnectionCallback;
    return this;
  }

  Client on(String eventName, Function onMessageCallback) {
    eventListeners.putIfAbsent(eventName, onMessageCallback);
    return this;
  }

  Client authenticate(dynamic requestAccess) {
    this.requestAccess = requestAccess;
    return this;
  }

  Future send(String eventName, dynamic data) async {
    var message = new Message(eventName, data);
    final isConnected = await sendReceive(sendPort, 'connected');
    if (isConnected == '1') {
      return await sendReceive(sendPort, message);
    }
    final connected = await sendReceive(sendPort, this.url);
    if (connected == '1') {
      var authMessage = new Message('RequestAccess', this.requestAccess);
      final ackMessage = Message.unserialize(
          await sendReceive(sendPort, authMessage.serialize())
      );
      if ((ackMessage != null) && (ackMessage.event == Message.ACK)) {
        return await sendReceive(sendPort, message);
      }
    }
    return await new Future(() => '0');
  }

  Future sendReceive(SendPort port, msg) {
    ReceivePort response = new ReceivePort();
    port.send([msg, response.sendPort]);
    return response.first;
  }
}

DataTransport(SendPort sendPort) async {
  var port = new ReceivePort();
  sendPort.send(port.sendPort);
  WebSocket ws = null;
  var message, sender;
  await for (var pkg in port) {
    message = pkg[0];
    sender = pkg[1];
    print('<<' + message.toString());
    if (message.toString().startsWith('connected')) {
      sender.send((ws != null && ws.closeCode == null) ? 1 : 0);
      continue;
    }
    if (message.toString().startsWith('ws://')) {
      ws = await WebSocket.connect(message);
      if (ws.closeCode == null) {
        sender.send('1');
        ws.listen((textMessage) {
          print('>> ' + textMessage);
          sender.send(textMessage);
        });
      } else {
        sender.send('0');
      }
      continue;
    }
    if (ws.closeCode == null) {
      ws.add(message);
    }
  }
}
