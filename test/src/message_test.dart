// Copyright 2018 Food Tiny Authors. All rights reserved.
// Note that this is NOT an open source project
// Unauthorized copying of this file, via any medium is strictly prohibited
// Proprietary and confidential for the commercial

import 'package:test/test.dart';
import 'package:socket_client_dart/src/client.dart';

void main() {
  test('Message:constructor', () async {
    var message = new Message(
        "onUserSignIn", {"username": "loint", "password": "123456"});
    expect(message.requestId.length, greaterThan(0));
    expect(message.event, equals("onUserSignIn"));
    expect(message.message, equals('{"username":"loint","password":"123456"}'));
  });

  test('Message:serialize', () async {
    var message = new Message(
        "onUserSignIn", {"username": "loint", "password": "123456"});
    expect(message.requestId.length, greaterThan(0));
    expect(message.event, equals("onUserSignIn"));
    expect(message.message, equals('{"username":"loint","password":"123456"}'));
  });

  test('Message:serialization', () async {
    var message = new Message(
        "onUserSignIn", {"username": "loint", "password": "123456"});
    expect(message.serialize().length, greaterThan(0));
    // Un-serialize message again to verify information
    var unserializedMessage = Message.unserialize(message.serialize());
    expect(unserializedMessage.requestId, equals(message.requestId));
    expect(unserializedMessage.event, equals(message.event));
    expect(unserializedMessage.message, equals(message.message));
  });
}
