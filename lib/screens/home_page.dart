import 'package:blind_search_app/main.dart';
import 'package:blind_search_app/screens/live_detection_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter_vibrate/flutter_vibrate.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter/services.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final iconColors = [Colors.teal.shade100, Colors.red];
  int colorIndex = 0;
  String objectToSearch = '';
  FlutterTts ttsSpeaker = FlutterTts();
  final welcomeText =
      "Welcome ! Blind Search App is ready to help you search an object. Long press and say the object you want us to find for you";
  final SpeechToText _speechToText = SpeechToText();

  @override
  void initState() {
    super.initState();
    _initSpeech();
  }

  void _initSpeech() async {
    await _speechToText.initialize();
    setState(() {});
  }

  /// Each time to start a speech recognition session
  void _startListening() async {
    changeIconColor();
    await _speechToText.listen(onResult: _onSpeechResult);
    setState(() {});
  }

  /// Manually stop the active speech recognition session
  /// Note that there are also timeouts that each platform enforces
  /// and the SpeechToText plugin supports setting timeouts on the
  /// listen method.
  void _stopListening() async {
    changeIconColor();
    await _speechToText.stop();
    setState(() {});
  }

  /// This is the callback that the SpeechToText plugin calls when
  /// the platform returns recognized words.
  void _onSpeechResult(SpeechRecognitionResult result) {
    setState(() {
      objectToSearch = result.recognizedWords.toLowerCase();
    });
  }

  void sayMessage(String message) async {
    await ttsSpeaker.setLanguage("en-US");
    await ttsSpeaker.setPitch(0.8);
    await ttsSpeaker.speak(message);
  }

  void changeIconColor() {
    setState(() {
      colorIndex = (colorIndex + 1) % 2;
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        sayMessage(welcomeText);
      },
      onLongPress: () {
        _startListening();
      },
      onLongPressEnd: (longPressEndDetails) {
        _stopListening();
        print(objectToSearch);
      },
      onDoubleTap: () async {
        await Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => LiveDetectionScreen(
              title: "Live Detection",
              objectToSearch: objectToSearch,
              cameras: cameras,
            ),
          ),
        );
      },
      child: Center(
        child: SizedBox(
          width: 400,
          height: 400,
          child: Icon(
            Icons.mic,
            color: iconColors[colorIndex],
            size: 200,
          ),
        ),
      ),
    );
  }
}
