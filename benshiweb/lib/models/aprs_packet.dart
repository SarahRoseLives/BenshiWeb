// lib/models/aprs_packet.dart

// Placeholder for APRS packet data structures.
// This can be fleshed out later if APRS functionality is needed.

class AprsPacket {
  final String source;
  final double? latitude;
  final double? longitude;

  AprsPacket({
    required this.source,
    this.latitude,
    this.longitude,
  });

  // This factory constructor is needed by radio_controller.dart
  static AprsPacket? fromAX25Frame(List<int> frame) {
    // This is a stub. A real implementation would parse the AX.25 frame.
    return null;
  }
}