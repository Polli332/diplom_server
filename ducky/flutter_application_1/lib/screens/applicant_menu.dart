import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import '../global_config.dart';

class ApplicantMenu extends StatefulWidget {
  const ApplicantMenu({super.key});

  @override
  State<ApplicantMenu> createState() => _ApplicantMenuState();
}

class _ApplicantMenuState extends State<ApplicantMenu> {
  String? userName;
  String? userEmail;
  int? userId;
  String? userPhoto;
  List<dynamic> requests = [];
  List<dynamic> transports = [];
  List<dynamic> services = [];
  bool _isAccountPanelOpen = false;
  String _sortOrder = 'newest';
  String? _statusFilter;
  String? _transportFilter;
  bool _isLoading = true;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _problemController = TextEditingController();
  final TextEditingController _transportNameController = TextEditingController();
  String _selectedTransportType = 'троллейбусы';
  final TextEditingController _serialController = TextEditingController();
  final TextEditingController _modelController = TextEditingController();
  int? _selectedServiceId;
  
  String? _selectedPhotoBase64;
  String? _selectedProfilePhotoBase64;
  final ImagePicker _picker = ImagePicker();
  
  // Базовый URL
  Future<String> get _baseUrl async => await GlobalConfig.baseUrl;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _problemController.dispose();
    _transportNameController.dispose();
    _serialController.dispose();
    _modelController.dispose();
    super.dispose();
  }

  // Метод для прямого обращения к серверу
  Future<dynamic> _makeApiRequest(
    String endpoint, {
    String method = 'GET',
    Map<String, dynamic>? body,
  }) async {
    try {
      final baseUrl = await _baseUrl;
      final url = Uri.parse('$baseUrl$endpoint');
      
      debugPrint('API Request: $method $url');
      
      http.Response response;
      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };
      
      switch (method.toUpperCase()) {
        case 'GET':
          response = await http.get(url, headers: headers);
          break;
        case 'POST':
          response = await http.post(
            url,
            headers: headers,
            body: jsonEncode(body),
          );
          break;
        case 'PUT':
          response = await http.put(
            url,
            headers: headers,
            body: jsonEncode(body),
          );
          break;
        case 'DELETE':
          response = await http.delete(url, headers: headers);
          break;
        default:
          throw Exception('Неподдерживаемый HTTP метод: $method');
      }
      
      debugPrint('Response status: ${response.statusCode}');
      
      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (response.body.isEmpty) {
          return {};
        }
        try {
          return jsonDecode(response.body);
        } catch (e) {
          debugPrint('Error decoding JSON: $e');
          return response.body;
        }
      } else {
        try {
          final errorData = jsonDecode(response.body);
          throw Exception(errorData['error'] ?? 'Ошибка ${response.statusCode}');
        } catch (e) {
          throw Exception('Ошибка сервера: ${response.statusCode}');
        }
      }
    } catch (e) {
      debugPrint('Network error: $e');
      rethrow;
    }
  }

  Future<void> _loadUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      userId = prefs.getInt('user_id');
      userName = prefs.getString('user_name') ?? 'Пользователь';
      userEmail = prefs.getString('user_email') ?? 'Email не указан';
      userPhoto = prefs.getString('user_photo');
      
      _nameController.text = userName ?? '';
      _emailController.text = userEmail ?? '';

      if (userId != null) {
        await _loadUserDataFromServer();
      }
      
      await Future.wait([
        _loadUserRequests(),
        _loadTransports(),
        _loadServices(),
      ]);
      
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Ошибка загрузки данных: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadUserDataFromServer() async {
    try {
      if (userId == null) return;
      
      final userData = await _makeApiRequest('/applicants/$userId');
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('user_id', userData['id']);
      await prefs.setString('user_name', userData['name']);
      await prefs.setString('user_email', userData['email']);
      if (userData['photo'] != null) {
        await prefs.setString('user_photo', userData['photo']);
      }
      
      setState(() {
        userName = userData['name'];
        userEmail = userData['email'];
        userPhoto = userData['photo'];
        _nameController.text = userName ?? '';
        _emailController.text = userEmail ?? '';
      });
    } catch (e) {
      debugPrint('Ошибка загрузки данных с сервера: $e');
    }
  }

  Future<void> _loadUserRequests() async {
    try {
      if (userId == null) {
        debugPrint('User ID is null');
        setState(() {
          requests = [];
        });
        return;
      }

      // Получаем ВСЕ заявки
      final allRequests = await _makeApiRequest('/requests');
      
      if (allRequests is! List) {
        debugPrint('Ошибка: данные заявок не являются списком');
        setState(() {
          requests = [];
        });
        return;
      }
      
      debugPrint('Всего заявок от сервера: ${allRequests.length}');
      debugPrint('ID текущего пользователя: $userId');
      
      // Фильтруем заявки по applicantId
      final List<dynamic> userRequests = [];
      
      for (final request in allRequests) {
        if (request['applicantId'] == userId) {
          userRequests.add(request);
        } else if (request['applicant'] != null && 
                   request['applicant']['id'] == userId) {
          userRequests.add(request);
        } else if (request['applicantId'] != null) {
          // Преобразуем applicantId к int для сравнения
          final applicantId = request['applicantId'];
          int? parsedId;
          
          if (applicantId is int) {
            parsedId = applicantId;
          } else if (applicantId is String) {
            parsedId = int.tryParse(applicantId);
          }
          
          if (parsedId == userId) {
            userRequests.add(request);
          }
        }
      }
      
      debugPrint('Найдено заявок для пользователя: ${userRequests.length}');
      
      setState(() {
        requests = userRequests;
      });
    } catch (e) {
      debugPrint('Ошибка загрузки заявок: $e');
      setState(() {
        requests = [];
      });
    }
  }

  Future<void> _loadTransports() async {
    try {
      final data = await _makeApiRequest('/transports');
      
      if (data is List) {
        setState(() {
          transports = data;
        });
      } else {
        debugPrint('Неизвестный формат данных транспорта');
        setState(() {
          transports = [];
        });
      }
    } catch (e) {
      debugPrint('Ошибка загрузки транспорта: $e');
      setState(() {
        transports = [];
      });
    }
  }

  Future<void> _loadServices() async {
    try {
      final data = await _makeApiRequest('/services');
      
      if (data is List) {
        setState(() {
          services = data;
        });
      } else {
        debugPrint('Неизвестный формат данных сервисов');
        setState(() {
          services = [];
        });
      }
    } catch (e) {
      debugPrint('Ошибка загрузки сервисов: $e');
      setState(() {
        services = [];
      });
    }
  }

  Widget _buildAvatar(String? photoBase64, double radius) {
    if (photoBase64 != null && photoBase64.isNotEmpty) {
      try {
        if (photoBase64.length > 100) {
          return CircleAvatar(
            radius: radius,
            backgroundColor: Colors.white,
            backgroundImage: MemoryImage(base64Decode(photoBase64)),
            onBackgroundImageError: (exception, stackTrace) {
              debugPrint('Ошибка загрузки фото: $exception');
            },
          );
        }
      } catch (e) {
        debugPrint('Ошибка декодирования фото: $e');
      }
    }
    
    return CircleAvatar(
      radius: radius,
      backgroundColor: Colors.blue,
      child: Icon(
        Icons.person,
        size: radius,
        color: Colors.white,
      ),
    );
  }

  Future<void> _pickImage(String type) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );

      if (image != null) {
        final bytes = await File(image.path).readAsBytes();
        final base64Image = base64Encode(bytes);
        
        if (type == 'transport') {
          setState(() {
            _selectedPhotoBase64 = base64Image;
          });
          _showSuccess('Фото транспорта выбрано');
        } else if (type == 'profile') {
          setState(() {
            _selectedProfilePhotoBase64 = base64Image;
          });
          _showSuccess('Фото профиля выбрано');
        }
      }
    } catch (e) {
      _showError('Ошибка выбора фото: $e');
    }
  }

  void _createRequest() {
    _selectedServiceId = null;
    _selectedPhotoBase64 = null;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Создать заявку'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: _problemController,
                      decoration: const InputDecoration(
                        labelText: 'Описание проблемы *',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 16),
                    
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Выберите сервис:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<int?>(
                      initialValue: _selectedServiceId,
                      items: [
                        const DropdownMenuItem<int?>(
                          value: null,
                          child: Text('Выберите сервис *'),
                        ),
                        ...services.map((service) {
                          final serviceId = service['id'] is int 
                              ? service['id'] 
                              : int.tryParse(service['id'].toString()) ?? 0;
                          final address = service['address']?.toString() ?? 'Неизвестный адрес';
                          final workTime = service['workTime']?.toString() ?? '';
                          return DropdownMenuItem<int>(
                            value: serviceId,
                            child: Text('$address ${workTime.isNotEmpty ? '($workTime)' : ''}'),
                          );
                        }),
                      ],
                      onChanged: (int? newValue) {
                        setDialogState(() {
                          _selectedServiceId = newValue;
                        });
                      },
                      decoration: const InputDecoration(
                        labelText: 'Сервисный центр *',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    const Text(
                      'Данные транспорта:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _transportNameController,
                      decoration: const InputDecoration(
                        labelText: 'Название транспорта *',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedTransportType,
                      items: GlobalConfig.transportTypes.map((String type) {
                        return DropdownMenuItem<String>(
                          value: type,
                          child: Text(type),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        setDialogState(() {
                          if (newValue != null) {
                            _selectedTransportType = newValue;
                          }
                        });
                      },
                      decoration: const InputDecoration(
                        labelText: 'Тип транспорта *',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _serialController,
                      decoration: const InputDecoration(
                        labelText: 'Серийный номер *',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _modelController,
                      decoration: const InputDecoration(
                        labelText: 'Модель *',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        ElevatedButton(
                          onPressed: () => _pickImage('transport'),
                          child: const Text('Выбрать фото транспорта'),
                        ),
                        const SizedBox(width: 8),
                        if (_selectedPhotoBase64 != null)
                          const Text(
                            'Фото выбрано',
                            style: TextStyle(color: Colors.green),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '* - обязательные поля',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    _clearRequestForm();
                    Navigator.of(context).pop();
                  },
                  child: const Text('Отмена'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (_validateRequestForm()) {
                      _addNewRequest();
                      Navigator.of(context).pop();
                    }
                  },
                  child: const Text('Создать'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  bool _validateRequestForm() {
    if (_problemController.text.trim().isEmpty) {
      _showError('Введите описание проблемы');
      return false;
    }
    if (_selectedServiceId == null) {
      _showError('Выберите сервисный центр');
      return false;
    }
    if (_transportNameController.text.trim().isEmpty) {
      _showError('Введите название транспорта');
      return false;
    }
    if (_serialController.text.trim().isEmpty) {
      _showError('Введите серийный номер');
      return false;
    }
    if (_modelController.text.trim().isEmpty) {
      _showError('Введите модель транспорта');
      return false;
    }
    return true;
  }

  Future<void> _addNewRequest() async {
    try {
      // Создаем транспорт
      final transportData = {
        'type': _selectedTransportType,
        'serial': _serialController.text.trim(),
        'model': _transportNameController.text.trim(),
      };
      
      if (_selectedPhotoBase64 != null && _selectedPhotoBase64!.isNotEmpty) {
        transportData['photo'] = _selectedPhotoBase64!;
      }
      
      debugPrint('Создаем транспорт: $transportData');
      
      final transport = await _makeApiRequest(
        '/transports',
        method: 'POST',
        body: transportData,
      );
      
      final transportId = transport['id'] is int 
          ? transport['id'] 
          : int.tryParse(transport['id'].toString()) ?? 0;

      debugPrint('Транспорт создан, ID: $transportId');

      // Создаем заявку
      final requestData = {
        'problem': _problemController.text.trim(),
        'transportId': transportId,
        'applicantId': userId,
        'serviceId': _selectedServiceId,
        'status': "новая",
      };

      debugPrint('Создаем заявку: $requestData');
      
      await _makeApiRequest(
        '/requests',
        method: 'POST',
        body: requestData,
      );

      // Обновляем данные
      await Future.wait([
        _loadUserRequests(),
        _loadTransports(),
      ]);
      
      _clearRequestForm();
      _showSuccess('Заявка успешно создана!');
      
    } catch (e) {
      debugPrint('Ошибка создания заявки: $e');
      _showError('Ошибка создания заявки: $e');
    }
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _clearRequestForm() {
    _problemController.clear();
    _transportNameController.clear();
    _serialController.clear();
    _modelController.clear();
    _selectedPhotoBase64 = null;
    _selectedTransportType = 'троллейбусы';
    _selectedServiceId = null;
  }

  Future<void> _updateProfile() async {
    if (_nameController.text.trim().isEmpty || _emailController.text.trim().isEmpty) {
      _showError('Заполните имя и email');
      return;
    }

    try {
      final Map<String, dynamic> updateData = {
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
      };

      if (_selectedProfilePhotoBase64 != null) {
        updateData['photo'] = _selectedProfilePhotoBase64!;
      }

      if (_passwordController.text.trim().isNotEmpty) {
        updateData['password'] = _passwordController.text.trim();
      }

      debugPrint('Обновляем профиль: $updateData');
      
      final user = await _makeApiRequest(
        '/applicants/$userId',
        method: 'PUT',
        body: updateData,
      );
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_name', user['name']);
      await prefs.setString('user_email', user['email']);
      if (user['photo'] != null) {
        await prefs.setString('user_photo', user['photo']);
      }
      
      setState(() {
        userName = user['name'];
        userEmail = user['email'];
        userPhoto = user['photo'];
        _passwordController.clear();
        _selectedProfilePhotoBase64 = null;
      });

      _showSuccess('Профиль успешно обновлен');
    } catch (e) {
      debugPrint('Ошибка обновления профиля: $e');
      _showError('Ошибка обновления профиля: $e');
    }
  }

  Future<void> _logout() async {
    setState(() => _isAccountPanelOpen = false);
    await Future.delayed(const Duration(milliseconds: 300));
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    
    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(
        context, 
        '/login', 
        (route) => false
      );
    }
  }

  void _showRequestDetails(Map<String, dynamic> request) {
    final transport = transports.firstWhere(
      (t) => (t['id'] is int ? t['id'] : int.tryParse(t['id'].toString()) ?? 0) == 
             (request['transportId'] is int ? request['transportId'] : int.tryParse(request['transportId'].toString()) ?? 0),
      orElse: () => {'type': 'Неизвестно', 'serial': 'Неизвестно', 'model': 'Неизвестно', 'photo': null},
    );

    final service = request['serviceId'] != null 
        ? services.firstWhere(
            (s) => (s['id'] is int ? s['id'] : int.tryParse(s['id'].toString()) ?? 0) == 
                   (request['serviceId'] is int ? request['serviceId'] : int.tryParse(request['serviceId'].toString()) ?? 0),
            orElse: () => {'address': 'Не указан', 'workTime': ''},
          )
        : {'address': 'Не назначен', 'workTime': ''};

    final status = _getRequestStatus(request);
    final statusColor = _getStatusColor(request);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Детали заявки',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildDetailRow('Номер заявки:', '#${request['id']}'),
                  _buildDetailRow('Статус:', status),
                  _buildDetailRow('Проблема:', request['problem']?.toString() ?? ''),
                  _buildDetailRow('Сервис:', service['address']?.toString() ?? ''),
                  
                  _buildDetailRow('Дата создания:', 
                    _formatDateTime(request['submittedAt']?.toString() ?? '')),
                  
                  if (request['closedAt'] != null) ...[
                    _buildDetailRow('Дата закрытия:', 
                      _formatDate(request['closedAt']?.toString() ?? '')),
                  ],
                  
                  const SizedBox(height: 20),
                  const Text(
                    'Данные транспорта:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  const SizedBox(height: 10),
                  _buildDetailRow('Тип:', transport['type']?.toString() ?? ''),
                  _buildDetailRow('Серийный номер:', transport['serial']?.toString() ?? ''),
                  _buildDetailRow('Модель:', transport['model']?.toString() ?? ''),
                  
                  if (transport['photo'] != null && transport['photo'] is String && (transport['photo'] as String).isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Text(
                      'Фото транспорта:',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 200,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.memory(
                          base64Decode(transport['photo'] as String),
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return const Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.error, color: Colors.red, size: 40),
                                  SizedBox(height: 8),
                                  Text('Ошибка загрузки изображения'),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                  
                  const SizedBox(height: 24),
                  Center(
                    child: SizedBox(
                      width: 200,
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text('Закрыть'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _formatDateTime(String dateTimeStr) {
    try {
      final dateTime = DateTime.parse(dateTimeStr);
      return '${dateTime.day.toString().padLeft(2, '0')}.${dateTime.month.toString().padLeft(2, '0')}.${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return 'Неизвестно';
    }
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
    } catch (e) {
      return 'Неизвестно';
    }
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ],
      )
    );
  }

  String _getRequestStatus(Map<String, dynamic> request) {
    if (request['status'] != null && request['status'] is String) {
      final status = request['status'].toString().toLowerCase();
      return status;
    }
    
    if (request['closedAt'] != null) {
      if (request['status'] == 'отклонена') {
        return 'отклонена';
      } else if (request['status'] == 'завершена') {
        return 'завершена';
      }
      return 'завершена';
    }
    if (request['mechanicId'] != null) return 'в работе';
    return 'новая';
  }

  Color _getStatusColor(Map<String, dynamic> request) {
    final status = _getRequestStatus(request).toLowerCase();
    switch (status) {
      case 'новая':
        return Colors.blue;
      case 'принята':
        return Colors.orange;
      case 'в работе':
        return Colors.purple;
      case 'отклонена':
        return Colors.red;
      case 'завершена':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  List<dynamic> _getFilteredAndSortedRequests() {
    List<dynamic> filtered = List.from(requests);

    if (_statusFilter != null) {
      filtered = filtered.where((request) => 
        _getRequestStatus(request) == _statusFilter
      ).toList();
    }

    if (_transportFilter != null) {
      filtered = filtered.where((request) {
        final transport = transports.firstWhere(
          (t) => (t['id'] is int ? t['id'] : int.tryParse(t['id'].toString()) ?? 0) == 
                 (request['transportId'] is int ? request['transportId'] : int.tryParse(request['transportId'].toString()) ?? 0),
          orElse: () => {'type': ''},
        );
        return transport['type'] == _transportFilter;
      }).toList();
    }

    filtered.sort((a, b) {
      final aDateStr = a['submittedAt']?.toString() ?? '';
      final bDateStr = b['submittedAt']?.toString() ?? '';
      try {
        final aDate = DateTime.parse(aDateStr);
        final bDate = DateTime.parse(bDateStr);
        if (_sortOrder == 'newest') {
          return bDate.compareTo(aDate);
        } else {
          return aDate.compareTo(bDate);
        }
      } catch (e) {
        return 0;
      }
    });

    return filtered;
  }

  void _showSortFilterDialog() {
    String? sortGroupValue = _sortOrder;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Сортировка и фильтры'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Сортировка по дате:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    
                    Column(
                      children: [
                        Radio<String>(
                          value: 'newest',
                          groupValue: sortGroupValue,
                          onChanged: (String? value) {
                            setDialogState(() {
                              sortGroupValue = value;
                            });
                          },
                        ),
                        const Text('Сначала новые'),
                        const SizedBox(height: 8),
                        Radio<String>(
                          value: 'oldest',
                          groupValue: sortGroupValue,
                          onChanged: (String? value) {
                            setDialogState(() {
                              sortGroupValue = value;
                            });
                          },
                        ),
                        const Text('Сначала старые'),
                      ],
                    ),
                    
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 8),
                    
                    const Text(
                      'Фильтр по статусу:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    DropdownButtonFormField<String?>(
                      initialValue: _statusFilter,
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('Все статусы'),
                        ),
                        ...['новая', 'принята', 'в работе', 'отклонена', 'завершена'].map((status) => 
                          DropdownMenuItem<String>(
                            value: status,
                            child: Text(status),
                          )
                        ),
                      ],
                      onChanged: (String? newValue) {
                        setState(() {
                          _statusFilter = newValue;
                        });
                      },
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                      ),
                    ),
                    
                    const SizedBox(height: 12),
                    
                    const Text(
                      'Фильтр по типу транспорта:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    DropdownButtonFormField<String?>(
                      initialValue: _transportFilter,
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('Все типы'),
                        ),
                        ...GlobalConfig.transportTypes.map((type) => 
                          DropdownMenuItem<String>(
                            value: type,
                            child: Text(type),
                          )
                        ),
                      ],
                      onChanged: (String? newValue) {
                        setState(() {
                          _transportFilter = newValue;
                        });
                      },
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    setState(() {
                      _sortOrder = 'newest';
                      _statusFilter = null;
                      _transportFilter = null;
                    });
                    Navigator.of(context).pop();
                  },
                  child: const Text('Сбросить'),
                ),
                TextButton(
                  onPressed: () {
                    if (sortGroupValue != null) {
                      setState(() {
                        _sortOrder = sortGroupValue!;
                      });
                    }
                    Navigator.of(context).pop();
                  },
                  child: const Text('Закрыть'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildRequestCard(Map<String, dynamic> request) {
    final transport = transports.firstWhere(
      (t) => (t['id'] is int ? t['id'] : int.tryParse(t['id'].toString()) ?? 0) == 
             (request['transportId'] is int ? request['transportId'] : int.tryParse(request['transportId'].toString()) ?? 0),
      orElse: () => {'type': 'Неизвестно', 'serial': 'Неизвестно', 'model': 'Неизвестно', 'photo': null},
    );

    final status = _getRequestStatus(request);
    final statusColor = _getStatusColor(request);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () => _showRequestDetails(request),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: transport['photo'] != null && transport['photo'] is String && (transport['photo'] as String).isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.memory(
                          base64Decode(transport['photo'] as String),
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return const Center(
                              child: Icon(Icons.error, color: Colors.red),
                            );
                          },
                        ),
                      )
                    : const Center(
                        child: Icon(Icons.directions_bus, size: 40, color: Colors.grey),
                      ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      transport['model']?.toString() ?? 'Неизвестно',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      request['problem']?.toString() ?? '',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black87,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: statusColor),
                      ),
                      child: Text(
                        status.toUpperCase(),
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.calendar_today, size: 14, color: Colors.grey.shade600),
                        const SizedBox(width: 4),
                        Text(
                          _formatDateTime(request['submittedAt']?.toString() ?? ''),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredRequests = _getFilteredAndSortedRequests();

    return Stack(
      children: [
        Scaffold(
          body: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(16, 40, 16, 16),
                decoration: BoxDecoration(
                  color: Colors.blue,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Мои заявки',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh, color: Colors.white),
                      onPressed: () {
                        setState(() {
                          _isLoading = true;
                        });
                        _loadUserData();
                      },
                      tooltip: 'Обновить',
                    ),
                    IconButton(
                      icon: const Icon(Icons.filter_list, color: Colors.white),
                      onPressed: _showSortFilterDialog,
                      tooltip: 'Сортировка и фильтры',
                    ),
                    IconButton(
                      icon: const Icon(Icons.account_circle, color: Colors.white),
                      onPressed: () => setState(() => _isAccountPanelOpen = true),
                      tooltip: 'Аккаунт',
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 16),
                            Text('Загрузка заявок...'),
                          ],
                        ),
                      )
                    : filteredRequests.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.list_alt, size: 80, color: Colors.grey),
                                const SizedBox(height: 16),
                                const Text(
                                  'Заявок нет',
                                  style: TextStyle(fontSize: 18, color: Colors.grey),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Создайте первую заявку',
                                  style: TextStyle(color: Colors.grey),
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton(
                                  onPressed: _createRequest,
                                  child: const Text('Создать заявку'),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            itemCount: filteredRequests.length,
                            itemBuilder: (context, index) {
                              final request = filteredRequests[index];
                              return _buildRequestCard(request);
                            },
                          ),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: _createRequest,
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            child: const Icon(Icons.add),
          ),
        ),

        if (_isAccountPanelOpen)
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            width: MediaQuery.of(context).size.width * 0.8,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    height: 80,
                    padding: const EdgeInsets.fromLTRB(16, 40, 16, 16),
                    decoration: const BoxDecoration(
                      color: Colors.blue,
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: () => setState(() => _isAccountPanelOpen = false),
                        ),
                        const SizedBox(width: 16),
                        const Text(
                          'Профиль',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.logout, color: Colors.white),
                          onPressed: _logout,
                          tooltip: 'Выйти',
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          GestureDetector(
                            onTap: () => _pickImage('profile'),
                            child: Stack(
                              children: [
                                _buildAvatar(
                                  _selectedProfilePhotoBase64 ?? userPhoto, 
                                  50
                                ),
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(
                                      color: Colors.blue,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'Нажмите на фото для изменения',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 20),
                          TextField(
                            controller: _nameController,
                            decoration: const InputDecoration(
                              labelText: 'Имя',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _emailController,
                            decoration: const InputDecoration(
                              labelText: 'Email',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.emailAddress,
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _passwordController,
                            decoration: const InputDecoration(
                              labelText: 'Новый пароль (оставьте пустым, если не хотите менять)',
                              border: OutlineInputBorder(),
                            ),
                            obscureText: true,
                          ),
                          const SizedBox(height: 30),
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              onPressed: _updateProfile,
                              child: const Text('Сохранить изменения'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}