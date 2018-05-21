// Copyright 2018 Food Tiny Authors. All rights reserved.
// Note that this is NOT an open source project
// Unauthorized copying of this file, via any medium is strictly prohibited
// Proprietary and confidential for the commercial

library client;

import 'dart:async';
import 'dart:isolate';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:convert/convert.dart';
import 'package:crypto/crypto.dart' as crypto;
part 'listener.dart';
part 'message.dart';
part 'socket_listener.dart';

bool SOCKET_CLIENT_TERMINATED = false;
bool SOCKET_CLIENT_DEBUG = false;

bool _SOCKET_CLIENT_REPLIED = false;
bool _SOCKET_CLIENT_RETRY =  false;
bool _SOCKET_CLIENT_CONNECTED = false;

Message lastMessage = null;
LinkedList<Message> messageQueue = new LinkedList();
WebSocket ws = null;

class Client {
  String url = '';
  int heartbeatTime;
  bool debug;
  bool isConnected = false;
  bool isRetry = true;
  bool isReplied = false;
  dynamic requestAccess;
  Function onConnectionCallback;
  Function onDisconnectionCallback;
  LinkedList<SocketListener> listeners = new LinkedList();
  HashMap<String, Function> eventListeners = new HashMap();

  Client(this.url,
      [this.heartbeatTime = 1000,
        this.debug = true]) {}

  // Enable logging for debug mode
  static void log(String message) {
    if (SOCKET_CLIENT_DEBUG) {
      print(message);
    }
  }

  // Establish new connection
  // to web socket server
  Future connect() async {
    log('Connect with ' + url);
    try {
      isConnected = false;
      try {
        ws = await WebSocket.connect(this.url);
        isConnected = true;
      } catch (e) {
        ws = null;
        return;
      }
      log('say hello at ' + this.url);
      ws.add("hello");
      ws.listen((textMessage) {
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
      log('Done connection function');
    } catch (e) {
      print(e.toString());
    }
    log('Done connect');
  }

  // Close web socket connection
  static void disconnect() {
    if (ws != null) {
      ws.close();
    }
  }

  // Disconnect with current connection
  // Establish new connection
  Future reconnect() async {
    disconnect();
    await connect();
    log('Done reconnect');
  }

  // Try to establish connection to server
  // Only single connection at one time
  // @return Future
  Future retry() async {
    if (isRetry) {
      log('Retry');
      // Not allow retry while reconnecting
      // to prevent connection overlapping
      isRetry = false;
      await reconnect();
      log('Done retry');
    }
  }

  // Only allow to terminate if all messages
  // are already sent and terminate signal was declared
  static bool canTerminate() {
    return messageQueue.isEmpty && SOCKET_CLIENT_TERMINATED;
  }

  // Watch connection and presents a retry mechanism
  // This watcher supports testing mode with isTerminated flag
  Future watchConnection() async {
    log('Fork listener');
    // Create a message broker to isolate process
    var receivePort = new ReceivePort();
    await Isolate.spawn(WebSocketListener, receivePort.sendPort);
    final sendPort = await receivePort.first;
    log('Enter loop');
    while (true) {
      sleep(new Duration(milliseconds: this.heartbeatTime));

      // Trigger isolate sending process
      ReceivePort response = new ReceivePort();
      await sendPort.send(["push", response.sendPort]);

      log('Test connection');

      if (ws == null || !isConnected) {
        await retry();
        continue;
      }

      if (canTerminate()) break;
    }
  }

  // After sending message we need to wait
  // and verify if any response from server
  // before sending next package to avoid package lost
  static verifyMessagePackage() {
    log('Verify message');
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

        if (_SOCKET_CLIENT_REPLIED) {
          log("Message received success");
          break;
        }

        // Counter reach number of times
        // Support 600 times for slow connection
        if (tryCounter > 100) {
          log("||[client] Server does not response - timeout !");
          // Give up
          // Allow connection do retry
          _SOCKET_CLIENT_RETRY = true;
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
    messageQueue.addFirst(message);
    return this;
  }

  Client emit(String eventName, dynamic data) {
    Message message = new Message(eventName, data.toString());
    messageQueue.add(message);
    return this;
  }
}

WebSocketListener(SendPort sendPort) async {
  print('WebSocketListener');
  var port = new ReceivePort();
  sendPort.send(port.sendPort);
  await for (var msg in port) {
    print('Checking message in queue \n');
    if (messageQueue.isEmpty) {
      continue;
    }

    // Prepare next package will be sent
    Message sendMessage = lastMessage;
    if (sendMessage == null) {
      sendMessage = messageQueue.last;
    }
    print('Sending ' + sendMessage.serialize());
    // Send message and waiting for verification
    await ws.add(sendMessage.serialize());
    await Client.verifyMessagePackage();
    messageQueue.remove(sendMessage);
  }
}

