import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:familysphere_app/core/config/api_config.dart';
import 'dart:developer' as developer;

class SocketService {
  late IO.Socket _socket;

  SocketService() {
    final baseUrl = ApiConfig.baseUrl;
    developer.log('[Socket] Initializing for: $baseUrl', name: 'SocketService');
    
    _socket = IO.io(
      baseUrl,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .enableForceNew() // Ensure a fresh connection
          .build(),
    );

    _socket.onConnect((_) {
      developer.log('[Socket] Connected successfully', name: 'SocketService');
    });

    _socket.onDisconnect((_) {
      developer.log('[Socket] Disconnected from server', name: 'SocketService');
    });

    _socket.onConnectError((err) {
      developer.log('[Socket] Connection Error: $err', name: 'SocketService', error: err);
    });
  }

  void connect() {
    if (!_socket.connected) {
      _socket.connect();
    }
  }

  void disconnect() {
    if (_socket.connected) {
      _socket.disconnect();
    }
  }

  void joinFamily(String familyId) {
    if (familyId.isNotEmpty) {
      _socket.emit('join_family', familyId);
      developer.log('[Socket] Joining family room: $familyId', name: 'SocketService');
    }
  }

  void leaveFamily(String familyId) {
    if (familyId.isNotEmpty) {
      _socket.emit('leave_family', familyId);
      developer.log('[Socket] Leaving family room: $familyId', name: 'SocketService');
    }
  }

  void on(String event, Function(dynamic) handler) {
    _socket.on(event, handler);
  }

  void off(String event) {
    _socket.off(event);
  }

  bool get connected => _socket.connected;
  String? get id => _socket.id;
}

final socketServiceProvider = Provider<SocketService>((ref) {
  final service = SocketService();
  // Automatically connect when provider is used
  service.connect();
  
  ref.onDispose(() {
    developer.log('[Socket] Provider disposed, disconnecting...', name: 'SocketService');
    service.disconnect();
  });
  
  return service;
});
