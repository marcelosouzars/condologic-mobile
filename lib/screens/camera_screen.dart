import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

class CameraScreen extends StatefulWidget {
  @override
  _CameraScreenState createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _controller;
  Future<void>? _initializeControllerFuture;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) return;
    
    _controller = CameraController(
      cameras.first,
      ResolutionPreset.high,
      enableAudio: false,
    );
    _initializeControllerFuture = _controller!.initialize();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _takePictureAndCrop() async {
    try {
      await _initializeControllerFuture;
      final image = await _controller!.takePicture();
      
      final bytes = await File(image.path).readAsBytes();
      img.Image? originalImage = img.decodeImage(bytes);

      if (originalImage != null) {
        int width = originalImage.width;
        int height = originalImage.height;
        
        int cropHeight = (height * 0.20).toInt();
        int cropTop = (height / 2 - cropHeight / 2).toInt();

        img.Image croppedImage = img.copyCrop(
          originalImage,
          x: 0,
          y: cropTop,
          width: width,
          height: cropHeight,
        );
        
        final tempDir = await getTemporaryDirectory();
        final croppedFile = File('${tempDir.path}/cropped_${DateTime.now().millisecondsSinceEpoch}.jpg');
        await croppedFile.writeAsBytes(img.encodeJpg(croppedImage, quality: 85));

        Navigator.pop(context, croppedFile.path);
      }
    } catch (e) {
      print("Erro ao capturar/recortar: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: Text("Centralize o Relógio"), backgroundColor: Colors.blueGrey[900]),
      body: FutureBuilder<void>(
        future: _initializeControllerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            return Stack(
              children: [
                CameraPreview(_controller!),
                Center(
                  child: Container(
                    width: double.infinity,
                    height: 100,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.red, width: 3),
                      color: Colors.red.withOpacity(0.1),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 30,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: FloatingActionButton(
                      backgroundColor: Colors.red,
                      child: Icon(Icons.camera_alt, color: Colors.white),
                      onPressed: _takePictureAndCrop,
                    ),
                  ),
                ),
              ],
            );
          } else {
            return Center(child: CircularProgressIndicator());
          }
        },
      ),
    );
  }
}