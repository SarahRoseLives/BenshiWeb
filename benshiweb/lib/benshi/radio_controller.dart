// lib/benshi/radio_controller.dart

import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:js/js.dart';
import 'dart:js_util' as js_util;

import '../models/aprs_packet.dart';
import 'protocol/protocol.dart';

@JS('navigator.bluetooth')
external dynamic get _bluetooth;

class RadioController extends ChangeNotifier {
  dynamic _btDevice;
  dynamic _txCharacteristic;

  StreamController<Message> _messageStreamController =
      StreamController<Message>.broadcast();

  Completer<void> _initializationCompleter = Completer<void>();

  // --- State Properties ---
  bool isConnected = false;
  DeviceInfo? deviceInfo;
  StatusExt? status;
  Settings? settings;
  Channel? currentChannel;
  Channel? channelA;
  Channel? channelB;
  List<Channel> channels = [];
  bool _isDisposed = false;

  RadioController();

  /// Resets the completer used to track the initial download of radio data.
  /// This should be called before `connect` if a previous connection attempt
  /// failed or if the user is starting a new session.
  void resetInitializationCompleter() {
    if (_initializationCompleter.isCompleted) {
      _initializationCompleter = Completer<void>();
    }
  }

  Future<void> waitForInitialization() => _initializationCompleter.future;

  Future<bool> connect({bool isReconnection = false}) async {
    const primaryServiceUUID = "00001100-d102-11e1-9b23-00025b00a5a5";
    const txCharacteristicUUID = "00001101-d102-11e1-9b23-00025b00a5a5";
    const rxCharacteristicUUID = "00001102-d102-11e1-9b23-00025b00a5a5";

    try {
      final options = js_util.jsify({
        'acceptAllDevices': true,
        'optionalServices': [primaryServiceUUID]
      });

      final promise = js_util.callMethod(_bluetooth, 'requestDevice', [options]);
      _btDevice = await js_util.promiseToFuture(promise);
      if (_btDevice == null) return false;

      js_util.setProperty(_btDevice, 'ongattserverdisconnected', allowInterop((event) {
        _handleDisconnection("Device disconnected unexpectedly.");
      }));

      final gatt = js_util.getProperty(_btDevice, 'gatt');
      final serverPromise = js_util.callMethod(gatt, 'connect', []);
      final server = await js_util.promiseToFuture(serverPromise);

      isConnected = true;
      notifyListeners();

      final servicePromise =
          js_util.callMethod(server, 'getPrimaryService', [primaryServiceUUID]);
      final service = await js_util.promiseToFuture(servicePromise);

      final txPromise =
          js_util.callMethod(service, 'getCharacteristic', [txCharacteristicUUID]);
      _txCharacteristic = await js_util.promiseToFuture(txPromise);

      final rxPromise =
          js_util.callMethod(service, 'getCharacteristic', [rxCharacteristicUUID]);
      final rxCharacteristic = await js_util.promiseToFuture(rxPromise);

      await js_util.promiseToFuture(
          js_util.callMethod(rxCharacteristic, 'startNotifications', []));

      js_util.setProperty(rxCharacteristic, 'oncharacteristicvaluechanged', allowInterop((event) {
        final value = js_util.getProperty(event.target, 'value');
        final byteData = (value as ByteData);
        _onDataReceived(byteData.buffer.asUint8List());
      }));

      if (!isReconnection) {
        unawaited(_initializeRadioState());
      }

      return true;
    } catch (e) {
      if (kDebugMode) print('Web Bluetooth connection error: $e');
      _handleDisconnection("Connection failed.");
      return false;
    }
  }

  void _handleDisconnection(String reason) {
    if (!isConnected || _isDisposed) return;
    if (kDebugMode) print("--- $reason ---");
    isConnected = false;
    _btDevice = null;
    _txCharacteristic = null;
    notifyListeners();
  }

  void disconnect() {
    if (_btDevice != null) {
      final gatt = js_util.getProperty(_btDevice, 'gatt');
      if (gatt != null && js_util.getProperty(gatt, 'connected')) {
        js_util.callMethod(gatt, 'disconnect', []);
      }
    }
    // The ongattserverdisconnected event will call _handleDisconnection
  }

  void _onDataReceived(Uint8List data) {
    if (_messageStreamController.isClosed) return;
    if (kDebugMode) print("RAW RX: $data");
    try {
      final message = Message.fromBytes(data);
      if (message.command == BasicCommand.EVENT_NOTIFICATION &&
          message.body is EventNotificationBody) {
        _handleEvent(message.body as EventNotificationBody);
      } else {
        _messageStreamController.add(message);
      }
    } catch (e, s) {
      if (kDebugMode) {
        print('Error parsing message: $e\n$s');
      }
    }
  }

  void _handleEvent(EventNotificationBody eventBody) async {
    if (_isDisposed) return;
    if (eventBody.event case GetHtStatusReplyBody(status: final newStatus?)) {
      status = newStatus;
    } else if (eventBody.event case ReadSettingsReplyBody(settings: final newSettings?)) {
      settings = newSettings;
      await _updateVfoChannels();
    } else if (eventBody.event case ReadRFChReplyBody(rfCh: final updatedChannel?)) {
      if (status?.currentChannelId == updatedChannel.channelId) currentChannel = updatedChannel;
      if (updatedChannel.channelId == settings?.channelA) channelA = updatedChannel;
      if (updatedChannel.channelId == settings?.channelB) channelB = updatedChannel;
    }
    notifyListeners();
  }

  Future<void> _initializeRadioState() async {
    try {
      await _registerForEvents();

      deviceInfo = await getDeviceInfo();
      status = await getStatus();
      settings = await getSettings();

      if (status != null) {
        currentChannel = await getChannel(status!.currentChannelId);
      }
      if (settings != null) {
        await _updateVfoChannels();
      }

      const totalChannelsToRead = 32;
      final newChannels = <Channel>[];
      for (int i = 0; i < totalChannelsToRead; i++) {
        if (!isConnected || _isDisposed) break;
        final channel = await getChannel(i);
        newChannels.add(channel);
        channels = List.from(newChannels);
        notifyListeners();
        await Future.delayed(const Duration(milliseconds: 50));
      }
    } catch (e) {
      if (kDebugMode) print('Error initializing radio state: $e');
    } finally {
      if (!_initializationCompleter.isCompleted) {
        _initializationCompleter.complete();
      }
    }
  }

  Future<void> _updateVfoChannels() async {
    if (settings == null) return;
    try {
      channelA = await getChannel(settings!.channelA);
      channelB = await getChannel(settings!.channelB);
    } catch (e) {
      if (kDebugMode) print("Error updating VFO channels: $e");
    }
  }

  Future<void> _sendCommand(Message command) async {
    if (!isConnected || _txCharacteristic == null) {
      throw Exception('Cannot send command: Not connected.');
    }
    final bytes = command.toBytes();
    if (kDebugMode) print("RAW TX: $bytes");
    final jsBuffer = js_util.jsify(bytes);
    await js_util.promiseToFuture(
        js_util.callMethod(_txCharacteristic, 'writeValue', [jsBuffer]));
  }

  Future<T> _sendCommandExpectReply<T extends ReplyBody>({
    required Message command,
    required BasicCommand replyCommand,
    bool Function(T body)? validator,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    if (_messageStreamController.isClosed) {
      throw Exception("Controller is disposed, cannot send command.");
    }
    final completer = Completer<T>();
    late StreamSubscription streamSub;

    streamSub = _messageStreamController.stream.listen((message) {
      if (message.command == replyCommand && message.isReply) {
        final body = message.body as T;
        if (validator != null && !validator(body)) return;
        if (completer.isCompleted) return;

        if (body.replyStatus != ReplyStatus.SUCCESS) {
          completer.completeError(
              Exception("Command failed with status: ${body.replyStatus}"));
        } else {
          completer.complete(body);
        }
        streamSub.cancel();
      }
    });

    try {
      await _sendCommand(command);
    } catch (e) {
      streamSub.cancel();
      completer.completeError(e);
    }

    Future.delayed(timeout, () {
      if (!completer.isCompleted) {
        completer.completeError(
            TimeoutException('Radio did not reply in time for ${command.command}.'));
        streamSub.cancel();
      }
    });

    return completer.future;
  }

  Future<void> _registerForEvents() async {
    final eventsToRegister = [
      EventType.HT_STATUS_CHANGED,
      EventType.HT_SETTINGS_CHANGED,
      EventType.HT_CH_CHANGED,
      EventType.DATA_RXD,
    ];
    for (var eventType in eventsToRegister) {
      if (_isDisposed) break;
      await _sendCommand(Message(
          commandGroup: CommandGroup.BASIC,
          command: BasicCommand.REGISTER_NOTIFICATION,
          isReply: false,
          body: RegisterNotificationBody(eventType: eventType)));
      await Future.delayed(const Duration(milliseconds: 50));
    }
  }

  Future<DeviceInfo?> getDeviceInfo() async {
    final reply = await _sendCommandExpectReply<GetDevInfoReplyBody>(
      command: Message(
          commandGroup: CommandGroup.BASIC,
          command: BasicCommand.GET_DEV_INFO,
          isReply: false,
          body: GetDevInfoBody()),
      replyCommand: BasicCommand.GET_DEV_INFO,
    );
    return deviceInfo = reply.devInfo;
  }

  Future<Settings?> getSettings() async {
    final reply = await _sendCommandExpectReply<ReadSettingsReplyBody>(
      command: Message(
          commandGroup: CommandGroup.BASIC,
          command: BasicCommand.READ_SETTINGS,
          isReply: false,
          body: ReadSettingsBody()),
      replyCommand: BasicCommand.READ_SETTINGS,
    );
    return settings = reply.settings;
  }

  Future<StatusExt?> getStatus() async {
    final reply = await _sendCommandExpectReply<GetHtStatusReplyBody>(
      command: Message(
          commandGroup: CommandGroup.BASIC,
          command: BasicCommand.GET_HT_STATUS,
          isReply: false,
          body: GetHtStatusBody()),
      replyCommand: BasicCommand.GET_HT_STATUS,
    );
    return status = reply.status;
  }

  Future<Channel> getChannel(int channelId) async {
    final reply = await _sendCommandExpectReply<ReadRFChReplyBody>(
      command: Message(
          commandGroup: CommandGroup.BASIC,
          command: BasicCommand.READ_RF_CH,
          isReply: false,
          body: ReadRFChBody(channelId: channelId)),
      replyCommand: BasicCommand.READ_RF_CH,
      validator: (body) => body.rfCh?.channelId == channelId,
    );
    if (reply.rfCh == null) throw Exception('Failed to get channel $channelId.');
    return reply.rfCh!;
  }

  Future<void> writeChannel(Channel channel, {Duration? timeout}) async {
    await _sendCommandExpectReply<WriteRFChReplyBody>(
      command: Message(
        commandGroup: CommandGroup.BASIC,
        command: BasicCommand.WRITE_RF_CH,
        isReply: false,
        body: WriteRFChBody(rfCh: channel),
      ),
      replyCommand: BasicCommand.WRITE_RF_CH,
      validator: (body) => body.channelId == channel.channelId,
      timeout: timeout ?? const Duration(seconds: 10),
    );
  }

  @override
  void dispose() {
    _isDisposed = true;
    disconnect();
    if (!_messageStreamController.isClosed) {
      _messageStreamController.close();
    }
    super.dispose();
  }
}