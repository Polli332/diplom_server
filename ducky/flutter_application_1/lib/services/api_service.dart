import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  String? _baseUrl;
  
  Future<String> get baseUrl async {
    if (_baseUrl == null) {
      final prefs = await SharedPreferences.getInstance();
      _baseUrl = prefs.getString('base_url') ?? 'https://jvvrlmfl-3000.euw.devtunnels.ms';
    }
    return _baseUrl!;
  }
  
  Future<void> updateBaseUrl(String newUrl) async {
    _baseUrl = newUrl;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('base_url', newUrl);
  }
  
  Future<Map<String, String>> _getHeaders() async {
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
  }

  // ==================== АВТОРИЗАЦИЯ ====================
  Future<Map<String, dynamic>> authenticateUser(String email, String password) async {
    try {
      final currentBaseUrl = await baseUrl;
      final response = await http.post(
        Uri.parse('$currentBaseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data;
      } else {
        final error = jsonDecode(response.body)['error'] ?? 'Ошибка аутентификации';
        throw Exception(error);
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> registerUser(String name, String email, String password) async {
    try {
      final currentBaseUrl = await baseUrl;
      final response = await http.post(
        Uri.parse('$currentBaseUrl/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': name, 
          'email': email, 
          'password': password,
          'role': 'applicant'
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body);
      } else {
        final error = jsonDecode(response.body)['error'] ?? 'Ошибка регистрации';
        throw Exception(error);
      }
    } catch (e) {
      rethrow;
    }
  }

  // ==================== ПОЛЬЗОВАТЕЛЬСКИЕ ПРОФИЛИ ====================
  Future<UserProfile> getUserProfile(int userId, String role) async {
    try {
      String endpoint;
      switch (role.toLowerCase()) {
        case 'applicant':
          endpoint = 'applicants';
          break;
        case 'mechanic':
          endpoint = 'mechanics';
          break;
        case 'manager':
          endpoint = 'managers';
          break;
        default:
          endpoint = 'applicants';
      }

      final currentBaseUrl = await baseUrl;
      final response = await http.get(
        Uri.parse('$currentBaseUrl/$endpoint/$userId'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return UserProfile(
          id: data['id'] is int ? data['id'] : int.tryParse(data['id'].toString()) ?? 0,
          name: data['name'] ?? '',
          email: data['email'] ?? '',
          photo: data['photo'] is String && data['photo'].isNotEmpty ? data['photo'] : null,
          role: data['role'] ?? role,
          serviceId: data['serviceId'] is int ? data['serviceId'] : 
                    data['serviceId'] != null ? int.tryParse(data['serviceId'].toString()) : null,
        );
      } else {
        throw Exception('Ошибка загрузки профиля: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<UserProfile> updateUserProfile(
      int userId, String role, Map<String, dynamic> data) async {
    try {
      String endpoint;
      switch (role.toLowerCase()) {
        case 'applicant':
          endpoint = 'applicants';
          break;
        case 'mechanic':
          endpoint = 'mechanics';
          break;
        case 'manager':
          endpoint = 'managers';
          break;
        default:
          endpoint = 'applicants';
      }

      final currentBaseUrl = await baseUrl;
      final response = await http.put(
        Uri.parse('$currentBaseUrl/$endpoint/$userId'),
        headers: await _getHeaders(),
        body: jsonEncode(data),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        return UserProfile(
          id: responseData['id'] is int ? responseData['id'] : int.tryParse(responseData['id'].toString()) ?? 0,
          name: responseData['name'] ?? '',
          email: responseData['email'] ?? '',
          photo: responseData['photo'] is String && responseData['photo'].isNotEmpty ? responseData['photo'] : null,
          role: responseData['role'] ?? role,
          serviceId: responseData['serviceId'] is int ? responseData['serviceId'] : 
                    responseData['serviceId'] != null ? int.tryParse(responseData['serviceId'].toString()) : null,
        );
      } else {
        final error = jsonDecode(response.body)['error'] ?? 'Ошибка обновления профиля';
        throw Exception(error);
      }
    } catch (e) {
      rethrow;
    }
  }

  // ==================== ЗАЯВКИ ====================
  Future<List<dynamic>> getRequests() async {
    try {
      final currentBaseUrl = await baseUrl;
      final response = await http.get(
        Uri.parse('$currentBaseUrl/requests'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Ошибка загрузки заявок: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<dynamic> getRequest(int requestId) async {
    try {
      final currentBaseUrl = await baseUrl;
      final response = await http.get(
        Uri.parse('$currentBaseUrl/requests/$requestId'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Ошибка загрузки заявки: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<dynamic> updateRequest(int requestId, Map<String, dynamic> data) async {
    try {
      final currentBaseUrl = await baseUrl;
      final response = await http.put(
        Uri.parse('$currentBaseUrl/requests/$requestId'),
        headers: await _getHeaders(),
        body: jsonEncode(data),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final error = jsonDecode(response.body)['error'] ?? 'Ошибка обновления заявки';
        throw Exception(error);
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<dynamic> createRequest(Map<String, dynamic> data) async {
    try {
      final currentBaseUrl = await baseUrl;
      final response = await http.post(
        Uri.parse('$currentBaseUrl/requests'),
        headers: await _getHeaders(),
        body: jsonEncode(data),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body);
      } else {
        final error = jsonDecode(response.body)['error'] ?? 'Ошибка создания заявки';
        throw Exception(error);
      }
    } catch (e) {
      rethrow;
    }
  }

  // ==================== ТРАНСПОРТ ====================
  Future<List<dynamic>> getTransports() async {
    try {
      final currentBaseUrl = await baseUrl;
      final response = await http.get(
        Uri.parse('$currentBaseUrl/transports'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Ошибка загрузки транспорта: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<dynamic> createTransport(Map<String, dynamic> data) async {
    try {
      final currentBaseUrl = await baseUrl;
      final response = await http.post(
        Uri.parse('$currentBaseUrl/transports'),
        headers: await _getHeaders(),
        body: jsonEncode(data),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body);
      } else {
        final error = jsonDecode(response.body)['error'] ?? 'Ошибка создания транспорта';
        throw Exception(error);
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<List<dynamic>> getAllTransports() async {
    try {
      final currentBaseUrl = await baseUrl;
      final response = await http.get(
        Uri.parse('$currentBaseUrl/all-transports'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Ошибка загрузки всего транспорта: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  // ==================== СЕРВИСЫ ====================
  Future<List<dynamic>> getServices() async {
    try {
      final currentBaseUrl = await baseUrl;
      final response = await http.get(
        Uri.parse('$currentBaseUrl/services'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Ошибка загрузки сервисов: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getServiceDetails(int serviceId) async {
    try {
      final currentBaseUrl = await baseUrl;
      final response = await http.get(
        Uri.parse('$currentBaseUrl/services/$serviceId'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Ошибка загрузки сервиса: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<List<dynamic>> getAllServices() async {
    try {
      final currentBaseUrl = await baseUrl;
      final response = await http.get(
        Uri.parse('$currentBaseUrl/services'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Ошибка загрузки всех сервисов: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<dynamic> createService(Map<String, dynamic> data) async {
    try {
      final currentBaseUrl = await baseUrl;
      final response = await http.post(
        Uri.parse('$currentBaseUrl/services'),
        headers: await _getHeaders(),
        body: jsonEncode(data),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body);
      } else {
        final error = jsonDecode(response.body)['error'] ?? 'Ошибка создания сервиса';
        throw Exception(error);
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<dynamic> updateService(int id, Map<String, dynamic> data) async {
    try {
      final currentBaseUrl = await baseUrl;
      final response = await http.put(
        Uri.parse('$currentBaseUrl/services/$id'),
        headers: await _getHeaders(),
        body: jsonEncode(data),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final error = jsonDecode(response.body)['error'] ?? 'Ошибка обновления сервиса';
        throw Exception(error);
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<dynamic> deleteService(int id) async {
    try {
      final currentBaseUrl = await baseUrl;
      final response = await http.delete(
        Uri.parse('$currentBaseUrl/services/$id'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final error = jsonDecode(response.body)['error'] ?? 'Ошибка удаления сервиса';
        throw Exception(error);
      }
    } catch (e) {
      rethrow;
    }
  }

  // ==================== ЗАЯВИТЕЛИ ====================
  Future<List<dynamic>> getApplicants() async {
    try {
      final currentBaseUrl = await baseUrl;
      final response = await http.get(
        Uri.parse('$currentBaseUrl/applicants'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Ошибка загрузки заявителей: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<List<dynamic>> getAllApplicants() async {
    try {
      final currentBaseUrl = await baseUrl;
      final response = await http.get(
        Uri.parse('$currentBaseUrl/applicants'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Ошибка загрузки всех заявителей: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  // ==================== МЕХАНИКИ ====================
  Future<List<dynamic>> getMechanics() async {
    try {
      final currentBaseUrl = await baseUrl;
      final response = await http.get(
        Uri.parse('$currentBaseUrl/mechanics'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Ошибка загрузки механиков: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<List<dynamic>> getAllMechanics() async {
    try {
      final currentBaseUrl = await baseUrl;
      final response = await http.get(
        Uri.parse('$currentBaseUrl/mechanics'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Ошибка загрузки всех механиков: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<dynamic> createMechanic(Map<String, dynamic> data) async {
    try {
      final currentBaseUrl = await baseUrl;
      final response = await http.post(
        Uri.parse('$currentBaseUrl/mechanics'),
        headers: await _getHeaders(),
        body: jsonEncode(data),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body);
      } else {
        final error = jsonDecode(response.body)['error'] ?? 'Ошибка создания механика';
        throw Exception(error);
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<dynamic> updateMechanic(int id, Map<String, dynamic> data) async {
    try {
      final currentBaseUrl = await baseUrl;
      final response = await http.put(
        Uri.parse('$currentBaseUrl/mechanics/$id'),
        headers: await _getHeaders(),
        body: jsonEncode(data),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final error = jsonDecode(response.body)['error'] ?? 'Ошибка обновления механика';
        throw Exception(error);
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<dynamic> deleteMechanic(int mechanicId) async {
    try {
      final currentBaseUrl = await baseUrl;
      final response = await http.delete(
        Uri.parse('$currentBaseUrl/mechanics/$mechanicId'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final error = jsonDecode(response.body)['error'] ?? 'Ошибка удаления механика';
        throw Exception(error);
      }
    } catch (e) {
      rethrow;
    }
  }

  // ==================== МЕНЕДЖЕРЫ ====================
  Future<List<dynamic>> getManagers() async {
    try {
      final currentBaseUrl = await baseUrl;
      final response = await http.get(
        Uri.parse('$currentBaseUrl/managers'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Ошибка загрузки менеджеров: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<List<dynamic>> getAllManagers() async {
    try {
      final currentBaseUrl = await baseUrl;
      final response = await http.get(
        Uri.parse('$currentBaseUrl/managers'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Ошибка загрузки всех менеджеров: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<dynamic> createManager(Map<String, dynamic> data) async {
    try {
      final currentBaseUrl = await baseUrl;
      final response = await http.post(
        Uri.parse('$currentBaseUrl/managers'),
        headers: await _getHeaders(),
        body: jsonEncode(data),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body);
      } else {
        final error = jsonDecode(response.body)['error'] ?? 'Ошибка создания менеджера';
        throw Exception(error);
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<dynamic> updateManager(int id, Map<String, dynamic> data) async {
    try {
      final currentBaseUrl = await baseUrl;
      final response = await http.put(
        Uri.parse('$currentBaseUrl/managers/$id'),
        headers: await _getHeaders(),
        body: jsonEncode(data),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final error = jsonDecode(response.body)['error'] ?? 'Ошибка обновления менеджера';
        throw Exception(error);
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<dynamic> deleteManager(int id) async {
    try {
      final currentBaseUrl = await baseUrl;
      final response = await http.delete(
        Uri.parse('$currentBaseUrl/managers/$id'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final error = jsonDecode(response.body)['error'] ?? 'Ошибка удаления менеджера';
        throw Exception(error);
      }
    } catch (e) {
      rethrow;
    }
  }

  // ==================== ВСЕ ЗАЯВКИ ====================
  Future<List<dynamic>> getAllRequests() async {
    try {
      final currentBaseUrl = await baseUrl;
      final response = await http.get(
        Uri.parse('$currentBaseUrl/all-requests'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Ошибка загрузки всех заявок: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  // ==================== ЗАЯВКИ МЕХАНИКА ====================
  Future<List<dynamic>> getMechanicRequests(int mechanicId) async {
    try {
      final currentBaseUrl = await baseUrl;
      final response = await http.get(
        Uri.parse('$currentBaseUrl/mechanic/requests/$mechanicId'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Ошибка загрузки заявок механика: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<dynamic> completeRequest(int requestId) async {
    try {
      final currentBaseUrl = await baseUrl;
      final response = await http.put(
        Uri.parse('$currentBaseUrl/requests/$requestId/complete'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final error = jsonDecode(response.body)['error'] ?? 'Ошибка завершения заявки';
        throw Exception(error);
      }
    } catch (e) {
      rethrow;
    }
  }

  // ==================== ПОЛУЧЕНИЕ ВСЕХ ДАННЫХ (для отладки) ====================
  Future<Map<String, dynamic>> getDebugDatabaseInfo() async {
    try {
      final currentBaseUrl = await baseUrl;
      final response = await http.get(
        Uri.parse('$currentBaseUrl/debug/database'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Ошибка загрузки отладочной информации: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }
}

class UserProfile {
  final int id;
  final String name;
  final String email;
  final String? photo;
  final String? role;
  final int? serviceId;

  UserProfile({
    required this.id,
    required this.name,
    required this.email,
    this.photo,
    this.role,
    this.serviceId,
  });
}