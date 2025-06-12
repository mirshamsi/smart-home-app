import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_serial_communication/models/device_info.dart';
import 'package:topaz/providers/connection_provider.dart';
import 'package:topaz/providers/device_provider.dart';
import 'package:topaz/providers/theme_provider.dart';
import 'package:topaz/screens/gas_sensor_page.dart';
import 'package:topaz/screens/manage_device.dart';
import 'package:topaz/services/serial_service.dart';

class TabScreen extends StatefulWidget {
  final String itemName;

  const TabScreen({required this.itemName});

  @override
  _TabScreenState createState() => _TabScreenState();
}

class _TabScreenState extends State<TabScreen> with WidgetsBindingObserver {
  final SerialService _serialService = SerialService();
  List<int> receivedBytesBuffer = [];
  List<String> receivedMessages = [];
  String deviceId = '';
  List<Map<String, String>> devices = [];
  bool _isLearning = false;
  bool _isReceiving = false;
  StreamSubscription? _serialSubscription;
  Timer? _receiveTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Provider.of<DeviceProvider>(
      context,
      listen: false,
    ).loadDevicesFromHive(widget.itemName);
    _loadDevicesFromHive();
    _checkAndConnectToDevice();
    _setupSerialListener();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    debugPrint("Lifecycle State (TabScreen): $state");
    if (state == AppLifecycleState.resumed) {
      _checkAndConnectToDevice();
      _setupSerialListener();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _serialSubscription?.cancel();
    }
  }

  void _setupSerialListener() {
    _serialSubscription?.cancel();
    _serialSubscription = _serialService.getSerialMessages().listen((event) {
      receivedBytesBuffer.addAll(event);
      int endIndex = receivedBytesBuffer.indexOf(0x46);
      if (endIndex != -1) {
        int startIndex = receivedBytesBuffer.lastIndexOf(0x23, endIndex);
        if (startIndex != -1) {
          String message = utf8
              .decode(receivedBytesBuffer.sublist(startIndex, endIndex + 1))
              .trim();
          receivedBytesBuffer.removeRange(0, endIndex + 1);
          debugPrint("پیام دریافتی (TabScreen): $message");
          setState(() {
            receivedMessages.add(message);
            if (_isReceiving) {
              _processReceivedMessageForReceiver(message);
            } else {
              _processReceivedMessage(message);
            }
          });
        }
      }
    });
  }

  Future<void> _loadDevicesFromHive() async {
    final devices = Provider.of<DeviceProvider>(
      context,
      listen: false,
    ).getDevices(widget.itemName);
    setState(() {
      this.devices = devices;
    });
  }

  Future<void> _checkAndConnectToDevice() async {
    List<DeviceInfo> devices = await _serialService.getAvailableDevices();
    if (devices.isNotEmpty) {
      bool isConnectionSuccess = await _serialService.connect(
        devices.first,
        115200,
      );
      if (isConnectionSuccess) {
        Provider.of<ConnectionProvider>(
          context,
          listen: false,
        ).setConnectionStatus(true);
        debugPrint("اتصال به دستگاه ${devices.first.deviceName} برقرار شد");
      } else {
        debugPrint("اتصال به دستگاه ناموفق بود");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("اتصال به دستگاه ناموفق بود")),
        );
      }
    } else {
      debugPrint("هیچ دستگاهی یافت نشد");
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("هیچ دستگاهی یافت نشد")));
    }
  }

  void _processReceivedMessage(String message) {
    RegExp regex = RegExp(r"#(\d+)A(\d+)B(\d+)C(\d+)D(\d+)E(\d+)F");
    Match? match = regex.firstMatch(message);
    if (match != null) {
      String stateCode = match.group(1)!;
      String buttonCode = match.group(2)!;
      String deviceInfo = match.group(3)!;
      String receivedDeviceId = match.group(4)!;

      // Check if device already exists to prevent duplicates
      bool deviceExists = Provider.of<DeviceProvider>(context, listen: false)
          .getDevices(widget.itemName)
          .any((device) => device["deviceId"] == receivedDeviceId);

      if (_isLearning && !deviceExists) {
        String deviceName;
        String deviceImage;
        Map<String, String> deviceData;
        if (deviceInfo == "12") {
          deviceName = "گاز";
          deviceImage = "assets/sensor-gaz.png";
          deviceData = {
            "name": deviceName,
            "deviceId":
                receivedDeviceId, // Use receivedDeviceId instead of stateCode
            "image": deviceImage,
            "deviceInfo": deviceInfo,
          };
        } else {
          int poleCount = 0;
          switch (deviceInfo) {
            case "66":
              deviceName = "کلید لمسی 6 پل";
              deviceImage = "assets/6-pol.png";
              poleCount = 6;
            break;
            case "64":
              deviceName = "کلید لمسی 4 پل";
              deviceImage = "assets/4-pol.png";
              poleCount = 4;
              break;
            case "63":
              deviceName = "کلید لمسی 3 پل";
              deviceImage = "assets/3-pol.png";
              poleCount = 3;
              break;
            case "62":
              deviceName = "کلید لمسی 2 پل";
              deviceImage = "assets/2-pol.png";
              poleCount = 2;
              break;
            case "61":
              deviceName = "کلید لمسی 1 پل";
              deviceImage = "assets/1-pol.png";
              poleCount = 1;
              break;
            default:
              deviceName = "دستگاه ناشناخته";
              deviceImage = "assets/1-pol.png";
              poleCount = 1;
              break;
          }
          deviceData = {
            "name": deviceName,
            "deviceId": receivedDeviceId,
            "image": deviceImage,
            "poleCount": poleCount.toString(),
            "deviceInfo": deviceInfo,
          };
        }

        setState(() {
          deviceId = receivedDeviceId;
          Provider.of<DeviceProvider>(
            context,
            listen: false,
          ).addDevice(deviceData, widget.itemName);
          debugPrint(
            "Device added: $deviceName with ID ${deviceData["deviceId"]}",
          );
        });
      } else if (!_isLearning && deviceInfo != "12") {
        bool newState = stateCode == "1";
        int relayNumber = int.parse(buttonCode);
        Provider.of<DeviceProvider>(
          context,
          listen: false,
        ).updateButtonStatesFromString(receivedDeviceId, stateCode);
        debugPrint(
          "وضعیت تاچ به‌روزرسانی شد: $receivedDeviceId, رله $relayNumber, حالت $newState",
        );
      } else if (deviceExists) {
        debugPrint(
          "Device with ID $receivedDeviceId already exists, skipping addition.",
        );
      }
    }
  }

  void _processReceivedMessageForReceiver(String message) {
    RegExp regex = RegExp(r"#(\d+)A(\d+)B(\d+)C(\d+)D([^E]+)E(\d+)F");
    Match? match = regex.firstMatch(message);
    if (match != null) {
      String stateCode = match.group(1)!;
      String deviceInfo = match.group(3)!;
      String receivedDeviceId = match.group(4)!;

      // Check if device already exists
      bool deviceExists = Provider.of<DeviceProvider>(context, listen: false)
          .getDevices(widget.itemName)
          .any((device) => device["deviceId"] == receivedDeviceId);

      String deviceName;
      String deviceImage;
      Map<String, String> deviceData;
      int poleCount = 0;

      if (deviceInfo == "12") {
        deviceName = "گاز";
        deviceImage = "assets/sensor-gaz.png";
        deviceData = {
          "name": deviceName,
          "deviceId": receivedDeviceId,
          "image": deviceImage,
          "deviceInfo": deviceInfo,
        };
      } else {
        switch (deviceInfo) {
          case "66":
            deviceName = "کلید لمسی 6 پل";
            deviceImage = "assets/6-pol.png";
            poleCount = 6;
            break;
          case "64":
            deviceName = "کلید لمسی 4 پل";
            deviceImage = "assets/4-pol.png";
            poleCount = 4;
            break;
          case "63":
            deviceName = "کلید لمسی 3 پل";
            deviceImage = "assets/3-pol.png";
            poleCount = 3;
            break;
          case "62":
            deviceName = "کلید لمسی 2 پل";
            deviceImage = "assets/2-pol.png";
            poleCount = 2;
            break;
          case "61":
            deviceName = "کلید لمسی 1 پل";
            deviceImage = "assets/1-pol.png";
            poleCount = 1;
            break;
          default:
            deviceName = "دستگاه ناشناخته";
            deviceImage = "assets/1-pol.png";
            poleCount = 1;
            break;
        }
        deviceData = {
          "name": deviceName,
          "deviceId": receivedDeviceId,
          "image": deviceImage,
          "poleCount": poleCount.toString(),
          "deviceInfo": deviceInfo,
        };
      }

      // اگر دستگاه وجود ندارد، آن را اضافه کن
      if (!deviceExists) {
        setState(() {
          deviceId = receivedDeviceId;
          Provider.of<DeviceProvider>(
            context,
            listen: false,
          ).addDevice(deviceData, widget.itemName);
          debugPrint(
            "Device added in receiving mode: $deviceName with ID ${deviceData["deviceId"]}",
          );
        });
      } else {
        debugPrint("Device with ID $receivedDeviceId already exists.");
      }

      // در هر صورت، اگر دستگاه کلید است، وضعیت دکمه‌هایش را به‌روزرسانی کن
      if (deviceInfo != "12") {
        Provider.of<DeviceProvider>(
          context,
          listen: false,
        ).updateButtonStatesFromString(receivedDeviceId, stateCode);
        debugPrint(
          "وضعیت تاچ‌ها به‌روزرسانی شد: $receivedDeviceId, حالت‌ها $stateCode",
        );
      }
    }
  }

  void _startReceiving() {
    setState(() {
      _isReceiving = true;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("دریافت پیام‌ها به مدت 1 دقیقه آغاز شد")),
    );
    _receiveTimer = Timer(const Duration(minutes: 1), () {
      setState(() {
        _isReceiving = false;
      });
      debugPrint("Receiving mode disabled");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("دریافت پیام‌ها پایان یافت")),
      );
    });
  }

  _sendLearnCommand() async {
    final connectionProvider = Provider.of<ConnectionProvider>(
      context,
      listen: false,
    );
    if (!connectionProvider.isConnected) {
      await _checkAndConnectToDevice();
      if (!connectionProvider.isConnected) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("لطفاً ابتدا دستگاه را متصل کنید")),
        );
        return;
      }
    }

    String command = "LEARN\r";
    bool isMessageSent = await _serialService.write(command);
    debugPrint("Is LEARN Command Sent: $isMessageSent");
    if (!isMessageSent) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("ارسال دستور LEARN ناموفق بود")),
      );
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("دستگاه در حال شناسایی...")));
      setState(() {
        _isLearning = true;
      });
      await Future.delayed(const Duration(seconds: 5), () {
        setState(() {
          _isLearning = false;
        });
        debugPrint("LEARN mode disabled");
      });
    }
  }

  _sendTransCommand() async {
    String command = "TRANS\r";
    bool isMessageSent = await _serialService.write(command);
    debugPrint("Is TRANS Command Sent: $isMessageSent");
  }

  void _toggleDarkMode() {
    Provider.of<ThemeProvider>(context, listen: false).toggleTheme();
  }

  @override
  void dispose() {
    _serialSubscription?.cancel();
    _receiveTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final connectionProvider = Provider.of<ConnectionProvider>(context);
    final isTablet = MediaQuery.of(context).size.width > 600;
    final themeProvider = Provider.of<ThemeProvider>(context);
    final deviceProvider = Provider.of<DeviceProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.itemName,
          style: TextStyle(
            fontSize: isTablet ? 30 : 20,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        backgroundColor: themeProvider.isDarkMode
            ? Colors.grey[900]
            : Colors.amber[700],
        actions: [
          IconButton(
            icon: Icon(
              Icons.send,
              color: Colors.white,
              size: isTablet ? 28 : 24,
            ),
            tooltip: 'گیرنده با واسطه',
            onPressed: _startReceiving,
          ),
          IconButton(
            icon: Icon(
              Icons.call_received,
              color: Colors.white,
              size: isTablet ? 28 : 24,
            ),
            tooltip: 'فرستنده',
            onPressed: _sendTransCommand,
          ),
          PopupMenuButton<String>(
            icon: Icon(
              themeProvider.isDarkMode ? Icons.light_mode : Icons.dark_mode,
              color: Colors.white,
              size: isTablet ? 28 : 24,
            ),
            onSelected: (String value) {
              if (value == 'toggle_theme') _toggleDarkMode();
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
                    SizedBox(width: isTablet ? 10 : 8),
                    Text(themeProvider.isDarkMode ? 'حالت روشن' : 'حالت تاریک'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: deviceProvider.getDevices(widget.itemName).isEmpty
            ? Center(
                child: AnimatedOpacity(
                  opacity: 1.0,
                  duration: const Duration(milliseconds: 500),
                  child: Container(
                    padding: const EdgeInsets.all(24.0),
                    decoration: BoxDecoration(
                      color: themeProvider.isDarkMode
                          ? Colors.grey[850]
                          : Colors.grey[200],
                      borderRadius: BorderRadius.circular(16.0),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 8.0,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.device_unknown,
                          size: 60,
                          color: themeProvider.isDarkMode
                              ? Colors.yellow[300]
                              : Colors.yellow[800],
                        ),
                        const SizedBox(height: 16.0),
                        Text(
                          "هیچ دستگاهی یافت نشد",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: themeProvider.isDarkMode
                                ? Colors.yellow[300]
                                : Colors.yellow[800],
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8.0),
                        Text(
                          "لطفاً دستگاه را متصل کنید یا دوباره تلاش کنید",
                          style: TextStyle(
                            fontSize: 14,
                            color: themeProvider.isDarkMode
                                ? Colors.grey[500]
                                : Colors.grey[700],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              )
            : GridView.builder(
                padding: const EdgeInsets.all(16.0),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: _getCrossAxisCount(context),
                  crossAxisSpacing: 12.0,
                  mainAxisSpacing: 12.0,
                  childAspectRatio: 1.0,
                ),
                itemCount: deviceProvider.getDevices(widget.itemName).length,
                itemBuilder: (context, index) {
                  final device = deviceProvider.getDevices(
                    widget.itemName,
                  )[index];
                  return GestureDetector(
                    onTap: () {
                      if (device["deviceInfo"] == "12") {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => GasSensorPage(
                              deviceId: device["deviceId"]!,
                              deviceName: device["name"]!,
                            ),
                          ),
                        );
                      } else {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ManageDevice(
                              deviceId: device["deviceId"]!,
                              itemName: widget.itemName,
                              deviceInfo: device["deviceInfo"]!,
                            ),
                          ),
                        );
                      }
                    },
                    child: Card(
                      elevation: 4.0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16.0),
                      ),
                      color: themeProvider.isDarkMode
                          ? Colors.grey[800]
                          : Colors.white,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Image.asset(
                            device["image"]!,
                            height: isTablet ? 80 : 60,
                            fit: BoxFit.contain,
                          ),
                          const SizedBox(height: 8.0),
                          Text(
                            device["name"]!,
                            style: TextStyle(
                              fontSize: isTablet ? 18 : 14,
                              fontWeight: FontWeight.bold,
                              color: themeProvider.isDarkMode
                                  ? Colors.grey[200]
                                  : Colors.grey[900],
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 4.0),
                          Text(
                            device["deviceId"]!,
                            style: TextStyle(
                              fontSize: isTablet ? 14 : 12,
                              color: themeProvider.isDarkMode
                                  ? Colors.grey[400]
                                  : Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isLearning || _isReceiving ? null : _sendLearnCommand,
        backgroundColor: _isLearning || _isReceiving
            ? Colors.grey
            : Colors.amber,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.0),
        ),
        label: Row(
          children: [
            if (_isLearning)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                ),
              ),
            const SizedBox(width: 8),
            Text(
              _isLearning ? "در حال شناسایی..." : "افزودن دستگاه",
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
          ],
        ),
        icon: Icon(
          _isLearning ? Icons.hourglass_empty : Icons.add,
          color: Colors.black,
        ),
        elevation: 6,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  int _getCrossAxisCount(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width > 1200) return 4;
    if (width > 600) return 3;
    return 2;
  }

  Widget _buildButton(
    BuildContext context, {
    required String title,
    required IconData icon,
    required VoidCallback onPressed,
    required LinearGradient gradient,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 20, color: Colors.white),
        label: Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        style:
            ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.0),
              ),
              elevation: 6,
              backgroundColor: Colors.transparent,
              shadowColor: Colors.black26,
              foregroundColor: Colors.white.withOpacity(0.9),
            ).copyWith(
              backgroundColor: MaterialStateProperty.resolveWith<Color>((
                states,
              ) {
                if (states.contains(MaterialState.pressed))
                  return gradient.colors[1].withOpacity(0.8);
                return Colors.transparent;
              }),
            ),
      ),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(12.0),
        boxShadow: [
          BoxShadow(
            color: gradient.colors[1].withOpacity(0.4),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
    );
  }
}
