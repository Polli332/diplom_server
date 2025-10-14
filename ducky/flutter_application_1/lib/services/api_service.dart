// lib/services/api_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/user_model.dart';

class ApiService {
  // ЗАМЕНИ на адрес твоего сервера, если он не localhost или порт другой
  // Если тестируешь на эмуляторе Android: http://10.0.2.2:3000
  static const String baseUrl = 'http://localhost:3000';

  // helper: GET all from endpoint
  static Future<List<dynamic>> _getAll(String path) async {
    final uri = Uri.parse('$baseUrl$path');
    final resp = await http.get(uri);
    if (resp.statusCode == 200) {
      return jsonDecode(resp.body) as List<dynamic>;
    } else {
      throw Exception('Ошибка запроса $path (${resp.statusCode})');
    }
  }

  // Регистрация заявителя (applicant)
  static Future<UserModel> registerApplicant(String name, String email, String password) async {
    final uri = Uri.parse('$baseUrl/applicants');
    final resp = await http.post(uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'name': name, 'role': 'applicant', 'photo': null, 'password': password, 'email': email}));
    if (resp.statusCode == 200 || resp.statusCode == 201) {
      final map = jsonDecode(resp.body) as Map<String, dynamic>;
      return UserModel.fromMap(map, 'applicant');
    } else {
      throw Exception('Не удалось зарегистрировать: ${resp.body}');
    }
  }

  // Попытка логина: ищем пользователя в таблицах applicants, mechanics, managers
  // Возвращаем UserModel с role или кидаем Exception
  static Future<UserModel> login(String email, String password) async {
    // 1) Applicants
    final applicants = await _getAll('/applicants');
    for (final a in applicants) {
      if (a['email'] == email && a['password'] == password) {
        return UserModel.fromMap(a as Map<String, dynamic>, 'applicant');
      }
    }

    // 2) Mechanics
    final mechanics = await _getAll('/mechanics');
    for (final m in mechanics) {
      if (m['email'] == email && m['password'] == password) {
        return UserModel.fromMap(m as Map<String, dynamic>, 'mechanic');
      }
    }

    // 3) Managers
    final managers = await _getAll('/managers');
    for (final mg in managers) {
      if (mg['email'] == email && mg['password'] == password) {
        return UserModel.fromMap(mg as Map<String, dynamic>, 'manager');
      }
    }

    throw Exception('Неверный email или пароль');
  }
}
