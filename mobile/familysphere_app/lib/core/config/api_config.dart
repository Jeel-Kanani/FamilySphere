class ApiConfig {
  // Base URLs for different environments
  static const String _localAndroidEmulator = 'http://10.0.2.2:5000';
  static const String _localIOSSimulator = 'http://localhost:5000';
  static const String _localPhysicalDevice = 'http://10.63.65.206:5000'; // Your computer's local network IP
  static const String _productionUrl = 'https://familysphere-api.example.com'; // Update when deployed
  
  // Current environment - change this based on deployment
  static const bool _isProduction = false;
  static const bool _isIOS = false; // Set to true when running on iOS
  static const bool _isPhysicalDevice = true; // Set to true when testing on physical device, false for emulator
  
  // Get base URL based on platform and environment
  static String get baseUrl {
    if (_isProduction) {
      return _productionUrl;
    }
    
    if (_isIOS) {
      return _localIOSSimulator;
    }
    
    // Android
    return _isPhysicalDevice ? _localPhysicalDevice : _localAndroidEmulator;
  }
  
  // API endpoints
  static const String authBase = '/api/auth';
  static const String registerEndpoint = '$authBase/register';
  static const String loginEndpoint = '$authBase/login';
  static const String currentUserEndpoint = '$authBase/me';
  static const String updateProfileEndpoint = '$authBase/profile';
  
  // Timeouts
  static const Duration connectTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);
  
  // Headers
  static Map<String, String> get defaultHeaders => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };
}
