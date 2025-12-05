import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

class ManagerMenu extends StatefulWidget {
  const ManagerMenu({super.key});

  @override
  State<ManagerMenu> createState() => _ManagerMenuState();
}

class _ManagerMenuState extends State<ManagerMenu> with SingleTickerProviderStateMixin {
  String? userName;
  String? userEmail;
  int? userId;
  int? serviceId;
  String? userPhoto;
  String? serviceAddress;
  List<dynamic> requests = [];
  List<dynamic> mechanics = [];
  List<dynamic> transports = [];
  List<dynamic> applicants = [];
  List<dynamic> services = [];
  bool _isAccountPanelOpen = false;
  String _sortOrder = 'newest';
  String? _statusFilter;
  String? _mechanicFilter;
  bool _isLoading = true;
  bool _photoLoading = false;

  late TabController _tabController;
  final ImagePicker _picker = ImagePicker();
  final String _baseUrl = 'http://localhost:3000';

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _mechanicNameController = TextEditingController();
  final TextEditingController _mechanicEmailController = TextEditingController();
  final TextEditingController _mechanicPasswordController = TextEditingController();
  String? _selectedMechanicPhotoBase64;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadUserData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _mechanicNameController.dispose();
    _mechanicEmailController.dispose();
    _mechanicPasswordController.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>> _apiRequest(String endpoint, {String method = 'GET', Map<String, dynamic>? body}) async {
    final url = Uri.parse('$_baseUrl$endpoint');
    final headers = {'Content-Type': 'application/json'};
    
    http.Response response;
    
    switch(method) {
      case 'GET':
        response = await http.get(url, headers: headers);
        break;
      case 'POST':
        response = await http.post(url, headers: headers, body: jsonEncode(body));
        break;
      case 'PUT':
        response = await http.put(url, headers: headers, body: jsonEncode(body));
        break;
      case 'DELETE':
        response = await http.delete(url, headers: headers);
        break;
      default:
        throw Exception('Неподдерживаемый метод: $method');
    }
    
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } else {
      final error = jsonDecode(utf8.decode(response.bodyBytes));
      throw Exception(error['error'] ?? 'Ошибка сервера: ${response.statusCode}');
    }
  }

  Future<void> _loadUserPhoto() async {
    if (userId == null) return;
    
    setState(() {
      _photoLoading = true;
    });

    try {
      final userData = await _apiRequest('/users/$userId?role=manager');
      
      if (userData['photo'] != null && userData['photo'].isNotEmpty) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_photo', userData['photo']);
        
        setState(() {
          userPhoto = userData['photo'];
        });
      }
    } catch (e) {
      debugPrint('Ошибка загрузки фото менеджера: $e');
    } finally {
      setState(() {
        _photoLoading = false;
      });
    }
  }

  Widget _buildAvatar(String? photoBase64, double radius) {
    if (_photoLoading) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: Colors.grey[300],
        child: const CircularProgressIndicator(),
      );
    }

    if (photoBase64 != null && photoBase64.isNotEmpty) {
      try {
        if (photoBase64.length > 100) {
          return CircleAvatar(
            radius: radius,
            backgroundColor: Colors.white,
            backgroundImage: MemoryImage(base64Decode(photoBase64)),
            onBackgroundImageError: (exception, stackTrace) {
              debugPrint('Ошибка загрузки изображения: $exception');
            },
          );
        }
      } catch (e) {
        debugPrint('Ошибка декодирования base64 изображения: $e');
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

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );

      if (image != null) {
        final bytes = await File(image.path).readAsBytes();
        final base64Image = base64Encode(bytes);
        
        await _updateManagerPhoto(base64Image);
      }
    } catch (e) {
      _showError('Ошибка выбора фото: $e');
    }
  }

  Future<void> _updateManagerPhoto(String base64Image) async {
    setState(() {
      _photoLoading = true;
    });

    try {
      final user = await _apiRequest('/users/$userId', 
        method: 'PUT',
        body: {
          'role': 'manager',
          'photo': base64Image,
        }
      );
      
      setState(() {
        userPhoto = user['photo'];
      });
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_photo', user['photo']);
      
      _showSuccess('Фото профиля обновлено');
      await _loadUserPhoto();
    } catch (e) {
      _showError('Ошибка обновления фото: $e');
    } finally {
      setState(() {
        _photoLoading = false;
      });
    }
  }

  Future<void> _pickMechanicImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );

      if (image != null) {
        final bytes = await File(image.path).readAsBytes();
        final base64Image = base64Encode(bytes);
        
        setState(() {
          _selectedMechanicPhotoBase64 = base64Image;
        });
        _showSuccess('Фото механика выбрано');
      }
    } catch (e) {
      _showError('Ошибка выбора фото механика: $e');
    }
  }

  Future<void> _loadUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        userId = prefs.getInt('user_id');
        userName = prefs.getString('user_name') ?? 'Менеджер';
        userEmail = prefs.getString('user_email') ?? 'Email не указан';
        
        _nameController.text = userName ?? '';
        _emailController.text = userEmail ?? '';
      });

      if (userId != null) {
        await _loadUserPhoto();
        await _loadManagerService();
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Ошибка загрузки данных пользователя: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadManagerService() async {
    try {
      final userData = await _apiRequest('/users/$userId?role=manager');
      
      setState(() {
        serviceId = userData['serviceId'];
      });
      
      if (serviceId != null) {
        await _loadServiceDetails();
      }
      await _loadAllData();
    } catch (e) {
      debugPrint('Ошибка загрузки сервиса менеджера: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadServiceDetails() async {
    try {
      final serviceData = await _apiRequest('/services/$serviceId/details');
      
      setState(() {
        serviceAddress = serviceData['address'] ?? 'Адрес не указан';
      });
    } catch (e) {
      debugPrint('Ошибка загрузки адреса сервиса: $e');
      setState(() {
        serviceAddress = 'Адрес не указан';
      });
    }
  }

  Future<void> _loadAllData() async {
    try {
      await Future.wait([
        _loadServiceRequests(),
        _loadServiceMechanics(),
        _loadTransports(),
        _loadApplicants(),
        _loadServices(),
      ]);
      setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('Ошибка загрузки всех данных: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadServiceRequests() async {
  try {
    final dynamic data = await _apiRequest('/requests');
    
    if (data is! List) {
      debugPrint('Ошибка: данные заявок не являются списком');
      setState(() {
        requests = [];
      });
      return;
    }
    
    final List<dynamic> filteredRequests = [];
    for (final request in data) {
      final requestServiceId = request['serviceId'];
      final parsedServiceId = requestServiceId is int 
          ? requestServiceId 
          : int.tryParse(requestServiceId?.toString() ?? '');
      
      if (parsedServiceId == serviceId) {
        filteredRequests.add(request);
      }
    }
    
    setState(() {
      requests = filteredRequests;
    });
  } catch (e) {
    debugPrint('Ошибка загрузки заявок: $e');
    setState(() {
      requests = [];
    });
  }
}

  Future<void> _loadServices() async {
  try {
    final dynamic data = await _apiRequest('/services');
    
    if (data is List) {
      setState(() {
        services = data;
      });
    } else {
      debugPrint('Сервисы пришли не как список');
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

  Future<void> _loadServiceMechanics() async {
  try {
    final dynamic data = await _apiRequest('/mechanics');
    
    if (data is! List) {
      debugPrint('Ошибка: данные механиков не являются списком');
      setState(() {
        mechanics = [];
      });
      return;
    }
    
    final List<dynamic> filteredMechanics = [];
    for (final mechanic in data) {
      final mechanicServiceId = mechanic['serviceId'];
      final parsedServiceId = mechanicServiceId is int 
          ? mechanicServiceId 
          : int.tryParse(mechanicServiceId?.toString() ?? '');
      
      if (parsedServiceId == serviceId) {
        filteredMechanics.add(mechanic);
      }
    }
    
    setState(() {
      mechanics = filteredMechanics;
    });
  } catch (e) {
    debugPrint('Ошибка загрузки механиков: $e');
    setState(() {
      mechanics = [];
    });
  }
}

  Future<void> _loadTransports() async {
  try {
    final dynamic data = await _apiRequest('/transports');
    
    if (data is List) {
      setState(() {
        transports = data;
      });
    } else {
      debugPrint('Транспорты пришли не как список');
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


  Future<void> _loadApplicants() async {
  try {
    final dynamic data = await _apiRequest('/applicants');
    
    if (data is List) {
      setState(() {
        applicants = data;
      });
    } else {
      debugPrint('Заявители пришли не как список');
      setState(() {
        applicants = [];
      });
    }
  } catch (e) {
    debugPrint('Ошибка загрузки заявителей: $e');
    setState(() {
      applicants = [];
    });
  }
}

  void _showRequestDetails(Map<String, dynamic> request) {
    final applicant = applicants.firstWhere(
      (a) => (a['id'] is int ? a['id'] : int.tryParse(a['id'].toString()) ?? 0) == 
             (request['applicantId'] is int ? request['applicantId'] : int.tryParse(request['applicantId'].toString()) ?? 0),
      orElse: () => {'name': 'Неизвестно', 'email': 'Неизвестно'},
    );
        
    final transport = transports.firstWhere(
      (t) => (t['id'] is int ? t['id'] : int.tryParse(t['id'].toString()) ?? 0) == 
             (request['transportId'] is int ? request['transportId'] : int.tryParse(request['transportId'].toString()) ?? 0),
      orElse: () => {'type': 'Неизвестно', 'model': 'Неизвестно', 'serial': 'Неизвестно', 'photo': ''},
    );

    final mechanic = _getRequestMechanic(request);

    final status = request['status']?.toString() ?? 'новая';
    final statusColor = _getStatusColor(status);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            width: MediaQuery.of(context).size.width * 0.95,
            padding: const EdgeInsets.all(16),
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
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildDetailRow('Номер заявки:', '#${request['id']}'),
                  _buildDetailRow('Статус:', status),
                  _buildDetailRow('Проблема:', request['problem']?.toString() ?? ''),
                  
                  _buildDetailRow('Дата создания:', 
                    _formatDateTime(request['submittedAt']?.toString() ?? '')),
                  
                  const SizedBox(height: 12),
                  const Text('Данные заявителя:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  _buildDetailRow('Имя:', applicant['name']?.toString() ?? 'Неизвестно'),
                  _buildDetailRow('Email:', applicant['email']?.toString() ?? 'Неизвестно'),
                  
                  const SizedBox(height: 12),
                  const Text('Данные транспорта:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  _buildDetailRow('Тип:', transport['type']?.toString() ?? 'Неизвестно'),
                  _buildDetailRow('Модель:', transport['model']?.toString() ?? 'Неизвестно'),
                  _buildDetailRow('Серийный номер:', transport['serial']?.toString() ?? 'Неизвестно'),
                  
                  const SizedBox(height: 12),
                  const Text('Назначенный механик:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  _buildDetailRow('Имя:', mechanic?['name']?.toString() ?? 'Не назначен'),
                  _buildDetailRow('Email:', mechanic?['email']?.toString() ?? 'Не назначен'),
                  
                  if (transport['photo'] != null && transport['photo'] is String && (transport['photo'] as String).isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Text(
                      'Фото транспорта:',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 150,
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
                                  Icon(Icons.error, color: Colors.red, size: 30),
                                  SizedBox(height: 8),
                                  Text('Ошибка загрузки изображения', style: TextStyle(fontSize: 12)),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                  
                  if (request['closedAt'] != null) ...[
                    const SizedBox(height: 12),
                    _buildDetailRow('Дата закрытия:', 
                      _formatDate(request['closedAt']?.toString() ?? '')),
                  ],
                  
                  const SizedBox(height: 20),
                  Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: const Text('Закрыть'),
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (status != 'отклонена' && status != 'завершена')
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                              _showAssignmentDialog(request);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: const Text('Назначить механика'),
                          ),
                        ),
                      if (status != 'отклонена' && status != 'завершена') ...[
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                              _showStatusDialog(request);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: const Text('Сменить статус'),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showAssignmentDialog(Map<String, dynamic> request) {
    String? selectedMechanicId = request['mechanicId']?.toString();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Назначить механика'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Выберите механика для этой заявки:'),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String?>(
                    initialValue: selectedMechanicId,
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('Не назначен'),
                      ),
                      ...mechanics.map<DropdownMenuItem<String>>(
                        (mechanic) {
                          final mechanicId = mechanic['id'] is int 
                              ? mechanic['id'].toString() 
                              : mechanic['id']?.toString() ?? '';
                          return DropdownMenuItem<String>(
                            value: mechanicId,
                            child: Text('${mechanic['name']} (${mechanic['email']})'),
                          );
                        },
                      ),
                    ],
                    onChanged: (String? newValue) {
                      setDialogState(() {
                        selectedMechanicId = newValue;
                      });
                    },
                    decoration: const InputDecoration(
                      labelText: 'Механик',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Отмена'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (selectedMechanicId != null) {
                      _assignMechanicToRequest(request, int.parse(selectedMechanicId!));
                    } else {
                      _removeMechanicFromRequest(request);
                    }
                    Navigator.of(context).pop();
                  },
                  child: const Text('Сохранить'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showStatusDialog(Map<String, dynamic> request) {
    String selectedStatus = request['status']?.toString() ?? 'новая';

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Сменить статус'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Выберите новый статус заявки:'),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: selectedStatus,
                    items: [
                      'новая',
                      'принята', 
                      'в работе',
                      'отклонена',
                      'завершена'
                    ].map<DropdownMenuItem<String>>((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      setDialogState(() {
                        if (newValue != null) {
                          selectedStatus = newValue;
                        }
                      });
                    },
                    decoration: const InputDecoration(
                      labelText: 'Статус',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Отмена'),
                ),
                ElevatedButton(
                  onPressed: () {
                    _updateRequestStatus(request, selectedStatus);
                    Navigator.of(context).pop();
                  },
                  child: const Text('Сохранить'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _assignMechanicToRequest(Map<String, dynamic> request, int mechanicId) async {
    try {
      await _apiRequest(
        '/requests/${request['id']}',
        method: 'PUT',
        body: {
          'mechanicId': mechanicId,
          'status': 'в работе',
        }
      );

      await _loadServiceRequests();
      _showSuccess('Механик успешно назначен');
    } catch (e) {
      _showError('Ошибка назначения механика: $e');
    }
  }

  Future<void> _removeMechanicFromRequest(Map<String, dynamic> request) async {
    try {
      await _apiRequest(
        '/requests/${request['id']}',
        method: 'PUT',
        body: {
          'mechanicId': null,
          'status': 'новая',
        }
      );

      await _loadServiceRequests();
      _showSuccess('Механик удален из заявки');
    } catch (e) {
      _showError('Ошибка удаления механика: $e');
    }
  }

  Future<void> _updateRequestStatus(Map<String, dynamic> request, String newStatus) async {
    try {
      final Map<String, dynamic> updateData = {'status': newStatus};
      
      if (newStatus == 'отклонена' || newStatus == 'завершена') {
        updateData['closedAt'] = DateTime.now().toIso8601String();
      }

      await _apiRequest(
        '/requests/${request['id']}',
        method: 'PUT',
        body: updateData
      );

      await _loadServiceRequests();
      _showSuccess('Статус заявки обновлен на "$newStatus"');
    } catch (e) {
      debugPrint('Ошибка обновления статуса: $e');
      _showError('Ошибка обновления статуса: $e');
    }
  }

  void _showAddMechanicDialog() {
    _clearMechanicForm();
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Добавить механика'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: _mechanicNameController,
                      decoration: const InputDecoration(
                        labelText: 'Имя механика *',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _mechanicEmailController,
                      decoration: const InputDecoration(
                        labelText: 'Email *',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _mechanicPasswordController,
                      decoration: const InputDecoration(
                        labelText: 'Пароль *',
                        border: OutlineInputBorder(),
                      ),
                      obscureText: true,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        ElevatedButton(
                          onPressed: _pickMechanicImage,
                          child: const Text('Выбрать фото'),
                        ),
                        const SizedBox(width: 8),
                        if (_selectedMechanicPhotoBase64 != null)
                          const Text('Фото выбрано', style: TextStyle(color: Colors.green)),
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
                    _clearMechanicForm();
                    Navigator.of(context).pop();
                  },
                  child: const Text('Отмена'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (_validateMechanicForm()) {
                      _createMechanic();
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

  bool _validateMechanicForm() {
    if (_mechanicNameController.text.trim().isEmpty) {
      _showError('Введите имя механика');
      return false;
    }
    if (_mechanicEmailController.text.trim().isEmpty) {
      _showError('Введите email механика');
      return false;
    }
    if (_mechanicPasswordController.text.trim().isEmpty) {
      _showError('Введите пароль механика');
      return false;
    }
    return true;
  }

  Future<void> _createMechanic() async {
    try {
      final Map<String, dynamic> mechanicData = {
        'name': _mechanicNameController.text.trim(),
        'email': _mechanicEmailController.text.trim(),
        'password': _mechanicPasswordController.text.trim(),
        'role': 'mechanic',
      };
      
      if (_selectedMechanicPhotoBase64 != null && _selectedMechanicPhotoBase64!.isNotEmpty) {
        mechanicData['photo'] = _selectedMechanicPhotoBase64!;
      }
      
      if (serviceId != null) {
        mechanicData['serviceId'] = serviceId;
      }
      
      await _apiRequest(
        '/mechanics',
        method: 'POST',
        body: mechanicData,
      );
      
      await _loadServiceMechanics();
      _clearMechanicForm();
      _showSuccess('Механик успешно создан');
    } catch (e) {
      debugPrint('Полная ошибка создания механика: $e');
      _showError('Ошибка создания механика: $e');
    }
  }

  void _clearMechanicForm() {
    _mechanicNameController.clear();
    _mechanicEmailController.clear();
    _mechanicPasswordController.clear();
    _selectedMechanicPhotoBase64 = null;
  }

  Future<void> _deleteMechanic(Map<String, dynamic> mechanic) async {
    try {
      await _apiRequest(
        '/mechanics/${mechanic['id']}',
        method: 'DELETE',
      );

      await _loadServiceMechanics();
      _showSuccess('Механик удален');
    } catch (e) {
      _showError('Ошибка удаления механика: $e');
    }
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      )
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

  Map<String, dynamic>? _getRequestMechanic(Map<String, dynamic> request) {
    if (request['mechanicId'] == null) return null;
    try {
      return mechanics.firstWhere((m) => 
        (m['id'] is int ? m['id'] : int.tryParse(m['id'].toString()) ?? 0) == 
        (request['mechanicId'] is int ? request['mechanicId'] : int.tryParse(request['mechanicId'].toString()) ?? 0)
      );
    } catch (e) {
      return null;
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'новая': return Colors.blue;
      case 'принята': return Colors.orange;
      case 'в работе': return Colors.purple;
      case 'отклонена': return Colors.red;
      case 'завершена': return Colors.green;
      default: return Colors.grey;
    }
  }

  List<dynamic> _getFilteredAndSortedRequests() {
    List<dynamic> filtered = List.from(requests);

    if (_statusFilter != null) {
      filtered = filtered.where((request) => request['status'] == _statusFilter).toList();
    }

    if (_mechanicFilter != null) {
      filtered = filtered.where((request) => 
        request['mechanicId']?.toString() == _mechanicFilter
      ).toList();
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
                    const Text('Сортировка по дате:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    
                    Column(
                      children: [
                        Radio<String>(
                          value: 'newest',
                          groupValue: _sortOrder,
                          onChanged: (String? value) {
                            if (value != null) {
                              setState(() {
                                _sortOrder = value;
                              });
                            }
                          },
                        ),
                        const Text('Сначала новые'),
                        const SizedBox(height: 8),
                        Radio<String>(
                          value: 'oldest',
                          groupValue: _sortOrder,
                          onChanged: (String? value) {
                            if (value != null) {
                              setState(() {
                                _sortOrder = value;
                              });
                            }
                          },
                        ),
                        const Text('Сначала старые'),
                      ],
                    ),
                    
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 8),
                    
                    const Text('Фильтр по статусу:', style: TextStyle(fontWeight: FontWeight.bold)),
                    DropdownButtonFormField<String?>(
                      initialValue: _statusFilter,
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('Все статусы'),
                        ),
                        ...['новая', 'принята', 'в работе', 'отклонена', 'завершена']
                            .map<DropdownMenuItem<String>>((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(value),
                          );
                        }),
                      ],
                      onChanged: (String? newValue) => setState(() => _statusFilter = newValue),
                      decoration: const InputDecoration(border: OutlineInputBorder()),
                    ),
                    
                    const SizedBox(height: 12),
                    
                    const Text('Фильтр по механику:', style: TextStyle(fontWeight: FontWeight.bold)),
                    DropdownButtonFormField<String?>(
                      initialValue: _mechanicFilter,
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('Все механики'),
                        ),
                        ...mechanics.map<DropdownMenuItem<String>>(
                          (mechanic) {
                            final mechanicId = mechanic['id'] is int 
                                ? mechanic['id'].toString() 
                                : mechanic['id']?.toString() ?? '';
                            return DropdownMenuItem<String>(
                              value: mechanicId,
                              child: Text(mechanic['name']?.toString() ?? 'Без имени'),
                            );
                          },
                        ),
                      ],
                      onChanged: (String? newValue) => setState(() => _mechanicFilter = newValue),
                      decoration: const InputDecoration(border: OutlineInputBorder()),
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
                      _mechanicFilter = null;
                    });
                    Navigator.of(context).pop();
                  },
                  child: const Text('Сбросить'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Закрыть'),
                ),
              ],
            );
          },
        );
      },
    );
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
        'role': 'manager',
      };

      if (_passwordController.text.trim().isNotEmpty) {
        updateData['password'] = _passwordController.text.trim();
      }

      final user = await _apiRequest(
        '/users/$userId',
        method: 'PUT',
        body: updateData,
      );
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_name', user['name']);
      await prefs.setString('user_email', user['email']);
      
      setState(() {
        userName = user['name'];
        userEmail = user['email'];
        _passwordController.clear();
      });

      _showSuccess('Профиль успешно обновлен');
    } catch (e) {
      _showError('Ошибка обновления профиля: $e');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
    }
  }

  Widget _buildProfilePanel() {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.8,
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 10,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              height: 150,
              decoration: BoxDecoration(
                color: Colors.blue[700],
              ),
              child: Stack(
                children: [
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        GestureDetector(
                          onTap: _pickImage,
                          child: Stack(
                            children: [
                              _buildAvatar(userPhoto, 50),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: Colors.blue[700],
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 2.0),
                                  ),
                                  child: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    top: 16,
                    left: 16,
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => setState(() => _isAccountPanelOpen = false),
                    ),
                  ),
                  Positioned(
                    top: 16,
                    right: 16,
                    child: IconButton(
                      icon: const Icon(Icons.logout, color: Colors.white),
                      onPressed: _logout,
                      tooltip: 'Выйти из аккаунта',
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE3F2FD),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.business, color: Color(0xFF1976D2)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Адрес сервиса',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1976D2),
                                  ),
                                ),
                                Text(
                                  serviceAddress ?? 'Адрес не указан',
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),
                    TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Имя',
                        prefixIcon: Icon(Icons.person),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _emailController,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.email),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _passwordController,
                      decoration: const InputDecoration(
                        labelText: 'Новый пароль (оставьте пустым, если не хотите менять)',
                        prefixIcon: Icon(Icons.lock),
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
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF1976D2),
                          side: const BorderSide(color: Color(0xFF1976D2)),
                          elevation: 2,
                        ),
                        child: const Text(
                          'Сохранить изменения',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredRequests = _getFilteredAndSortedRequests();

    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            title: const Text('Панель менеджера'),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () {
                  setState(() => _isLoading = true);
                  _loadAllData().then((_) => setState(() => _isLoading = false));
                },
                tooltip: 'Обновить',
              ),
              IconButton(
                icon: const Icon(Icons.filter_list),
                onPressed: _showSortFilterDialog,
                tooltip: 'Сортировка и фильтры',
              ),
              IconButton(
                icon: const Icon(Icons.account_circle),
                onPressed: () => setState(() => _isAccountPanelOpen = true),
                tooltip: 'Профиль',
              ),
            ],
            bottom: TabBar(
              controller: _tabController,
              tabs: const [
                Tab(icon: Icon(Icons.list_alt), text: 'Заявки'),
                Tab(icon: Icon(Icons.engineering), text: 'Механики'),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : filteredRequests.isEmpty
                      ? const Center(child: Text('Заявок нет'))
                      : ListView.builder(
                          itemCount: filteredRequests.length,
                          itemBuilder: (context, index) {
                            final request = filteredRequests[index];
                            return _buildRequestCard(request);
                          },
                        ),
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: ElevatedButton.icon(
                            onPressed: _showAddMechanicDialog,
                            icon: const Icon(Icons.person_add),
                            label: const Text('Добавить механика'),
                          ),
                        ),
                        Expanded(
                          child: mechanics.isEmpty
                              ? const Center(child: Text('Механиков нет'))
                              : ListView.builder(
                                  itemCount: mechanics.length,
                                  itemBuilder: (context, index) {
                                    final mechanic = mechanics[index];
                                    return Card(
                                      margin: const EdgeInsets.symmetric(
                                          vertical: 4, horizontal: 8),
                                      child: ListTile(
                                        leading: _buildAvatar(mechanic['photo'], 20),
                                        title: Text(mechanic['name']?.toString() ?? ''),
                                        subtitle: Text(mechanic['email']?.toString() ?? ''),
                                        trailing: IconButton(
                                          icon: const Icon(Icons.delete,
                                              color: Colors.red),
                                          onPressed: () =>
                                              _deleteMechanic(mechanic),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
            ],
          ),
        ),

        if (_isAccountPanelOpen)
          Container(
            color: const Color.fromARGB(137, 0, 0, 0),
          ),

        if (_isAccountPanelOpen)
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            child: _buildProfilePanel(),
          ),
      ],
    );
  }

  Widget _buildRequestCard(Map<String, dynamic> request) {
    final transport = transports.firstWhere(
      (t) => (t['id'] is int ? t['id'] : int.tryParse(t['id'].toString()) ?? 0) == 
             (request['transportId'] is int ? request['transportId'] : int.tryParse(request['transportId'].toString()) ?? 0),
      orElse: () => {'type': 'Неизвестно', 'model': 'Неизвестно', 'serial': 'Неизвестно', 'photo': ''},
    );

    final status = request['status']?.toString() ?? 'новая';
    final statusColor = _getStatusColor(status);

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
                child: (transport['photo'] != null && transport['photo'] is String && (transport['photo'] as String).isNotEmpty)
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.memory(
                          base64Decode(transport['photo'] as String),
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            debugPrint('Ошибка загрузки фото транспорта: $error');
                            return const Center(
                              child: Icon(Icons.directions_bus, size: 40, color: Colors.grey),
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
}