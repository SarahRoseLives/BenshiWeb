// lib/benshi/web_ui/models/channel_data_source.dart

import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import '../../protocol/data_models.dart';
import '../../protocol/common.dart';

class ChannelDataSource extends DataGridSource {
  List<Channel> _channels;
  List<DataGridRow> _channelRows = [];
  final void Function(int oldIndex, int newIndex) onRowsMoved;

  // This will hold the new value from the editor temporarily.
  dynamic newCellValue;

  ChannelDataSource({
    required List<Channel> channels,
    required this.onRowsMoved, // Callback to update state in the view
  }) : _channels = channels {
    updateDataGridSource();
  }

  // Helper to rebuild DataGridRows when the underlying data is changed.
  void updateDataGridSource() {
    _channelRows = _channels.asMap().entries.map<DataGridRow>((entry) {
      final index = entry.key;
      final channel = entry.value;
      return DataGridRow(cells: [
        DataGridCell<int>(columnName: 'channelId', value: index),
        DataGridCell<String>(columnName: 'name', value: channel.name),
        DataGridCell<double>(columnName: 'rxFreq', value: channel.rxFreq),
        DataGridCell<double>(columnName: 'txFreq', value: channel.txFreq),
        DataGridCell<String>(columnName: 'rxTone', value: Channel.formatSubAudio(channel.rxSubAudio)),
        DataGridCell<String>(columnName: 'txTone', value: Channel.formatSubAudio(channel.txSubAudio)),
        DataGridCell<String>(columnName: 'bandwidth', value: channel.bandwidth.name),
        DataGridCell<String>(columnName: 'txPower', value: channel.txPower),
        DataGridCell<bool>(columnName: 'scan', value: channel.scan),
      ]);
    }).toList();
    notifyListeners(); // Important to refresh the grid UI
  }

  // --- DRAG AND DROP LOGIC ---
  @override
  Future<void> onRowDrop(int oldIndex, int newIndex) async {
    // This calls the method in RadioView to update the state.
    onRowsMoved(oldIndex, newIndex);
  }

  @override
  List<DataGridRow> get rows => _channelRows;

  @override
  DataGridRowAdapter buildRow(DataGridRow row) {
    return DataGridRowAdapter(
      cells: row.getCells().map<Widget>((cell) {
        if (cell.columnName == 'scan') {
          return Checkbox(
            value: cell.value as bool,
            onChanged: (value) {
              if (value != null) {
                final rowIndex = _channelRows.indexOf(row);
                _channels[rowIndex] = _channels[rowIndex].copyWith(scan: value);
                updateDataGridSource();
              }
            },
          );
        }
        return Container(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Text(cell.value.toString()),
        );
      }).toList(),
    );
  }

  // --- EDITING LOGIC (Using the correct modern API) ---

  @override
  Widget? buildEditWidget(DataGridRow dataGridRow, RowColumnIndex rowColumnIndex, GridColumn column, void Function() submitCell) {
    final dynamic oldValue = dataGridRow.getCells()[rowColumnIndex.columnIndex].value;

    if (column.columnName == 'bandwidth') {
      return _buildDropdownEditor(oldValue.toString(), BandwidthType.values.map((e) => e.name).toList(), submitCell);
    } else if (column.columnName == 'txPower') {
      return _buildDropdownEditor(oldValue.toString(), ['High', 'Medium', 'Low'], submitCell);
    } else {
      return _buildTextEditor(oldValue.toString(), submitCell);
    }
  }

  @override
  Future<void> onCellSubmit(DataGridRow dataGridRow, RowColumnIndex rowColumnIndex, GridColumn column) async {
    final int dataRowIndex = _channelRows.indexOf(dataGridRow);
    final dynamic oldValue = dataGridRow.getCells()[rowColumnIndex.columnIndex].value;

    if (newCellValue == null || oldValue.toString() == newCellValue.toString()) {
      newCellValue = null;
      return;
    }

    final channelIndex = dataRowIndex;
    final currentChannel = _channels[channelIndex];

    switch (column.columnName) {
      case 'name':
        _channels[channelIndex] = currentChannel.copyWith(name: newCellValue as String);
        break;
      case 'rxFreq':
        _channels[channelIndex] = currentChannel.copyWith(rxFreq: double.tryParse(newCellValue.toString()) ?? currentChannel.rxFreq);
        break;
      case 'txFreq':
        _channels[channelIndex] = currentChannel.copyWith(txFreq: double.tryParse(newCellValue.toString()) ?? currentChannel.txFreq);
        break;
      case 'rxTone':
          _channels[channelIndex] = currentChannel.copyWith(rxSubAudio: Channel.parseSubAudioFromString(newCellValue.toString()));
        break;
      case 'txTone':
          _channels[channelIndex] = currentChannel.copyWith(txSubAudio: Channel.parseSubAudioFromString(newCellValue.toString()));
        break;
      case 'bandwidth':
        _channels[channelIndex] = currentChannel.copyWith(bandwidth: BandwidthType.values.firstWhere((e) => e.name == newCellValue));
        break;
      case 'txPower':
        bool isMax = newCellValue == 'High';
        bool isMed = newCellValue == 'Medium';
        _channels[channelIndex] = currentChannel.copyWith(txAtMaxPower: isMax, txAtMedPower: isMed);
        break;
    }

    updateDataGridSource();
    newCellValue = null;
  }

  Widget _buildTextEditor(String oldValue, void Function() submitCell) {
    final TextEditingController controller = TextEditingController(text: oldValue);
    return Container(
      padding: const EdgeInsets.all(8.0),
      alignment: Alignment.center,
      child: TextField(
        controller: controller,
        autofocus: true,
        decoration: const InputDecoration(contentPadding: EdgeInsets.all(8)),
        onChanged: (String value) {
          newCellValue = value;
        },
        onSubmitted: (String value) {
          submitCell();
        },
      ),
    );
  }

  Widget _buildDropdownEditor(String oldValue, List<String> items, void Function() submitCell) {
    return Container(
      padding: const EdgeInsets.all(8.0),
      alignment: Alignment.center,
      child: DropdownButton<String>(
        autofocus: true,
        value: oldValue,
        items: items.map((String value) {
          return DropdownMenuItem<String>(value: value, child: Text(value));
        }).toList(),
        onChanged: (String? value) {
          if (value != null) {
            newCellValue = value;
            submitCell();
          }
        },
      ),
    );
  }
}