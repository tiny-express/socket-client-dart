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

part of client;

// Message entity is a data inter-change format
// Support for serialize and un-serialize
class Message {

  static const PING = "Ping";
  static const ACK = "Ack";

  String requestId;
  String event;
  String message;

  Message(String event, dynamic message) {
    this.requestId = generateRequestId();
    this.event = event;
    if (!(message is String)) {
      message = JSON.encode(message);
    }
    this.message = message;
  }

  // Decode text message to message object
  // Support for retrieving data from server
  static Message unserialize(String textMessage) {
    if (textMessage == null) {
      return null;
    }
    var messageComponents = textMessage.split("|");
    if (messageComponents.length != 3) {
      return null;
    }
    var requestId = messageComponents[0];
    var eventName = messageComponents[1];
    var encodedData = messageComponents[2];
    var data = '{}';
    try {
      var bytes = new Base64Decoder().convert(encodedData);
      data = new Utf8Decoder().convert(bytes);
    } catch (e) {
      log(e);
      // Do not handle exception here
    }
    Message newMessage = new Message(eventName, data);
    newMessage.requestId = requestId;
    return newMessage;
  }

  // Serialize data for transferring
  String serialize() {
    var bytes = new Utf8Encoder().convert(message);
    String encodedText = new Base64Codec().encode(bytes);
    return requestId + "|" + event + "|" + encodedText;
  }

  // Generate request id with md5 format
  String generateRequestId() {
    var random = new Random();
    int timestamp = new DateTime.now().millisecondsSinceEpoch;
    // Unique string presents for request id
    var data = timestamp.toString() +
        random.nextDouble().toString() +
        random.nextDouble().toString();
    var content = new Utf8Encoder().convert(data);
    var md5 = crypto.md5;
    var digest = md5.convert(content);
    return hex.encode(digest.bytes);
  }
}
