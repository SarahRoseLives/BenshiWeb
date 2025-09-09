// lib/main.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'benshi/radio_controller.dart';
import 'benshi/web_ui/views/home_view.dart';

void main() {
  runApp(
    // Provide the RadioController to the entire application. This ensures
    // the controller's state persists across navigation events.
    ChangeNotifierProvider(
      create: (_) => RadioController(),
      child: const BluetoothWebApp(),
    ),
  );
}

class BluetoothWebApp extends StatelessWidget {
  const BluetoothWebApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Benshi Web Programmer',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
      ),
      home: const HomeView(),
      debugShowCheckedModeBanner: false,
    );
  }
}