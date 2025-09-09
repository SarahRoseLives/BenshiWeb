import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../protocol/data_models.dart';
import '../../radio_controller.dart';
import '../models/channel_data_source.dart';
import '../widgets/channel_data_grid.dart';
import 'home_view.dart';

class RadioView extends StatefulWidget {
  const RadioView({super.key});

  @override
  State<RadioView> createState() => _RadioViewState();
}

class _RadioViewState extends State<RadioView> {
  // This list will hold the local, editable copy of the channels.
  List<Channel> _channels = [];
  late ChannelDataSource _channelDataSource;

  @override
  void initState() {
    super.initState();
    final radio = context.read<RadioController>();

    // Create a mutable copy of the channels from the controller.
    _channels = List<Channel>.from(radio.channels);
    _channelDataSource = ChannelDataSource(
      channels: _channels,
      onRowsMoved: handleRowDragAndDrop, // Pass the handler to the data source
    );
  }

  void handleRowDragAndDrop(int oldIndex, int newIndex) {
    if (!mounted) return;
    setState(() {
      final row = _channels.removeAt(oldIndex);
      _channels.insert(newIndex, row);
      // After reordering, we need to regenerate the data source rows.
      _channelDataSource.updateDataGridSource();
    });
  }

  Future<void> _uploadToRadio() async {
    final radio = context.read<RadioController>();
    final progressNotifier = ValueNotifier<String>('Connecting to radio...');

    // Show a dialog that can be updated during the process.
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Upload in Progress'),
        content: ValueListenableBuilder<String>(
          valueListenable: progressNotifier,
          builder: (context, value, child) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 20),
                Text(value),
              ],
            );
          },
        ),
      ),
    );

    try {
      // Step 1: Check connection and reconnect if needed.
      if (!radio.isConnected) {
        final success = await radio.reconnect();
        if (!success) {
          throw Exception('Failed to reconnect to the radio.');
        }
      }

      // Step 2: Proceed with the upload.
      progressNotifier.value = 'Uploading channels... Please wait.';
      for (int i = 0; i < _channels.length; i++) {
        // IMPORTANT: Update the channelId to match its current position in the list.
        final channelToWrite = _channels[i].copyWith(channelId: i);
        await radio.writeChannel(channelToWrite);
        await Future.delayed(const Duration(milliseconds: 50));
      }

      if (mounted) {
        Navigator.of(context).pop(); // Close the progress dialog
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Upload complete!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Close the progress dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Upload failed: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Using context.watch() ensures this widget rebuilds whenever the
    // RadioController notifies its listeners (e.g., on disconnect).
    final radio = context.watch<RadioController>();
    final devInfo = radio.deviceInfo;
    const totalChannels = 32;

    final isDownloadComplete = radio.channels.length >= totalChannels;

    return Scaffold(
      appBar: AppBar(
        title: Text(devInfo != null
            ? '${devInfo.productName} Programmer'
            : 'Radio Programmer'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: Tooltip(
              message: radio.isConnected ? 'Connected' : 'Disconnected',
              child: Icon(
                radio.isConnected
                    ? Icons.bluetooth_connected
                    : Icons.bluetooth_disabled,
                color: radio.isConnected ? Colors.green : Colors.grey,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.cloud_upload_outlined),
            onPressed: !isDownloadComplete ? null : _uploadToRadio,
            tooltip: 'Upload to Radio',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Expanded(
              child: !isDownloadComplete && radio.isConnected
                  ? const Center(child: CircularProgressIndicator())
                  : ChannelDataGrid(
                      dataSource: _channelDataSource,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}