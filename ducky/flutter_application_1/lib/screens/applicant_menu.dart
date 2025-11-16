import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:file_picker/file_picker.dart';
import '../global_config.dart';

// Объявляем базовый URL в начале файла
const String baseUrl = 'https://jvvrlmfl-3000.euw.devtunnels.ms'; // Замените на ваш публичный URL

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
  List<Request> requests = [];
  List<Transport> transports = [];
  List<Service> services = [];
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
  final ImagePicker _imagePicker = ImagePicker();

  final List<String> _transportTypes = [
    'троллейбусы',
    'электробусы',
    'трамваи',
    'электрогрузовики'
  ];

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  // Метод для загрузки данных пользователя с сервера
  Future<void> _loadUserDataFromServer() async {
    try {
      print('Loading user data from server for user ID: $userId');
      final response = await http.get(
        Uri.parse('$baseUrl/user-data/applicant/$userId'),
      );

      if (response.statusCode == 200) {
        final userData = json.decode(response.body);
        print('User data loaded from server: $userData');
        
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
          _nameController.text = userName!;
          _emailController.text = userEmail!;
        });
        
        print('User data saved to SharedPreferences');
      } else {
        print('Failed to load user data from server: ${response.statusCode}');
      }
    } catch (e) {
      print('Error loading user data from server: $e');
    }
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      userId = prefs.getInt('user_id');
      userName = prefs.getString('user_name') ?? 'Пользователь';
      userEmail = prefs.getString('user_email') ?? 'Email не указан';
      userPhoto = prefs.getString('user_photo');
      
      _nameController.text = userName!;
      _emailController.text = userEmail!;
    });
    
    print('User loaded from SharedPreferences: ID=$userId, Name=$userName, Photo: ${userPhoto != null ? "exists" : "null"}');
    
    // Всегда загружаем актуальные данные с сервера
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
  }

  Future<void> _loadUserRequests() async {
    try {
      print('Loading user requests for user ID: $userId');
      final response = await http.get(Uri.parse('$baseUrl/requests'));
      
      print('Requests response status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        print('Total requests loaded from server: ${data.length}');
        
        setState(() {
          requests = data.map((item) => Request.fromJson(item)).toList();
          requests = requests.where((request) => request.applicantId == userId).toList();
          print('Filtered requests for user $userId: ${requests.length}');
        });
      } else {
        print('Error loading requests: ${response.statusCode}');
      }
    } catch (e) {
      print('Ошибка загрузки заявок: $e');
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
        print('Loaded ${transports.length} transports');
      }
    } catch (e) {
      print('Ошибка загрузки транспорта: $e');
    }
  }

  Future<void> _loadServices() async {
    try {
      print('Loading services...');
      final response = await http.get(Uri.parse('$baseUrl/services'));
      
      print('Services response status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        print('Successfully loaded ${data.length} services');
        
        setState(() {
          services = data.map((item) => Service.fromJson(item)).toList();
        });
      } else {
        print('Failed to load services: ${response.statusCode}');
      }
    } catch (e) {
      print('Ошибка загрузки сервисов: $e');
    }
  }

  // Метод для построения аватарки с обработкой ошибок
  Widget _buildAvatar(String? photoBase64, double radius) {
    if (photoBase64 != null && photoBase64.isNotEmpty) {
      try {
        if (photoBase64.length > 100) {
          return CircleAvatar(
            radius: radius,
            backgroundColor: Colors.white,
            backgroundImage: MemoryImage(base64Decode(photoBase64)),
          );
        }
      } catch (e) {
        print('Error decoding base64 image: $e');
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

  // Обновленный метод для выбора фото транспорта с поддержкой всех платформ
  Future<void> _pickImage() async {
    try {
      print('Начало выбора фото транспорта...');
      
      if (kIsWeb) {
        await _pickImageWeb('transport');
      } else {
        await _pickImageMobile('transport');
      }
    } catch (e) {
      print('Ошибка выбора фото транспорта: $e');
      _showError('Ошибка выбора фото: $e');
    }
  }

  // Метод для выбора фото на веб-платформе с использованием file_picker
  Future<void> _pickImageWeb(String type) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );

      if (result != null && result.files.single.bytes != null) {
        final bytes = result.files.single.bytes!;
        final base64Image = base64Encode(bytes);
        
        print('Фото выбрано на веб-платформе, размер: ${bytes.length} байт');
        
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
      print('Ошибка выбора фото на веб-платформе: $e');
      _showError('Ошибка выбора фото: $e');
    }
  }

  // Метод для выбора фото на мобильных платформах
  Future<void> _pickImageMobile(String type) async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 80,
      );
      
      if (image != null) {
        if (kIsWeb) {
          // Для веба используем file_picker
          await _pickImageWeb(type);
        } else {
          // Для мобильных платформ
          await _processImageFile(File(image.path), type);
        }
      }
    } catch (e) {
      print('Ошибка выбора фото на мобильной платформе: $e');
      _showError('Ошибка выбора фото: $e');
    }
  }

  // Метод для обработки файла изображения (для мобильных платформ)
  Future<void> _processImageFile(File imageFile, String type) async {
    try {
      print('Обработка файла: ${imageFile.path}');
      final bytes = await imageFile.readAsBytes();
      print('Размер фото: ${bytes.length} байт');
      final base64Image = base64Encode(bytes);
      print('Base64 длина: ${base64Image.length} символов');
      
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
    } catch (e) {
      print('Ошибка обработки файла: $e');
      _showError('Ошибка обработки файла: $e');
    }
  }

  // Обновленный метод для выбора фото профиля с поддержкой всех платформ
  Future<void> _pickProfileImage() async {
    try {
      print('Начало выбора фото профиля...');
      
      if (kIsWeb) {
        await _pickImageWeb('profile');
      } else {
        await _pickImageMobile('profile');
      }
    } catch (e) {
      print('Ошибка выбора фото профиля: $e');
      _showError('Ошибка выбора фото: $e');
    }
  }

  void _createRequest() {
    _selectedServiceId = null;

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
                    DropdownButtonFormField<int>(
                      value: _selectedServiceId,
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('Выберите сервис *'),
                        ),
                        ...services.map((Service service) {
                          return DropdownMenuItem(
                            value: service.id,
                            child: Text('${service.address} (${service.workTime})'),
                          );
                        }).toList(),
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
                      value: _selectedTransportType,
                      items: _transportTypes.map((String type) {
                        return DropdownMenuItem(
                          value: type,
                          child: Text(type),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        setDialogState(() {
                          _selectedTransportType = newValue!;
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
                          onPressed: _pickImage,
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

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  Future<void> _addNewRequest() async {
    try {
      print('Starting to create new request...');
      print('Selected service ID: $_selectedServiceId');

      final transportResponse = await http.post(
        Uri.parse('$baseUrl/transports'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'type': _selectedTransportType,
          'serial': _serialController.text.trim(),
          'model': _modelController.text.trim(),
          'photo': _selectedPhotoBase64,
        }),
      );

      if (transportResponse.statusCode == 200) {
        final transportData = json.decode(transportResponse.body);
        final transportId = transportData['id'];
        print('Transport created with ID: $transportId');

        final requestResponse = await http.post(
          Uri.parse('$baseUrl/requests'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'problem': _problemController.text.trim(),
            'transportId': transportId,
            'applicantId': userId,
            'mechanicId': null,
            'serviceId': _selectedServiceId,
            'closedAt': null,
            'status': "новая"
          }),
        );

        if (requestResponse.statusCode == 200) {
          final requestData = json.decode(requestResponse.body);
          final newRequest = Request.fromJson(requestData);
          
          setState(() {
            requests.insert(0, newRequest);
          });
          
          _clearRequestForm();
          _showSuccess('Заявка успешно создана!');
          
          await _loadUserRequests();
        } else {
          throw Exception('Failed to create request: ${requestResponse.statusCode}');
        }
      } else {
        throw Exception('Failed to create transport: ${transportResponse.statusCode}');
      }
    } catch (e) {
      print('Ошибка создания заявки: $e');
      _showError('Ошибка при создании заявки: $e');
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
        updateData['photo'] = _selectedProfilePhotoBase64;
        print('Updating profile with new photo, length: ${_selectedProfilePhotoBase64!.length}');
      }

      if (_passwordController.text.trim().isNotEmpty) {
        updateData['password'] = _passwordController.text.trim();
      }

      print('Sending update request for user $userId');
      final response = await http.put(
        Uri.parse('$baseUrl/applicants/$userId'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(updateData),
      );

      print('Update response status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_name', _nameController.text.trim());
        await prefs.setString('user_email', _emailController.text.trim());
        if (_selectedProfilePhotoBase64 != null) {
          await prefs.setString('user_photo', _selectedProfilePhotoBase64!);
          print('Photo saved to SharedPreferences');
        }
        
        setState(() {
          userName = _nameController.text.trim();
          userEmail = _emailController.text.trim();
          if (_selectedProfilePhotoBase64 != null) {
            userPhoto = _selectedProfilePhotoBase64;
          }
          _passwordController.clear();
          _selectedProfilePhotoBase64 = null;
        });

        _showSuccess('Профиль успешно обновлен');
      } else {
        print('Server error: ${response.statusCode}, body: ${response.body}');
        throw Exception('Ошибка сервера: ${response.statusCode}');
      }
    } catch (e) {
      print('Ошибка обновления профиля: $e');
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

  void _showRequestDetails(Request request) {
    final transport = transports.firstWhere(
      (t) => t.id == request.transportId,
      orElse: () => Transport(id: 0, type: 'Неизвестно', serial: 'Неизвестно', model: 'Неизвестно'),
    );

    final service = request.serviceId != null 
        ? services.firstWhere(
            (s) => s.id == request.serviceId,
            orElse: () => Service(id: 0, address: 'Не указан', workTime: ''),
          )
        : Service(id: 0, address: 'Не назначен', workTime: '');

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
                  _buildDetailRow('Номер заявки:', '#${request.id}'),
                  _buildDetailRow('Проблема:', request.problem),
                  _buildDetailRow('Статус:', _getRequestStatus(request)),
                  _buildDetailRow('Сервис:', service.address),
                  _buildDetailRow('Дата создания:', 
                    '${request.submittedAt.day}.${request.submittedAt.month}.${request.submittedAt.year} ${request.submittedAt.hour}:${request.submittedAt.minute.toString().padLeft(2, '0')}'),
                  if (request.closedAt != null)
                    _buildDetailRow('Дата закрытия:', 
                      '${request.closedAt!.day}.${request.closedAt!.month}.${request.closedAt!.year}'),
                  const SizedBox(height: 20),
                  const Text(
                    'Данные транспорта:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  const SizedBox(height: 10),
                  _buildDetailRow('Тип:', transport.type),
                  _buildDetailRow('Серийный номер:', transport.serial),
                  _buildDetailRow('Модель:', transport.model),
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

  String _getRequestStatus(Request request) {
    if (request.closedAt != null) return 'закрыта';
    if (request.mechanicId != null) return 'в работе';
    return 'новая';
  }

  Color _getStatusColor(Request request) {
    final status = _getRequestStatus(request);
    switch (status) {
      case 'новая':
        return Colors.blue;
      case 'в работе':
        return Colors.orange;
      case 'закрыта':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  List<Request> _getFilteredAndSortedRequests() {
    List<Request> filtered = List.from(requests);

    if (_statusFilter != null) {
      filtered = filtered.where((request) => _getRequestStatus(request) == _statusFilter).toList();
    }

    if (_transportFilter != null) {
      filtered = filtered.where((request) {
        final transport = transports.firstWhere(
          (t) => t.id == request.transportId,
          orElse: () => Transport(id: 0, type: '', serial: '', model: ''),
        );
        return transport.type == _transportFilter;
      }).toList();
    }

    filtered.sort((a, b) {
      if (_sortOrder == 'newest') {
        return b.submittedAt.compareTo(a.submittedAt);
      } else {
        return a.submittedAt.compareTo(b.submittedAt);
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
                    const Text(
                      'Сортировка по дате:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    RadioListTile<String>(
                      title: const Text('Сначала новые'),
                      value: 'newest',
                      groupValue: _sortOrder,
                      onChanged: (String? value) {
                        setState(() {
                          _sortOrder = value!;
                        });
                        Navigator.of(context).pop();
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
                        Navigator.of(context).pop();
                      },
                    ),
                    
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 8),
                    
                    const Text(
                      'Фильтр по статусу:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    DropdownButtonFormField<String>(
                      value: _statusFilter,
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('Все статусы'),
                        ),
                        ...['новая', 'в работе', 'закрыта'].map((String status) {
                          return DropdownMenuItem(
                            value: status,
                            child: Text(status),
                          );
                        }).toList(),
                      ],
                      onChanged: (String? newValue) {
                        setState(() {
                          _statusFilter = newValue;
                        });
                        Navigator.of(context).pop();
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
                    DropdownButtonFormField<String>(
                      value: _transportFilter,
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('Все типы'),
                        ),
                        ..._transportTypes.map((String type) {
                          return DropdownMenuItem(
                            value: type,
                            child: Text(type),
                          );
                        }).toList(),
                      ],
                      onChanged: (String? newValue) {
                        setState(() {
                          _transportFilter = newValue;
                        });
                        Navigator.of(context).pop();
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

  // НОВЫЙ ДИЗАЙН КАРТОЧКИ ЗАЯВКИ
  Widget _buildRequestCard(Request request) {
    final transport = transports.firstWhere(
      (t) => t.id == request.transportId,
      orElse: () => Transport(id: 0, type: 'Неизвестно', serial: 'Неизвестно', model: 'Неизвестно'),
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
                    // Название транспорта
                    Text(
                      transport.model,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    // Описание проблемы
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
                    // Статус заявки
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
                  ],
                ),
              ),
            ],
          ),
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
          appBar: null, // Убираем AppBar
          body: Column(
            children: [
              // Кастомный заголовок вместо AppBar
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

        // Панель аккаунта
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
                  // Кастомный заголовок для панели аккаунта
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
                            onTap: _pickProfileImage,
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

class Request {
  final int id;
  final String problem;
  final DateTime submittedAt;
  final DateTime? closedAt;
  final int transportId;
  final int applicantId;
  final int? mechanicId;
  final int? serviceId;

  Request({
    required this.id,
    required this.problem,
    required this.submittedAt,
    this.closedAt,
    required this.transportId,
    required this.applicantId,
    this.mechanicId,
    this.serviceId,
  });

  factory Request.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic date) {
      if (date == null) return DateTime.now();
      try {
        if (date is String) {
          return DateTime.parse(date);
        }
        return DateTime.now();
      } catch (e) {
        print('Error parsing date: $date, error: $e');
        return DateTime.now();
      }
    }

    return Request(
      id: json['id'] ?? 0,
      problem: json['problem'] ?? 'Описание не указано',
      submittedAt: parseDate(json['submittedAt']),
      closedAt: json['closedAt'] != null ? parseDate(json['closedAt']) : null,
      transportId: json['transportId'] ?? 0,
      applicantId: json['applicantId'] ?? 0,
      mechanicId: json['mechanicId'],
      serviceId: json['serviceId'],
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

class Service {
  final int id;
  final String address;
  final String workTime;
  final Manager? manager;
  final List<Mechanic>? mechanics;

  Service({
    required this.id,
    required this.address,
    required this.workTime,
    this.manager,
    this.mechanics,
  });

  factory Service.fromJson(Map<String, dynamic> json) {
    return Service(
      id: json['id'] ?? 0,
      address: json['address'] ?? 'Адрес не указан',
      workTime: json['workTime'] ?? 'Время работы не указано',
      manager: json['manager'] != null ? Manager.fromJson(json['manager']) : null,
      mechanics: json['mechanics'] != null && json['mechanics'] is List
          ? (json['mechanics'] as List).map((i) => Mechanic.fromJson(i)).toList()
          : null,
    );
  }
}

class Manager {
  final int id;
  final String name;

  Manager({required this.id, required this.name});

  factory Manager.fromJson(Map<String, dynamic> json) {
    return Manager(
      id: json['id'] ?? 0,
      name: json['name'] ?? 'Неизвестно',
    );
  }
}

class Mechanic {
  final int id;
  final String name;

  Mechanic({required this.id, required this.name});

  factory Mechanic.fromJson(Map<String, dynamic> json) {
    return Mechanic(
      id: json['id'] ?? 0,
      name: json['name'] ?? 'Неизвестно',
    );
  }
}