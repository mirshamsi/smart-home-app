// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'dart:convert';
// import 'package:flutter_serial_communication/flutter_serial_communication.dart';
// import 'package:flutter_serial_communication/models/device_info.dart';

// void main() {
//   runApp(const MyApp());
// }

// class MyApp extends StatefulWidget {
//   const MyApp({super.key});

//   @override
//   State<MyApp> createState() => _MyAppState();
// }

// class _MyAppState extends State<MyApp> {
//   final _flutterSerialCommunicationPlugin = FlutterSerialCommunication();
//   bool isConnected = false;
//   List<DeviceInfo> connectedDevices = [];
//   List<String> receivedMessages = [];
//   TextEditingController messageController = TextEditingController();
//   List<int> receivedBytesBuffer = []; // Buffer to accumulate bytes

//   @override
//   void initState() {
//     super.initState();

//     // Listener for receiving messages
//     _flutterSerialCommunicationPlugin
//         .getSerialMessageListener()
//         .receiveBroadcastStream()
//         .listen((event) {
//           receivedBytesBuffer.addAll(event); // Add incoming bytes to buffer

//           // Check for end of message (e.g., #...F)
//           int endIndex = -1;
//           for (int i = 0; i < receivedBytesBuffer.length; i++) {
//             if (receivedBytesBuffer[i] == 0x46) {
//               // ASCII code for 'F'
//               int startIndex = -1;
//               for (int j = i - 1; j >= 0; j--) {
//                 if (receivedBytesBuffer[j] == 0x23) {
//                   // ASCII code for '#'
//                   startIndex = j;
//                   endIndex = i;
//                   break;
//                 }
//               }
//               if (startIndex != -1) break;
//             }
//           }

//           if (endIndex != -1) {
//             List<int> completeMessageBytes = receivedBytesBuffer.sublist(
//               0,
//               endIndex + 1,
//             );
//             String message;
//             try {
//               message = utf8.decode(completeMessageBytes); // Decode using UTF-8
//             } catch (e) {
//               message = "Error decoding: $e"; // Handle decoding errors
//             }

//             receivedBytesBuffer.removeRange(
//               0,
//               endIndex + 1,
//             ); // Clear the processed message from buffer

//             message = message.trim(); // Remove whitespace and line endings

//             setState(() {
//               receivedMessages.add(message);
//             });
//             debugPrint("Received From Native: $message");
//           }
//         });

//     // Listener for connection status
//     _flutterSerialCommunicationPlugin
//         .getDeviceConnectionListener()
//         .receiveBroadcastStream()
//         .listen((event) {
//           setState(() {
//             isConnected = event;
//           });
//         });
//   }

//   _getAllConnectedDevicesButtonPressed() async {
//     List<DeviceInfo> newConnectedDevices =
//         await _flutterSerialCommunicationPlugin.getAvailableDevices();
//     setState(() {
//       connectedDevices = newConnectedDevices;
//     });
//   }

//   _connectButtonPressed(DeviceInfo deviceInfo) async {
//     bool isConnectionSuccess = await _flutterSerialCommunicationPlugin.connect(
//       deviceInfo,
//       115200,
//     );
//     debugPrint("Is Connection Success: $isConnectionSuccess");
//   }

//   _disconnectButtonPressed() async {
//     await _flutterSerialCommunicationPlugin.disconnect();
//     setState(() {
//       receivedMessages.clear();
//     });
//   }

//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       home: Scaffold(
//         appBar: AppBar(title: const Text('Flutter Serial Communication App')),
//         body: SingleChildScrollView(
//           child: Padding(
//             padding: const EdgeInsets.all(16.0),
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text("Is Connected: $isConnected"),
//                 const SizedBox(height: 16.0),
//                 ElevatedButton(
//                   onPressed: _getAllConnectedDevicesButtonPressed,
//                   child: const Text("Get All Connected Devices"),
//                 ),
//                 const SizedBox(height: 16.0),
//                 ...connectedDevices.asMap().entries.map((entry) {
//                   return Row(
//                     children: [
//                       Flexible(child: Text(entry.value.productName)),
//                       const SizedBox(width: 16.0),
//                       ElevatedButton(
//                         onPressed: () {
//                           _connectButtonPressed(entry.value);
//                         },
//                         child: const Text("Connect"),
//                       ),
//                     ],
//                   );
//                 }).toList(),
//                 const SizedBox(height: 16.0),
//                 if (isConnected) ...[
//                   ElevatedButton(
//                     onPressed: _disconnectButtonPressed,
//                     child: const Text("Disconnect"),
//                   ),
//                   const SizedBox(height: 16.0),
//                   const Text(
//                     "Status:",
//                     style: TextStyle(fontWeight: FontWeight.bold),
//                   ),
//                 ],
//               ],
//             ),
//           ),
//         ),
//       ),
//     );
//   }
// }

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:topaz/config/app_theme.dart';
import 'package:topaz/config/localization.dart';
import 'package:topaz/models/device_model.dart';
import 'package:topaz/models/shedule_model.dart';
import 'package:topaz/providers/connection_provider.dart';
import 'package:topaz/providers/device_provider.dart';
import 'package:topaz/providers/theme_provider.dart';
import 'package:topaz/screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  Hive.registerAdapter(DeviceModelAdapter());
  Hive.registerAdapter(ButtonStateModelAdapter());
  Hive.registerAdapter(PacketNumberModelAdapter());
  Hive.registerAdapter(ScheduleModelAdapter());

  FlutterForegroundTask.initCommunicationPort();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ConnectionProvider()),
        ChangeNotifierProvider(create: (_) => DeviceProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          locale: const Locale("fa", ""),
          localizationsDelegates: AppLocalization.localizationsDelegates,
          supportedLocales: AppLocalization.supportedLocales,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeProvider.isDarkMode
              ? ThemeMode.dark
              : ThemeMode.light,
          debugShowCheckedModeBanner: false,
          home: const HomeScreen(),
        );
      },
    );
  }
}
