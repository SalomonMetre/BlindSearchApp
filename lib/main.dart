import 'dart:developer' as developer;
import 'package:blind_search_app/screens/home_page.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

late List<CameraDescription> cameras;

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  cameras = await availableCameras();
  runApp(MaterialApp(
    routes: <String, WidgetBuilder>{
      'home/': (context) => const HomePage(),
    },
    initialRoute: 'home/',
    darkTheme: ThemeData.dark(
      useMaterial3: true,
    ),
    debugShowCheckedModeBanner: false,
  ));
}
