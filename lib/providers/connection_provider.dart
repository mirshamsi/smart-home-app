import 'package:flutter/material.dart';

class ConnectionProvider extends ChangeNotifier {
  bool _isConnected = false;
  String? _connectedDeviceId;

  bool get isConnected => _isConnected;
  String? get connectedDeviceId => _connectedDeviceId;

  void setConnectionStatus(bool status, {String? deviceId}) {
    _isConnected = status;
    _connectedDeviceId = deviceId;
    notifyListeners();
  }
}
