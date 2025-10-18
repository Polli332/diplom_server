import 'dart:convert';
import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show kIsWeb;

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
  List<Request> requests = [];
  List<Mechanic> mechanics = [];
  List<Transport> transports = [];
  List<Applicant> applicants = [];
  bool _isAccountPanelOpen = false;
  String _sortOrder = 'newest';
  String? _statusFilter;
  String? _mechanicFilter;
  bool _isLoading = true;
  bool _photoLoading = false;

  late TabController _tabController;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _mechanicNameController = TextEditingController();
  final TextEditingController _mechanicEmailController = TextEditingController();
  final TextEditingController _mechanicPasswordController = TextEditingController();
  String? _selectedMechanicPhotoBase64;

  final ImagePicker _imagePicker = ImagePicker();
  final List<String> _statusList = ['новая', 'принята', 'в работе', 'отклонена'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadUserData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // УПРОЩЕННЫЙ МЕТОД ЗАГРУЗКИ ФОТО С СЕРВЕРА
  Future<void> _loadUserPhoto() async {
    if (userId == null) return;
    
    setState(() {
      _photoLoading = true;
    });

    try {
      print('🔄 ЗАГРУЗКА ФОТО С СЕРВЕРА ДЛЯ USER_ID: $userId');
      
      // Пробуем загрузить фото напрямую из данных менеджера
      final managerResponse = await http.get(
        Uri.parse('http://localhost:3000/managers/$userId'),
      );

      if (managerResponse.statusCode == 200) {
        final managerData = json.decode(managerResponse.body);
        print('📊 ДАННЫЕ МЕНЕДЖЕРА: ${managerData.containsKey('photo')}');
        
        if (managerData['photo'] != null && managerData['photo'].isNotEmpty) {
          final String photoBase64 = managerData['photo'];
          print('✅ ФОТО НАЙДЕНО В ДАННЫХ МЕНЕДЖЕРА');
          
          // Сохраняем в SharedPreferences и состояние
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('user_photo', photoBase64);
          
          setState(() {
            userPhoto = photoBase64;
          });
          return;
        }
      }

      // Если в данных менеджера нет фото, пробуем отдельный эндпоинт
      print('🔄 Пробуем загрузить фото через отдельный эндпоинт...');
      final photoResponse = await http.get(
        Uri.parse('http://localhost:3000/user-photo/manager/$userId'),
      );

      if (photoResponse.statusCode == 200) {
        final photoData = json.decode(photoResponse.body);
        print('📊 ДАННЫЕ ФОТО: ${photoData.containsKey('photo')}');
        
        if (photoData['photo'] != null && photoData['photo'].isNotEmpty) {
          final String photoBase64 = photoData['photo'];
          print('✅ ФОТО НАЙДЕНО В ОТДЕЛЬНОМ ЭНДПОИНТЕ');
          
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('user_photo', photoBase64);
          
          setState(() {
            userPhoto = photoBase64;
          });
          return;
        }
      }

      // Если фото нет нигде
      print('❌ ФОТО НЕ НАЙДЕНО НА СЕРВЕРЕ');
      _setDefaultPhoto();

    } catch (e) {
      print('💥 ОШИБКА ЗАГРУЗКИ ФОТО: $e');
      _setDefaultPhoto();
    } finally {
      setState(() {
        _photoLoading = false;
      });
    }
  }

  // Метод для установки фото по умолчанию
  void _setDefaultPhoto() {
    setState(() {
      userPhoto = null;
    });
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
      backgroundColor: Colors.blue,
      child: Icon(
        Icons.person,
        size: radius,
        color: Colors.white,
      ),
    );
  }

  // Обновленный метод для выбора фото
  Future<void> _pickImage() async {
    try {
      if (kIsWeb) {
        await _pickImageWeb();
      } else {
        final XFile? image = await _imagePicker.pickImage(
          source: ImageSource.gallery,
          imageQuality: 50,
          maxWidth: 800,
        );
        
        if (image != null) {
          await _processImageFile(File(image.path), 'manager');
        }
      }
    } catch (e) {
      _showError('Ошибка выбора фото: $e');
    }
  }

  // Метод для выбора фото на веб-платформе
  Future<void> _pickImageWeb() async {
    final html.FileUploadInputElement input = html.FileUploadInputElement();
    input.accept = 'image/*';
    input.click();

    await input.onChange.first;

    if (input.files!.isNotEmpty) {
      final html.File file = input.files!.first;
      final reader = html.FileReader();

      reader.readAsArrayBuffer(file);

      await reader.onLoadEnd.first;

      if (reader.result != null) {
        final List<int> bytes = List<int>.from(reader.result as List<int>);
        final base64Image = base64Encode(bytes);
        
        await _updateManagerPhoto(base64Image);
      }
    }
  }

  // Метод для обработки файла изображения
  Future<void> _processImageFile(File imageFile, String type) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(bytes);
      
      if (type == 'manager') {
        await _updateManagerPhoto(base64Image);
      } else if (type == 'mechanic') {
        setState(() {
          _selectedMechanicPhotoBase64 = base64Image;
        });
        _showSuccess('Фото механика выбрано');
      }
    } catch (e) {
      _showError('Ошибка обработки файла: $e');
    }
  }

  // УЛУЧШЕННЫЙ МЕТОД ОБНОВЛЕНИЯ ФОТО
  Future<void> _updateManagerPhoto(String base64Image) async {
    setState(() {
      _photoLoading = true;
    });

    try {
      print('🔄 ОБНОВЛЕНИЕ ФОТО НА СЕРВЕРЕ...');
      
      // Обновляем фото в данных менеджера
      final response = await http.put(
        Uri.parse('http://localhost:3000/managers/$userId'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'photo': base64Image,
        }),
      );

      print('📊 СТАТУС ОТВЕТА: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        // НЕМЕДЛЕННО обновляем состояние
        setState(() {
          userPhoto = base64Image;
        });
        
        // Сохраняем в SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_photo', base64Image);
        
        _showSuccess('Фото профиля обновлено');
        print('✅ ФОТО УСПЕШНО ОБНОВЛЕНО');
        
        // ПЕРЕЗАГРУЖАЕМ ДАННЫЕ ДЛЯ ПРОВЕРКИ
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

  // ДОБАВЛЕН МЕТОД ДЛЯ ВЫБОРА ФОТО МЕХАНИКА
  Future<void> _pickMechanicImage() async {
    try {
      if (kIsWeb) {
        await _pickMechanicImageWeb();
      } else {
        final XFile? image = await _imagePicker.pickImage(
          source: ImageSource.gallery,
          imageQuality: 50,
          maxWidth: 800,
        );
        
        if (image != null) {
          await _processImageFile(File(image.path), 'mechanic');
        }
      }
    } catch (e) {
      _showError('Ошибка выбора фото механика: $e');
    }
  }

  // Метод для выбора фото механика на веб-платформе
  Future<void> _pickMechanicImageWeb() async {
    final html.FileUploadInputElement input = html.FileUploadInputElement();
    input.accept = 'image/*';
    input.click();

    await input.onChange.first;

    if (input.files!.isNotEmpty) {
      final html.File file = input.files!.first;
      final reader = html.FileReader();

      reader.readAsArrayBuffer(file);

      await reader.onLoadEnd.first;

      if (reader.result != null) {
        final List<int> bytes = List<int>.from(reader.result as List<int>);
        final base64Image = base64Encode(bytes);
        
        setState(() {
          _selectedMechanicPhotoBase64 = base64Image;
        });
        _showSuccess('Фото механика выбрано');
      }
    }
  }

  // УЛУЧШЕННЫЙ МЕТОД ЗАГРУЗКИ ДАННЫХ
  Future<void> _loadUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        userId = prefs.getInt('user_id');
        userName = prefs.getString('user_name') ?? 'Менеджер';
        userEmail = prefs.getString('user_email') ?? 'Email не указан';
        
        _nameController.text = userName!;
        _emailController.text = userEmail!;
      });

      print('👤 ЗАГРУЖЕНЫ ДАННЫЕ: userId=$userId');

      if (userId != null) {
        // ПЕРВОЕ ДЕЛО - ЗАГРУЖАЕМ ФОТО С СЕРВЕРА
        await _loadUserPhoto();
        await _loadManagerService();
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print('Ошибка загрузки данных пользователя: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadManagerService() async {
    try {
      final response = await http.get(Uri.parse('http://localhost:3000/managers/$userId'));
      
      if (response.statusCode == 200) {
        final managerData = json.decode(response.body);
        setState(() {
          serviceId = managerData['serviceId'];
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
      final response = await http.get(Uri.parse('http://localhost:3000/services/$serviceId'));
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
        _loadServiceRequests(),
        _loadServiceMechanics(),
        _loadTransports(),
        _loadApplicants(),
      ]);
      setState(() => _isLoading = false);
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadServiceRequests() async {
    try {
      final response = await http.get(Uri.parse('http://localhost:3000/requests'));
      
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        List<Request> allRequests = data.map((item) => Request.fromJson(item)).toList();
        
        setState(() {
          requests = allRequests.where((request) => request.serviceId == serviceId).toList();
        });
      }
    } catch (e) {
      print('Error loading requests: $e');
    }
  }

  Future<void> _loadServiceMechanics() async {
    try {
      final response = await http.get(Uri.parse('http://localhost:3000/mechanics'));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        List<Mechanic> allMechanics = data.map((item) => Mechanic.fromJson(item)).toList();
        
        setState(() {
          mechanics = allMechanics.where((mechanic) => mechanic.serviceId == serviceId).toList();
        });
      }
    } catch (e) {
      print('Error loading mechanics: $e');
    }
  }

  Future<void> _loadTransports() async {
    try {
      final response = await http.get(Uri.parse('http://localhost:3000/transports'));
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
      final response = await http.get(Uri.parse('http://localhost:3000/applicants'));
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

    final mechanic = _getRequestMechanic(request);

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
                  
                  const SizedBox(height: 16),
                  const Text('Назначенный механик:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  _buildDetailRow('Имя:', mechanic?.name ?? 'Не назначен'),
                  _buildDetailRow('Email:', mechanic?.email ?? 'Не назначен'),
                  
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
                  
                  if (request.closedAt != null) ...[
                    const SizedBox(height: 16),
                    _buildDetailRow('Дата закрытия:', 
                      '${request.closedAt!.day}.${request.closedAt!.month}.${request.closedAt!.year}'),
                  ],
                  
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                        ),
                        child: const Text('Закрыть'),
                      ),
                      if (request.status != 'отклонена')
                        ElevatedButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                            _showMechanicAssignmentDialog(request);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                          ),
                          child: const Text('Назначить механика'),
                        ),
                      if (request.status != 'отклонена')
                        ElevatedButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                            _showStatusChangeDialog(request);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                          ),
                          child: const Text('Сменить статус'),
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

  void _showMechanicAssignmentDialog(Request request) {
    String? selectedMechanicId = request.mechanicId?.toString();

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
                  DropdownButtonFormField<String>(
                    value: selectedMechanicId,
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('Не назначен'),
                      ),
                      ...mechanics.map((mechanic) {
                        return DropdownMenuItem(
                          value: mechanic.id.toString(),
                          child: Text('${mechanic.name} (${mechanic.email})'),
                        );
                      }).toList(),
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

  void _showStatusChangeDialog(Request request) {
    String selectedStatus = request.status;

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
                    value: selectedStatus,
                    items: _statusList.map((String status) {
                      return DropdownMenuItem(
                        value: status,
                        child: Text(status),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      setDialogState(() {
                        selectedStatus = newValue!;
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

  Future<void> _assignMechanicToRequest(Request request, int mechanicId) async {
    try {
      final response = await http.put(
        Uri.parse('http://localhost:3000/requests/${request.id}'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'mechanicId': mechanicId,
        }),
      );

      if (response.statusCode == 200) {
        await _loadServiceRequests();
        _showSuccess('Механик успешно назначен');
      } else {
        _showError('Ошибка назначения механика: ${response.statusCode}');
      }
    } catch (e) {
      _showError('Ошибка назначения механика: $e');
    }
  }

  Future<void> _removeMechanicFromRequest(Request request) async {
    try {
      final response = await http.put(
        Uri.parse('http://localhost:3000/requests/${request.id}'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'mechanicId': null,
        }),
      );

      if (response.statusCode == 200) {
        await _loadServiceRequests();
        _showSuccess('Механик удален из заявки');
      } else {
        _showError('Ошибка удаления механика: ${response.statusCode}');
      }
    } catch (e) {
      _showError('Ошибка удаления механика: $e');
    }
  }

  Future<void> _updateRequestStatus(Request request, String newStatus) async {
    try {
      final updateData = {'status': newStatus};
      
      if (newStatus == 'отклонена') {
        updateData['closedAt'] = DateTime.now().toIso8601String();
      }

      final response = await http.put(
        Uri.parse('http://localhost:3000/requests/${request.id}'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(updateData),
      );

      if (response.statusCode == 200) {
        await _loadServiceRequests();
        _showSuccess('Статус заявки обновлен');
      } else {
        _showError('Ошибка обновления статуса: ${response.statusCode}');
      }
    } catch (e) {
      _showError('Ошибка обновления статуса: $e');
    }
  }

  void _showAddMechanicDialog() {
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
      final response = await http.post(
        Uri.parse('http://localhost:3000/mechanics'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'name': _mechanicNameController.text.trim(),
          'email': _mechanicEmailController.text.trim(),
          'password': _mechanicPasswordController.text.trim(),
          'photo': _selectedMechanicPhotoBase64,
          'role': 'mechanic',
          'serviceId': serviceId,
        }),
      );
      
      if (response.statusCode == 200) {
        await _loadServiceMechanics();
        _clearMechanicForm();
        _showSuccess('Механик успешно создан');
      } else {
        _showError('Ошибка создания механика: ${response.statusCode}');
      }
    } catch (e) {
      _showError('Ошибка создания механика: $e');
    }
  }

  void _clearMechanicForm() {
    _mechanicNameController.clear();
    _mechanicEmailController.clear();
    _mechanicPasswordController.clear();
    _selectedMechanicPhotoBase64 = null;
  }

  Future<void> _deleteMechanic(Mechanic mechanic) async {
    try {
      final response = await http.delete(
        Uri.parse('http://localhost:3000/mechanics/${mechanic.id}'),
      );

      if (response.statusCode == 200) {
        await _loadServiceMechanics();
        _showSuccess('Механик удален');
      } else {
        _showError('Ошибка удаления механика: ${response.statusCode}');
      }
    } catch (e) {
      _showError('Ошибка удаления механика: $e');
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

  Mechanic? _getRequestMechanic(Request request) {
    if (request.mechanicId == null) return null;
    return mechanics.firstWhere(
      (m) => m.id == request.mechanicId,
      orElse: () => Mechanic(id: 0, name: 'Неизвестно', email: 'Неизвестно', serviceId: 0),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'новая': return Colors.blue;
      case 'принята': return Colors.orange;
      case 'в работе': return Colors.purple;
      case 'отклонена': return Colors.red;
      default: return Colors.grey;
    }
  }

  List<Request> _getFilteredAndSortedRequests() {
    List<Request> filtered = List.from(requests);

    if (_statusFilter != null) {
      filtered = filtered.where((request) => request.status == _statusFilter).toList();
    }

    if (_mechanicFilter != null) {
      filtered = filtered.where((request) => request.mechanicId.toString() == _mechanicFilter).toList();
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

  // НОВЫЙ ДИЗАЙН КАРТОЧКИ ЗАЯВКИ
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
                
                const SizedBox(height: 12),
                
                const Text('Фильтр по механику:', style: TextStyle(fontWeight: FontWeight.bold)),
                DropdownButtonFormField<String>(
                  value: _mechanicFilter,
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Все механики')),
                    ...mechanics.map((mechanic) => DropdownMenuItem(
                      value: mechanic.id.toString(),
                      child: Text(mechanic.name),
                    )),
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
        Uri.parse('http://localhost:3000/managers/$userId'),
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

  // Обновленный метод построения панели профиля
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
            // Шапка профиля
            Container(
              height: 200,
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
                                    color: Colors.blue,
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
                          userName ?? 'Менеджер',
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
                  // Кнопка закрытия в левом углу
                  Positioned(
                    top: 16,
                    left: 16,
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => setState(() => _isAccountPanelOpen = false),
                    ),
                  ),
                  // Кнопка выхода в правом углу
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
            // Контент профиля
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    // Информация о сервисе
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.business, color: Colors.blue[700]),
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
                                    color: Colors.blue[700],
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
                    // Форма редактирования
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
                    // Кнопка сохранить изменения (белая без иконки)
                    SizedBox(
                      width: double.infinity, 
                      height: 50, 
                      child: ElevatedButton(
                        onPressed: _updateProfile, 
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.blue[700],
                          side: BorderSide(color: Colors.blue[700]!),
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
        // Основной контент
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
              // Вкладка механиков
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
                                        leading: _buildAvatar(mechanic.photo, 20),
                                        title: Text(mechanic.name),
                                        subtitle: Text(mechanic.email),
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

        // затемнение фона
        if (_isAccountPanelOpen)
          Container(
            color: Colors.black54,
          ),

        // панель профиля
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