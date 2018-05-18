// Copyright 2018 Food Tiny Authors. All rights reserved.
// Note that this is NOT an open source project
// Unauthorized copying of this file, via any medium is strictly prohibited
// Proprietary and confidential for the commercial

library client;

import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:convert/convert.dart';
import 'package:crypto/crypto.dart' as crypto;
import 'package:web_socket_channel/io.dart';

part 'listener.dart';
part 'message.dart';
part 'socket_listener.dart';

class Client {
  String url = '';
  int heartbeatTime;
  bool isTerminated;
  bool debug;
  bool isConnected = false;
  bool isRetry = true;
  bool isReplied = false;
  dynamic requestAccess;
  Function onConnectionCallback;
  Function onDisconnectionCallback;
  IOWebSocketChannel webSocketChannel;
  Message lastMessage;
  LinkedList<Message> messageQueue = new LinkedList();
  LinkedList<SocketListener> listeners = new LinkedList();
  HashMap<String, Function> eventListeners = new HashMap();

  Client(this.url,
      [this.heartbeatTime = 1000,
      this.debug = true,
      this.isTerminated = false]) {}

  // Enable logging for debug mode
  void log(String message) {
    if (debug) {
      print(message);
    }
  }

  // Establish new connection
  // to web socket server
  Future connect() async {
    log('Connect with ' + url);
    try {
      isConnected = false;
      log('Before connect');
      webSocketChannel = new IOWebSocketChannel(await WebSocket.connect(this.url));
      new Timer(new Duration(milliseconds: 1), () {
        log('Listening server');
        webSocketChannel.stream.listen((textMessage) {
          print(textMessage);
          var message = Message.unserialize(textMessage);
          log(message.event);
          log(message.message);
          // Acknowledge connection
          // Require authentication
          if (message.event == "Hello") {
            // Connection is connected
            // Do not allow retry anymore
            isConnected = true;
            isRetry = false;
            if (requestAccess != null) {
              log('Authenticating...');
              emitFirst("RequestAcccess", requestAccess);
            }
            return;
          }
          // Connection is authenticated
          if (message.event == "RequestAccess") {
            onConnectionCallback();
            return;
          }
          // Connection is authenticated
          if (message.event == "Ack") {
            isReplied = true;
            return;
          }
          log('Find event ' + message.event);
          // Find event and invoke corresponding  callback
          Function callback = eventListeners[message.event];
          if (callback != null) {
            callback();
          }
        });
      });
      webSocketChannel.sink.add("hello");
      log('Prepare sleep');
      while (true) {
        sleep(new Duration(seconds: this.heartbeatTime));
        print('sleeping ...');
        if (canTerminate()) {
          break;
        }
      }
    } catch (e) {
      log(e.toString());
    }
  }

  // Close web socket connection
  void disconnect() {
    if (webSocketChannel != null) {
      webSocketChannel.sink.close();
    }
  }

  // Disconnect with current connection
  // Establish new connection
  Future reconnect() async {
    log('Reconnect');
    disconnect();
    log('Fork connection thread');
    await connect();
    log('finish reconnect');
  }

  // Try to establish connection to server
  // Only single connection at one time
  Future retry() async {
    if (isRetry) {
      log('Retry');
      // Not allow retry while reconnecting
      // to prevent connection overlapping
      isRetry = false;
      await reconnect();
    }
  }

  // Serialize message as string and delivery to server
  // This method solve the duplicated message by
  // checking with last message
  // @param message message
  // @return boolean
  bool send(Message message) {
    // Can not send because connection is not established
    if (!isConnected) {
      isRetry = true;
      return false;
    }

    // If there is no last message and current message is not last message
    // Do not send duplicated message
    if (lastMessage == null || !(lastMessage.requestId == message.requestId)) {
      try {
        isReplied = false;
        webSocketChannel.sink.add(message.serialize());
        log(">>[client] " + message.serialize());
        return true;
      } catch (e) {
        // Error when sending message
        log("Sending event " + message.event + "  fail !");
        isRetry = true;
      }
    }

    // Do not send message
    return false;
  }

  // Only allow to terminate if all messages
  // are already sent and terminate signal was declared
  bool canTerminate() {
    return messageQueue.isEmpty && isTerminated;
  }

  // Watch connection and presents a retry mechanism
  // This watcher supports testing mode with isTerminated flag
  Future watchConnection() async {
    log('Watching connection ...');
    while (true) {
      sleep(new Duration(milliseconds: this.heartbeatTime));
      // Support breakpoint for testing
      //if (canTerminate()) break;
      try {
        if (!isConnected) {
          await retry();
          continue;
        }
        if (messageQueue.isEmpty) {
          log('No message');
          continue;
        }
        // Prepare next package will be sent
        Message sendMessage = lastMessage;
        if (sendMessage == null) {
          sendMessage = messageQueue.last;
        }
        // Send message and waiting for verification
        bool isSent = send(sendMessage);
        if (isSent) {
          log('Verify message');
          await verifyMessagePackage();
          messageQueue.remove(sendMessage);
          lastMessage = null;
        }
      } catch (e) {
        log(e.toString());
      }
    }
  }

  // After sending message we need to wait
  // and verify if any response from server
  // before sending next package to avoid package lost
  Future verifyMessagePackage() async {
    try {
      // Waiting for verification
      int tryCounter = 0;
      while (true) {
        log('Checking ' + tryCounter.toString());
        if (canTerminate()) {
          disconnect();
          break;
        }

        tryCounter++;

        if (isReplied) {
          log("Message received success");
          break;
        }

        // Counter reach number of times
        // Support 600 times for slow connection
        if (tryCounter > 100) {
          log("||[client] Server does not response - timeout !");
          // Give up
          // Allow connection do retry
          isRetry = true;
          break;
        }

        // Sleep at the end to optimize time
        sleep(new Duration(milliseconds: 50));
      }
    } catch (e) {
      log(e.toString());
    }
  }

  Client onConnection(Function onConnectionCallback) {
    this.onConnectionCallback = onConnectionCallback;
    return this;
  }

  Client onDisconnection(Function onDisconnectionCallback) {
    this.onDisconnectionCallback = onDisconnectionCallback;
    return this;
  }

  Client on(String eventName, Function onMessageCallback) {
    eventListeners.putIfAbsent(eventName, onMessageCallback);
    return this;
  }

  Client authenticate(dynamic requestAccess) {
    this.requestAccess = requestAccess;
    return this;
  }

  Client emitFirst(String eventName, dynamic data) {
    Message message = new Message(eventName, data);
    this.messageQueue.addFirst(message);
    return this;
  }

  Client emit(String eventName, dynamic data) {
    Message message = new Message(eventName, data.toString());
    this.messageQueue.add(message);
    return this;
  }
}
