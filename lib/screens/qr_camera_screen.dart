// lib/screens/qr_camera_screen.dart
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class QrCameraScreen extends StatefulWidget {
  const QrCameraScreen({super.key});

  @override
  State<QrCameraScreen> createState() => _QrCameraScreenState();
}

class _QrCameraScreenState extends State<QrCameraScreen> {
  final MobileScannerController _controller = MobileScannerController();
  bool _handled = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) async {
    if (_handled) return;

    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final raw = barcodes.first.rawValue;
    if (raw == null || raw.trim().isEmpty) return;

    _handled = true;
    await _controller.stop();

    if (!mounted) return;
    Navigator.of(context).pop(raw.trim()); // <- renvoie le texte du QR
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scanner un QR code'),
        actions: [
          IconButton(
            tooltip: 'Torche',
            onPressed: () => _controller.toggleTorch(),
            icon: const Icon(Icons.flash_on),
          ),
          IconButton(
            tooltip: 'Changer caméra',
            onPressed: () => _controller.switchCamera(),
            icon: const Icon(Icons.cameraswitch),
          ),
        ],
      ),
      body: MobileScanner(
        controller: _controller,
        onDetect: _onDetect,
      ),
    );
  }
}
