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

part 'message.dart';

abstract class Client {

  String url;
  dynamic requestAccess;
  Function onConnectionCallback;
  Function onDisconnectionCallback;
  dynamic eventListeners = {};
  Message lastMessage = null;
  StreamController<String> responseStream;
  SocketClient socket;
  bool debug;

  Client(this.url);

  void log(String message) {
    if (debug) {
      print(message);
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
    log('Listening: ' + eventName);
    eventListeners[eventName] = onMessageCallback;
    return this;
  }

  Client authenticate(dynamic requestAccess) {
    this.requestAccess = requestAccess;
    return this;
  }

  Future<bool> invoke(Message message) async {
    if ((message == null) || message.event.length == 0) {
      return false;
    }
    var callback = eventListeners[message.event];
    if (callback == null) {
      print('Can not handle event : ' + message.event);
      return false;
    }
    await callback(message);
    return true;
  }

  Future<bool> emit(String eventName, dynamic message) async {
    lastMessage = new Message(eventName, message);
    if (socket.isConnected()) {
      socket.add(lastMessage.serialize());
      lastMessage = null;
      return true;
    }
    return false;
  }

  Future listenResponse() async {
    socket.listen((textMessage) {
      var message = Message.unserialize(textMessage);
      invoke(message);
    });
  }
}
