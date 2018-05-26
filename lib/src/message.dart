// Copyright 2018 Food Tiny Authors. All rights reserved.
// Note that this is NOT an open source project
// Unauthorized copying of this file, via any medium is strictly prohibited
// Proprietary and confidential for the commercial

part of client;

// Message entity is a data inter-change format
// Support for serialize and un-serialize
class Message extends LinkedListEntry<Message> {

  static const HELLO = "Hello";
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
