import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

/// Service to monitor network connectivity
class ConnectivityService {
  final Connectivity _connectivity = Connectivity();
  
  // Stream controller for connectivity changes
  final StreamController<bool> _connectionController = StreamController<bool>.broadcast();
  
  Stream<bool> get connectionStream => _connectionController.stream;
  
  bool _isConnected = false;
  bool get isConnected => _isConnected;
  
  ConnectivityService() {
    _init();
  }
  
  void _init() {
    _connectivity.onConnectivityChanged.listen(_updateConnectionStatus);
    checkConnection();
  }
  
  Future<bool> checkConnection() async {
    final results = await _connectivity.checkConnectivity();
    _updateConnectionStatus(results);
    return _isConnected;
  }
  
  void _updateConnectionStatus(List<ConnectivityResult> results) {
    final wasConnected = _isConnected;
    
    _isConnected = results.isNotEmpty && 
        !results.contains(ConnectivityResult.none);
    
    if (wasConnected != _isConnected) {
      _connectionController.add(_isConnected);
    }
  }
  
  void dispose() {
    _connectionController.close();
  }
}
