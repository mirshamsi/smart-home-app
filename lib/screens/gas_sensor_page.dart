import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:provider/provider.dart';
import 'package:topaz/providers/theme_provider.dart';
import 'package:topaz/services/serial_service.dart';

class GasSensorPage extends StatefulWidget {
  final String deviceId;
  final String deviceName;

  const GasSensorPage({required this.deviceId, required this.deviceName});

  @override
  _GasSensorPageState createState() => _GasSensorPageState();
}

class _GasSensorPageState extends State<GasSensorPage> {
  final SerialService _serialService = SerialService();
  bool isGasDetected = false;
  int gasLevel = 0; // Store the stateCode (gas level)
  StreamSubscription? _serialSubscription;
  List<int> receivedBytesBuffer = [];
  Timer? _updateTimer;
  late Box _gasSensorBox; // Hive box for storing gas level

  @override
  void initState() {
    super.initState();
    _initializeHive();
    _loadGasLevel();
    _setupSerialListener();
    _startPeriodicUpdate();
  }

  // Initialize Hive and open the gasSensorData box
  Future<void> _initializeHive() async {
    _gasSensorBox = await Hive.openBox('gasSensorData');
  }

  // Load the stored gas level from Hive
  Future<void> _loadGasLevel() async {
    await _initializeHive();
    final storedGasLevel = _gasSensorBox.get(widget.deviceId, defaultValue: 0);
    setState(() {
      gasLevel = storedGasLevel;
      isGasDetected = gasLevel > 0;
    });
  }

  // Save the gas level to Hive
  Future<void> _saveGasLevel(int level) async {
    await _gasSensorBox.put(widget.deviceId, level);
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
          _processReceivedMessage(message);
        }
      }
    });
  }

  void _processReceivedMessage(String message) {
    RegExp regex = RegExp(r"#(\d+)A(\d+)B(\d+)C(\d+)D(\d+)E(\d+)F");
    Match? match = regex.firstMatch(message);
    if (match != null &&
        match.group(3) == "12" &&
        match.group(4) == widget.deviceId) {
      int newGasLevel = int.parse(match.group(1)!);
      setState(() {
        gasLevel = newGasLevel;
        isGasDetected = gasLevel > 0;
      });
      _saveGasLevel(gasLevel); // Persist the new gas level
    }
  }

  // Start a timer to update the UI every 30 seconds
  void _startPeriodicUpdate() {
    _updateTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      setState(() {
        // UI will update with the current gasLevel (already updated by _processReceivedMessage or loaded from Hive)
      });
    });
  }

  @override
  void dispose() {
    _serialSubscription?.cancel();
    _updateTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isTablet = MediaQuery.of(context).size.width > 600;

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
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(isTablet ? 24.0 : 16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  'assets/sensor-gaz.png',
                  height: isTablet ? 200 : 150,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 24.0),
                Text(
                  widget.deviceName,
                  style: TextStyle(
                    fontSize: isTablet ? 28 : 24,
                    fontWeight: FontWeight.bold,
                    color: themeProvider.isDarkMode
                        ? Colors.grey[200]
                        : Colors.grey[900],
                  ),
                ),
                const SizedBox(height: 16.0),
                Text(
                  'شناسه دستگاه: ${widget.deviceId}',
                  style: TextStyle(
                    fontSize: isTablet ? 18 : 16,
                    color: themeProvider.isDarkMode
                        ? Colors.grey[400]
                        : Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 24.0),
                Container(
                  padding: EdgeInsets.all(isTablet ? 24.0 : 16.0),
                  decoration: BoxDecoration(
                    color: isGasDetected ? Colors.red[100] : Colors.green[100],
                    borderRadius: BorderRadius.circular(16.0),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 8.0,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    'میزان گاز: $gasLevel ppm',
                    style: TextStyle(
                      fontSize: isTablet ? 24 : 20,
                      fontWeight: FontWeight.bold,
                      color: isGasDetected
                          ? Colors.red[900]
                          : Colors.green[900],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
