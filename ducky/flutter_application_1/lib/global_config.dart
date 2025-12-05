import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GlobalConfig {
  static const String defaultBaseUrl = 'https://jvvrlmfl-3000.euw.devtunnels.ms';
  static const String defaultAdminUsername = 'admin';
  static const String defaultAdminPassword = 'admin';

  // Ключи для SharedPreferences
  static const String _baseUrlKey = 'base_url';
  static const String _adminUsernameKey = 'admin_username';
  static const String _adminPasswordKey = 'admin_password';
  static const String _userEmailKey = 'user_email';
  static const String _userPasswordKey = 'user_password';

  // Геттеры и сеттеры для настроек
  static Future<String> get baseUrl async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_baseUrlKey) ?? defaultBaseUrl;
  }
  
  static Future<void> setBaseUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_baseUrlKey, url);
  }
  
  static Future<String> get adminUsername async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_adminUsernameKey) ?? defaultAdminUsername;
  }
  
  static Future<void> setAdminUsername(String username) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_adminUsernameKey, username);
  }
  
  static Future<String> get adminPassword async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_adminPasswordKey) ?? defaultAdminPassword;
  }
  
  static Future<void> setAdminPassword(String password) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_adminPasswordKey, password);
  }
  
  // Метод для проверки роли администратора
  static Future<bool> isAdminLogin(String username, String password) async {
    final adminUser = await adminUsername;
    final adminPass = await adminPassword;
    return username == adminUser && password == adminPass;
  }
  
  // Методы для сохранения/получения пользовательских учетных данных
  static Future<void> saveUserCredentials(String email, String password) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userEmailKey, email);
    await prefs.setString(_userPasswordKey, password);
  }
  
  static Future<Map<String, String>> getUserCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString(_userEmailKey);
    final password = prefs.getString(_userPasswordKey);
    
    return {
      'email': email ?? '',
      'password': password ?? '',
    };
  }
  
  static Future<void> clearUserCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userEmailKey);
    await prefs.remove(_userPasswordKey);
  }
  
  // Таймауты запросов
  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 15);
  
  // Статусы заявок
  static const List<String> requestStatuses = [
    'новая',
    'принята', 
    'в работе',
    'завершена',
    'отклонена'
  ];
  
  // Типы транспорта
  static const List<String> transportTypes = [
    'троллейбусы',
    'электробусы',
    'трамваи',
    'электрогрузовики'
  ];
  
  // Роли пользователей
  static const List<String> userRoles = [
    'applicant',
    'mechanic',
    'manager',
    'admin'
  ];
  
  // Время работы сервисов
  static const List<String> serviceWorkTimes = [
    '9:00-18:00',
    '10:00-19:00',
    '8:00-17:00',
    'Круглосуточно',
    'По записи'
  ];
  
  // Цвета для статусов заявок
  static Map<String, Color> statusColors = {
    'новая': Colors.blue,
    'принята': Colors.orange,
    'в работе': Colors.purple,
    'завершена': Colors.green,
    'отклонена': Colors.red,
  };
  
  // Иконки для статусов заявок
  static Map<String, IconData> statusIcons = {
    'новая': Icons.new_releases,
    'принята': Icons.check_circle_outline,
    'в работе': Icons.build,
    'завершена': Icons.check_circle,
    'отклонена': Icons.cancel,
  };
  
  // Цвета для ролей пользователей
  static Map<String, Color> roleColors = {
    'applicant': Colors.blue,
    'mechanic': Colors.green,
    'manager': Colors.orange,
    'admin': Colors.purple,
  };
  
  // Иконки для ролей пользователей
  static Map<String, IconData> roleIcons = {
    'applicant': Icons.person,
    'mechanic': Icons.engineering,
    'manager': Icons.business_center,
    'admin': Icons.admin_panel_settings,
  };
  
  // Метод для получения цвета статуса
  static Color getStatusColor(String status) {
    return statusColors[status.toLowerCase()] ?? Colors.grey;
  }
  
  // Метод для получения иконки статуса
  static IconData getStatusIcon(String status) {
    return statusIcons[status.toLowerCase()] ?? Icons.help_outline;
  }
  
  // Метод для получения цвета роли
  static Color getRoleColor(String role) {
    return roleColors[role.toLowerCase()] ?? Colors.grey;
  }
  
  // Метод для получения иконки роли
  static IconData getRoleIcon(String role) {
    return roleIcons[role.toLowerCase()] ?? Icons.person_outline;
  }
  
  // Метод для получения цвета статуса с прозрачностью
  static Color getStatusColorWithOpacity(String status, [double opacity = 0.1]) {
    final color = getStatusColor(status);
    return color.withOpacity(opacity.clamp(0.0, 1.0));
  }
  
  // Метод для получения цвета роли с прозрачностью
  static Color getRoleColorWithOpacity(String role, [double opacity = 0.1]) {
    final color = getRoleColor(role);
    return color.withOpacity(opacity.clamp(0.0, 1.0));
  }
  
  // Метод для проверки валидности URL
  static bool isValidUrl(String url) {
    try {
      if (url.isEmpty) return false;
      
      // Добавляем http:// если нет схемы
      if (!url.toLowerCase().startsWith('http://') && 
          !url.toLowerCase().startsWith('https://')) {
        url = 'http://$url';
      }
      
      final uri = Uri.tryParse(url);
      return uri != null && uri.isAbsolute && uri.hasScheme;
    } catch (e) {
      return false;
    }
  }
  
  // Метод для форматирования даты
  static String formatDateTime(DateTime dateTime) {
    return '${dateTime.day.toString().padLeft(2, '0')}.'
           '${dateTime.month.toString().padLeft(2, '0')}.'
           '${dateTime.year} '
           '${dateTime.hour.toString().padLeft(2, '0')}:'
           '${dateTime.minute.toString().padLeft(2, '0')}';
  }
  
  // Метод для форматирования только даты
  static String formatDate(DateTime dateTime) {
    return '${dateTime.day.toString().padLeft(2, '0')}.'
           '${dateTime.month.toString().padLeft(2, '0')}.'
           '${dateTime.year}';
  }
  
  // Метод для форматирования времени
  static String formatTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:'
           '${dateTime.minute.toString().padLeft(2, '0')}';
  }
  
  // Метод для парсинга даты из строки
  static DateTime? parseDateTime(String dateString) {
    try {
      return DateTime.parse(dateString);
    } catch (e) {
      try {
        // Пробуем парсить в формате dd.mm.yyyy
        final parts = dateString.split('.');
        if (parts.length == 3) {
          return DateTime(
            int.parse(parts[2]),
            int.parse(parts[1]),
            int.parse(parts[0]),
          );
        }
      } catch (e2) {
        return null;
      }
      return null;
    }
  }
  
  // Метод для генерации случайного пароля
  static String generateRandomPassword({int length = 8}) {
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#\$%^&*()';
    final random = Random();
    return String.fromCharCodes(
      Iterable.generate(
        length,
        (_) => chars.codeUnitAt(random.nextInt(chars.length)),
      ),
    );
  }
  
  // Метод для валидации email
  static bool isValidEmail(String email) {
    const pattern = r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$';
    final regExp = RegExp(pattern);
    return regExp.hasMatch(email);
  }
  
  // Метод для получения инициалов
  static String getInitials(String name) {
    if (name.isEmpty) return '?';
    
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      final first = parts[0].isNotEmpty ? parts[0][0] : '';
      final second = parts[1].isNotEmpty ? parts[1][0] : '';
      return '${first}${second}'.toUpperCase();
    } else if (parts.isNotEmpty && parts[0].isNotEmpty) {
      return parts[0].substring(0, 1).toUpperCase();
    }
    return '?';
  }
  
  // Метод для сброса настроек администратора к значениям по умолчанию
  static Future<void> resetAdminSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_adminUsernameKey);
    await prefs.remove(_adminPasswordKey);
    await prefs.remove(_baseUrlKey);
  }
  
  // Метод для сброса всех настроек
  static Future<void> resetAllSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
  
  // Метод для получения всех настроек
  static Future<Map<String, dynamic>> getAllSettings() async {
    return {
      'base_url': await baseUrl,
      'admin_username': await adminUsername,
      'admin_password': await adminPassword,
    };
  }
  
  // Метод для получения настроек приложения
  static Future<Map<String, dynamic>> getAppConfig() async {
    return {
      'version': '1.0.0',
      'build': '1',
      'api_url': await baseUrl,
      'admin_enabled': true,
      'max_file_size': 5242880, // 5MB
      'supported_image_formats': ['jpg', 'jpeg', 'png', 'gif'],
    };
  }
  
  // Метод для проверки подключения к серверу
  static Future<bool> checkServerConnection() async {
    try {
      final url = await baseUrl;
      if (!isValidUrl(url)) return false;
      
      // Пробуем сделать простой запрос
      final response = await Future.delayed(
        Duration(seconds: 2),
        () => true, // В реальности здесь должен быть HTTP-запрос
      );
      
      return response;
    } catch (e) {
      return false;
    }
  }
  
  // Метод для создания полного URL
  static Future<String> buildUrl(String endpoint) async {
    final base = await baseUrl;
    // Убедимся, что base заканчивается на /
    final formattedBase = base.endsWith('/') ? base : '$base/';
    // Убедимся, что endpoint не начинается с /
    final formattedEndpoint = endpoint.startsWith('/') 
        ? endpoint.substring(1) 
        : endpoint;
    
    return '$formattedBase$formattedEndpoint';
  }
  
  // Метод для логирования
  static void log(String message, {String type = 'INFO'}) {
    final timestamp = formatDateTime(DateTime.now());
    print('[$timestamp] [$type] $message');
  }
  
  // Метод для отображения дефолтных подсказок
  static Map<String, String> getFieldHints() {
    return {
      'email': 'example@email.com',
      'password': 'Введите пароль',
      'name': 'Иван Иванов',
      'address': 'ул. Примерная, д. 1',
      'phone': '+7 (999) 123-45-67',
      'serial': 'ABC123456',
      'model': 'Модель транспорта',
    };
  }
  
  // Метод для валидации пароля
  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Введите пароль';
    }
    if (value.length < 6) {
      return 'Пароль должен быть не менее 6 символов';
    }
    return null;
  }
  
  // Метод для валидации email
  static String? validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Введите email';
    }
    if (!isValidEmail(value)) {
      return 'Введите корректный email';
    }
    return null;
  }
  
  // Метод для валидации имени
  static String? validateName(String? value) {
    if (value == null || value.isEmpty) {
      return 'Введите имя';
    }
    if (value.length < 2) {
      return 'Имя должно быть не менее 2 символов';
    }
    return null;
  }
}