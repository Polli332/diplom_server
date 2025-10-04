import 'package:flutter/material.dart';

// --- Страницы для разных ролей ---
class AdminHomePage extends StatelessWidget {
  const AdminHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Администратор")),
      body: const Center(child: Text("Управление пользователями и системой")),
    );
  }
}

class ManagerHomePage extends StatelessWidget {
  const ManagerHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Менеджер автосервиса")),
      body: const Center(child: Text("Приём и распределение заявок")),
    );
  }
}

class MechanicHomePage extends StatelessWidget {
  const MechanicHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Механик")),
      body: const Center(child: Text("Заявки на ремонт и их закрытие")),
    );
  }
}

class ClientHomePage extends StatelessWidget {
  const ClientHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Заявитель")),
      body: const Center(child: Text("Создание заявок на ремонт транспорта")),
    );
  }
}

// --- Экран входа ---
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  
  TextEditingController? get loginController => null;

  void _login() {
    if (_formKey.currentState!.validate()) {
      String email = emailController.text.trim();
      String password = passwordController.text.trim();

      // 🔹 Здесь позже будет запрос в базу / API
      // Пока делаем определение роли по email
      String role;
      if (email.contains("admin")) {
        role = "admin";
      } else if (email.contains("manager")) {
        role = "manager";
      } else if (email.contains("mech")) {
        role = "mechanic";
      } else {
        role = "client"; // по умолчанию — заявитель
      }

      // 🔹 Переход на нужный экран
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => _getHomePageByRole(role),
        ),
      );
    }
  }

  Widget _getHomePageByRole(String role) {
    switch (role) {
      case "admin":
        return const AdminHomePage();
      case "manager":
        return const ManagerHomePage();
      case "mechanic":
        return const MechanicHomePage();
      case "client":
      default:
        return const ClientHomePage();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Вход / Регистрация")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextFormField(
                controller: loginController,
                obscureText: true,
                decoration: const InputDecoration(labelText: "Логин"),
                validator: (value) =>
                    value!.isEmpty ? "Введите логин" : null,
              ),TextFormField(
                controller: emailController,
                decoration: const InputDecoration(labelText: "Email"),
                validator: (value) =>
                    value!.isEmpty ? "Введите email" : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: "Пароль"),
                validator: (value) =>
                    value!.isEmpty ? "Введите пароль" : null,
              ),
              
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _login,
                child: const Text("Войти"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
