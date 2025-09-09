// lib/benshi/web_ui/views/home_view.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../radio_controller.dart';
import 'radio_view.dart';

class HomeView extends StatelessWidget {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => RadioController(),
      child: const _HomeViewBody(),
    );
  }
}

class _HomeViewBody extends StatefulWidget {
  const _HomeViewBody();

  @override
  State<_HomeViewBody> createState() => _HomeViewBodyState();
}

class _HomeViewBodyState extends State<_HomeViewBody> {
  String _status = 'Ready to Connect';
  bool _isConnecting = false;

  Future<void> _connectToRadio() async {
    final radio = Provider.of<RadioController>(context, listen: false);
    setState(() {
      _status = 'Opening browser device picker...';
      _isConnecting = true;
    });

    try {
      final success = await radio.connect();
      if (success && mounted) {
        setState(() => _status = 'Connected! Initializing radio state...');
        // Wait for the initial handshake and data download to complete
        await radio.waitForInitialization();
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => ChangeNotifierProvider.value(
                value: radio,
                child: const RadioView(),
              ),
            ),
          );
        }
      } else if(mounted) {
        setState(() => _status = 'No device selected or connection failed.');
      }
    } catch (e) {
      if (mounted) setState(() => _status = 'Error: $e');
    } finally {
      if (mounted) setState(() => _isConnecting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Benshi Web Programmer'),
        centerTitle: true,
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.radio, size: 100, color: Theme.of(context).colorScheme.primary),
                const SizedBox(height: 20),
                Text(
                  'Welcome to the Benshi Web Programmer',
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  'Use Google Chrome or MS Edge on a desktop computer to connect to your radio.',
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),
                if (_isConnecting)
                  const CircularProgressIndicator()
                else
                  FilledButton.icon(
                    onPressed: _connectToRadio,
                    icon: const Icon(Icons.bluetooth_searching),
                    label: const Text('Connect to Radio'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                      textStyle: const TextStyle(fontSize: 18),
                    ),
                  ),
                const SizedBox(height: 20),
                Text(_status, style: Theme.of(context).textTheme.labelSmall),
              ],
            ),
          ),
        ),
      ),
    );
  }
}