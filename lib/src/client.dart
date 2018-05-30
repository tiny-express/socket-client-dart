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
import 'dart:convert';
import 'dart:math';
import 'package:convert/convert.dart';
import 'package:crypto/crypto.dart' as crypto;
import 'socket_client.dart';

part 'listener.dart';
part 'message.dart';

abstract class Client {
  String url;
  dynamic requestAccess;
  Function onConnectionCallback;
  Function onDisconnectionCallback;
  dynamic eventListeners = {};
  static bool isDebug = false;
  Message lastMessage = null;
  StreamController<String> responseStream;
  SocketClient socket;

  Client(this.url);

  SocketClient getSocket();

  // Enable logging for debug mode
  static void log(String message) {
    if (isDebug) {
      print(message);
    }
  }

  Future<String> transport(String message) async {
    if (message.toString().startsWith('connected')) {
      return socket != null && socket.isConnected() ? '1' : '0';
    }
    if (message.toString().startsWith('ws://')) {
      socket = await getSocket().initialize();
      if (socket.isConnected()) {
        // Create new stream for new connection
        responseStream = new StreamController.broadcast();
        await socket.listen((textMessage) {
          responseStream.add(textMessage);
        });
        return '1';
      } else {
        return '0';
      }
    }
    if (socket.isConnected()) {
      print('<< [client ] ' + message);
      socket.add(message);
      return responseStream.stream.first;
    }
    return null;
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

  Future<int> invoke(Message message) async {
    if ((message == null) || message.event.length == 0) {
      return 0;
    }
    if (message.event == Message.AUTHENTICATED) {
      if (this.onConnectionCallback != null) {
        return await this.onConnectionCallback();
      }
    }
    var callback = eventListeners[message.event];
    if (callback == null) {
      print('Can not handle event : ' + message.event);
      return 0;
    }
    await callback(message);
    return 0;
  }

  Future<Message> emit(String eventName, dynamic data) async {
    final isConnected = await transport('connected');
    var connected = '1';
    if (isConnected.toString() != '1') {
      connected = await transport(this.url);
    }
    if (connected.toString() == '1') {
      var requestMessage = new Message(eventName, data);
      String responseText = null;
      try {
        responseText = await transport(requestMessage.serialize());
        lastMessage = null;
      } catch (e) {}
      print('>> [server] ' + responseText);
      var responseMessage = Message.unserialize(responseText);
      await invoke(responseMessage);
      return responseMessage;
    }
    return null;
  }
}
