import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_code_editor/flutter_code_editor.dart';
import 'package:highlight/languages/python.dart';
import 'package:http/http.dart' as http;

// Custom theme
final draculaTheme = {
  'root': const TextStyle(color: Colors.greenAccent),
  'keyword': const TextStyle(color: Colors.purpleAccent),
  'string': const TextStyle(color: Colors.orangeAccent),
  'comment': const TextStyle(color: Colors.grey),
};

class EditorScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  const EditorScreen({super.key, required this.cameras});

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  late CameraController _cameraController;
  late CodeController _codeController;

  // Finger coordinates
  late double screenWidth;
  late double screenHeight;
  double fingerX = 0;
  double fingerY = 0;

  Timer? _timer;

  @override
void initState() {
  super.initState();

  // Initialize camera
  _cameraController = CameraController(
    widget.cameras[0],
    ResolutionPreset.medium,
    enableAudio: false,
  );
  _cameraController.initialize().then((_) {
    if (!mounted) return;
    setState(() {});
  });

  // Initialize code controller
  _codeController = CodeController(
    text: "# Start coding...\n",
    language: python,
    patternMap: {},
  );

  // Start polling server for finger coordinates every 50ms
  _timer = Timer.periodic(const Duration(milliseconds: 50), (_) {
    fetchFingerCoordinates();
  });
}

@override
void didChangeDependencies() {
  super.didChangeDependencies();
  screenWidth = MediaQuery.of(context).size.width;
  screenHeight = MediaQuery.of(context).size.height;
}

  @override
  void dispose() {
    _cameraController.dispose();
    _codeController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  // Example: Fetch coordinates from Flask server
  Future<void> fetchFingerCoordinates() async {
  try {
    final response = await http.get(Uri.parse('http://127.0.0.1:8000/finger'));
    if (response.statusCode == 200) {
      
      final data = jsonDecode(response.body);
      print("X: ${data['x']}  Y: ${data['y']}");
      setState(() {
  fingerX = data['x'] * screenWidth;
  fingerY = data['y'] * screenHeight;
});
    }
  } catch (e) {
    // ignore errors for now
  }
}

  @override
  Widget build(BuildContext context) {
    if (!_cameraController.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }
    final screenSize = MediaQuery.of(context).size;
final previewSize = _cameraController.value.previewSize!;

// Because camera sensor is landscape internally
final previewWidth = previewSize.height;
final previewHeight = previewSize.width;

// Scale preview to fit width
final scale = screenSize.width / previewWidth;
final fittedHeight = previewHeight * scale;

// Vertical offset (black bars)
final verticalOffset = (screenSize.height - fittedHeight) / 2;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1️⃣ Camera Preview
          Center(
  child: AspectRatio(
    aspectRatio: _cameraController.value.aspectRatio,
    child: CameraPreview(_cameraController),
  ),
),

          // 2️⃣ Transparent overlay with blur effect
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
              child: Container(
                color: Colors.black.withOpacity(0.1),
              ),
            ),
          ),

          // 3️⃣ Moving Finger Dot
          Positioned(
            left: fingerX - 10, // offset to center the dot
            top: fingerY - 10,
            child: const Icon(Icons.circle, color: Colors.red, size: 20),
          ),

          // 4️⃣ Transparent code editor overlay
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: SingleChildScrollView(
                child: CodeTheme(
                  data: CodeThemeData(styles: draculaTheme),
                  child: CodeField(
                    background: Colors.transparent,
                    controller: _codeController,
                    textStyle: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 16,
                      color: Colors.greenAccent,
                    ),
                    expands: false,
                    minLines: 20,
                    maxLines: null,
                    lineNumberStyle: const LineNumberStyle(
                      textStyle: TextStyle(color: Colors.green, fontSize: 14),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}