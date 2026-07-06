import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_serial_communication/flutter_serial_communication.dart';
import 'package:flutter_serial_communication/models/device_info.dart';
import 'package:topaz/providers/connection_provider.dart';
import 'package:topaz/providers/device_provider.dart';
import 'package:topaz/providers/theme_provider.dart';
import 'package:topaz/services/serial_service.dart';

class TemperatureAndHumidity extends StatefulWidget {
  final String deviceName;
  final String deviceId;
  const TemperatureAndHumidity({
    required this.deviceName,
    required this.deviceId,
  });

  @override
  _TemperatureAndHumidityPageState createState() =>
      _TemperatureAndHumidityPageState();
}

class _TemperatureAndHumidityPageState extends State<TemperatureAndHumidity>
    with SingleTickerProviderStateMixin {
  // List mySmartDevices = [];
  // bool _isSending = false;
  final SerialService _serialService = SerialService();
  final _flutterSerialCommunicationPlugin = FlutterSerialCommunication();
  List<int> receivedBytesBuffer = [];
  List<String> receivedMessages = [];
  List<String> sentMessages = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<DeviceProvider>(
        context,
        listen: false,
      ).loadTemperatureHumidityFromHive(widget.deviceId);
    });
    _initialize();
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

  void _processReceivedMessage(String message) {
    RegExp regex = RegExp(r"#(\d+)A(\d+)B(\d+)C(\d+)D([^E]+)E(\d+)F");
    Match? match = regex.firstMatch(message);
    if (match != null && match.group(4) == widget.deviceId) {
      String temperatureStr = match.group(1)!;
      String humidityStr = match.group(2)!;

      double temperature = double.parse(temperatureStr);
      double humidity = double.parse(humidityStr);

      final deviceProvider = Provider.of<DeviceProvider>(
        context,
        listen: false,
      );
      deviceProvider.updateTemperatureHumidity(
        widget.deviceId,
        temperature,
        humidity,
      );

      // setState(() {
      //   _currentTemperature = "$temperature °C";
      //   _currentHumidity = "$humidity%";
      // });
    } else {
      debugPrint("پیام نامعتبر یا deviceId مطابقت ندارد: $message");
    }
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

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    // final isTablet = MediaQuery.of(context).size.width > 600;
    final deviceProvider = Provider.of<DeviceProvider>(context);
    final data = deviceProvider.getTemperatureHumidity(widget.deviceId);

    String temperatureText = "-- °C";
    String humidityText = "--%";
    String lastUpdateText = "در انتظار داده...";

    if (data != null) {
      temperatureText = "${data.temperature.toStringAsFixed(1)} °C";
      humidityText = "${data.humidity.toStringAsFixed(1)}%";
      lastUpdateText = "آخرین به‌روزرسانی: ${_formatDateTime(data.lastUpdate)}";
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.deviceName),
        backgroundColor: themeProvider.isDarkMode
            ? Colors.grey[900]
            : Colors.amber,
        actions: [
          // IconButton(
          //   icon: Icon(Icons.refresh),
          //   onPressed: () async {
          //     // شبیه‌سازی دریافت داده جدید
          //     await deviceProvider.updateTemperatureHumidity(
          //       widget.deviceId,
          //       26.5, // دما
          //       45.0, // رطوبت
          //     );
          //     ScaffoldMessenger.of(
          //       context,
          //     ).showSnackBar(SnackBar(content: Text('اطلاعات به‌روزرسانی شد')));
          //   },
          // ),
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
          padding: const EdgeInsets.all(8.0),
          child: Column(
            children: [
              // --- show temperature ---
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 4,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  width: double.infinity,
                  child: Column(
                    children: [
                      Icon(
                        Icons.thermostat,
                        size: 60,
                        color: data == null ? Colors.grey : Colors.red,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        temperatureText,
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 5),
                      Text(
                        "دمای فعلی",
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      Text(
                        lastUpdateText,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // --- show humidity ---
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 4,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  width: double.infinity,
                  child: Column(
                    children: [
                      Icon(
                        Icons.water_drop,
                        size: 60,
                        color: data == null ? Colors.grey : Colors.blue,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        humidityText,
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 5),
                      Text(
                        "رطوبت فعلی",
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      Text(
                        lastUpdateText,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 30),

              // --- دکمه‌های کنترلی ---
              // Row(
              //   mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              //   children: [
              //     ElevatedButton.icon(
              //       onPressed: () {},
              //       icon: const Icon(Icons.ac_unit),
              //       label: const Text("روشن کردن کولر"),
              //     ),
              //     ElevatedButton.icon(
              //       onPressed: () {},
              //       icon: const Icon(Icons.local_fire_department),
              //       label: const Text("روشن کردن بخاری"),
              //     ),
              //   ],
              // ),
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

  String _formatDateTime(DateTime dateTime) {
    return "${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')} - ${dateTime.day}/${dateTime.month}/${dateTime.year}";
  }
}
