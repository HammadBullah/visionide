import 'package:flutter/material.dart';
import 'package:visionide/handtrackerscreen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VisionIDE',
      theme: ThemeData.dark(),
      home: const HandTrackerScreen(),  // your screen with camera + red dot
      debugShowCheckedModeBanner: false,
    );
  }
}