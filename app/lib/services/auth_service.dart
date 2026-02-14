import 'dart:convert';
import 'package:http/http.dart' as http;

class AuthResponse {
  final String sessionToken;
  final String userId;
  final String username;

  AuthResponse({
    required this.sessionToken,
    required this.userId,
    required this.username,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      sessionToken: json['session_token'] as String,
      userId: json['user_id'] as String,
      username: json['username'] as String,
    );
  }
}

class AuthService {
  final String baseUrl;

  AuthService({required this.baseUrl});

  Future<AuthResponse> register(String username, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/password/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username, 'password': password}),
    );

    if (response.statusCode == 200) {
      return AuthResponse.fromJson(jsonDecode(response.body));
    } else {
      throw Exception(response.body);
    }
  }

  Future<AuthResponse> login(String username, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/password/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username, 'password': password}),
    );

    if (response.statusCode == 200) {
      return AuthResponse.fromJson(jsonDecode(response.body));
    } else {
      throw Exception(response.body);
    }
  }

  Future<void> logout(String token) async {
    await http.post(
      Uri.parse('$baseUrl/auth/logout'),
      headers: {
        'Content-Type': 'application/json',
        'x-session-token': token,
      },
    );
  }
}
