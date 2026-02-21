import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'screens/editor_screen.dart';
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final cameras = await availableCameras();
  runApp(MaterialApp(
    home: EditorScreen(cameras: cameras),
    debugShowCheckedModeBanner: false,
  ));
}
