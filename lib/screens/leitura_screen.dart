import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img; // Biblioteca de imagem do Flutter
import 'camera_screen.dart';
import '../services/api_service.dart'; // Chamando nosso ajudante do SQLite

class LeituraScreen extends StatefulWidget {
  final Map unidade;
  final Map medidor;

  LeituraScreen({required this.unidade, required this.medidor});

  @override
  _LeituraScreenState createState() => _LeituraScreenState();
}

class _LeituraScreenState extends State<LeituraScreen> {
  File? _imageFile;
  bool _isProcessing = false;
  String _baseUrl = "https://condologic-backend.onrender.com";

  Future<void> _capturarFoto() async {
    final String? path = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => CameraScreen()),
    );

    if (path != null) {
      setState(() {
        _imageFile = File(path);
      });
      _processarOuSalvar(path);
    }
  }

  // =================================================================
  // LÓGICA OFFLINE E REDIMENSIONAMENTO (LIMITES DE 50MB RESPEITADOS)
  // =================================================================
  Future<void> _processarOuSalvar(String path) async {
    setState(() => _isProcessing = true);

    try {
      // 1. LER O ARQUIVO BRUTO
      final bytes = await File(path).readAsBytes();
      
      // 2. COMPRIMIR E REDIMENSIONAR A IMAGEM (Diminui MUITO o tamanho)
      // Decodifica a imagem original
      img.Image? originalImage = img.decodeImage(bytes);
      if (originalImage == null) throw Exception("Falha ao decodificar imagem");
      
      // Redimensiona para uma largura de 800px (ideal para OCR) e comprime a 80%
      img.Image resizedImage = img.copyResize(originalImage, width: 800);
      List<int> compressedBytes = img.encodeJpg(resizedImage, quality: 80);
      
      // Transforma na string Base64 compactada
      String base64Image = base64Encode(compressedBytes);

      // 3. TENTAR ENVIAR PARA O SERVIDOR (COM TIMEOUT CURTO)
      try {
        final response = await http.post(
          Uri.parse('$_baseUrl/api/leitura/processar-ia'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'image': base64Image,
            'medidor_id': widget.medidor['id'],
            'tenant_id': widget.unidade['tenant_id'],
            'leitura_anterior': widget.medidor['leitura_anterior']
          }),
        ).timeout(const Duration(seconds: 15)); // Tenta por 15 segundos

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          _mostrarSucesso("A IA identificou o valor: ${data['leitura']}");
        } else {
          throw Exception("Erro do Servidor");
        }

      } catch (e) {
        // ============================================================
        // SE CHEGOU AQUI: CAIU A INTERNET OU SERVIDOR DEMOROU
        // ENTRA EM AÇÃO O MODO OFFLINE!
        // ============================================================
        print("Falha na rede. Salvando offline: $e");
        
        // Salva a leitura no banco de dados local SQLite
        await DatabaseHelper().salvarLeituraOffline(
          widget.unidade['id'] ?? widget.unidade['unidade_id'] ?? 0, 
          widget.medidor['id'], 
          0.0, // Ainda não temos o valor lido, a IA vai dar depois
          path // Salva o caminho físico da foto no celular
        );

        _mostrarAvisoOffline();
      }

    } catch (e) {
      _mostrarErro("Falha catastrófica ao processar foto.");
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _mostrarAvisoOffline() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Row(
          children: [
            Icon(Icons.wifi_off, color: Colors.orange, size: 30),
            SizedBox(width: 10),
            Text("Salvo Offline", style: TextStyle(color: Colors.white, fontSize: 18)),
          ],
        ),
        content: const Text(
          "Parece que você está sem sinal de internet no momento.\n\nA foto foi gravada com segurança no seu celular e será enviada para o sistema assim que você sincronizar.",
          style: TextStyle(color: Colors.grey),
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); 
              Navigator.pop(context, true); 
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text("ENTENDIDO", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }

  void _mostrarSucesso(String mensagem) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Icon(Icons.check_circle, color: Colors.green, size: 60),
        content: Text(
          "LEITURA PROCESSADA!\n\n$mensagem\nO consumo foi calculado e salvo com sucesso no servidor.",
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); 
              Navigator.pop(context, true); 
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text("OK, PRÓXIMA", style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }

  void _mostrarErro(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg, style: const TextStyle(color: Colors.white)), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      appBar: AppBar(
        title: Text("Unidade ${widget.unidade['identificacao']}", style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            "MEDIDOR: ${widget.medidor['tipo_medidor']}",
            style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 18),
          ),
          const SizedBox(height: 10),
          Text(
            "Leitura Anterior: ${widget.medidor['leitura_anterior']}",
            style: const TextStyle(color: Colors.grey, fontSize: 16),
          ),
          const SizedBox(height: 40),
          
          Center(
            child: _imageFile == null
                ? const Icon(Icons.image_search, size: 150, color: Colors.white10)
                : Container(
                    height: 120,
                    width: double.infinity,
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.blueAccent, width: 2),
                      image: DecorationImage(image: FileImage(_imageFile!), fit: BoxFit.cover),
                    ),
                  ),
          ),
          
          const SizedBox(height: 50),
          
          if (_isProcessing)
            const Column(
              children: [
                CircularProgressIndicator(color: Colors.blueAccent),
                SizedBox(height: 20),
                Text("PROCESSANDO OU SALVANDO...", style: TextStyle(color: Colors.white, letterSpacing: 1.5)),
              ],
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: SizedBox(
                width: double.infinity,
                height: 70,
                child: ElevatedButton.icon(
                  onPressed: _capturarFoto,
                  icon: const Icon(Icons.camera_alt, size: 30, color: Colors.white),
                  label: const Text("TIRAR FOTO DO RELÓGIO", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
} 