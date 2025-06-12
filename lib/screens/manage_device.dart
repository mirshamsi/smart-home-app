import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_serial_communication/models/device_info.dart';
import 'package:flutter_serial_communication/flutter_serial_communication.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:topaz/models/shedule_model.dart';
import 'package:topaz/providers/connection_provider.dart';
import 'package:topaz/providers/device_provider.dart';
import 'package:topaz/providers/theme_provider.dart';
import 'package:topaz/services/serial_service.dart';
import 'package:topaz/widgets/schedule_settings.dart';
import 'package:topaz/widgets/smart_device_box.dart';

class ManageDevice extends StatefulWidget {
  final String deviceId;
  final String itemName;
  final String deviceInfo;

  const ManageDevice({
    required this.deviceId,
    required this.itemName,
    required this.deviceInfo,
  });

  @override
  _ManageDeviceState createState() => _ManageDeviceState();
}

class _ManageDeviceState extends State<ManageDevice>
    with WidgetsBindingObserver {
  final SerialService _serialService = SerialService();
  final _flutterSerialCommunicationPlugin = FlutterSerialCommunication();
  Map<int, ScheduleModel> relaySchedules = {};
  List<int> receivedBytesBuffer = [];
  List<String> receivedMessages = [];
  List<String> sentMessages = [];
  List mySmartDevices = [];
  StreamSubscription? _serialSubscription;
  bool _isSending = false;
  Timer? _scheduleCheckerTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initialize();
  }

  Future<void> _initialize() async {
    await loadSchedules();
    await _reconnectIfNeeded();
    _startScheduleChecker();
    await _requestSwitchStatus(); // Send command once on page entry

    final deviceProvider = Provider.of<DeviceProvider>(context, listen: false);
    await deviceProvider.loadButtonStatesFromHive(widget.deviceId);
    await deviceProvider.loadPacketNumbersFromHive(widget.deviceId);
    _updateSmartDevices(deviceProvider);
    _setupSerialListener();
  }

  Future<void> _requestSwitchStatus() async {
    if (_isSending ||
        !Provider.of<ConnectionProvider>(context, listen: false).isConnected) {
      return;
    }

    setState(() {
      _isSending = true;
    });

    try {
      final deviceProvider = Provider.of<DeviceProvider>(
        context,
        listen: false,
      );
      int lastPacketNumber = deviceProvider.getLastPacketNumber(
        widget.deviceId,
        0,
      );
      int newPacketNumber = (lastPacketNumber + 1) % 10000;
      String command = "#3A0B7C7D${widget.deviceId}E${newPacketNumber}F\n";
      debugPrint("دستور ارسالی برای وضعیت: $command");

      bool isMessageSent = await _serialService
          .write(command)
          .timeout(
            const Duration(seconds: 5),
            onTimeout: () {
              debugPrint("مهلت زمانی ارسال دستور به پایان رسید.");
              return false;
            },
          );

      if (isMessageSent) {
        debugPrint("دستور وضعیت با موفقیت ارسال شد");
        deviceProvider.updateLastPacketNumber(
          widget.deviceId,
          0,
          newPacketNumber,
        );
        setState(() {
          sentMessages.add(command.trim());
          if (sentMessages.length > 10) sentMessages.removeAt(0);
        });
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("ارسال دستور ناموفق بود")));
      }
    } catch (e) {
      debugPrint("خطای غیرمنتظره در ارسال دستور: $e");
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("خطای غیرمنتظره: $e")));
    } finally {
      setState(() {
        _isSending = false;
      });
    }
  }

  void _updateSmartDevices(DeviceProvider deviceProvider) {
    final device = deviceProvider.getDeviceById(
      widget.deviceId,
      widget.itemName,
    );
    if (device.isNotEmpty) {
      int poleCount = int.parse(device["poleCount"] ?? "1");
      setState(() {
        mySmartDevices = List.generate(
          poleCount,
          (index) => [
            "تاچ ${index + 1}",
            "assets/lightbulb.png",
            (deviceProvider.getButtonStates(widget.deviceId)[index + 1] ??
                    "0") ==
                "1",
          ],
        );
      });
    }
  }

  void _startScheduleChecker() {
    _scheduleCheckerTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (mounted) {
        _checkSchedules();
      }
    });
  }

  void _checkSchedules() {
    final now = TimeOfDay.now();
    final deviceProvider = Provider.of<DeviceProvider>(context, listen: false);

    relaySchedules.forEach((relay, schedule) {
      if (schedule.onTime != null &&
          now.hour == schedule.onTime!.hour &&
          now.minute == schedule.onTime!.minute &&
          !schedule.onTriggered) {
        if ((deviceProvider.getButtonStates(widget.deviceId)[relay] ?? "0") ==
            "0") {
          _toggleCommand(relay, true);
        }
        setState(() {
          schedule.onTriggered = true;
        });
        saveSchedules();
      } else if (schedule.onTime != null &&
          (now.hour != schedule.onTime!.hour ||
              now.minute != schedule.onTime!.minute)) {
        if (schedule.onTriggered) {
          setState(() {
            schedule.onTriggered = false;
          });
          saveSchedules();
        }
      }

      if (schedule.offTime != null &&
          now.hour == schedule.offTime!.hour &&
          now.minute == schedule.offTime!.minute &&
          !schedule.offTriggered) {
        if ((deviceProvider.getButtonStates(widget.deviceId)[relay] ?? "0") ==
            "1") {
          _toggleCommand(relay, false);
        }
        setState(() {
          schedule.offTriggered = true;
        });
        saveSchedules();
      } else if (schedule.offTime != null &&
          (now.hour != schedule.offTime!.hour ||
              now.minute != schedule.offTime!.minute)) {
        if (schedule.offTriggered) {
          setState(() {
            schedule.offTriggered = false;
          });
          saveSchedules();
        }
      }
    });
  }

  Future<void> saveSchedules() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    Map<String, dynamic> scheduleMap = relaySchedules.map(
      (key, value) => MapEntry(key.toString(), value.toJson()),
    );
    await prefs.setString(
      'schedules_${widget.deviceId}',
      jsonEncode(scheduleMap),
    );
  }

  Future<void> loadSchedules() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? scheduleJson = prefs.getString('schedules_${widget.deviceId}');
    if (scheduleJson != null) {
      Map<String, dynamic> scheduleMap = jsonDecode(scheduleJson);
      setState(() {
        relaySchedules = scheduleMap.map(
          (key, value) =>
              MapEntry(int.parse(key), ScheduleModel.fromJson(value)),
        );
      });
    }
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
      String stateString = match.group(1)!; 
      debugPrint("پیام پردازش شد: وضعیت تاچ‌ها $stateString");

      Provider.of<DeviceProvider>(
        context,
        listen: false,
      ).updateButtonStatesFromString(widget.deviceId, stateString);

      setState(() {
        final deviceProvider = Provider.of<DeviceProvider>(
          context,
          listen: false,
        );
        for (int i = 0; i < mySmartDevices.length; i++) {
          mySmartDevices[i][2] =
              (deviceProvider.getButtonStates(widget.deviceId)[i + 1] ?? "0") ==
              "1";
        }
      });
    } else {
      debugPrint("پیام نامعتبر یا deviceId مطابقت ندارد: $message");
    }
  }

  Future<void> _toggleCommand(int relayNumber, bool newValue) async {
    if (_isSending) {
      debugPrint("ارسال دستور در حال انجام است، لطفاً منتظر بمانید...");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("ارسال دستور در حال انجام است")),
      );
      return;
    }

    final connectionProvider = Provider.of<ConnectionProvider>(
      context,
      listen: false,
    );
    if (!connectionProvider.isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("لطفاً ابتدا دستگاه را متصل کنید")),
      );
      await _reconnectIfNeeded();
      if (!connectionProvider.isConnected) return;
    }

    setState(() {
      _isSending = true;
    });

    try {
      final deviceProvider = Provider.of<DeviceProvider>(
        context,
        listen: false,
      );
      int lastPacketNumber = deviceProvider.getLastPacketNumber(
        widget.deviceId,
        relayNumber,
      );
      int newPacketNumber = (lastPacketNumber + 1) % 10000;

      String command =
          "#${newValue ? '1' : '0'}A${relayNumber}B7C7D${widget.deviceId}E${newPacketNumber}F\n";
      debugPrint("دستور ارسالی: $command");

      bool isMessageSent = await _serialService
          .write(command)
          .timeout(
            const Duration(seconds: 5),
            onTimeout: () {
              debugPrint("مهلت زمانی ارسال دستور به پایان رسید.");
              return false;
            },
          );

      if (isMessageSent) {
        debugPrint("دستور با موفقیت ارسال شد");
        deviceProvider.updateLastPacketNumber(
          widget.deviceId,
          relayNumber,
          newPacketNumber,
        );
        setState(() {
          sentMessages.add(command.trim());
          if (sentMessages.length > 10) sentMessages.removeAt(0);
          deviceProvider.updateButtonState(
            widget.deviceId,
            relayNumber,
            newValue ? "1" : "0",
          );
          mySmartDevices[relayNumber - 1][2] = newValue;

          if (relaySchedules.containsKey(relayNumber)) {
            if (newValue && relaySchedules[relayNumber]!.onTime != null) {
              relaySchedules[relayNumber]!.onTriggered = true;
            } else if (!newValue &&
                relaySchedules[relayNumber]!.offTime != null) {
              relaySchedules[relayNumber]!.offTriggered = true;
            }
          }
        });
        await saveSchedules();
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("ارسال دستور ناموفق بود")));
      }
    } catch (e) {
      debugPrint("خطای غیرمنتظره در ارسال دستور: $e");
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("خطای غیرمنتظره: $e")));
    } finally {
      setState(() {
        _isSending = false;
      });
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

  void _showScheduleBottomSheet(int relayNumber) {
    relaySchedules[relayNumber] ??= ScheduleModel();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.4,
        minChildSize: 0.2,
        maxChildSize: 0.6,
        expand: false,
        builder: (context, scrollController) => StatefulBuilder(
          builder: (BuildContext context, StateSetter bottomSheetSetState) {
            return SingleChildScrollView(
              controller: scrollController,
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 40,
                      height: 5,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    Text(
                      "زمان‌بندی ${mySmartDevices[relayNumber - 1][0]}",
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildModernTimeBox(
                          context,
                          "روشن",
                          relaySchedules[relayNumber]!.onTime,
                          () async {
                            TimeOfDay? picked = await showTimePicker(
                              context: context,
                              initialTime: TimeOfDay.now(),
                              builder: (context, child) => MediaQuery(
                                data: MediaQuery.of(
                                  context,
                                ).copyWith(alwaysUse24HourFormat: true),
                                child: child!,
                              ),
                            );
                            if (picked != null) {
                              bottomSheetSetState(() {
                                relaySchedules[relayNumber]!.onTime = picked;
                                relaySchedules[relayNumber]!.onTriggered =
                                    false;
                              });
                              setState(() {});
                              await saveSchedules();
                            }
                          },
                          Colors.green,
                        ),
                        _buildModernTimeBox(
                          context,
                          "خاموش",
                          relaySchedules[relayNumber]!.offTime,
                          () async {
                            TimeOfDay? picked = await showTimePicker(
                              context: context,
                              initialTime: TimeOfDay.now(),
                              builder: (context, child) => MediaQuery(
                                data: MediaQuery.of(
                                  context,
                                ).copyWith(alwaysUse24HourFormat: true),
                                child: child!,
                              ),
                            );
                            if (picked != null) {
                              bottomSheetSetState(() {
                                relaySchedules[relayNumber]!.offTime = picked;
                                relaySchedules[relayNumber]!.offTriggered =
                                    false;
                              });
                              setState(() {});
                              await saveSchedules();
                            }
                          },
                          Colors.red,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton.icon(
                          onPressed: () {
                            setState(() {
                              relaySchedules[relayNumber]!.onTime = null;
                              relaySchedules[relayNumber]!.offTime = null;
                              relaySchedules[relayNumber]!.onTriggered = false;
                              relaySchedules[relayNumber]!.offTriggered = false;
                            });
                            saveSchedules();
                            Navigator.pop(context);
                          },
                          icon: const Icon(Icons.delete_outline, size: 20),
                          label: const Text("پاک کردن"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red.shade50,
                            foregroundColor: Colors.red.shade700,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 20),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blueGrey.shade50,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 30,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            "بستن",
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.blueGrey,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildModernTimeBox(
    BuildContext context,
    String label,
    TimeOfDay? time,
    VoidCallback onTap,
    Color color,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 120,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: color.withOpacity(0.3), width: 1),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              time?.format(context) ?? "--:--",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.amber[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    debugPrint("Lifecycle State: $state");
    if (state == AppLifecycleState.resumed) {
      _reconnectIfNeeded();
      _setupSerialListener();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _serialSubscription?.cancel();
    }
  }

  @override
  void dispose() {
    _serialSubscription?.cancel();
    _scheduleCheckerTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final deviceProvider = Provider.of<DeviceProvider>(context);
    _updateSmartDevices(deviceProvider);

    final device = deviceProvider.getDeviceById(
      widget.deviceId,
      widget.itemName,
    );
    int poleCount = device.isNotEmpty
        ? int.parse(device["poleCount"] ?? "1")
        : 0;

    if (poleCount == 0) {
      return Scaffold(
        appBar: AppBar(
          title: Text("مدیریت دستگاه ${widget.deviceId}"),
          backgroundColor: themeProvider.isDarkMode
              ? Colors.grey[900]
              : Colors.amber,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: const Center(child: Text("دستگاهی برای نمایش وجود ندارد")),
      );
    }

    final double screenWidth = MediaQuery.of(context).size.width;
    int crossAxisCount = screenWidth > 600 ? 4 : 2;
    double childAspectRatio = screenWidth > 600 ? 1 / 1.5 : 1 / 1.3;

    return Scaffold(
      appBar: AppBar(
        title: Text("مدیریت دستگاه ${widget.deviceId}"),
        backgroundColor: themeProvider.isDarkMode
            ? Colors.grey[900]
            : Colors.amber,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
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
          child: ListView(
            children: [
              const SizedBox(height: 16.0),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: screenWidth > 600 ? 50 : 25,
                  vertical: screenWidth > 600 ? 30 : 25,
                ),
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: mySmartDevices.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    childAspectRatio: childAspectRatio,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                  ),
                  itemBuilder: (context, index) {
                    return SmartDeviceBox(
                      key: Key('${widget.deviceId}_${index + 1}'),
                      smartDeviceName: mySmartDevices[index][0],
                      iconPath: mySmartDevices[index][1],
                      powerOn: mySmartDevices[index][2],
                      onChanged: (value) => _toggleCommand(index + 1, value),
                      relayNumber: index + 1,
                      deviceId: widget.deviceId,
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),
              ScheduleSettings(
                smartDevices: mySmartDevices,
                relaySchedules: relaySchedules,
                onScheduleTap: _showScheduleBottomSheet,
              ),
              const SizedBox(height: 20),
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
              const SizedBox(height: 20),
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
                      "پیام‌های ارسالی:",
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
                      child: sentMessages.isEmpty
                          ? Text(
                              "هیچ پیامی ارسال نشده است",
                              style: TextStyle(
                                fontSize: 16,
                                color: themeProvider.isDarkMode
                                    ? Colors.grey[400]
                                    : Colors.black54,
                              ),
                            )
                          : ListView.builder(
                              itemCount: sentMessages.length,
                              itemBuilder: (context, index) {
                                return Text(
                                  sentMessages[index],
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
