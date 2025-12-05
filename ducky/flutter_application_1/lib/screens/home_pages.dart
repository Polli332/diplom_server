import 'package:flutter/material.dart';
import 'applicant_menu.dart';
import 'manager_menu.dart';
import 'mehanic_menu.dart';

class ClientHomePage extends StatelessWidget {
  const ClientHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: ApplicantMenu(),
    );
  }
}

class ManagerHomePage extends StatelessWidget {
  const ManagerHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: ManagerMenu(),
    );
  }
}

class MechanicHomePage extends StatelessWidget {
  const MechanicHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: MechanicMenu(),
    );
  }
}