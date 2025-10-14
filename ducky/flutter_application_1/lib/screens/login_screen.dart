import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../models/user_model.dart';
import 'home_pages.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  bool isLogin = true;
  final TextEditingController emailCtl = TextEditingController();
  final TextEditingController passCtl = TextEditingController();
  final TextEditingController nameCtl = TextEditingController();
  bool _loading = false;
  bool _obscurePassword = true;

  // Тестовые данные для быстрой проверки
  void _fillTestData() {
    if (isLogin) {
      emailCtl.text = 'applicant@test.com';
      passCtl.text = 'password';
    } else {
      nameCtl.text = 'Тестовый пользователь';
      emailCtl.text = 'test@test.com';
      passCtl.text = 'password';
    }
    _formKey.currentState?.validate();
  }

  Future<void> _doRegister() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _loading = true);
    try {
      print('🔐 Регистрация пользователя: ${emailCtl.text}');
      final user = await ApiService.registerApplicant(
        nameCtl.text.trim(), 
        emailCtl.text.trim(), 
        passCtl.text.trim()
      );
      print('✅ Успешная регистрация: ${user.role}');
      await _saveAndNavigate(user);
    } catch (e) {
      print('❌ Ошибка регистрации: $e');
      _showError('Ошибка регистрации: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _doLogin() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _loading = true);
    try {
      print('🔐 Вход пользователя: ${emailCtl.text}');
      final user = await ApiService.login(
        emailCtl.text.trim(), 
        passCtl.text.trim()
      );
      print('✅ Успешный вход: ${user.role}');
      await _saveAndNavigate(user);
    } catch (e) {
      print('❌ Ошибка входа: $e');
      _showError('Ошибка входа: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _saveAndNavigate(UserModel user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('user_id', user.id);
      await prefs.setString('user_name', user.name);
      await prefs.setString('user_email', user.email);
      await prefs.setString('user_role', user.role);

      print('💾 Данные сохранены: ${user.name} (${user.role})');

      if (mounted) {
        _navigateByRole(user.role);
      }
    } catch (e) {
      print('❌ Ошибка сохранения: $e');
      if (mounted) {
        _showError('Ошибка сохранения данных: $e');
      }
    }
  }

  void _navigateByRole(String role) {
    print('🧭 Навигация для роли: $role');
    
    final normalizedRole = role.toLowerCase();
    print('🔧 Нормализованная роль: $normalizedRole');

    Widget page;
    switch (normalizedRole) {
      case 'manager':
        page = const ManagerHomePage();
        break;
      case 'mechanic':
        page = const MechanicHomePage();
        break;
      case 'applicant':
      default:
        page = const ClientHomePage();
        break;
    }

    print('🚀 Переход на: ${page.runtimeType}');
    
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => page),
      (route) => false,
    );
  }

  void _showError(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isLogin ? 'Вход в систему' : 'Регистрация'),
        actions: [
          IconButton(
            icon: const Icon(Icons.bug_report),
            onPressed: _fillTestData,
            tooltip: 'Заполнить тестовые данные',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: _loading
            ? _buildLoading()
            : SingleChildScrollView(
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      // Заголовок
                      const SizedBox(height: 20),
                      Icon(
                        isLogin ? Icons.login : Icons.person_add,
                        size: 60,
                        color: Theme.of(context).primaryColor,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        isLogin ? 'Вход в систему' : 'Создание аккаунта',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 30),

                      // Поля формы
                      if (!isLogin) ...[
                        TextFormField(
                          controller: nameCtl,
                          decoration: const InputDecoration(
                            labelText: 'Полное имя',
                            prefixIcon: Icon(Icons.person),
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) => v == null || v.trim().isEmpty 
                              ? 'Введите ваше имя' 
                              : null,
                        ),
                        const SizedBox(height: 16),
                      ],
                      
                      TextFormField(
                        controller: emailCtl,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          prefixIcon: Icon(Icons.email),
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) => v == null || !v.contains('@') 
                            ? 'Введите корректный email' 
                            : null,
                      ),
                      const SizedBox(height: 16),
                      
                      TextFormField(
                        controller: passCtl,
                        decoration: InputDecoration(
                          labelText: 'Пароль',
                          prefixIcon: const Icon(Icons.lock),
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword 
                                  ? Icons.visibility_off 
                                  : Icons.visibility
                            ),
                            onPressed: () => setState(() => 
                                _obscurePassword = !_obscurePassword),
                          ),
                        ),
                        obscureText: _obscurePassword,
                        validator: (v) => v == null || v.length < 4 
                            ? 'Пароль должен быть не менее 4 символов' 
                            : null,
                      ),
                      const SizedBox(height: 30),

                      // Кнопки
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _loading 
                              ? null 
                              : (isLogin ? _doLogin : _doRegister),
                          child: Text(
                            isLogin ? 'Войти' : 'Зарегистрироваться',
                            style: const TextStyle(fontSize: 16),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      
                      TextButton(
                        onPressed: _loading 
                            ? null 
                            : () => setState(() => isLogin = !isLogin),
                        child: Text(
                          isLogin 
                              ? 'Нет аккаунта? Зарегистрируйтесь' 
                              : 'Уже есть аккаунт? Войти',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildLoading() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 20),
          Text('Выполняется вход...'),
        ],
      ),
    );
  }
}