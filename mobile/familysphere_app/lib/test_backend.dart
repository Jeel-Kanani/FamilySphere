import 'dart:convert';
import 'package:http/http.dart' as http;

/// Simple manual test to verify backend connectivity
/// Run with: dart run lib/test_backend.dart
void main() async {
  print('🧪 Testing FamilySphere Backend API\n');
  
  const String baseUrl = 'http://localhost:5000';
  // Use 'http://10.0.2.2:5000' if running on Android emulator
  // Use 'http://localhost:5000' if running on iOS simulator or physical device on same network
  
  // Test 1: Register a new user
  print('📝 Test 1: Register User');
  try {
    final registerResponse = await http.post(
      Uri.parse('$baseUrl/api/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'name': 'Test User',
        'email': 'test${DateTime.now().millisecondsSinceEpoch}@example.com',
        'password': 'password123',
      }),
    );
    
    if (registerResponse.statusCode == 201) {
      print('✅ Registration successful!');
      print('   Response: ${registerResponse.body}\n');
      
      final userData = jsonDecode(registerResponse.body);
      final token = userData['token'];
      final email = userData['email'];
      
      // Test 2: Login with the registered user
      print('🔐 Test 2: Login User');
      final loginResponse = await http.post(
        Uri.parse('$baseUrl/api/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': 'password123',
        }),
      );
      
      if (loginResponse.statusCode == 200) {
        print('✅ Login successful!');
        print('   Response: ${loginResponse.body}\n');
        
        // Test 3: Get current user (protected route)
        print('👤 Test 3: Get Current User (Protected Route)');
        final meResponse = await http.get(
          Uri.parse('$baseUrl/api/auth/me'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
        );
        
        if (meResponse.statusCode == 200) {
          print('✅ Get current user successful!');
          print('   Response: ${meResponse.body}\n');
          
          // Test 4: Try accessing protected route without token
          print('🔒 Test 4: Protected Route Without Token');
          final noTokenResponse = await http.get(
            Uri.parse('$baseUrl/api/auth/me'),
            headers: {'Content-Type': 'application/json'},
          );
          
          if (noTokenResponse.statusCode == 401) {
            print('✅ Correctly rejected unauthorized request');
            print('   Response: ${noTokenResponse.body}\n');
          } else {
            print('❌ Should have returned 401 Unauthorized');
          }
        } else {
          print('❌ Get current user failed: ${meResponse.statusCode}');
          print('   ${meResponse.body}\n');
        }
      } else {
        print('❌ Login failed: ${loginResponse.statusCode}');
        print('   ${loginResponse.body}\n');
      }
    } else {
      print('❌ Registration failed: ${registerResponse.statusCode}');
      print('   ${registerResponse.body}\n');
    }
  } catch (e) {
    print('❌ Error: $e');
    print('⚠️  Make sure the backend server is running on port 5000');
  }
  
  print('\n🎉 Backend connectivity test complete!');
}
