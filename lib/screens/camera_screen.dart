import 'package:flutter/material.dart';
import 'package:camera/camera.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  _CameraScreenState createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _controller;
  List<CameraDescription>? cameras;
  bool _isReady = false;

  @override
  void initState() {
    super.initState();
    _setupCamera();
  }

  Future<void> _setupCamera() async {
    try {
      cameras = await availableCameras();
      if (cameras != null && cameras!.isNotEmpty) {
        _controller = CameraController(
          cameras![0], // Câmera traseira
          ResolutionPreset.high,
          enableAudio: false,
        );
        await _controller!.initialize();
        if (mounted) {
          setState(() {
            _isReady = true;
          });
        }
      }
    } catch (e) {
      print("Erro ao inicializar câmera: $e");
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _takePicture() async {
    if (!_controller!.value.isInitialized) return;
    if (_controller!.value.isTakingPicture) return;

    try {
      final XFile file = await _controller!.takePicture();
      Navigator.pop(context, file.path); // Retorna o caminho da foto
    } catch (e) {
      print("Erro ao tirar foto: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isReady || _controller == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.blueAccent)),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Preview da Câmera Ocupando a Tela Toda
          Positioned.fill(
            child: CameraPreview(_controller!),
          ),
          
          // ==========================================
          // A "PONTARIA" (MIRA VERMELHA) VOLTOU!
          // ==========================================
          Center(
            child: Container(
              width: MediaQuery.of(context).size.width * 0.85, // 85% da largura da tela
              height: 120, // Altura ideal para focar apenas nos números
              decoration: BoxDecoration(
                border: Border.all(color: Colors.redAccent, width: 4), // Borda vermelha grossa
                borderRadius: BorderRadius.circular(10), // Cantinhos arredondados
              ),
              child: Center(
                child: Container(
                  width: 30,
                  height: 2,
                  color: Colors.redAccent.withOpacity(0.5), // Linha guia sutil no meio (opcional)
                ),
              ),
            ),
          ),
          
          // Instrução de texto no topo para o Leiturista
          const Positioned(
            top: 120,
            left: 0,
            right: 0,
            child: Text(
              "Enquadre os números na área vermelha",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                shadows: [
                  Shadow(
                    color: Colors.black,
                    blurRadius: 10,
                    offset: Offset(0, 2),
                  )
                ],
              ),
            ),
          ),

          // Botão de Captura (embaixo)
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Center(
              child: GestureDetector(
                onTap: _takePicture,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 4),
                    color: Colors.white.withOpacity(0.3),
                  ),
                  child: const Icon(Icons.camera, color: Colors.white, size: 40),
                ),
              ),
            ),
          ),

          // Botão de Voltar (no topo à esquerda)
          Positioned(
            top: 50,
            left: 20,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 35),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    );
  }
}