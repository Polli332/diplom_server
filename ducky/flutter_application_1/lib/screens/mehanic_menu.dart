import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:file_picker/file_picker.dart';

const String baseUrl = 'https://jvvrlmfl-3000.euw.devtunnels.ms';

class MechanicMenu extends StatefulWidget {
  const MechanicMenu({super.key});

  @override
  State<MechanicMenu> createState() => _MechanicMenuState();
}

class _MechanicMenuState extends State<MechanicMenu> {
  String? userName;
  String? userEmail;
  int? userId;
  int? serviceId;
  String? userPhoto;
  String? serviceAddress;
  List<Request> requests = [];
  List<Transport> transports = [];
  List<Applicant> applicants = [];
  bool _isAccountPanelOpen = false;
  String _sortOrder = 'newest';
  String? _statusFilter;
  bool _isLoading = true;
  bool _photoLoading = false;
  final TextEditingController _searchController = TextEditingController();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  final List<String> _statusList = ['новая', 'принята', 'в работе'];

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  // Загрузка фото пользователя
  Future<void> _loadUserPhoto() async {
    if (userId == null) return;
    
    setState(() {
      _photoLoading = true;
    });

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/mechanic/$userId'),
      );

      if (response.statusCode == 200) {
        final mechanicData = json.decode(response.body);
        
        if (mechanicData['photo'] != null && mechanicData['photo'].isNotEmpty) {
          final String photoBase64 = mechanicData['photo'];
          
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('user_photo', photoBase64);
          
          setState(() {
            userPhoto = photoBase64;
          });
        }
      }
    } catch (e) {
      print('Error loading mechanic photo: $e');
    } finally {
      setState(() {
        _photoLoading = false;
      });
    }
  }

  // Метод для построения аватарки
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
              print('Ошибка загрузки изображения: $exception');
            },
          );
        }
      } catch (e) {
        print('Ошибка декодирования base64 изображения: $e');
      }
    }
    
    return CircleAvatar(
      radius: radius,
      backgroundColor: Colors.green,
      child: Icon(
        Icons.person,
        size: radius,
        color: Colors.white,
      ),
    );
  }

  // Выбор фото
  Future<void> _pickImage() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );

      if (result != null && result.files.single.bytes != null) {
        final bytes = result.files.single.bytes!;
        final base64Image = base64Encode(bytes);
        
        await _updateMechanicPhoto(base64Image);
      }
    } catch (e) {
      _showError('Ошибка выбора фото: $e');
    }
  }

  // Обновление фото механика
  Future<void> _updateMechanicPhoto(String base64Image) async {
    setState(() {
      _photoLoading = true;
    });

    try {
      final response = await http.put(
        Uri.parse('$baseUrl/mechanics/$userId'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'photo': base64Image,
        }),
      );
      
      if (response.statusCode == 200) {
        setState(() {
          userPhoto = base64Image;
        });
        
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_photo', base64Image);
        
        _showSuccess('Фото профиля обновлено');
        await _loadUserPhoto();
      } else {
        _showError('Ошибка сервера: ${response.statusCode}');
      }
    } catch (e) {
      _showError('Ошибка обновления фото: $e');
    } finally {
      setState(() {
        _photoLoading = false;
      });
    }
  }

  // Загрузка данных пользователя
  Future<void> _loadUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        userId = prefs.getInt('user_id');
        userName = prefs.getString('user_name') ?? 'Механик';
        userEmail = prefs.getString('user_email') ?? 'Email не указан';
        
        _nameController.text = userName!;
        _emailController.text = userEmail!;
      });

      if (userId != null) {
        await _loadUserPhoto();
        await _loadMechanicService();
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print('Ошибка загрузки данных пользователя: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMechanicService() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/mechanic/$userId'));
      
      if (response.statusCode == 200) {
        final mechanicData = json.decode(response.body);
        setState(() {
          serviceId = mechanicData['serviceId'];
        });
        
        if (serviceId != null) {
          await _loadServiceDetails();
        }
        await _loadAllData();
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadServiceDetails() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/services/$serviceId'));
      if (response.statusCode == 200) {
        final serviceData = json.decode(response.body);
        setState(() {
          serviceAddress = serviceData['address'] ?? 'Адрес не указан';
        });
      }
    } catch (e) {
      setState(() {
        serviceAddress = 'Адрес не указан';
      });
    }
  }

  Future<void> _loadAllData() async {
    try {
      await Future.wait([
        _loadMechanicRequests(),
        _loadTransports(),
        _loadApplicants(),
      ]);
      setState(() => _isLoading = false);
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  // Загрузка заявок механика
  Future<void> _loadMechanicRequests() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/mechanic/requests/$userId'));
      
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          requests = data.map((item) => Request.fromJson(item)).toList();
        });
      } else {
        // Fallback: загружаем все заявки и фильтруем
        await _loadAllRequestsAndFilter();
      }
    } catch (e) {
      print('Error loading mechanic requests: $e');
      // Fallback: загружаем все заявки и фильтруем
      await _loadAllRequestsAndFilter();
    }
  }

  // Fallback метод для загрузки заявок
  Future<void> _loadAllRequestsAndFilter() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/requests'));
      
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        List<Request> allRequests = data.map((item) => Request.fromJson(item)).toList();
        
        setState(() {
          requests = allRequests.where((request) => 
            request.mechanicId == userId && request.status != 'завершена'
          ).toList();
        });
      }
    } catch (e) {
      print('Error loading all requests: $e');
    }
  }

  Future<void> _loadTransports() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/transports'));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          transports = data.map((item) => Transport.fromJson(item)).toList();
        });
      }
    } catch (e) {
      print('Error loading transports: $e');
    }
  }

  Future<void> _loadApplicants() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/applicants'));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          applicants = data.map((item) => Applicant.fromJson(item)).toList();
        });
      }
    } catch (e) {
      print('Error loading applicants: $e');
    }
  }

  // Просмотр деталей заявки
  void _showRequestDetails(Request request) {
    final applicant = request.applicant != null 
        ? Applicant.fromJson(request.applicant!)
        : applicants.firstWhere(
            (a) => a.id == request.applicantId,
            orElse: () => Applicant(id: 0, name: 'Неизвестно', email: 'Неизвестно'),
          );
        
    final transport = request.transport != null
        ? Transport.fromJson(request.transport!)
        : transports.firstWhere(
            (t) => t.id == request.transportId,
            orElse: () => Transport(id: 0, type: 'Неизвестно', model: 'Неизвестно', serial: 'Неизвестно'),
          );

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
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildDetailRow('Номер заявки:', '#${request.id}'),
                  _buildDetailRow('Проблема:', request.problem),
                  _buildDetailRow('Статус:', request.status),
                  _buildDetailRow('Дата создания:', 
                    '${request.submittedAt.day}.${request.submittedAt.month}.${request.submittedAt.year} ${request.submittedAt.hour}:${request.submittedAt.minute.toString().padLeft(2, '0')}'),
                  
                  const SizedBox(height: 16),
                  const Text('Данные заявителя:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  _buildDetailRow('Имя:', applicant.name),
                  _buildDetailRow('Email:', applicant.email),
                  
                  const SizedBox(height: 16),
                  const Text('Данные транспорта:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  _buildDetailRow('Тип:', transport.type),
                  _buildDetailRow('Модель:', transport.model),
                  _buildDetailRow('Серийный номер:', transport.serial),
                  
                  if (transport.photo != null && transport.photo!.isNotEmpty) ...[
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
                          base64Decode(transport.photo!),
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          _completeRequest(request);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                        ),
                        child: const Text('Завершить заявку'),
                      ),
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

  // Завершение заявки
  Future<void> _completeRequest(Request request) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/mechanic/requests/${request.id}/complete'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        await _loadMechanicRequests();
        _showSuccess('Заявка завершена');
      } else {
        // Fallback: используем обычный эндпоинт
        await _completeRequestFallback(request);
      }
    } catch (e) {
      // Fallback: используем обычный эндпоинт
      await _completeRequestFallback(request);
    }
  }

  // Fallback метод для завершения заявки
  Future<void> _completeRequestFallback(Request request) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/requests/${request.id}'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'status': 'завершена',
          'closedAt': DateTime.now().toIso8601String(),
        }),
      );

      if (response.statusCode == 200) {
        await _loadMechanicRequests();
        _showSuccess('Заявка завершена');
      } else {
        _showError('Ошибка завершения заявки: ${response.statusCode}');
      }
    } catch (e) {
      _showError('Ошибка завершения заявки: $e');
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
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'новая': return Colors.blue;
      case 'принята': return Colors.orange;
      case 'в работе': return Colors.purple;
      case 'завершена': return Colors.green;
      default: return Colors.grey;
    }
  }

  List<Request> _getFilteredAndSortedRequests() {
    List<Request> filtered = List.from(requests);

    // Поиск
    if (_searchController.text.isNotEmpty) {
      final searchLower = _searchController.text.toLowerCase();
      filtered = filtered.where((request) {
        return request.problem.toLowerCase().contains(searchLower) ||
               request.status.toLowerCase().contains(searchLower) ||
               _getTransportModel(request.transportId).toLowerCase().contains(searchLower);
      }).toList();
    }

    // Фильтр по статусу
    if (_statusFilter != null) {
      filtered = filtered.where((request) => request.status == _statusFilter).toList();
    }

    // Сортировка
    filtered.sort((a, b) {
      if (_sortOrder == 'newest') {
        return b.submittedAt.compareTo(a.submittedAt);
      } else {
        return a.submittedAt.compareTo(b.submittedAt);
      }
    });

    return filtered;
  }

  String _getTransportModel(int transportId) {
    final transport = transports.firstWhere(
      (t) => t.id == transportId,
      orElse: () => Transport(id: 0, type: 'Неизвестно', model: 'Неизвестно', serial: 'Неизвестно'),
    );
    return transport.model;
  }

  // Карточка заявки
  Widget _buildRequestCard(Request request) {
    final transport = request.transport != null
        ? Transport.fromJson(request.transport!)
        : transports.firstWhere(
            (t) => t.id == request.transportId,
            orElse: () => Transport(id: 0, type: 'Неизвестно', model: 'Неизвестно', serial: 'Неизвестно'),
          );

    final statusColor = _getStatusColor(request.status);

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
              // Фото транспорта
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: transport.photo != null && transport.photo!.isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.memory(
                          base64Decode(transport.photo!),
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
                      transport.model,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      request.problem,
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
                        request.status.toUpperCase(),
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
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

  void _showSortFilterDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Сортировка и фильтры'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Сортировка по дате:', style: TextStyle(fontWeight: FontWeight.bold)),
                RadioListTile<String>(
                  title: const Text('Сначала новые'),
                  value: 'newest',
                  groupValue: _sortOrder,
                  onChanged: (String? value) {
                    setState(() {
                      _sortOrder = value!;
                    });
                  },
                ),
                RadioListTile<String>(
                  title: const Text('Сначала старые'),
                  value: 'oldest',
                  groupValue: _sortOrder,
                  onChanged: (String? value) {
                    setState(() {
                      _sortOrder = value!;
                    });
                  },
                ),
                
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                
                const Text('Фильтр по статусу:', style: TextStyle(fontWeight: FontWeight.bold)),
                DropdownButtonFormField<String>(
                  value: _statusFilter,
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Все статусы')),
                    ..._statusList.map((status) => DropdownMenuItem(value: status, child: Text(status))),
                  ],
                  onChanged: (String? newValue) => setState(() => _statusFilter = newValue),
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
                  _searchController.clear();
                });
                Navigator.of(context).pop();
              },
              child: const Text('Сбросить'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Применить'),
            ),
          ],
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
      };

      if (_passwordController.text.trim().isNotEmpty) {
        updateData['password'] = _passwordController.text.trim();
      }

      final response = await http.put(
        Uri.parse('$baseUrl/mechanics/$userId'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(updateData),
      );

      if (response.statusCode == 200) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_name', _nameController.text.trim());
        await prefs.setString('user_email', _emailController.text.trim());
        
        setState(() {
          userName = _nameController.text.trim();
          userEmail = _emailController.text.trim();
          _passwordController.clear();
        });

        _showSuccess('Профиль успешно обновлен');
      } else {
        _showError('Ошибка обновления профиля: ${response.statusCode}');
      }
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

  // Панель профиля
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
              height: 200,
              decoration: BoxDecoration(
                color: Colors.green[700],
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
                                    color: Colors.green,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 2),
                                  ),
                                  child: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          userName ?? 'Механик',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          userEmail ?? 'Email не указан',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
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
                        color: Colors.green[50],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.business, color: Colors.green[700]),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Адрес сервиса',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green[700],
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
                      )
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _emailController, 
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.email),
                        border: OutlineInputBorder(),
                      )
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _passwordController, 
                      decoration: const InputDecoration(
                        labelText: 'Новый пароль (оставьте пустым, если не хотите менять)',
                        prefixIcon: Icon(Icons.lock),
                        border: OutlineInputBorder(),
                      ), 
                      obscureText: true
                    ),
                    const SizedBox(height: 30),
                    SizedBox(
                      width: double.infinity, 
                      height: 50, 
                      child: ElevatedButton(
                        onPressed: _updateProfile, 
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.green[700],
                          side: BorderSide(color: Colors.green[700]!),
                          elevation: 2,
                        ),
                        child: const Text(
                          'Сохранить изменения',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )
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
            title: const Text('Панель механика'),
            backgroundColor: Colors.green,
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
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Поиск заявок...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              setState(() {
                                _searchController.clear();
                              });
                            },
                          )
                        : null,
                  ),
                  onChanged: (value) => setState(() {}),
                ),
              ),
              Expanded(
                child: _isLoading
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
              ),
            ],
          ),
        ),

        if (_isAccountPanelOpen)
          Container(
            color: Colors.black54,
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
}

// Модели данных
class Request {
  final int id;
  final String problem;
  final DateTime submittedAt;
  final DateTime? closedAt;
  final int transportId;
  final int applicantId;
  final int? mechanicId;
  final int? serviceId;
  final String status;
  final Map<String, dynamic>? applicant;
  final Map<String, dynamic>? transport;
  final Map<String, dynamic>? mechanic;

  Request({
    required this.id,
    required this.problem,
    required this.submittedAt,
    this.closedAt,
    required this.transportId,
    required this.applicantId,
    this.mechanicId,
    this.serviceId,
    required this.status,
    this.applicant,
    this.transport,
    this.mechanic,
  });

  factory Request.fromJson(Map<String, dynamic> json) {
    return Request(
      id: json['id'] ?? 0,
      problem: json['problem'] ?? 'Описание не указано',
      submittedAt: DateTime.parse(json['submittedAt'] ?? DateTime.now().toIso8601String()),
      closedAt: json['closedAt'] != null ? DateTime.parse(json['closedAt']) : null,
      transportId: json['transportId'] ?? 0,
      applicantId: json['applicantId'] ?? 0,
      mechanicId: json['mechanicId'],
      serviceId: json['serviceId'],
      status: json['status'] ?? 'новая',
      applicant: json['applicant'] is Map ? Map<String, dynamic>.from(json['applicant']) : null,
      transport: json['transport'] is Map ? Map<String, dynamic>.from(json['transport']) : null,
      mechanic: json['mechanic'] is Map ? Map<String, dynamic>.from(json['mechanic']) : null,
    );
  }
}

class Mechanic {
  final int id;
  final String name;
  final String email;
  final String? photo;
  final int serviceId;

  Mechanic({
    required this.id,
    required this.name,
    required this.email,
    required this.serviceId,
    this.photo,
  });

  factory Mechanic.fromJson(Map<String, dynamic> json) {
    return Mechanic(
      id: json['id'] ?? 0,
      name: json['name'] ?? 'Неизвестно',
      email: json['email'] ?? 'Неизвестно',
      serviceId: json['serviceId'] ?? 0,
      photo: json['photo'],
    );
  }
}

class Applicant {
  final int id;
  final String name;
  final String email;

  Applicant({required this.id, required this.name, required this.email});

  factory Applicant.fromJson(Map<String, dynamic> json) {
    return Applicant(
      id: json['id'] ?? 0,
      name: json['name'] ?? 'Неизвестно',
      email: json['email'] ?? 'Неизвестно',
    );
  }
}

class Transport {
  final int id;
  final String type;
  final String serial;
  final String? photo;
  final String model;

  Transport({
    required this.id,
    required this.type,
    required this.serial,
    required this.model,
    this.photo,
  });

  factory Transport.fromJson(Map<String, dynamic> json) {
    return Transport(
      id: json['id'] ?? 0,
      type: json['type'] ?? 'Неизвестно',
      serial: json['serial'] ?? 'Неизвестно',
      model: json['model'] ?? 'Неизвестно',
      photo: json['photo'],
    );
  }
}