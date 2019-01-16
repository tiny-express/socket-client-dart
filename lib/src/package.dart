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

part of client;

// Package entity is a data inter-change format
// Support for serialize and un-serialize
class Package {
  
  String event;
  String payload;

  Package(String event, String package) {
    this.event = event;
    this.payload = package;
  }
  
  List<int> bufferPayload() {
    String rawPayload = payload.substring(1, payload.length - 1);
    List<String> payloadBytes = rawPayload.split(",");
    List<int> buffer = new List(payloadBytes.length);
    for (int index=0; index<payloadBytes.length; index++) {
      buffer[index] = int.parse(payloadBytes[index].trim());
    }
    return buffer;
  }

  // Decode text package to package object
  // Support for retrieving data from server
  static Package fromString(String textPackage) {
    if (textPackage == null) {
      return null;
    }
    var packageComponents = textPackage.split(".");
    if (packageComponents.length != 2) {
      return null;
    }
    var eventName = packageComponents[0];
    var payload = packageComponents[1];
    return new Package(eventName, payload);
  }

  // Serialize data for transferring
  String toString() {
    return event + "." + payload;
  }
}
