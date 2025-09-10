import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import '../models/channel_data_source.dart';

class ChannelDataGrid extends StatelessWidget {
  final ChannelDataSource dataSource;

  const ChannelDataGrid({
    super.key,
    required this.dataSource,
  });

  @override
  Widget build(BuildContext context) {
    return SfDataGrid(
      source: dataSource,
      columnWidthMode: ColumnWidthMode.fill,
      allowEditing: true,
      selectionMode: SelectionMode.single,
      navigationMode: GridNavigationMode.cell,
      columns: [
        GridColumn(columnName: 'channelId', allowEditing: false, width: 60, label: const Center(child: Text('ID'))),
        GridColumn(columnName: 'name', label: const Center(child: Text('Name'))),
        GridColumn(columnName: 'rxFreq', label: const Center(child: Text('RX Freq'))),
        GridColumn(columnName: 'txFreq', label: const Center(child: Text('TX Freq'))),
        GridColumn(columnName: 'rxTone', label: const Center(child: Text('RX Tone'))),
        GridColumn(columnName: 'txTone', label: const Center(child: Text('TX Tone'))),
        GridColumn(columnName: 'bandwidth', label: const Center(child: Text('BW'))),
        GridColumn(columnName: 'txPower', label: const Center(child: Text('Power'))),
        GridColumn(columnName: 'scan', width: 80, label: const Center(child: Text('Scan'))),
        GridColumn(columnName: 'actions', allowEditing: false, width: 100, label: const Center(child: Text('Move'))),
      ],
    );
  }
}