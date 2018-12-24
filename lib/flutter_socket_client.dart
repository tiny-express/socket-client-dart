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

library socket.futter;

import 'dart:io';
import 'dart:async';
import 'package:socket_client_dart/src/client.dart';
import 'package:socket_client_dart/src/socket_client.dart';

class FlutterSocketClient extends Client implements SocketClient {

  WebSocket _client;
  FlutterSocketClient(String url) : super(url);
  bool isSubscribed = false;

  @override
  SocketClient getSocket() {
    return this;
  }

  @override
  Future connect() async {
    socket = this;
    retry();
    new Timer.periodic(new Duration(seconds: 5), (Timer timer) async { retry(); });
  }

  void retry() async {
    if (!isConnected() && !isConnecting()) {
      log('Connecting to ' + url);
      try {
        _client = await WebSocket.connect(url);
        log('Connected to ' + url);
        if (!isSubscribed) {
          listenResponse();
          isSubscribed = true;
        }
        if (onConnectionCallback != null) {
          await onConnectionCallback();
          while (!packageQueue.isEmpty) {
            var package = packageQueue.removeFirst();
            await emit(package.event, package.payload);
          }
        }
      } catch (e) {
        print(e);
      }
    }
  }

  @override
  bool isConnecting() {
    return _client != null && _client.readyState == WebSocket.connecting;
  }

  @override
  bool isConnected() {
    return _client != null && _client.readyState == WebSocket.open;
  }
  
  @override
  Future add(String package) async {
    if (_client != null) {
      return await _client.add(package);
    }
  }

  @override
  void listen(Function callback) {
    if (_client != null) {
      _client.listen((package) {
        callback(package.toString());
      });
    }
  }
}
