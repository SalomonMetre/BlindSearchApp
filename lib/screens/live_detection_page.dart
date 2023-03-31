import 'package:blind_search_app/screens/home_page.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter_vibrate/flutter_vibrate.dart';
import 'package:google_mlkit_object_detection/google_mlkit_object_detection.dart';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_vibrate/flutter_vibrate.dart';

class LiveDetectionScreen extends StatefulWidget {
  LiveDetectionScreen(
      {Key? key,
      required this.title,
      required this.objectToSearch,
      required this.cameras})
      : super(key: key);
  final String title, objectToSearch;
  final cameras;

  @override
  // ignore: library_private_types_in_public_api
  _LiveDetectionScreenState createState() => _LiveDetectionScreenState();
}

class _LiveDetectionScreenState extends State<LiveDetectionScreen> {
  dynamic controller;
  bool isBusy = false;
  dynamic objectDetector;
  late Size size;

  @override
  void initState() {
    super.initState();
    initializeCamera();
  }

  //code to initialize the camera feed
  initializeCamera() async {
    //initialize detector
    const mode = DetectionMode.stream;
// Options to configure the detector while using with base model.
    final modelPath = await _getModel('assets/ml/efficientnet.tflite');
    final options = LocalObjectDetectorOptions(
        modelPath: modelPath,
        mode: mode,
        classifyObjects: true,
        multipleObjects: true);
    objectDetector = ObjectDetector(options: options);
    controller = CameraController(widget.cameras[0], ResolutionPreset.high);
    await controller.initialize().then((_) {
      if (!mounted) {
        return;
      }
      controller.startImageStream((image) => {
            if (!isBusy)
              {isBusy = true, img = image, doObjectDetectionOnFrame()}
          });
    });
  }

  //close all resources
  @override
  void dispose() {
    controller?.dispose();
    objectDetector.close();
    super.dispose();
  }

  Future<String> _getModel(String assetPath) async {
    if (Platform.isAndroid) {
      return 'flutter_assets/$assetPath';
    }
    final path = '${(await getApplicationSupportDirectory()).path}/$assetPath';
    await Directory(dirname(path)).create(recursive: true);
    final file = File(path);
    if (!await file.exists()) {
      final byteData = await rootBundle.load(assetPath);
      await file.writeAsBytes(byteData.buffer
          .asUint8List(byteData.offsetInBytes, byteData.lengthInBytes));
    }
    return file.path;
  }

  // object detection on a frame
  dynamic _scanResults;
  CameraImage? img;
  doObjectDetectionOnFrame() async {
    var frameImg = getInputImage();
    List<DetectedObject> objects = await objectDetector.processImage(frameImg);
    print("len= ${objects.length}");
    setState(() {
      _scanResults = objects;
    });
    isBusy = false;
  }

  InputImage getInputImage() {
    final WriteBuffer allBytes = WriteBuffer();
    for (final Plane plane in img!.planes) {
      allBytes.putUint8List(plane.bytes);
    }
    final bytes = allBytes.done().buffer.asUint8List();
    final Size imageSize = Size(img!.width.toDouble(), img!.height.toDouble());
    final camera = widget.cameras[0];
    final imageRotation =
        InputImageRotationValue.fromRawValue(camera.sensorOrientation);
    // if (imageRotation == null) return;

    final inputImageFormat =
        InputImageFormatValue.fromRawValue(img!.format.raw);
    // if (inputImageFormat == null) return null;

    final planeData = img!.planes.map(
      (Plane plane) {
        return InputImagePlaneMetadata(
          bytesPerRow: plane.bytesPerRow,
          height: plane.height,
          width: plane.width,
        );
      },
    ).toList();

    final inputImageData = InputImageData(
      size: imageSize,
      imageRotation: imageRotation!,
      inputImageFormat: inputImageFormat!,
      planeData: planeData,
    );

    final inputImage =
        InputImage.fromBytes(bytes: bytes, inputImageData: inputImageData);
    return inputImage;
  }

  //Show rectangles around detected objects
  Widget buildResult() {
    if (_scanResults == null ||
        controller == null ||
        !controller.value.isInitialized) {
      return const Text('');
    }

    final Size imageSize = Size(
      controller.value.previewSize!.height,
      controller.value.previewSize!.width,
    );
    CustomPainter painter =
        ObjectDetectorPainter(imageSize, _scanResults, widget.objectToSearch);
    return CustomPaint(
      painter: painter,
    );
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> stackChildren = [];
    size = MediaQuery.of(context).size;
    if (controller != null) {
      stackChildren.add(
        Positioned(
          top: 0.0,
          left: 0.0,
          width: size.width,
          height: size.height,
          child: Container(
            child: (controller.value.isInitialized)
                ? AspectRatio(
                    aspectRatio: controller.value.aspectRatio,
                    child: CameraPreview(controller),
                  )
                : Container(),
          ),
        ),
      );

      stackChildren.add(
        Positioned(
            top: 0.0,
            left: 0.0,
            width: size.width,
            height: size.height,
            child: buildResult()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text("Detecting ${widget.objectToSearch} ..."),
        backgroundColor: Theme.of(context).primaryColor,
      ),
      backgroundColor: Colors.black,
      body: Container(
          margin: const EdgeInsets.only(top: 0),
          color: Colors.black,
          child: GestureDetector(
            onLongPress: (){
              FlutterTts()..setPitch(0.8)..speak("Stopped searching. Back to Home Screen");
              Navigator.pushReplacement(
                context, 
                MaterialPageRoute(
                  builder: (context) => const HomePage(),
                ),
              );  
            },
            child: Stack(
              children: stackChildren,
            ),
          )),
    );
  }
}

class ObjectDetectorPainter extends CustomPainter {
  ObjectDetectorPainter(
      this.absoluteImageSize, this.objects, this.objectToSearch);
  final String objectToSearch;
  final Size absoluteImageSize;
  final List<DetectedObject> objects;

  @override
  void paint(Canvas canvas, Size size) async{
    final double scaleX = size.width / absoluteImageSize.width;
    final double scaleY = size.height / absoluteImageSize.height;

    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..color = Colors.pinkAccent;

    for (DetectedObject detectedObject in objects) {
      canvas.drawRect(
        Rect.fromLTRB(
          detectedObject.boundingBox.left * scaleX,
          detectedObject.boundingBox.top * scaleY,
          detectedObject.boundingBox.right * scaleX,
          detectedObject.boundingBox.bottom * scaleY,
        ),
        paint,
      );

      var list = detectedObject.labels;
      for (Label label in list) {
        if (label.text.toLowerCase() == objectToSearch) {
          if(await Vibrate.canVibrate){
            Vibrate.vibrate();
          }
        }
        // print("${label.text}   ${label.confidence.toStringAsFixed(2)}");
        TextSpan span = TextSpan(
            text: label.text,
            style: const TextStyle(fontSize: 25, color: Colors.blue));
        TextPainter tp = TextPainter(
            text: span,
            textAlign: TextAlign.left,
            textDirection: TextDirection.ltr);
        tp.layout();
        tp.paint(
            canvas,
            Offset(detectedObject.boundingBox.left * scaleX,
                detectedObject.boundingBox.top * scaleY));
        break;
      }
    }
  }

  @override
  bool shouldRepaint(ObjectDetectorPainter oldDelegate) {
    return oldDelegate.absoluteImageSize != absoluteImageSize ||
        oldDelegate.objects != objects;
  }
}
