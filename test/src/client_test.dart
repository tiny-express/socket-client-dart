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

import 'package:test/test.dart';
import 'package:socket_client_dart/socket_flutter.dart';

void main() {
  test("Client:integration", () async {
    // Client connection is not allowed to retry
    // another connection is connected
    Client.isDebug = true;
    var client = new Client('ws://localhost:3000', 100);
    client.authenticate({
      "scope": "Mobile",
      "version": "v1_0",
      "platform": "Android",
      "device": "Sony Xperia Z",
      "osVersion": "1234",
      "ipAddress": "127.0.0.1"
    });
    client.onConnection(() async {
      client.on("UserAuthSignIn", (Message message) async {
        expect("UserAuthSignIn", equals(message.event));
        expect('{"status": "OK"}', equals(message.message));
      });
      await client.emit("UserAuthSignIn", {});
    });
    await client.connect();
  });

  test("Client:canTerminate", () async {
    // Client connection is not allowed to retry
    // another connection is connected
//    var client = new Client("");
//    client.isTerminated = true;
//    assert(client.canTerminate(), true);
  });
}
