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
    final progressNotifier =
        ValueNotifier<String>('Starting channel upload...');
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Uploading to Radio'),
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
      for (int i = 0; i < _channels.length; i++) {
        progressNotifier.value =
            'Writing channel ${i + 1} of ${_channels.length}...';

        final channelToWrite = _channels[i].copyWith(channelId: i);
        final bool isLastChannel = i == _channels.length - 1;

        if (isLastChannel) {
          progressNotifier.value = 'Saving final channel... This may take a moment.';
          // Give the final, slow write-to-memory operation a much longer timeout.
          await radio.writeChannel(channelToWrite,
              timeout: const Duration(seconds: 30));
        } else {
          // Use the default timeout for all other channels.
          await radio.writeChannel(channelToWrite);
        }

        // After every 8 channels, take a longer "cool-down" break.
        if ((i + 1) % 8 == 0 && !isLastChannel) {
          progressNotifier.value = 'Pausing to let radio process...';
          await Future.delayed(const Duration(seconds: 1));
        } else {
          // Use the regular, shorter delay for all other channels.
          await Future.delayed(const Duration(milliseconds: 200));
        }
      }

      navigator.pop(); // Close the progress dialog
      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text('Upload complete! ✅'),
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
    } finally {
      progressNotifier.dispose();
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