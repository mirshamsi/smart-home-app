import 'package:hive_flutter/hive_flutter.dart';

class HiveStorageService {
  static const String _itemsKey = 'items';
  static const String _connectionStatusKey = 'connection_status';

  Future<List<String>> loadItems() async {
    final box = await Hive.openBox<List<String>>('items');
    final items = box.get(
      _itemsKey,
      defaultValue: ['آشپزخانه', 'پذیرایی', 'سرویس بهداشتی'],
    );
    if (items == null || items.isEmpty) {
      final defaultItems = ['آشپزخانه', 'پذیرایی', 'سرویس بهداشتی'];
      await box.put(_itemsKey, defaultItems);
      return defaultItems;
    }
    return items;
  }

  Future<void> saveItems(List<String> items) async {
    final box = await Hive.openBox<List<String>>('items');
    await box.put(_itemsKey, items);
  }

  Future<bool> loadConnectionStatus() async {
    final box = await Hive.openBox<bool>('connection');
    return box.get(_connectionStatusKey, defaultValue: false)!;
  }

  Future<void> saveConnectionStatus(bool status) async {
    final box = await Hive.openBox<bool>('connection');
    await box.put(_connectionStatusKey, status);
  }
}
