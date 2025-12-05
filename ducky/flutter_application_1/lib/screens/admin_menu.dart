import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../global_config.dart';

class AdminMenu extends StatefulWidget {
  const AdminMenu({super.key});

  @override
  State<AdminMenu> createState() => _AdminMenuState();
}

class _AdminMenuState extends State<AdminMenu> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  bool _isSettingsOpen = false;
  
  // Данные
  List<dynamic> services = [];
  List<dynamic> managers = [];
  List<dynamic> mechanics = [];
  List<dynamic> applicants = [];
  List<dynamic> requests = [];
  
  // Контроллеры для форм
  final TextEditingController _serviceAddressController = TextEditingController();
  final TextEditingController _serviceWorkTimeController = TextEditingController();
  final TextEditingController _managerNameController = TextEditingController();
  final TextEditingController _managerEmailController = TextEditingController();
  final TextEditingController _managerPasswordController = TextEditingController();
  final TextEditingController _mechanicNameController = TextEditingController();
  final TextEditingController _mechanicEmailController = TextEditingController();
  final TextEditingController _mechanicPasswordController = TextEditingController();
  
  // Контроллеры для настроек
  final TextEditingController _adminUsernameController = TextEditingController();
  final TextEditingController _adminPasswordController = TextEditingController();
  final TextEditingController _apiUrlController = TextEditingController();
  
  int? _selectedManagerServiceId;
  int? _selectedMechanicServiceId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _loadSettings();
    _loadAllData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _serviceAddressController.dispose();
    _serviceWorkTimeController.dispose();
    _managerNameController.dispose();
    _managerEmailController.dispose();
    _managerPasswordController.dispose();
    _mechanicNameController.dispose();
    _mechanicEmailController.dispose();
    _mechanicPasswordController.dispose();
    _adminUsernameController.dispose();
    _adminPasswordController.dispose();
    _apiUrlController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    try {
      final username = await GlobalConfig.adminUsername;
      final password = await GlobalConfig.adminPassword;
      final baseUrl = await GlobalConfig.baseUrl;
      
      setState(() {
        _adminUsernameController.text = username;
        _adminPasswordController.text = password;
        _apiUrlController.text = baseUrl;
      });
    } catch (e) {
      debugPrint('Ошибка загрузки настроек: $e');
    }
  }

  Future<void> _saveSettings() async {
    if (_adminUsernameController.text.isEmpty || 
        _adminPasswordController.text.isEmpty || 
        _apiUrlController.text.isEmpty) {
      _showError('Заполните все поля настроек');
      return;
    }

    if (!GlobalConfig.isValidUrl(_apiUrlController.text)) {
      _showError('Введите корректный URL сервера');
      return;
    }

    try {
      // Сохраняем настройки
      await GlobalConfig.setAdminUsername(_adminUsernameController.text.trim());
      await GlobalConfig.setAdminPassword(_adminPasswordController.text.trim());
      await GlobalConfig.setBaseUrl(_apiUrlController.text.trim());
      
      _showSuccess('Настройки сохранены');
      setState(() => _isSettingsOpen = false);
      
      // Перезагружаем данные с новым URL
      await _loadAllData();
    } catch (e) {
      _showError('Ошибка сохранения настроек: $e');
    }
  }

  Future<void> _resetSettings() async {
    setState(() {
      _adminUsernameController.text = GlobalConfig.defaultAdminUsername;
      _adminPasswordController.text = GlobalConfig.defaultAdminPassword;
      _apiUrlController.text = GlobalConfig.defaultBaseUrl;
    });
    _showSuccess('Настройки сброшены к значениям по умолчанию');
  }

  Future<void> _loadAllData() async {
    if (!mounted) return;
    
    setState(() => _isLoading = true);
    
    try {
      final api = ApiService();
      
      // Загружаем данные последовательно
      await _loadServices(api);
      await _loadManagers(api);
      await _loadMechanics(api);
      await _loadApplicants(api);
      await _loadRequests(api);
      
      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Ошибка загрузки данных: $e');
      if (mounted) {
        _showError('Ошибка загрузки данных. Проверьте URL сервера в настройках.');
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadServices(ApiService api) async {
    try {
      final data = await api.getAllServices();
      if (mounted) {
        setState(() => services = data);
      }
    } catch (e) {
      debugPrint('Ошибка загрузки сервисов: $e');
      if (mounted) {
        setState(() => services = []);
      }
    }
  }

  Future<void> _loadManagers(ApiService api) async {
    try {
      final data = await api.getAllManagers();
      if (mounted) {
        setState(() => managers = data);
      }
    } catch (e) {
      debugPrint('Ошибка загрузки менеджеров: $e');
      if (mounted) {
        setState(() => managers = []);
      }
    }
  }

  Future<void> _loadMechanics(ApiService api) async {
    try {
      final data = await api.getAllMechanics();
      if (mounted) {
        setState(() => mechanics = data);
      }
    } catch (e) {
      debugPrint('Ошибка загрузки механиков: $e');
      if (mounted) {
        setState(() => mechanics = []);
      }
    }
  }

  Future<void> _loadApplicants(ApiService api) async {
    try {
      final data = await api.getAllApplicants();
      if (mounted) {
        setState(() => applicants = data);
      }
    } catch (e) {
      debugPrint('Ошибка загрузки заявителей: $e');
      if (mounted) {
        setState(() => applicants = []);
      }
    }
  }

  Future<void> _loadRequests(ApiService api) async {
    try {
      final data = await api.getAllRequests();
      if (mounted) {
        setState(() => requests = data);
      }
    } catch (e) {
      debugPrint('Ошибка загрузки заявок: $e');
      if (mounted) {
        setState(() => requests = []);
      }
    }
  }

  // CRUD операции для сервисов
  Future<void> _createService() async {
    if (_serviceAddressController.text.isEmpty) {
      _showError('Введите адрес сервиса');
      return;
    }

    try {
      final api = ApiService();
      
      await api.createService({
        'address': _serviceAddressController.text.trim(),
        'workTime': _serviceWorkTimeController.text.trim(),
      });

      await _loadServices(api);
      _clearServiceForm();
      _showSuccess('Сервис создан');
    } catch (e) {
      _showError('Ошибка создания сервиса: $e');
    }
  }

  Future<void> _updateService(Map<String, dynamic> service) async {
    final addressController = TextEditingController(text: service['address']?.toString() ?? '');
    final workTimeController = TextEditingController(text: service['workTime']?.toString() ?? '');
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Редактировать сервис'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: addressController,
              decoration: const InputDecoration(labelText: 'Адрес'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: workTimeController,
              decoration: const InputDecoration(labelText: 'Время работы'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                final api = ApiService();
                
                await api.updateService(
                  service['id'] is int ? service['id'] : int.tryParse(service['id'].toString()) ?? 0,
                  {
                    'address': addressController.text.trim(),
                    'workTime': workTimeController.text.trim(),
                  }
                );
                
                await _loadServices(api);
                if (context.mounted) {
                  Navigator.pop(context);
                }
                _showSuccess('Сервис обновлен');
              } catch (e) {
                _showError('Ошибка обновления сервиса: $e');
              }
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteService(Map<String, dynamic> service) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить сервис?'),
        content: Text('Вы уверены, что хотите удалить сервис "${service['address']}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final api = ApiService();
        
        // ИСПРАВЛЕННАЯ СТРОКА: Более надежное получение ID
        int serviceId;
        if (service['id'] is int) {
          serviceId = service['id'];
        } else if (service['id'] is String) {
          serviceId = int.tryParse(service['id']) ?? 0;
        } else {
          serviceId = 0;
        }
        
        if (serviceId <= 0) {
          _showError('Неверный ID сервиса');
          return;
        }
        
        await api.deleteService(serviceId);
        
        await _loadServices(api);
        _showSuccess('Сервис удален');
      } catch (e) {
        _showError('Ошибка удаления сервиса: $e');
      }
    }
  }

  // CRUD операции для менеджеров
  Future<void> _createManager() async {
    if (_managerNameController.text.isEmpty || 
        _managerEmailController.text.isEmpty || 
        _managerPasswordController.text.isEmpty) {
      _showError('Заполните все поля');
      return;
    }

    try {
      final api = ApiService();
      
      await api.createManager({
        'name': _managerNameController.text.trim(),
        'email': _managerEmailController.text.trim(),
        'password': _managerPasswordController.text.trim(),
        'serviceId': _selectedManagerServiceId,
      });

      await _loadManagers(api);
      _clearManagerForm();
      _showSuccess('Менеджер создан');
    } catch (e) {
      _showError('Ошибка создания менеджера: $e');
    }
  }

  Future<void> _updateManager(Map<String, dynamic> manager) async {
    final nameController = TextEditingController(text: manager['name']?.toString() ?? '');
    final emailController = TextEditingController(text: manager['email']?.toString() ?? '');
    final passwordController = TextEditingController();
    int? selectedServiceId = manager['serviceId'];
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Редактировать менеджера'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Имя'),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: emailController,
                    decoration: const InputDecoration(labelText: 'Email'),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: passwordController,
                    decoration: const InputDecoration(labelText: 'Новый пароль (оставьте пустым, если не менять)'),
                    obscureText: true,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<int?>(
                    initialValue: selectedServiceId,
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Не назначен')),
                      ...services.map((service) => DropdownMenuItem(
                        value: service['id'] is int ? service['id'] : int.tryParse(service['id'].toString()) ?? 0,
                        child: Text(service['address']?.toString() ?? ''),
                      )),
                    ],
                    onChanged: (value) => setState(() => selectedServiceId = value),
                    decoration: const InputDecoration(labelText: 'Сервис'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Отмена'),
              ),
              ElevatedButton(
                onPressed: () async {
                  try {
                    final Map<String, dynamic> updateData = {
                      'name': nameController.text.trim(),
                      'email': emailController.text.trim(),
                      'serviceId': selectedServiceId,
                    };
                    
                    if (passwordController.text.isNotEmpty) {
                      updateData['password'] = passwordController.text.trim();
                    }
                    
                    final api = ApiService();
                    
                    await api.updateManager(
                      manager['id'] is int ? manager['id'] : int.tryParse(manager['id'].toString()) ?? 0,
                      updateData
                    );
                    
                    await _loadManagers(api);
                    if (context.mounted) {
                      Navigator.pop(context);
                    }
                    _showSuccess('Менеджер обновлен');
                  } catch (e) {
                    _showError('Ошибка обновления менеджера: $e');
                  }
                },
                child: const Text('Сохранить'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _deleteManager(Map<String, dynamic> manager) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить менеджера?'),
        content: Text('Вы уверены, что хотите удалить менеджера "${manager['name']}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final api = ApiService();
        
        await api.deleteManager(
          manager['id'] is int ? manager['id'] : int.tryParse(manager['id'].toString()) ?? 0
        );
        
        await _loadManagers(api);
        _showSuccess('Менеджер удален');
      } catch (e) {
        _showError('Ошибка удаления менеджера: $e');
      }
    }
  }

  // CRUD операции для механиков
  Future<void> _createMechanic() async {
    if (_mechanicNameController.text.isEmpty || 
        _mechanicEmailController.text.isEmpty || 
        _mechanicPasswordController.text.isEmpty) {
      _showError('Заполните все поля');
      return;
    }

    try {
      final api = ApiService();
      
      await api.createMechanic({
        'name': _mechanicNameController.text.trim(),
        'email': _mechanicEmailController.text.trim(),
        'password': _mechanicPasswordController.text.trim(),
        'serviceId': _selectedMechanicServiceId,
      });

      await _loadMechanics(api);
      _clearMechanicForm();
      _showSuccess('Механик создан');
    } catch (e) {
      _showError('Ошибка создания механика: $e');
    }
  }

  Future<void> _updateMechanic(Map<String, dynamic> mechanic) async {
    final nameController = TextEditingController(text: mechanic['name']?.toString() ?? '');
    final emailController = TextEditingController(text: mechanic['email']?.toString() ?? '');
    final passwordController = TextEditingController();
    int? selectedServiceId = mechanic['serviceId'];
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Редактировать механика'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Имя'),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: emailController,
                    decoration: const InputDecoration(labelText: 'Email'),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: passwordController,
                    decoration: const InputDecoration(labelText: 'Новый пароль (оставьте пустым, если не менять)'),
                    obscureText: true,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<int?>(
                    initialValue: selectedServiceId,
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Не назначен')),
                      ...services.map((service) => DropdownMenuItem(
                        value: service['id'] is int ? service['id'] : int.tryParse(service['id'].toString()) ?? 0,
                        child: Text(service['address']?.toString() ?? ''),
                      )),
                    ],
                    onChanged: (value) => setState(() => selectedServiceId = value),
                    decoration: const InputDecoration(labelText: 'Сервис'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Отмена'),
              ),
              ElevatedButton(
                onPressed: () async {
                  try {
                    final Map<String, dynamic> updateData = {
                      'name': nameController.text.trim(),
                      'email': emailController.text.trim(),
                      'serviceId': selectedServiceId,
                    };
                    
                    if (passwordController.text.isNotEmpty) {
                      updateData['password'] = passwordController.text.trim();
                    }
                    
                    final api = ApiService();
                    
                    await api.updateMechanic(
                      mechanic['id'] is int ? mechanic['id'] : int.tryParse(mechanic['id'].toString()) ?? 0,
                      updateData
                    );
                    
                    await _loadMechanics(api);
                    if (context.mounted) {
                      Navigator.pop(context);
                    }
                    _showSuccess('Механик обновлен');
                  } catch (e) {
                    _showError('Ошибка обновления механика: $e');
                  }
                },
                child: const Text('Сохранить'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _deleteMechanic(Map<String, dynamic> mechanic) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить механика?'),
        content: Text('Вы уверены, что хотите удалить механика "${mechanic['name']}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final api = ApiService();
        
        await api.deleteMechanic(
          mechanic['id'] is int ? mechanic['id'] : int.tryParse(mechanic['id'].toString()) ?? 0
        );
        
        await _loadMechanics(api);
        _showSuccess('Механик удален');
      } catch (e) {
        _showError('Ошибка удаления механика: $e');
      }
    }
  }

  void _clearServiceForm() {
    _serviceAddressController.clear();
    _serviceWorkTimeController.clear();
    setState(() {});
  }

  void _clearManagerForm() {
    _managerNameController.clear();
    _managerEmailController.clear();
    _managerPasswordController.clear();
    _selectedManagerServiceId = null;
    setState(() {});
  }

  void _clearMechanicForm() {
    _mechanicNameController.clear();
    _mechanicEmailController.clear();
    _mechanicPasswordController.clear();
    _selectedMechanicServiceId = null;
    setState(() {});
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message), 
        backgroundColor: Colors.red
      )
    );
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message), 
        backgroundColor: Colors.green
      )
    );
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
    }
  }

  Widget _buildSettingsPanel() {
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
              height: 80,
              padding: const EdgeInsets.fromLTRB(16, 40, 16, 16),
              decoration: BoxDecoration(
                color: Colors.deepPurple[700],
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => setState(() => _isSettingsOpen = false),
                  ),
                  const SizedBox(width: 16),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    const Text(
                      'Учетные данные администратора',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.deepPurple,
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _adminUsernameController,
                      decoration: const InputDecoration(
                        labelText: 'Логин администратора',
                        border: OutlineInputBorder(),
                        hintText: 'admin',
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _adminPasswordController,
                      decoration: const InputDecoration(
                        labelText: 'Пароль администратора',
                        border: OutlineInputBorder(),
                        hintText: 'admin',
                      ),
                      obscureText: true,
                    ),
                    const SizedBox(height: 30),
                    const Text(
                      'Настройки API',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.deepPurple,
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _apiUrlController,
                      decoration: const InputDecoration(
                        labelText: 'URL сервера API',
                        border: OutlineInputBorder(),
                        hintText: 'https://jvvrlmfl-3000.euw.devtunnels.ms',
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Примеры:\n• https://jvvrlmfl-3000.euw.devtunnels.ms\n• http://localhost:3000\n• http://10.0.2.2:3000',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 30),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _saveSettings,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepPurple,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Сохранить настройки'),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _resetSettings,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Сбросить к значениям по умолчанию'),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _logout,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Выйти из системы'),
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

  // Виджеты для карточек
  Widget _buildServiceCard(Map<String, dynamic> service) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: ListTile(
        title: Text(service['address']?.toString() ?? ''),
        subtitle: Text('Время работы: ${service['workTime'] ?? 'не указано'}'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.blue),
              onPressed: () => _updateService(service),
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () => _deleteService(service),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildManagerCard(Map<String, dynamic> manager) {
    String serviceAddress = 'Не назначен';
    if (manager['serviceId'] != null) {
      final service = services.firstWhere(
        (s) => s['id'] == manager['serviceId'],
        orElse: () => {'address': 'Не назначен'},
      );
      serviceAddress = service['address'];
    }
    
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.person)),
        title: Text(manager['name']?.toString() ?? ''),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(manager['email']?.toString() ?? ''),
            Text('Сервис: $serviceAddress'),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.blue),
              onPressed: () => _updateManager(manager),
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () => _deleteManager(manager),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMechanicCard(Map<String, dynamic> mechanic) {
    String serviceAddress = 'Не назначен';
    if (mechanic['serviceId'] != null) {
      final service = services.firstWhere(
        (s) => s['id'] == mechanic['serviceId'],
        orElse: () => {'address': 'Не назначен'},
      );
      serviceAddress = service['address'];
    }
    
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.engineering)),
        title: Text(mechanic['name']?.toString() ?? ''),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(mechanic['email']?.toString() ?? ''),
            Text('Сервис: $serviceAddress'),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.blue),
              onPressed: () => _updateMechanic(mechanic),
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () => _deleteMechanic(mechanic),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildApplicantCard(Map<String, dynamic> applicant) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.person_outline)),
        title: Text(applicant['name']?.toString() ?? ''),
        subtitle: Text(applicant['email']?.toString() ?? ''),
      ),
    );
  }

  Widget _buildRequestCard(Map<String, dynamic> request) {
    final transport = request['transport'] is Map ? request['transport'] : {'model': 'Неизвестно'};
    final applicant = request['applicant'] is Map ? request['applicant'] : {'name': 'Неизвестно'};
    
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: ListTile(
        leading: Icon(
          _getStatusIcon(request['status']),
          color: _getStatusColor(request['status']),
        ),
        title: Text('Заявка #${request['id']}'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Транспорт: ${transport['model']}'),
            Text('Заявитель: ${applicant['name']}'),
            Text('Статус: ${request['status'] ?? 'новая'}'),
          ],
        ),
      ),
    );
  }

  IconData _getStatusIcon(String? status) {
    switch (status?.toLowerCase()) {
      case 'новая':
        return Icons.new_releases;
      case 'в работе':
        return Icons.build;
      case 'завершена':
        return Icons.check_circle;
      case 'отклонена':
        return Icons.cancel;
      default:
        return Icons.description;
    }
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'новая':
        return Colors.blue;
      case 'в работе':
        return Colors.orange;
      case 'завершена':
        return Colors.green;
      case 'отклонена':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            title: const Text('Панель администратора'),
            backgroundColor: Colors.deepPurple,
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _loadAllData,
                tooltip: 'Обновить данные',
              ),
              IconButton(
                icon: const Icon(Icons.settings),
                onPressed: () => setState(() => _isSettingsOpen = true),
                tooltip: 'Настройки',
              ),
            ],
            bottom: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabs: const [
                Tab(text: 'Сервисы'),
                Tab(text: 'Менеджеры'),
                Tab(text: 'Механики'),
                Tab(text: 'Заявители'),
                Tab(text: 'Заявки'),
              ],
            ),
          ),
          body: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : TabBarView(
                  controller: _tabController,
                  children: [
                    // Сервисы
                    Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                children: [
                                  const Text(
                                    'Создать новый сервис',
                                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 16),
                                  TextField(
                                    controller: _serviceAddressController,
                                    decoration: const InputDecoration(
                                      labelText: 'Адрес сервиса *',
                                      border: OutlineInputBorder(),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  TextField(
                                    controller: _serviceWorkTimeController,
                                    decoration: const InputDecoration(
                                      labelText: 'Время работы',
                                      border: OutlineInputBorder(),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  ElevatedButton(
                                    onPressed: _createService,
                                    child: const Text('Создать сервис'),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: services.isEmpty
                              ? const Center(child: Text('Сервисов нет'))
                              : ListView.builder(
                                  itemCount: services.length,
                                  itemBuilder: (context, index) {
                                    final service = services[index];
                                    return _buildServiceCard(service);
                                  },
                                ),
                        ),
                      ],
                    ),
                    // Менеджеры
                    Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                children: [
                                  const Text(
                                    'Создать нового менеджера',
                                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 16),
                                  TextField(
                                    controller: _managerNameController,
                                    decoration: const InputDecoration(
                                      labelText: 'Имя *',
                                      border: OutlineInputBorder(),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  TextField(
                                    controller: _managerEmailController,
                                    decoration: const InputDecoration(
                                      labelText: 'Email *',
                                      border: OutlineInputBorder(),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  TextField(
                                    controller: _managerPasswordController,
                                    decoration: const InputDecoration(
                                      labelText: 'Пароль *',
                                      border: OutlineInputBorder(),
                                    ),
                                    obscureText: true,
                                  ),
                                  const SizedBox(height: 12),
                                  DropdownButtonFormField<int?>(
                                    initialValue: _selectedManagerServiceId,
                                    items: [
                                      const DropdownMenuItem(value: null, child: Text('Выберите сервис')),
                                      ...services.map((service) => DropdownMenuItem(
                                        value: service['id'] is int ? service['id'] : int.tryParse(service['id'].toString()) ?? 0,
                                        child: Text(service['address']?.toString() ?? ''),
                                      )),
                                    ],
                                    onChanged: (value) => setState(() => _selectedManagerServiceId = value),
                                    decoration: const InputDecoration(
                                      labelText: 'Сервис',
                                      border: OutlineInputBorder(),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  ElevatedButton(
                                    onPressed: _createManager,
                                    child: const Text('Создать менеджера'),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: managers.isEmpty
                              ? const Center(child: Text('Менеджеров нет'))
                              : ListView.builder(
                                  itemCount: managers.length,
                                  itemBuilder: (context, index) {
                                    final manager = managers[index];
                                    return _buildManagerCard(manager);
                                  },
                                ),
                        ),
                      ],
                    ),
                    // Механики
                    Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                children: [
                                  const Text(
                                    'Создать нового механика',
                                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 16),
                                  TextField(
                                    controller: _mechanicNameController,
                                    decoration: const InputDecoration(
                                      labelText: 'Имя *',
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
                                  DropdownButtonFormField<int?>(
                                    initialValue: _selectedMechanicServiceId,
                                    items: [
                                      const DropdownMenuItem(value: null, child: Text('Выберите сервис')),
                                      ...services.map((service) => DropdownMenuItem(
                                        value: service['id'] is int ? service['id'] : int.tryParse(service['id'].toString()) ?? 0,
                                        child: Text(service['address']?.toString() ?? ''),
                                      )),
                                    ],
                                    onChanged: (value) => setState(() => _selectedMechanicServiceId = value),
                                    decoration: const InputDecoration(
                                      labelText: 'Сервис',
                                      border: OutlineInputBorder(),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  ElevatedButton(
                                    onPressed: _createMechanic,
                                    child: const Text('Создать механика'),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: mechanics.isEmpty
                              ? const Center(child: Text('Механиков нет'))
                              : ListView.builder(
                                  itemCount: mechanics.length,
                                  itemBuilder: (context, index) {
                                    final mechanic = mechanics[index];
                                    return _buildMechanicCard(mechanic);
                                  },
                                ),
                        ),
                      ],
                    ),
                    // Заявители
                    applicants.isEmpty
                        ? const Center(child: Text('Заявителей нет'))
                        : ListView.builder(
                            itemCount: applicants.length,
                            itemBuilder: (context, index) {
                              final applicant = applicants[index];
                              return _buildApplicantCard(applicant);
                            },
                          ),
                    // Заявки
                    requests.isEmpty
                        ? const Center(child: Text('Заявок нет'))
                        : ListView.builder(
                            itemCount: requests.length,
                            itemBuilder: (context, index) {
                              final request = requests[index];
                              return _buildRequestCard(request);
                            },
                          ),
                  ],
                ),
        ),

        if (_isSettingsOpen)
          Container(
            color: const Color.fromARGB(137, 0, 0, 0),
          ),

        if (_isSettingsOpen)
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            child: _buildSettingsPanel(),
          ),
      ],
    );
  }
}