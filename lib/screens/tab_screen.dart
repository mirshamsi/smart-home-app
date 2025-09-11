import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'package:flutter_serial_communication/models/device_info.dart';
import 'package:topaz/providers/connection_provider.dart';
import 'package:topaz/providers/device_provider.dart';
import 'package:topaz/providers/theme_provider.dart';
import 'package:topaz/screens/gas_sensor_page.dart';
import 'package:topaz/screens/manage_device.dart';
import 'package:topaz/screens/temperature_and_humidity.dart';
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
  final TextEditingController _deviceIdController = TextEditingController();
  String _selectedDeviceInfo = '61';

  final List<Map<String, String>> _deviceTypes = [
    {'value': '61', 'name': 'کلید لمسی 1 پل', 'image': 'assets/1-pol.png'},
    {'value': '62', 'name': 'کلید لمسی 2 پل', 'image': 'assets/2-pol.png'},
    {'value': '63', 'name': 'کلید لمسی 3 پل', 'image': 'assets/3-pol.png'},
    {'value': '64', 'name': 'کلید لمسی 4 پل', 'image': 'assets/4-pol.png'},
    {'value': '66', 'name': 'کلید لمسی 6 پل', 'image': 'assets/6-pol.png'},
    {'value': '12', 'name': 'تشخیص حرکت', 'image': 'assets/motion-sensor.png'},
    {'value': '13', 'name': 'سنسور دود', 'image': 'assets/smoke-sensor.png'},
    {
      'value': '14',
      'name': 'سنسور در و پنجره',
      'image': 'assets/door-window-sensor.png',
    },
    {
      'value': '11',
      'name': 'سنسور دما و رطوبت',
      'image': 'assets/temp-humidity-sensor.jpg',
    },
    {'value': '5', 'name': 'سر لامپی', 'image': 'assets/lamp-head.png'},
    {'value': '9', 'name': 'هاب IR', 'image': 'assets/unknown-device.png'},
    {'value': '7', 'name': 'هاب اصلی', 'image': 'assets/unknown-device.png'},
  ];

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

      bool deviceExists = Provider.of<DeviceProvider>(context, listen: false)
          .getDevices(widget.itemName)
          .any((device) => device["deviceId"] == receivedDeviceId);

      if (_isLearning && !deviceExists) {
        String deviceName;
        String deviceImage;
        Map<String, String> deviceData;

        // سنسورها و دستگاه‌های ویژه
        if (["12", "13", "14", "11", "5", "9", "7"].contains(deviceInfo)) {
          switch (deviceInfo) {
            case "12":
              deviceName = "تشخیص حرکت";
              deviceImage = "assets/motion-sensor.png";
              break;
            case "13":
              deviceName = "سنسور دود";
              deviceImage = "assets/smoke-sensor.png";
              break;
            case "14":
              deviceName = "سنسور در و پنجره";
              deviceImage = "assets/door-window-sensor.png";
              break;
            case "11":
              deviceName = "سنسور دما و رطوبت";
              deviceImage = "assets/temp-humidity-sensor.jpg";
              break;
            case "5":
              deviceName = "سر لامپی";
              deviceImage = "assets/lamp-head.png";
              break;
            case "9":
              deviceName = "هاب IR";
              deviceImage = "assets/unknown-device.png";
              break;
            case "7":
              deviceName = "هاب اصلی";
              deviceImage = "assets/unknown-device.png";
              break;
            default:
              deviceName = "دستگاه ناشناخته";
              deviceImage = "assets/unknown-device.png";
              break;
          }
          deviceData = {
            "name": deviceName,
            "deviceId": receivedDeviceId,
            "image": deviceImage,
            "deviceInfo": deviceInfo,
          };
        } else {
          // کلیدهای لمسی
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
        });
      } else if (!_isLearning &&
          !["12", "13", "14", "11", "5", "9", "7"].contains(deviceInfo)) {
        // فقط برای کلیدهای لمسی وضعیت به‌روزرسانی شود
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

      bool deviceExists = Provider.of<DeviceProvider>(context, listen: false)
          .getDevices(widget.itemName)
          .any((device) => device["deviceId"] == receivedDeviceId);

      String deviceName;
      String deviceImage;
      Map<String, String> deviceData;
      int poleCount = 0;

      // سنسورها و دستگاه‌های ویژه
      if (["12", "13", "14", "11", "5", "9", "7"].contains(deviceInfo)) {
        switch (deviceInfo) {
          case "12":
            deviceName = "تشخیص حرکت";
            deviceImage = "assets/motion-sensor.png";
            break;
          case "13":
            deviceName = "سنسور دود";
            deviceImage = "assets/smoke-sensor.png";
            break;
          case "14":
            deviceName = "سنسور در و پنجره";
            deviceImage = "assets/door-window-sensor.png";
            break;
          case "11":
            deviceName = "سنسور دما و رطوبت";
            deviceImage = "assets/temp-humidity-sensor.png";
            break;
          case "5":
            deviceName = "سر لامپی";
            deviceImage = "assets/lamp-head.png";
            break;
          case "9":
            deviceName = "هاب IR";
            deviceImage = "assets/unknown-device.jpg";
            break;
          case "7":
            deviceName = "هاب اصلی";
            deviceImage = "assets/unknown-device.jpg";
            break;
          default:
            deviceName = "دستگاه ناشناخته";
            deviceImage = "assets/unknown-device.jpg";
            break;
        }
        deviceData = {
          "name": deviceName,
          "deviceId": receivedDeviceId,
          "image": deviceImage,
          "deviceInfo": deviceInfo,
        };
      } else {
        // کلیدهای لمسی
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

      // فقط برای کلیدهای لمسی وضعیت به‌روزرسانی شود
      if (!["12", "13", "14", "11", "5", "9", "7"].contains(deviceInfo)) {
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

  _sendClearCommand() async {
    String command = "CLEAR\r";
    bool isMessageSent = await _serialService.write(command);
    debugPrint("Is CLEAR Command Sent: $isMessageSent");
  }

  void _toggleDarkMode() {
    Provider.of<ThemeProvider>(context, listen: false).toggleTheme();
  }

  // Show confirmation dialog for device deletion
  void _showDeleteDeviceDialog(String deviceId, String deviceName) {
    showDialog(
      context: context,
      builder: (context) {
        final themeProvider = Provider.of<ThemeProvider>(context);
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.0),
          ),
          backgroundColor: themeProvider.isDarkMode
              ? Colors.grey[850]
              : Colors.white,
          title: Text(
            'حذف دستگاه',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: themeProvider.isDarkMode
                  ? Colors.yellow[300]
                  : Colors.black,
            ),
          ),
          content: Text(
            'آیا مطمئن هستید که می‌خواهید دستگاه "$deviceName" را حذف کنید؟',
            style: TextStyle(
              color: themeProvider.isDarkMode
                  ? Colors.grey[300]
                  : Colors.grey[700],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('لغو', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () {
                Provider.of<DeviceProvider>(
                  context,
                  listen: false,
                ).removeDevice(deviceId, widget.itemName);
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('دستگاه $deviceName با موفقیت حذف شد'),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.0),
                ),
              ),
              child: const Text('حذف', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  void _showAddDeviceDialog() {
    _deviceIdController.clear();
    _selectedDeviceInfo = '61'; // ریست به پیش‌فرض

    showDialog(
      context: context,
      builder: (context) {
        final themeProvider = Provider.of<ThemeProvider>(context);
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16.0),
              ),
              backgroundColor: themeProvider.isDarkMode
                  ? Colors.grey[850]
                  : Colors.white,
              title: Text(
                'افزودن دستی دستگاه',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: themeProvider.isDarkMode
                      ? Colors.yellow[300]
                      : Colors.black,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // انتخاب نوع دستگاه
                    Text(
                      'نوع دستگاه:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: themeProvider.isDarkMode
                            ? Colors.grey[300]
                            : Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: themeProvider.isDarkMode
                              ? Colors.grey[600]!
                              : Colors.grey[400]!,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedDeviceInfo,
                          isExpanded: true,
                          dropdownColor: themeProvider.isDarkMode
                              ? Colors.grey[800]
                              : Colors.white,
                          style: TextStyle(
                            color: themeProvider.isDarkMode
                                ? Colors.grey[300]
                                : Colors.grey[700],
                          ),
                          items: _deviceTypes.map((device) {
                            return DropdownMenuItem<String>(
                              value: device['value'],
                              child: Row(
                                children: [
                                  Image.asset(
                                    device['image']!,
                                    width: 24,
                                    height: 24,
                                    fit: BoxFit.contain,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      device['name']!,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setDialogState(() {
                              _selectedDeviceInfo = value!;
                            });
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // وارد کردن Device ID
                    Text(
                      'شناسه دستگاه (Device ID):',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: themeProvider.isDarkMode
                            ? Colors.grey[300]
                            : Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _deviceIdController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(10), // محدود کردن طول
                      ],
                      style: TextStyle(
                        color: themeProvider.isDarkMode
                            ? Colors.grey[300]
                            : Colors.grey[700],
                      ),
                      decoration: InputDecoration(
                        hintText: 'مثال: 12345',
                        hintStyle: TextStyle(
                          color: themeProvider.isDarkMode
                              ? Colors.grey[500]
                              : Colors.grey[400],
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: themeProvider.isDarkMode
                                ? Colors.grey[600]!
                                : Colors.grey[400]!,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: themeProvider.isDarkMode
                                ? Colors.grey[600]!
                                : Colors.grey[400]!,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: themeProvider.isDarkMode
                                ? Colors.yellow[300]!
                                : Colors.amber[700]!,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text(
                    'لغو',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    _addDeviceManually();
                    Navigator.of(context).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: themeProvider.isDarkMode
                        ? Colors.yellow[300]
                        : Colors.amber[700],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.0),
                    ),
                  ),
                  child: const Text(
                    'افزودن',
                    style: TextStyle(color: Colors.black),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _addDeviceManually() {
    String inputDeviceId = _deviceIdController.text.trim();

    // بررسی خالی نبودن Device ID
    if (inputDeviceId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("لطفاً شناسه دستگاه را وارد کنید")),
      );
      return;
    }

    // بررسی تکراری نبودن Device ID
    bool deviceExists = Provider.of<DeviceProvider>(context, listen: false)
        .getDevices(widget.itemName)
        .any((device) => device["deviceId"] == inputDeviceId);

    if (deviceExists) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("دستگاه با این شناسه قبلاً اضافه شده است"),
        ),
      );
      return;
    }

    // پیدا کردن اطلاعات دستگاه انتخاب شده
    final selectedDevice = _deviceTypes.firstWhere(
      (device) => device['value'] == _selectedDeviceInfo,
    );

    String deviceName = selectedDevice['name']!;
    String deviceImage = selectedDevice['image']!;
    Map<String, String> deviceData;

    // ایجاد deviceData بر اساس نوع دستگاه
    if (["12", "13", "14", "11", "5", "9", "7"].contains(_selectedDeviceInfo)) {
      // سنسورها و دستگاه‌های ویژه
      deviceData = {
        "name": deviceName,
        "deviceId": inputDeviceId,
        "image": deviceImage,
        "deviceInfo": _selectedDeviceInfo,
      };
    } else {
      // کلیدهای لمسی
      int poleCount = 0;
      switch (_selectedDeviceInfo) {
        case "66":
          poleCount = 6;
          break;
        case "64":
          poleCount = 4;
          break;
        case "63":
          poleCount = 3;
          break;
        case "62":
          poleCount = 2;
          break;
        case "61":
          poleCount = 1;
          break;
        default:
          poleCount = 1;
          break;
      }
      deviceData = {
        "name": deviceName,
        "deviceId": inputDeviceId,
        "image": deviceImage,
        "poleCount": poleCount.toString(),
        "deviceInfo": _selectedDeviceInfo,
      };
    }

    // افزودن دستگاه
    Provider.of<DeviceProvider>(
      context,
      listen: false,
    ).addDevice(deviceData, widget.itemName);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('دستگاه $deviceName با موفقیت اضافه شد')),
    );

    debugPrint("Device manually added: $deviceName with ID $inputDeviceId");
  }

  @override
  void dispose() {
    _serialSubscription?.cancel();
    _receiveTimer?.cancel();
    _deviceIdController.dispose();
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
          IconButton(
            icon: Icon(
              Icons.restore_from_trash,
              color: Colors.white,
              size: isTablet ? 28 : 24,
            ),
            tooltip: 'پاک کردن',
            onPressed: _sendClearCommand,
          ),
          IconButton(
            icon: Icon(
              Icons.add_circle_outline,
              color: Colors.white,
              size: isTablet ? 28 : 24,
            ),
            tooltip: 'افزودن دستی دستگاه',
            onPressed: _showAddDeviceDialog,
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
                padding: EdgeInsets.all(isTablet ? 20.0 : 16.0),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: _getCrossAxisCount(context),
                  crossAxisSpacing: isTablet ? 16.0 : 12.0,
                  mainAxisSpacing: isTablet ? 16.0 : 12.0,
                  childAspectRatio: _getChildAspectRatio(context),
                ),
                itemCount: deviceProvider.getDevices(widget.itemName).length,
                itemBuilder: (context, index) {
                  final device = deviceProvider.getDevices(
                    widget.itemName,
                  )[index];
                  return Stack(
                    children: [
                      GestureDetector(
                        onTap: () {
                          if ([
                            "13",
                            "14",
                            "12",
                          ].contains(device["deviceInfo"])) {
                            // برای سنسورها به صفحه سنسور برو
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => GasSensorPage(
                                  // یا صفحه مخصوص سنسورها
                                  deviceId: device["deviceId"]!,
                                  deviceName: device["name"]!,
                                ),
                              ),
                            );
                          } else if (device["deviceInfo"] == "11") {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => TemperatureAndHumidity(
                                  deviceName: device["name"]!,
                                ),
                              ),
                            );
                          } else if ([
                            "5",
                            "9",
                            "7",
                          ].contains(device["deviceInfo"])) {
                            // برای هاب‌ها و سر لامپی به صفحه مدیریت خاص برو
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
                          } else {
                            // برای کلیدهای لمسی
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
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          child: Card(
                            elevation: themeProvider.isDarkMode ? 8.0 : 6.0,
                            shadowColor: themeProvider.isDarkMode
                                ? Colors.black54
                                : Colors.grey.withOpacity(0.3),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                isTablet ? 20.0 : 16.0,
                              ),
                              side: BorderSide(
                                color: themeProvider.isDarkMode
                                    ? Colors.grey[700]!
                                    : Colors.grey[300]!,
                                width: 0.5,
                              ),
                            ),
                            color: themeProvider.isDarkMode
                                ? Colors.grey[850]
                                : Colors.white,
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: isTablet ? 16 : 12,
                                vertical: isTablet ? 20 : 16,
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Container(
                                    height: isTablet ? 100 : 70,
                                    width: isTablet ? 100 : 70,
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: themeProvider.isDarkMode
                                          ? Colors.grey[800]
                                          : Colors.grey[100],
                                      borderRadius: BorderRadius.circular(
                                        isTablet ? 16 : 12,
                                      ),
                                      border: Border.all(
                                        color: themeProvider.isDarkMode
                                            ? Colors.grey[600]!
                                            : Colors.grey[300]!,
                                        width: 1,
                                      ),
                                    ),
                                    child: Image.asset(
                                      device["image"]!,
                                      fit: BoxFit.contain,
                                      errorBuilder:
                                          (context, error, stackTrace) {
                                            return Icon(
                                              Icons.device_unknown,
                                              size: isTablet ? 50 : 35,
                                              color: themeProvider.isDarkMode
                                                  ? Colors.grey[500]
                                                  : Colors.grey[600],
                                            );
                                          },
                                    ),
                                  ),
                                  SizedBox(height: isTablet ? 16.0 : 12.0),
                                  Container(
                                    width: double.infinity,
                                    child: Text(
                                      device["name"]!,
                                      style: TextStyle(
                                        fontSize: isTablet ? 18 : 14,
                                        fontWeight: FontWeight.bold,
                                        color: themeProvider.isDarkMode
                                            ? Colors.grey[100]
                                            : Colors.grey[800],
                                        height: 1.2,
                                      ),
                                      textAlign: TextAlign.center,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  SizedBox(height: isTablet ? 8.0 : 6.0),
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: isTablet ? 12 : 8,
                                      vertical: isTablet ? 6 : 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: themeProvider.isDarkMode
                                          ? Colors.amber[800]?.withOpacity(0.2)
                                          : Colors.amber[100],
                                      borderRadius: BorderRadius.circular(
                                        isTablet ? 12 : 8,
                                      ),
                                      border: Border.all(
                                        color: themeProvider.isDarkMode
                                            ? Colors.amber[600]!
                                            : Colors.amber[300]!,
                                        width: 1,
                                      ),
                                    ),
                                    child: Text(
                                      "ID: ${device["deviceId"]!}",
                                      style: TextStyle(
                                        fontSize: isTablet ? 13 : 11,
                                        fontWeight: FontWeight.w600,
                                        color: themeProvider.isDarkMode
                                            ? Colors.amber[300]
                                            : Colors.amber[800],
                                        letterSpacing: 0.5,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: isTablet ? 12 : 8,
                        right: isTablet ? 12 : 8,
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(
                              isTablet ? 12 : 8,
                            ),
                          ),
                          child: IconButton(
                            icon: Icon(
                              Icons.close_rounded,
                              color: Colors.red[600],
                              size: isTablet ? 23 : 20,
                            ),
                            onPressed: () => _showDeleteDeviceDialog(
                              device["deviceId"]!,
                              device["name"]!,
                            ),
                            padding: EdgeInsets.all(isTablet ? 8 : 4),
                            tooltip: 'حذف دستگاه',
                          ),
                        ),
                      ),
                    ],
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

  double _getChildAspectRatio(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width > 1200) return 0.85; // for desktop
    if (width > 600) return 0.9; // for tablet
    return 1.0; // for mobile
  }
}
