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
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context, rootNavigator: true);
    final radio = context.read<RadioController>();

    bool isReadyToUpload = radio.isConnected;

    // Step 1: If not connected, guide the user to reconnect.
    if (!isReadyToUpload) {
      final bool? wantsToConnect = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Reconnect Required'),
          content: const Text(
              'To upload data, you need a fresh connection to the radio. Please select your device in the upcoming browser prompt.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Connect'),
            ),
          ],
        ),
      );

      // If the user clicked "Connect", attempt the connection.
      if (wantsToConnect == true) {
        isReadyToUpload = await radio.connect(isReconnection: true);
      }
    }

    // Step 2: If we are not connected after the prompt, cancel the upload.
    if (!isReadyToUpload) {
      scaffoldMessenger.showSnackBar(
        const SnackBar(content: Text('Upload cancelled. No device connected.')),
      );
      return;
    }

    // Step 3: Perform the upload with progress feedback.
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        title: Text('Uploading to Radio...'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 20),
            Text('Writing channels. Please wait.'),
          ],
        ),
      ),
    );

    try {
      for (int i = 0; i < _channels.length; i++) {
        final channelToWrite = _channels[i].copyWith(channelId: i);
        await radio.writeChannel(channelToWrite);
        await Future.delayed(const Duration(milliseconds: 50));
      }

      navigator.pop(); // Close the progress dialog
      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text('Upload complete!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      navigator.pop(); // Close the progress dialog
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Upload failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
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