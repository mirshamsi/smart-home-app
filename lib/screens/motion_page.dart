import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:topaz/providers/theme_provider.dart';

class MotionPage extends StatefulWidget {
  final String deviceName;
  const MotionPage({required this.deviceName});

  @override
  _MotionPageState createState() => _MotionPageState();
}

class _MotionPageState extends State<MotionPage> {
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
                        Icons.motion_photos_on,
                        size: 80,
                        color: Colors.orange.shade600,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        "حرکت شناسایی شد!",
                        style: Theme.of(
                          context,
                        ).textTheme.headlineSmall?.copyWith(color: Colors.red),
                      ),
                      const SizedBox(height: 8),
                      Text("آخرین تشخیص: ۵ دقیقه پیش"),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 30),
              SwitchListTile(
                title: const Text("فعال‌سازی سنسور"),
                value: true,
                onChanged: (val) {},
                secondary: const Icon(Icons.sensors),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
