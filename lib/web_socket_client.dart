// Copyright 2018 Tiny Authors. All rights reserved.
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
import 'src/client.dart' as Client;
import 'src/socket_client.dart';

class WebSocketClient extends Client.Client implements SocketClient {
  
  WebSocketClient(String url) : super(url);
  WebSocket _client;
  bool _isRetry = false;

  SocketClient getSocket() {
    return this;
  }

  @override
  Future connect() async {
    socket = this;
    await retry();
    new Timer.periodic(new Duration(milliseconds: 300), (Timer timer) async {
      await retry();
    });
  }

  @override
  void disconnect() {
    if (_client != null) {
      _client.close();
      _client = null;
    }
  }

  void retry() async {
    if (_isRetry) {
      return;
    }
    _isRetry = true;
    if (!isConnected() && !isConnecting()) {
      try {
        disconnect();
        _client = new WebSocket(url);
        _client.onOpen.listen((e) async {
            if (isConnected() && onConnectionCallback != null) {
              listenResponse();
              await onConnectionCallback();
              while (!packageQueue.isEmpty) {
                var package = packageQueue.removeFirst();
                await emit(package.event, package.payload);
              }
            }
        });
      } catch (e) {
        print(e);
      }
    }
    _isRetry = false;
  }

  @override
  bool isConnecting() {
    return _client != null && 
      _client.readyState == WebSocket.CONNECTING;
  }
  
  @override
  bool isConnected() {
    return _client != null && 
      _client.readyState == WebSocket.OPEN;
  }

  @override
  Future add(String package) async {
    if (_client != null) {
      return await _client.send(package);
    }
  }

  @override
  void listen(Function callback) {
    if (_client != null) {
      _client.onMessage.listen((package) {
        callback(package.data);
      });
    }
  }
}
