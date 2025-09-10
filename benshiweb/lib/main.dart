// lib/main.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'benshi/radio_controller.dart';
import 'benshi/web_ui/views/home_view.dart';

void main() {
  runApp(
    // This is the ONLY place the RadioController should be created.
    // By placing it here, its lifecycle is tied to the entire app.
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