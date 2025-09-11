import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:topaz/providers/theme_provider.dart';

class DoorsWindowsPage extends StatefulWidget {
  final String deviceName;
  const DoorsWindowsPage({required this.deviceName});

  @override
  _DoorsWindowsPageState createState() => _DoorsWindowsPageState();
}

class _DoorsWindowsPageState extends State<DoorsWindowsPage> {
  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final items = [
      {"name": "در ورودی", "status": "باز"},
      {"name": "پنجره اتاق خواب", "status": "بسته"},
      {"name": "بالکن", "status": "بسته"},
    ];

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
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          bool isOpen = item["status"] == "باز";

          return Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 3,
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: Icon(
                isOpen ? Icons.door_front_door : Icons.verified_user,
                color: isOpen ? Colors.red : Colors.green,
                size: 40,
              ),
              title: Text(item["name"]!),
              subtitle: Text("وضعیت: ${item["status"]}"),
              trailing: IconButton(
                icon: const Icon(Icons.lock),
                onPressed: () {},
              ),
            ),
          );
        },
      ),
    );
  }
}
