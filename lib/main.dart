import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:flutter_serial_communication/flutter_serial_communication.dart';
import 'package:flutter_serial_communication/models/device_info.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _flutterSerialCommunicationPlugin = FlutterSerialCommunication();
  bool isConnected = false;
  List<DeviceInfo> connectedDevices = [];
  List<String> receivedMessages = [];
  TextEditingController messageController = TextEditingController();
  List<int> receivedBytesBuffer = []; // Buffer to accumulate bytes

  @override
  void initState() {
    super.initState();

    // Listener for receiving messages
    _flutterSerialCommunicationPlugin
        .getSerialMessageListener()
        .receiveBroadcastStream()
        .listen((event) {
          receivedBytesBuffer.addAll(event); // Add incoming bytes to buffer

          // Check for end of message (e.g., #...F)
          int endIndex = -1;
          for (int i = 0; i < receivedBytesBuffer.length; i++) {
            if (receivedBytesBuffer[i] == 0x46) {
              // ASCII code for 'F'
              int startIndex = -1;
              for (int j = i - 1; j >= 0; j--) {
                if (receivedBytesBuffer[j] == 0x23) {
                  // ASCII code for '#'
                  startIndex = j;
                  endIndex = i;
                  break;
                }
              }
              if (startIndex != -1) break;
            }
          }

          if (endIndex != -1) {
            List<int> completeMessageBytes = receivedBytesBuffer.sublist(
              0,
              endIndex + 1,
            );
            String message;
            try {
              message = utf8.decode(completeMessageBytes); // Decode using UTF-8
            } catch (e) {
              message = "Error decoding: $e"; // Handle decoding errors
            }

            receivedBytesBuffer.removeRange(
              0,
              endIndex + 1,
            ); // Clear the processed message from buffer

            message = message.trim(); // Remove whitespace and line endings

            setState(() {
              receivedMessages.add(message);
              _processReceivedMessage(message);
            });
            debugPrint("Received From Native: $message");
          }
        });

    // Listener for connection status
    _flutterSerialCommunicationPlugin
        .getDeviceConnectionListener()
        .receiveBroadcastStream()
        .listen((event) {
          setState(() {
            isConnected = event;
          });
        });
  }

  _getAllConnectedDevicesButtonPressed() async {
    List<DeviceInfo> newConnectedDevices =
        await _flutterSerialCommunicationPlugin.getAvailableDevices();
    setState(() {
      connectedDevices = newConnectedDevices;
    });
  }

  _connectButtonPressed(DeviceInfo deviceInfo) async {
    bool isConnectionSuccess = await _flutterSerialCommunicationPlugin.connect(
      deviceInfo,
      115200,
    );
    debugPrint("Is Connection Success: $isConnectionSuccess");
  }

  _disconnectButtonPressed() async {
    await _flutterSerialCommunicationPlugin.disconnect();
    setState(() {
      receivedMessages.clear();
    });
  }

  _sendMessageButtonPressed() async {
    String message = messageController.text;
    if (message.isNotEmpty) {
      bool isMessageSent = await _flutterSerialCommunicationPlugin.write(
        Uint8List.fromList(message.codeUnits),
      );
      debugPrint("Is Message Sent: $isMessageSent");
      messageController.clear();
    }
  }

  _sendLearnCommand() async {
    String command = "LEARN\n";
    bool isMessageSent = await _flutterSerialCommunicationPlugin.write(
      Uint8List.fromList(command.codeUnits),
    );
    debugPrint("Is LEARN Command Sent: $isMessageSent");
  }

  _sendTransCommand() async {
    String command = "TRANS\r";
    bool isMessageSent = await _flutterSerialCommunicationPlugin.write(
      Uint8List.fromList(command.codeUnits),
    );
    debugPrint("Is TRANS Command Sent: $isMessageSent");
  }

  TextEditingController statusController = TextEditingController();

  String extractNumbersBetween(String input, String startChar, String endChar) {
    // ساخت الگوی عبارت منظم
    RegExp regExp = RegExp('$startChar(\\d+)$endChar');

    // جستجو برای تطابق
    Match? match = regExp.firstMatch(input);

    // اگر تطابق پیدا شد، اعداد را برگردان
    if (match != null) {
      return match.group(1)!;
    }

    // اگر تطابقی پیدا نشد، رشته خالی برگردان
    return '';
  }

  void _processReceivedMessage(String message) {
    if (message.startsWith("#") && message.endsWith("F")) {
      // تجزیه رشته کد
      String id = message.substring(1, 2); // بخش ID
      String relayNumber = message.substring(3, 4); // شماره رله
      String deviceType = message.substring(5, 6); // نوع دستگاه
      String sourceId = extractNumbersBetween(
        message,
        'C',
        'D',
      ); // آی دی دستگاه مبدا
      String destinationId = extractNumbersBetween(
        message,
        'D',
        'E',
      ); // آی دی مقصد
      String packetNumber = extractNumbersBetween(
        message,
        'E',
        'F',
      ); // شماره بسته

      // تعیین وضعیت روشن/خاموش
      String powerStatus = (id == "1") ? "ON" : "OFF";

      // نمایش وضعیت در TextBox
      String status =
          """
      Power Status: $powerStatus
      Relay Number: $relayNumber
      Device Type: $deviceType
      Source ID: $sourceId
      Destination ID: $destinationId
      Packet Number: $packetNumber
      """;

      setState(() {
        statusController.text = status;
      });
    } else {
      setState(() {
        statusController.text = "Invalid message format!";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Flutter Serial Communication App')),
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Is Connected: $isConnected"),
                const SizedBox(height: 16.0),
                ElevatedButton(
                  onPressed: _getAllConnectedDevicesButtonPressed,
                  child: const Text("Get All Connected Devices"),
                ),
                const SizedBox(height: 16.0),
                ...connectedDevices.asMap().entries.map((entry) {
                  return Row(
                    children: [
                      Flexible(child: Text(entry.value.productName)),
                      const SizedBox(width: 16.0),
                      ElevatedButton(
                        onPressed: () {
                          _connectButtonPressed(entry.value);
                        },
                        child: const Text("Connect"),
                      ),
                    ],
                  );
                }).toList(),
                const SizedBox(height: 16.0),
                if (isConnected) ...[
                  ElevatedButton(
                    onPressed: _disconnectButtonPressed,
                    child: const Text("Disconnect"),
                  ),
                  const SizedBox(height: 16.0),
                  const Text(
                    "Status:",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextField(
                    controller: statusController,
                    maxLines: 6,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: "Status will be displayed here",
                    ),
                    readOnly: true,
                  ),
                  const SizedBox(height: 16.0),
                  TextField(
                    controller: messageController,
                    decoration: const InputDecoration(
                      labelText: "Enter Message",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8.0),
                  ElevatedButton(
                    onPressed: _sendMessageButtonPressed,
                    child: const Text("Send Message"),
                  ),
                  const SizedBox(height: 16.0),
                  const Text(
                    "Received Messages:",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Container(
                    height: 200, // ارتفاع ثابت برای بخش دریافت پیام‌ها
                    padding: const EdgeInsets.all(8.0),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    child: ListView.builder(
                      itemCount: receivedMessages.length,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: SelectableText(
                            receivedMessages[index],
                            style: const TextStyle(fontSize: 14.0),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16.0),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton(
                        onPressed: _sendLearnCommand,
                        child: const Text("LEARN"),
                      ),
                      ElevatedButton(
                        onPressed: _sendTransCommand,
                        child: const Text("TRANS"),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 16.0),
                const Text(
                  "Switch Types:",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8.0),
                Builder(
                  builder: (context) {
                    return ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const SwitchPage(
                              switchType: "Single Pole",
                              switchId: "SP-001", // ID برای Single Pole
                            ),
                          ),
                        );
                      },
                      child: const Text("Single Pole Switch"),
                    );
                  },
                ),
                const SizedBox(height: 8.0),
                Builder(
                  builder: (context) {
                    return ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const SwitchPage(
                              switchType: "Double Pole",
                              switchId: "DP-001", // ID برای Double Pole
                            ),
                          ),
                        );
                      },
                      child: const Text("Double Pole Switch"),
                    );
                  },
                ),
                const SizedBox(height: 8.0),
                Builder(
                  builder: (context) {
                    return ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const SwitchPage(
                              switchType: "Three Pole",
                              switchId: "TP-001", // ID برای Three Pole
                            ),
                          ),
                        );
                      },
                      child: const Text("Three Pole Switch"),
                    );
                  },
                ),
                const SizedBox(height: 8.0),
                Builder(
                  builder: (context) {
                    return ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const SwitchPage(
                              switchType: "Four Pole",
                              switchId: "FP-001", // ID برای Four Pole
                            ),
                          ),
                        );
                      },
                      child: const Text("Four Pole Switch"),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SwitchPage extends StatelessWidget {
  final String switchType;
  final String switchId;

  const SwitchPage({
    super.key,
    required this.switchType,
    required this.switchId,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('$switchType Switch - $switchId')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'This is the $switchType Switch Page',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            Text(
              'Switch ID: $switchId',
              style: const TextStyle(fontSize: 18, color: Colors.grey),
            ),
            const SizedBox(height: 20),
            // نمایش کلیدها بر اساس نوع سوئیچ
            if (switchType == "Single Pole") ...[
              _buildSwitchButton("Switch 1", switchId),
            ] else if (switchType == "Double Pole") ...[
              _buildSwitchButton("Switch 1", "$switchId-1"),
              _buildSwitchButton("Switch 2", "$switchId-2"),
            ] else if (switchType == "Three Pole") ...[
              _buildSwitchButton("Switch 1", "$switchId-1"),
              _buildSwitchButton("Switch 2", "$switchId-2"),
              _buildSwitchButton("Switch 3", "$switchId-3"),
            ] else if (switchType == "Four Pole") ...[
              _buildSwitchButton("Switch 1", "$switchId-1"),
              _buildSwitchButton("Switch 2", "$switchId-2"),
              _buildSwitchButton("Switch 3", "$switchId-3"),
              _buildSwitchButton("Switch 4", "$switchId-4"),
            ],
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Go Back'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchButton(String label, String id) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: ElevatedButton(
        onPressed: () {
          debugPrint("$label Pressed (ID: $id)");
        },
        child: Text("$label (ID: $id)"),
      ),
    );
  }
}
