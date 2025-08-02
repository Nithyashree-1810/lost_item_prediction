import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(LostItemFinderApp());
}

class LostItemFinderApp extends StatelessWidget {
  const LostItemFinderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Lost Item Finder',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  FlutterBluePlus flutterBlue = FlutterBluePlus.instance;
  BluetoothDevice? connectedDevice;
  LatLng lostItemLocation = LatLng(12.9716, 77.5946); // Default Location

  void scanAndConnect() {
    flutterBlue.startScan(timeout: Duration(seconds: 5));
    flutterBlue.scanResults.listen((results) {
      for (ScanResult result in results) {
        if (result.device.name == "LostItemTracker") {
          result.device.connect();
          setState(() {
            connectedDevice = result.device;
          });
          flutterBlue.stopScan();
        }
      }
    });
  }

  void triggerBuzzer() {
    if (connectedDevice != null) {
      connectedDevice!.writeCharacteristic(
        BluetoothCharacteristic(uuid: Guid("00002a19-0000-1000-8000-00805f9b34fb")),
        [1],
        type: CharacteristicWriteType.withResponse,
      );
    }
  }

  void fetchGPSLocation() {
    DatabaseReference ref = FirebaseDatabase.instance.reference().child("GPS_Location");
    ref.once().then((DatabaseEvent event) {
      Map<String, dynamic> data = event.snapshot.value as Map<String, dynamic>;
      setState(() {
        lostItemLocation = LatLng(data['latitude'], data['longitude']);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Lost Item Finder")),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ElevatedButton(
            onPressed: scanAndConnect,
            child: Text(connectedDevice == null ? "Connect to Device" : "Connected"),
          ),
          SizedBox(height: 20),
          ElevatedButton(
            onPressed: triggerBuzzer,
            child: Text("Trigger Buzzer"),
          ),
          SizedBox(height: 20),
          ElevatedButton(
            onPressed: fetchGPSLocation,
            child: Text("Fetch GPS Location"),
          ),
          SizedBox(height: 20),
          Expanded(
            child: GoogleMap(
              initialCameraPosition: CameraPosition(target: lostItemLocation, zoom: 15),
              markers: {
                Marker(
                  markerId: MarkerId("lostItem"),
                  position: lostItemLocation,
                  infoWindow: InfoWindow(title: "Lost Item Location"),
                ),
              },
            ),
          ),
        ],
      ),
    );
  }
}
