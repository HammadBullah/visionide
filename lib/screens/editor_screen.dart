import 'dart:async';
import 'dart:convert';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class EditorScreen extends StatefulWidget {
  const EditorScreen({super.key});

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  CameraController? _cameraController;
  bool _isCameraInitialized = false;
  Offset? _fingerPosition;
  Timer? _sendTimer;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) {
      print("No cameras found");
      return;
    }

    _cameraController = CameraController(
      cameras[0], // front camera
      ResolutionPreset.medium,
      enableAudio: false,
    );

    await _cameraController!.initialize();
    if (!mounted) return;

    setState(() => _isCameraInitialized = true);

    // Start sending frames every 150 ms
    _sendTimer = Timer.periodic(const Duration(milliseconds: 150), (_) => _sendCurrentFrame());
  }

  Future<void> _sendCurrentFrame() async {
    if (!_isCameraInitialized || _cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

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

          // Scale coordinates to Flutter preview size
          final previewSize = _cameraController!.value.previewSize!;
          final scaleX = MediaQuery.of(context).size.width / previewSize.width;
          final scaleY = MediaQuery.of(context).size.height / previewSize.height;

          setState(() {
            _fingerPosition = Offset(x * scaleX, y * scaleY);
          });
        }
      }
    } catch (e) {
      print('Error sending frame: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isCameraInitialized || _cameraController == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final preview = CameraPreview(_cameraController!);

    return Stack(
      fit: StackFit.expand,
      children: [
        // Camera preview
        preview,

        // Red dot overlay
        if (_fingerPosition != null)
          Positioned(
            left: _fingerPosition!.dx - 15,
            top: _fingerPosition!.dy - 15,
            child: Container(
              width: 30,
              height: 30,
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black45,
                    blurRadius: 6,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
          ),

        // Optional semi-transparent overlay for code editor area
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          height: MediaQuery.of(context).size.height * 0.45,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.0),
                  Colors.black.withOpacity(0.7),
                ],
              ),
            ),
            child: const Center(
              child: Text(
                'Code Editor Area',
                style: TextStyle(color: Colors.white70, fontSize: 24),
              ),
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