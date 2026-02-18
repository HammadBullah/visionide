import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class HandTrackerScreen extends StatefulWidget {
  const HandTrackerScreen({super.key});

  @override
  State<HandTrackerScreen> createState() => _HandTrackerScreenState();
}

class _HandTrackerScreenState extends State<HandTrackerScreen> {
  CameraController? _cameraController;
  bool _isInitialized = false;
  Offset? _fingerPos;
  Timer? _sendTimer;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
  try {
    final cameras = await availableCameras();
    print('Available cameras: ${cameras.length} → ${cameras.map((c) => c.name).toList()}');

    if (cameras.isEmpty) {
      print("No cameras found on this device");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No camera detected – check hardware/permissions')),
      );
      return;
    }

    // Use front camera if available, fallback to first one
    final frontCamera = cameras.firstWhere(
      (cam) => cam.lensDirection == CameraLensDirection.front,
      orElse: () => cameras[0],
    );

    _cameraController = CameraController(
      frontCamera,
      ResolutionPreset.medium,
      enableAudio: false,
    );

    await _cameraController!.initialize();
    print('Camera initialized: ${frontCamera.name}');

    if (!mounted) return;

    setState(() => _isInitialized = true);

    // Start sending frames
    _sendTimer = Timer.periodic(const Duration(milliseconds: 150), (_) => _sendFrame());
  } catch (e) {
    print('Camera init failed: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Camera error: $e')),
    );
  }
}

  Future<void> _sendFrame() async {
    if (!_isInitialized || _cameraController == null || !_cameraController!.value.isInitialized) return;

    try {
      final image = await _cameraController!.takePicture();
      final bytes = await image.readAsBytes();

      final response = await http.post(
        Uri.parse('http://127.0.0.1:5000/process_frame'),
        headers: {'Content-Type': 'image/jpeg'},
        body: bytes,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['index_finger'] != null) {
          final x = data['index_finger']['x'] as double;
          final y = data['index_finger']['y'] as double;

          // Scale to preview size
          final previewSize = _cameraController!.value.previewSize!;
          final scaleX = MediaQuery.of(context).size.width / previewSize.width;
          final scaleY = MediaQuery.of(context).size.height / previewSize.height;

          setState(() {
            _fingerPos = Offset(x * scaleX, y * scaleY);
          });
        }
      }
    } catch (e) {
      print('Frame send error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized || _cameraController == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        CameraPreview(_cameraController!),

        // Red dot on index finger
        if (_fingerPos != null)
          Positioned(
            left: _fingerPos!.dx - 20,
            top: _fingerPos!.dy - 20,
            child: Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: Colors.black45, blurRadius: 8, spreadRadius: 2),
                ],
              ),
            ),
          ),

        // Status text
        Positioned(
          top: 40,
          left: 16,
          right: 16,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'Hand Tracking Active • Red dot = Index Finger',
              style: TextStyle(color: Colors.white, fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _sendTimer?.cancel();
    _cameraController?.dispose();
    super.dispose();
  }
}