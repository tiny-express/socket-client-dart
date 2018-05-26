// Copyright 2018 Food Tiny Authors. All rights reserved.
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are met:
//
// Redistributions of source code must retain the above copyright
// notice, this list of conditions and the following disclaimer.
// Redistributions in binary form must reproduce the above
// copyright notice, this list of conditions and the following disclaimer
// in the documentation and/or other materials provided with the
// distribution.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
// "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
// LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
// A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
// OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
// SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
// LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
// DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
// THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
// (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
// OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

library client;

import 'dart:async';
import 'dart:isolate';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:convert/convert.dart';
import 'package:crypto/crypto.dart' as crypto;

part 'message.dart';

class Client {
  String url = '';
  int heartbeatTime;
  dynamic requestAccess;
  Function onConnectionCallback;
  Function onDisconnectionCallback;
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
