# Socket Client for Dart

For Flutter:
```dart
var client = new FlutterSocketClient('ws://localhost:3000');
```

For Web:
```dart
var client = new WebSocketClient('ws://localhost:3000');
```

Inspired by Socket.io
```dart
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
  client.onDisconnection(() async {
  });
  await client.emit("UserAuthSignIn", {});
  await client.emit("UserAuthSignIn", {});
});
await client.connect();
```