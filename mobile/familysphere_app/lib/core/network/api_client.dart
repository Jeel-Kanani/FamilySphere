import 'package:dio/dio.dart';
import 'package:familysphere_app/core/config/api_config.dart';
import 'package:familysphere_app/core/services/token_service.dart';

class ApiClient {
  late final Dio _dio;
  final TokenService _tokenService;
  
  ApiClient({required TokenService tokenService}) : _tokenService = tokenService {
    _dio = Dio(
      BaseOptions(
        baseUrl: ApiConfig.baseUrl,
        connectTimeout: ApiConfig.connectTimeout,
        receiveTimeout: ApiConfig.receiveTimeout,
        headers: ApiConfig.defaultHeaders,
      ),
    );
    
    _setupInterceptors();
  }
  
  void _setupInterceptors() {
    // Request interceptor - Add JWT token to headers
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // Get token from secure storage
          final token = await _tokenService.getToken();
          
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          
          // Log request (only in debug mode)
          // ignore: avoid_print
          print('🌐 REQUEST[${options.method}] => ${options.uri}');
          // ignore: avoid_print
          print('📤 Data: ${options.data}');
          
          return handler.next(options);
        },
        onResponse: (response, handler) {
          // Log response (only in debug mode)
          // ignore: avoid_print
          print('✅ RESPONSE[${response.statusCode}] => ${response.requestOptions.uri}');
          // ignore: avoid_print
          print('📥 Data: ${response.data}');
          
          return handler.next(response);
        },
        onError: (error, handler) async {
          // Log error
          // ignore: avoid_print
          print('❌ ERROR[${error.response?.statusCode}] => ${error.requestOptions.uri}');
          // ignore: avoid_print
          print('🔴 Message: ${error.message}');
          // ignore: avoid_print
          print('🔴 Data: ${error.response?.data}');
          
          // Handle specific error cases
          if (error.response?.statusCode == 401) {
            // Token expired or invalid - clear user session
            await _tokenService.clearUserData();
          }
          
          return handler.next(error);
        },
      ),
    );
  }
  
  // GET request
  Future<Response> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await _dio.get(
        path,
        queryParameters: queryParameters,
        options: options,
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }
  
  // POST request
  Future<Response> post(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await _dio.post(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }
  
  // PUT request
  Future<Response> put(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await _dio.put(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }
  
  // DELETE request
  Future<Response> delete(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await _dio.delete(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }
  
  // Error handling
  Exception _handleError(DioException error) {
    String message;
    
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        message = 'Connection timeout. Please check your internet connection.';
        break;
      case DioExceptionType.badResponse:
        message = _getErrorMessage(error.response);
        break;
      case DioExceptionType.cancel:
        message = 'Request cancelled';
        break;
      default:
        message = 'Network error. Please try again.';
    }
    
    return Exception(message);
  }
  
  String _getErrorMessage(Response? response) {
    if (response == null) return 'Unknown error occurred';
    
    try {
      // Try to get error message from response
      if (response.data is Map<String, dynamic>) {
        return response.data['message'] ?? 'Error: ${response.statusCode}';
      }
      return 'Error: ${response.statusCode}';
    } catch (e) {
      return 'Error: ${response.statusCode}';
    }
  }
}
