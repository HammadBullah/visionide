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
  bool isSelecting = false;
int selectionStartOffset = 0;

  Timer? poll_timer;

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
poll_timer = Timer.periodic(const Duration(milliseconds: 150), (_) {
    _fetchFingerAndGesture();
  });}

@override
void didChangeDependencies() {
  super.didChangeDependencies();
  screenWidth = MediaQuery.of(context).size.width;
  screenHeight = MediaQuery.of(context).size.height;
}
Future<void> _fetchFingerAndGesture() async {
  try {
    final response = await http.get(Uri.parse('http://127.0.0.1:8000/finger'));
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final x = data['x'] as double;
      final y = data['y'] as double;
      final gesture = data['gesture'] as String;

      final scaleX = MediaQuery.of(context).size.width;
      final scaleY = MediaQuery.of(context).size.height;
      setState(() {
        fingerX = x * scaleX;
        fingerY = y * scaleY;
        currentGesture = gesture;
      });
      _handlePinchSelection(gesture);
      _moveCursorToFinger(x, y);
      _handleGesture(gesture);
    }
  } catch (e) {
    print('Poll error: $e');
  }
}

void _handlePinchSelection(String gesture) {
  final controller = _codeController;

  if (gesture == "pinch") {
    if (!isSelecting) {
      // Pinch just started → begin selection from current cursor
      isSelecting = true;
      selectionStartOffset = controller.selection.baseOffset;
      print("Pinch started → selection begin at offset $selectionStartOffset");
    }

    // While pinching, extend selection to current cursor position
    // (cursor is already moved by _moveCursorToFinger in your existing code)
    final currentOffset = controller.selection.baseOffset;
    controller.selection = TextSelection(
      baseOffset: selectionStartOffset,
      extentOffset: currentOffset,
    );
  } 
  else {
    // Pinch released → stop selecting (keep current selection)
    if (isSelecting) {
      isSelecting = false;
      print("Pinch released → selection ended at offset ${controller.selection.extentOffset}");
    }
  }
}

void _moveCursorToFinger(double normX, double normY) {
  if (_codeController.text.isEmpty) return;

  // Estimate total lines in the editor
  final lines = _codeController.text.split('\n');
  final totalLines = lines.length;

  // Map Y (vertical) → line number
  int targetLine = (normY * totalLines).floor();
  targetLine = targetLine.clamp(0, totalLines - 1);

  // Map X (horizontal) → approximate char offset in that line
  final lineText = lines[targetLine];
  final charsInLine = lineText.length;
  int targetChar = (normX * charsInLine * 1.2).floor(); // 1.2 = generous scaling
  targetChar = targetChar.clamp(0, charsInLine);

  // Move cursor
  final offset = _codeController.text
      .split('\n')
      .take(targetLine)
      .fold(0, (sum, line) => sum + line.length + 1) + targetChar;

  setState(() {
    _codeController.selection = TextSelection.collapsed(offset: offset);
  });

  print('Cursor moved to line $targetLine, char $targetChar (offset: $offset)');
}

String currentGesture = "none";

void _handleGesture(String gesture) {
  if (gesture == "fist") {
    // Delete selected text
    print("Fist → delete");
    final sel = _codeController.selection;
    if (!sel.isCollapsed) {  // ← corrected line
      _codeController.text = _codeController.text.replaceRange(
        sel.start,
        sel.end,
        '',
      );
      _codeController.selection = TextSelection.collapsed(offset: sel.start);
    }
  } 
  else if (gesture == "open_palm") {
    // Deselect / normal mode
    _codeController.selection = TextSelection.collapsed(
      offset: _codeController.text.length,
    );
  }
}

  @override
  void dispose() {
    _cameraController.dispose();
    _codeController.dispose();
    poll_timer?.cancel();
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
            child: const Icon(Icons.circle, color: Color.fromARGB(255, 57, 57, 57), size: 20),
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