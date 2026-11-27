import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

/// Live selfie + GPS fix for exactly one attendance action.
class Capture {
  final Uint8List selfie;
  final String selfieBase64;
  final double lat, lng, accuracy;
  final String? address;
  final String device;
  Capture(this.selfie, this.selfieBase64, this.lat, this.lng, this.accuracy, this.address, this.device);
}

Future<void> openMap(double lat, double lng) =>
    launchUrl(Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng'), mode: LaunchMode.externalApplication);

Future<Position> _locate() async {
  if (!await Geolocator.isLocationServiceEnabled()) {
    throw 'Location is turned off. Please turn on GPS / Location Services and try again.';
  }
  var p = await Geolocator.checkPermission();
  if (p == LocationPermission.denied) p = await Geolocator.requestPermission();
  if (p == LocationPermission.deniedForever) {
    throw 'Location permission is permanently denied. Enable it for this app in system Settings to mark attendance.';
  }
  if (p == LocationPermission.denied) throw 'Location permission is required to mark attendance.';
  try {
    final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.best, timeLimit: Duration(seconds: 30)));
    if (pos.isMocked) throw 'Mock / fake GPS location detected. Disable it and try again.';
    return pos;
  } on TimeoutException {
    throw 'Could not get a GPS fix. Move to an open area and try again.';
  }
}

/// Full flow: consent -> live selfie -> GPS -> preview with map -> confirm.
/// Returns null when the user cancels. Throws a String message on denial/failure.
Future<Capture?> captureAttendance(BuildContext context, {required String title}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      icon: const Icon(Icons.privacy_tip_outlined, size: 32),
      title: Text(title),
      content: const Text(
          'To record this attendance the app will:\n\n'
          '• Open your front camera to take a live selfie\n'
          '• Read your current GPS location once\n\n'
          'Your camera and location are used only for this action. The app never tracks you in the background.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Continue')),
      ],
    ),
  );
  if (ok != true) return null;

  XFile? shot;
  try {
    shot = await ImagePicker().pickImage(
        source: ImageSource.camera, preferredCameraDevice: CameraDevice.front, maxWidth: 640, imageQuality: 60);
  } on PlatformException catch (e) {
    if (e.code.contains('denied') || e.code.contains('access')) {
      throw 'Camera permission is required to mark attendance. Enable it in system Settings.';
    }
    throw 'Could not open camera: ${e.message ?? e.code}';
  }
  if (shot == null) return null; // cancelled
  final bytes = await shot.readAsBytes();
  if (bytes.length > 700 * 1024) throw 'Selfie is too large, please retry.';

  final pos = await _locate();
  const String? addr = null; // street address lookup not bundled; coordinates + map link are stored
  final dev = '${defaultTargetPlatform.name} ${Platform.operatingSystemVersion}';
  final cap = Capture(bytes, base64Encode(bytes), pos.latitude, pos.longitude, pos.accuracy, addr,
      dev.length > 80 ? dev.substring(0, 80) : dev);

  if (!context.mounted) return null;
  final go = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (c) => _Preview(cap: cap, title: title),
  );
  return go == true ? cap : null;
}

class _Preview extends StatelessWidget {
  final Capture cap;
  final String title;
  const _Preview({required this.cap, required this.title});
  @override
  Widget build(BuildContext c) {
    final pt = LatLng(cap.lat, cap.lng);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Review & submit', style: Theme.of(c).textTheme.titleLarge),
          const SizedBox(height: 12),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.memory(cap.selfie, width: 110, height: 140, fit: BoxFit.cover)),
            const SizedBox(width: 12),
            Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Text('Lat ${cap.lat.toStringAsFixed(6)}\nLng ${cap.lng.toStringAsFixed(6)}'),
              const SizedBox(height: 6),
              Row(children: [
                const Icon(Icons.gps_fixed, size: 16),
                const SizedBox(width: 4),
                Text('Accuracy ±${cap.accuracy.round()} m'),
              ]),
              if (cap.address != null) ...[const SizedBox(height: 6), Text(cap.address!, style: Theme.of(c).textTheme.bodySmall)],
            ])),
          ]),
          const SizedBox(height: 12),
          SizedBox(height: 190, child: ClipRRect(borderRadius: BorderRadius.circular(12), child: LocationMap(point: pt, accuracy: cap.accuracy))),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(c, false), child: const Text('Retake / Cancel'))),
            const SizedBox(width: 12),
            Expanded(child: FilledButton.icon(onPressed: () => Navigator.pop(c, true), icon: const Icon(Icons.check), label: const Text('Confirm'))),
          ]),
        ]),
      ),
    );
  }
}

/// OpenStreetMap view (no API key needed).
class LocationMap extends StatelessWidget {
  final LatLng point;
  final double? accuracy;
  final bool interactive;
  const LocationMap({super.key, required this.point, this.accuracy, this.interactive = false});
  @override
  Widget build(BuildContext c) => FlutterMap(
        options: MapOptions(
          initialCenter: point,
          initialZoom: 16.5,
          interactionOptions: InteractionOptions(flags: interactive ? InteractiveFlag.all : InteractiveFlag.none),
        ),
        children: [
          TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.buildbymeet.attendance_app'),
          if (accuracy != null)
            CircleLayer(circles: [
              CircleMarker(point: point, radius: accuracy!, useRadiusInMeter: true, color: Colors.blue.withValues(alpha: 0.15), borderColor: Colors.blue, borderStrokeWidth: 1),
            ]),
          MarkerLayer(markers: [Marker(point: point, width: 40, height: 40, child: const Icon(Icons.location_on, color: Colors.red, size: 40))]),
        ],
      );
}
