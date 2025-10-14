import 'package:flutter/material.dart';
import 'applicant_menu.dart';
import 'manager_menu.dart';

class ClientHomePage extends StatelessWidget {
  const ClientHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Панель заявителя'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: const ApplicantMenu(),
    );
  }
}

class ManagerHomePage extends StatelessWidget {
  const ManagerHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Панель менеджера'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: const ManagerMenu(),
    );
  }
}

class MechanicHomePage extends StatelessWidget {
  const MechanicHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Панель механика'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.build, size: 80, color: Colors.orange),
            SizedBox(height: 20),
            Text(
              'Механик',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Text(
              'Просмотр назначенных заявок и выполнение работ',
              style: TextStyle(fontSize: 16, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}