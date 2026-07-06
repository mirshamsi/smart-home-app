import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_serial_communication/flutter_serial_communication.dart';
import 'package:flutter_serial_communication/models/device_info.dart';
import 'package:provider/provider.dart';
import 'package:topaz/providers/connection_provider.dart';
import 'package:topaz/providers/device_provider.dart';
import 'package:topaz/providers/theme_provider.dart';
import 'package:topaz/services/serial_service.dart';

class MotionPage extends StatefulWidget {
  final String deviceName;
  final String deviceId;
  const MotionPage({required this.deviceName, required this.deviceId});

  @override
  _MotionPageState createState() => _MotionPageState();
}

class _MotionPageState extends State<MotionPage> {
  final SerialService _serialService = SerialService();
  final _flutterSerialCommunicationPlugin = FlutterSerialCommunication();
  List<int> receivedBytesBuffer = [];
  List<String> receivedMessages = [];
  bool _isSensorActive = true;

  @override
  void initState() {
    super.initState();
    _initialize();
    _loadMotionData();
  }

  Future<void> _loadMotionData() async {
    final deviceProvider = Provider.of<DeviceProvider>(context, listen: false);
    await deviceProvider.loadMotionDataFromHive(widget.deviceId);

    final motionData = deviceProvider.getMotionData(widget.deviceId);
    if (motionData != null) {
      setState(() {
        _isSensorActive = motionData.isActive;
      });
    }
  }

  Future<void> _initialize() async {
    await _reconnectIfNeeded();
    _setupSerialListener();
  }

  void _setupSerialListener() {
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
  }

  Future<void> _reconnectIfNeeded() async {
    final connectionProvider = Provider.of<ConnectionProvider>(
      context,
      listen: false,
    );
    if (!connectionProvider.isConnected) {
      List<DeviceInfo> devices = await _serialService.getAvailableDevices();
      if (devices.isNotEmpty) {
        bool success = await _serialService.connect(devices.first, 115200);
        connectionProvider.setConnectionStatus(success);
        debugPrint("وضعیت اتصال: $success");
        if (!success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('اتصال به دستگاه ناموفق بود')),
          );
        }
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('هیچ دستگاهی یافت نشد')));
      }
    }
  }

  void _processReceivedMessage(String message) {
    RegExp regex = RegExp(r"#(\d+)A(\d+)B(\d+)C(\d+)D([^E]+)E(\d+)F");
    Match? match = regex.firstMatch(message);
    if (match != null && match.group(4) == widget.deviceId) {
      String relayMode = match.group(1)!;

      final deviceProvider = Provider.of<DeviceProvider>(
        context,
        listen: false,
      );
      deviceProvider.updateMotionData(
        widget.deviceId,
        relayMode,
        isActive: _isSensorActive,
      );

      if (_isSensorActive) {
        _showMotionDetectedNotification(relayMode);
      }
    } else {
      debugPrint("پیام نامعتبر یا deviceId مطابقت ندارد: $message");
    }
  }

  void _showMotionDetectedNotification(String relayMode) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.motion_photos_on, color: Colors.white),
            SizedBox(width: 8),
            Text('حرکت شناسایی شد! (Mode: $relayMode)'),
          ],
        ),
        backgroundColor: Colors.orange.shade700,
        duration: Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    // final isTablet = MediaQuery.of(context).size.width > 600;
    final deviceProvider = Provider.of<DeviceProvider>(context);
    final motionData = deviceProvider.getMotionData(widget.deviceId);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.deviceName),
        backgroundColor: themeProvider.isDarkMode
            ? Colors.grey[900]
            : Colors.amber,
        actions: [
          PopupMenuButton<String>(
            icon: Icon(
              themeProvider.isDarkMode ? Icons.light_mode : Icons.dark_mode,
              color: Colors.white,
            ),
            onSelected: (String value) {
              if (value == 'toggle_theme') {
                Provider.of<ThemeProvider>(
                  context,
                  listen: false,
                ).toggleTheme();
              }
            },
            itemBuilder: (BuildContext context) => [
              PopupMenuItem<String>(
                value: 'toggle_theme',
                child: Row(
                  children: [
                    Icon(
                      themeProvider.isDarkMode
                          ? Icons.light_mode
                          : Icons.dark_mode,
                      color: themeProvider.isDarkMode
                          ? Colors.yellow[300]
                          : Colors.yellow[800],
                    ),
                    SizedBox(width: 8),
                    Text(themeProvider.isDarkMode ? 'حالت روشن' : 'حالت تاریک'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 4,
                child: Container(
                  padding: const EdgeInsets.all(30),
                  width: double.infinity,
                  child: Column(
                    children: [
                      Icon(
                        motionData != null && _isSensorActive
                            ? Icons.motion_photos_on
                            : Icons.motion_photos_off,
                        size: 80,
                        color: motionData != null && _isSensorActive
                            ? Colors.orange.shade600
                            : Colors.grey,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        motionData != null && _isSensorActive
                            ? "حرکت شناسایی شد!"
                            : "بدون حرکت",
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              color: motionData != null && _isSensorActive
                                  ? Colors.red
                                  : Colors.grey,
                            ),
                      ),
                      const SizedBox(height: 8),
                      if (motionData != null)
                        Column(
                          children: [
                            Text(
                              "آخرین تشخیص: ${motionData.getFormattedTime()}",
                              style: TextStyle(
                                color: themeProvider.isDarkMode
                                    ? Colors.grey[400]
                                    : Colors.black54,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "حالت: ${motionData.relayMode}",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: themeProvider.isDarkMode
                                    ? Colors.amber[300]
                                    : Colors.amber[800],
                              ),
                            ),
                          ],
                        )
                      else
                        Text(
                          "در انتظار داده...",
                          style: TextStyle(
                            color: themeProvider.isDarkMode
                                ? Colors.grey[400]
                                : Colors.black54,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 30),

              // سوئیچ فعال/غیرفعال سازی
              // SwitchListTile(
              //   title: const Text("فعال‌سازی سنسور"),
              //   value: _isSensorActive,
              //   onChanged: (val) {
              //     setState(() {
              //       _isSensorActive = val;
              //     });

              //     // به‌روزرسانی وضعیت در Hive
              //     if (motionData != null) {
              //       deviceProvider.updateMotionData(
              //         widget.deviceId,
              //         motionData.relayMode,
              //         isActive: val,
              //       );
              //     }
              //   },
              //   secondary: Icon(
              //     _isSensorActive ? Icons.sensors : Icons.sensors_off,
              //     color: _isSensorActive ? Colors.green : Colors.grey,
              //   ),
              // ),
              // const SizedBox(height: 30),
              Container(
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: themeProvider.isDarkMode
                      ? Colors.grey[800]
                      : Colors.grey[200],
                  borderRadius: BorderRadius.circular(12.0),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "پیام‌های دریافتی:",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: themeProvider.isDarkMode
                            ? Colors.grey[200]
                            : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 100,
                      child: receivedMessages.isEmpty
                          ? Text(
                              "هیچ پیامی دریافت نشده است",
                              style: TextStyle(
                                fontSize: 16,
                                color: themeProvider.isDarkMode
                                    ? Colors.grey[400]
                                    : Colors.black54,
                              ),
                            )
                          : ListView.builder(
                              itemCount: receivedMessages.length,
                              itemBuilder: (context, index) {
                                return Text(
                                  receivedMessages[index],
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: themeProvider.isDarkMode
                                        ? Colors.grey[400]
                                        : Colors.black54,
                                    height: 1.5,
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
