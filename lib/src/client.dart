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
  dynamic eventListeners = {};

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

  Future connect() async {
    var receivePort = new ReceivePort();
    await Isolate.spawn(DataTransport, receivePort.sendPort);
    this.sendPort = await receivePort.first;
    var ackMessage = await send(Message.ACK, {});
    if (ackMessage != null && ackMessage.event == Message.ACK) {
      if (this.onConnectionCallback != null) {
        this.onConnectionCallback();
      }
    }
  }

  void onConnection(Function onConnectionCallback) {
    this.onConnectionCallback = onConnectionCallback;
  }

  Client onDisconnection(Function onDisconnectionCallback) {
    this.onDisconnectionCallback = onDisconnectionCallback;
    return this;
  }

  Client on(String eventName, Function onMessageCallback) {
    eventListeners[eventName] = onMessageCallback;
    return this;
  }

  Client authenticate(dynamic requestAccess) {
    this.requestAccess = requestAccess;
    return this;
  }

  Future<Message> invoke(eventName, dynamic data) async {
    var requestMessage = new Message(eventName, data);
    var responseMessage = Message.unserialize(
        await sendReceive(sendPort, requestMessage.serialize())
    );
    if (responseMessage != null && responseMessage.event.length > 0) {
      var callback = eventListeners[responseMessage.event];
      if (callback != null) {
        callback(responseMessage);
      }
    }
    return responseMessage;
  }

  Future<Message> send(String eventName, dynamic data) async {
    final isConnected = await sendReceive(sendPort, 'connected');
    if (isConnected.toString() == '1') {
      return await invoke(eventName, data);
    }
    final connected = await sendReceive(sendPort, this.url);
    if (connected.toString() == '1') {
      var authMessage = new Message('RequestAccess', this.requestAccess);
      final ackMessage = Message.unserialize(
          await sendReceive(sendPort, authMessage.serialize())
      );
      if ((ackMessage != null) && (ackMessage.event == Message.AUTHENTICATED)) {
        return await invoke(eventName, data);
      }
    }
    return await new Future(() => null);
  }

  Future<String> sendReceive(SendPort port, msg) {
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
    if (message.toString().startsWith('connected')) {
      sender.send((ws != null && ws.closeCode == null) ? '1' : '0');
      continue;
    }
    if (message.toString().startsWith('ws://')) {
      ws = await WebSocket.connect(message);
      if (ws.closeCode == null) {
        sender.send('1');
        ws.listen((textMessage) {
          print('>> ' + textMessage + '\n');
          sender.send(textMessage.toString());
        });
      } else {
        sender.send('0');
      }
      continue;
    }
    if (ws.closeCode == null) {
      print('<<' + message + '\n');
      ws.add(message);
    }
  }
}
