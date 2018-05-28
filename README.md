# Socket Client for Dart

For Flutter:
```dart
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
```