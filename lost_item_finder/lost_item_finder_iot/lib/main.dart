import 'dart:async';
import 'package:flutter/material.dart';
import 'package:vibration/vibration.dart';
import 'package:logger/logger.dart';
import 'package:http/http.dart' as http;
import 'package:wifi_iot/wifi_iot.dart';

var logger = Logger();

void main() {
  runApp(const LostItemFinderApp());
}

class LostItemFinderApp extends StatelessWidget {
  const LostItemFinderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lost Item Finder',
      theme: ThemeData.dark(),
      home: const RadarScreen(),
    );
  }
}

class RadarScreen extends StatefulWidget {
  const RadarScreen({super.key});

  @override
  RadarScreenState createState() => RadarScreenState();
}

class RadarScreenState extends State<RadarScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Timer _scanTimer;
  bool _deviceFound = false;
  String _proximity = "Unknown";

  @override
  void initState() {
    super.initState();
    _connectToESP32();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    _startScanning();
  }

  // 🔁 Connect to ESP32 AP mode
  void _connectToESP32() async {
    bool isConnected = await WiFiForIoTPlugin.connect("ESP32_LostItemFinder", password: "123456789");
    if (isConnected) {
      logger.i("Connected to ESP32 Wi-Fi network");
    } else {
      logger.e("Failed to connect to ESP32 Wi-Fi network");
    }
  }

  // 🔁 Periodic scan
  void _startScanning() {
    const Duration scanInterval = Duration(seconds: 3);

    _scanTimer = Timer.periodic(scanInterval, (timer) {
      _scanForWiFiNetworks();
    });
  }

  // 🧠 RSSI to proximity
  String _getProximityLevel(int rssi) {
    if (rssi >= -50) return "Very Close";
    if (rssi > -70) return "Nearby";
    return "Far Away";
  }

  // 🔍 Simulated Wi-Fi scan (you can customize it)
  Future<void> _scanForWiFiNetworks() async {
    try {
      final response = await http.get(Uri.parse("http://192.168.4.1/")).timeout(Duration(seconds: 30));
      if (response.statusCode == 200) {
        final networks = _parseWiFiNetworks(response.body);

        if (networks.isNotEmpty) {
          setState(() {
            _deviceFound = true;
            // Simulating RSSI from response; replace with actual logic if available
            int simulatedRssi = -45; // 👈 Adjust or parse real value here
            _proximity = _getProximityLevel(simulatedRssi);
          });
          _triggerVibration();
          _triggerBuzzerAndLed();
        } else {
          setState(() {
            _deviceFound = false;
            _proximity = "Unknown";
          });
        }
      } else {
        logger.d('Failed to get Wi-Fi networks. Status: ${response.statusCode}');
      }
    } catch (e) {
      logger.d('Error while scanning: $e');
    }
  }

  List<String> _parseWiFiNetworks(String responseBody) {
    return responseBody.split(',');
  }

  void _triggerVibration() async {
    if (await Vibration.hasVibrator()) {
      Vibration.vibrate(duration: 300);
    }
  }

  void _triggerBuzzerAndLed() async {
    try {
      final response = await http.get(Uri.parse("http://192.168.4.1/trigger"));
      if (response.statusCode == 200) {
        logger.i('Buzzer and LED triggered!');
      } else {
        logger.e('Failed to trigger. Status: ${response.statusCode}');
      }
    } catch (e) {
      logger.e('Error triggering buzzer and LED: $e');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scanTimer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Lost Item Finder')),
      body: Center(
        child: Stack(
          alignment: Alignment.center,
          children: [
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return CustomPaint(
                  painter: RadarPainter(_controller.value),
                  child: const SizedBox(width: 300, height: 300),
                );
              },
            ),
            Icon(
              _deviceFound ? Icons.location_on : Icons.wifi,
              size: 50,
              color: _deviceFound ? Colors.greenAccent : Colors.white,
            ),
            Positioned(
              bottom: 40,
              child: Column(
                children: [
                  Text(
                    _deviceFound ? "Device Found!" : "Searching...",
                    style: TextStyle(
                      color: _deviceFound ? Colors.greenAccent : Colors.white,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    _deviceFound ? "Proximity: $_proximity" : "",
                    style: const TextStyle(fontSize: 16, color: Colors.amberAccent),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class RadarPainter extends CustomPainter {
  final double animationValue;

  RadarPainter(this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.4;

    final paint = Paint()
      ..color = Colors.greenAccent.withAlpha((255 * (1 - animationValue)).toInt())
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawCircle(center, radius * animationValue, paint);
    canvas.drawCircle(center, radius * 0.6, paint..color = Colors.greenAccent.withAlpha(100));
    canvas.drawCircle(center, radius * 0.9, paint..color = Colors.greenAccent.withAlpha(60));
  }

  @override
  bool shouldRepaint(covariant RadarPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}
