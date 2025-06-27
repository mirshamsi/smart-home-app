import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_serial_communication/models/device_info.dart';
import 'package:topaz/models/item_device_model.dart';
import 'package:topaz/providers/connection_provider.dart';
import 'package:topaz/providers/device_provider.dart';
import 'package:topaz/providers/theme_provider.dart';
import 'package:topaz/screens/tab_screen.dart';
import 'package:topaz/services/hive_storage_service.dart';
import 'package:topaz/services/serial_service.dart';
import 'package:topaz/widgets/item_list_tile.dart';

class LiveRoom extends StatefulWidget {
  final String itemName;

  const LiveRoom({super.key, required this.itemName});

  @override
  _LiveRoomState createState() => _LiveRoomState();
}

class _LiveRoomState extends State<LiveRoom> with WidgetsBindingObserver {
  List<Map<String, String>> devices = [];
  final HiveStorageService _storageService = HiveStorageService();
  final TextEditingController _textController = TextEditingController();
  List<ItemDeviceModel> _items = [];
  final SerialService _serialService =
      SerialService(); // اضافه کردن SerialService
  List<int> receivedBytesBuffer = []; // بافر برای پیام‌های سریال
  List<String> receivedMessages = []; // لیست پیام‌های دریافتی
  StreamSubscription? _serialSubscription; // اشتراک برای گوش‌دهنده سریال

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
    _loadItems();
    _setupSerialListener();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    debugPrint("Lifecycle State (LiveRoom): $state");
    if (state == AppLifecycleState.resumed) {
      _checkAndConnectToDevice();
      _setupSerialListener();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _serialSubscription?.cancel();
    }
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

  Future<void> _loadItems() async {
    List<String> itemsJson = await _storageService.loadItems();
    setState(() {
      _items = itemsJson.map((item) => ItemDeviceModel(item)).toList();
    });
  }

  Future<void> _saveItems() async {
    List<String> itemsJson = _items.map((item) => item.name).toList();
    await _storageService.saveItems(itemsJson);
  }

  void _addItem(String name) {
    setState(() {
      _items.add(ItemDeviceModel(name));
    });
    _saveItems();
  }

  void _removeItem(int index) {
    setState(() {
      _items.removeAt(index);
    });
    _saveItems();
  }

  void _navigateToDetailScreen(String itemName) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => TabScreen(itemName: itemName)),
    );
  }

  void _showAddItemDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('اضافه کردن آیتم جدید'),
          content: TextField(
            controller: _textController,
            decoration: const InputDecoration(
              hintText: 'نام آیتم را وارد کنید',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('لغو'),
            ),
            ElevatedButton(
              onPressed: () {
                if (_textController.text.isNotEmpty) {
                  _addItem(_textController.text);
                  _textController.clear();
                  Navigator.of(context).pop();
                }
              },
              child: const Text('اضافه کردن'),
            ),
          ],
        );
      },
    );
  }

  void _toggleDarkMode() {
    Provider.of<ThemeProvider>(context, listen: false).toggleTheme();
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
          debugPrint("پیام دریافتی (LiveRoom): $message");
          setState(() {
            receivedMessages.add(message);
            _processReceivedMessage(message);
          });
        }
      }
    });
  }

  void _processReceivedMessage(String message) {
    RegExp regex = RegExp(r"#(\d)A(\d+)B(\d+)C(\d+)D(\d+)E(\d+)F");
    Match? match = regex.firstMatch(message);
    if (match != null) {
      String stateCode = match.group(1)!;
      String buttonCode = match.group(2)!;
      // String deviceInfo = match.group(3)!;
      String receivedDeviceId = match.group(4)!;
      bool newState = stateCode == "1";
      int relayNumber = int.parse(buttonCode);
      Provider.of<DeviceProvider>(
        context,
        listen: false,
      ).updateButtonStatesFromString(receivedDeviceId, stateCode);
      debugPrint(
        "وضعیت تاچ به‌روزرسانی شد: $receivedDeviceId, رله $relayNumber, حالت $newState",
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _textController.dispose();
    _serialSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer3<ConnectionProvider, DeviceProvider, ThemeProvider>(
      builder:
          (context, connectionProvider, deviceProvider, themeProvider, child) {
            final bool isTablet = MediaQuery.of(context).size.width > 600;

            return Scaffold(
              backgroundColor: themeProvider.isDarkMode
                  ? Colors.black12
                  : Colors.grey[200],
              appBar: AppBar(
                title: Text(
                  "محل نصب دستگاه",
                  style: TextStyle(
                    fontSize: isTablet ? 30 : 20,
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                backgroundColor: themeProvider.isDarkMode
                    ? Colors.grey[900]
                    : Colors.amber[700],
              ),
              body: SafeArea(
                child: Column(
                  children: [
                    Expanded(
                      child: Container(
                        color: themeProvider.isDarkMode
                            ? Colors.grey[850]
                            : Colors.grey[100],
                        child: ListView.builder(
                          padding: EdgeInsets.all(isTablet ? 16.0 : 8.0),
                          itemCount: _items.length,
                          itemBuilder: (context, index) {
                            return Card(
                              elevation: 2,
                              margin: EdgeInsets.symmetric(
                                vertical: 4,
                                horizontal: 8,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              color: themeProvider.isDarkMode
                                  ? Colors.grey[800]
                                  : Colors.white,
                              child: ItemListTile(
                                itemName: _items[index].name,
                                onDelete: () => _removeItem(index),
                                onTap: () =>
                                    _navigateToDetailScreen(_items[index].name),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              floatingActionButton: FloatingActionButton(
                backgroundColor: Colors.amber,
                shape: CircleBorder(),
                onPressed: _showAddItemDialog,
                child: Icon(Icons.add, size: 28),
                tooltip: 'اضافه کردن آیتم جدید',
                elevation: 6,
              ),
            );
          },
    );
  }
}
