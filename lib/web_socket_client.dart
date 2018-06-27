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

library socket.web;

import 'dart:html';
import 'dart:async';
import 'package:socket_client_dart/src/client.dart' as Client;
import 'package:socket_client_dart/src/socket_client.dart';

class WebSocketClient extends Client.Client implements SocketClient {

  WebSocket _client;
  WebSocketClient(String url) : super(url);

  SocketClient getSocket() {
    return this;
  }

  @override
  Future connect() async {
    socket = this;
    bool isSubscribed = false;
    new Timer.periodic(new Duration(seconds: 1), (Timer timer) async {
      if (!isConnected()) {
        log('Connecting to ' + this.url);
        try {
          _client = new WebSocket(this.url);
        } catch (e) {}
        _client.onOpen.listen((e) async{
          if (!isSubscribed) {
            listenResponse();
            isSubscribed = true;
          }
          if (isConnected() && this.onConnectionCallback != null) {
            listenResponse();
            this.onConnectionCallback();
            if (lastMessage != null) {
              await emit(lastMessage.event, lastMessage.message);
            }
          }
        });
      }
    });
  }

  @override
  bool isConnected() {
    return _client != null && _client.readyState == WebSocket.OPEN;
  }

  @override
  Future add(String message) async {
    if (_client != null) {
      return await _client.send(message);
    }
  }

  Future ping() async {
    return await add(Client.Message.PING);
  }

  @override
  void listen(Function callback) {
    if (_client != null) {
      _client.onMessage.listen((message) {
      callback(message.data);
    });
    }
  }
}

