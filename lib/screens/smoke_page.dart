import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:topaz/providers/theme_provider.dart';

class SmokePage extends StatefulWidget {
  final String deviceName;
  const SmokePage({required this.deviceName});

  @override
  _SmokePageState createState() => _SmokePageState();
}

class _SmokePageState extends State<SmokePage> {
  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    bool smokeDetected = true;

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
        child: Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 5,
          child: Container(
            padding: const EdgeInsets.all(40),
            width: 280,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.smoke_free,
                  size: 80,
                  color: smokeDetected ? Colors.red : Colors.green,
                ),
                const SizedBox(height: 15),
                Text(
                  smokeDetected ? "دود شناسایی شد!" : "محیط سالم است",
                  style: TextStyle(
                    fontSize: 20,
                    color: smokeDetected ? Colors.red : Colors.green,
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.notifications),
                  label: const Text("تست هشدار"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
