import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'camera_screen.dart';
import '../services/api_service.dart';
import '../database_helper.dart'; 

class LeituraScreen extends StatefulWidget {
  final Map unidade;
  final Map medidor;

  const LeituraScreen({super.key, required this.unidade, required this.medidor});

  @override
  _LeituraScreenState createState() => _LeituraScreenState();
}

class _LeituraScreenState extends State<LeituraScreen> {
  File? _imageFile;
  bool _isProcessing = false;
  final String _baseUrl = "https://condologic-backend.onrender.com";

  Future<void> _capturarFoto() async {
    final String? path = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CameraScreen()),
    );

    if (path != null) {
      setState(() {
        _imageFile = File(path);
      });
      _processarOuSalvar(path);
    }
  }

  Future<void> _processarOuSalvar(String path) async {
    setState(() => _isProcessing = true);

    try {
      final bytes = await File(path).readAsBytes();
      img.Image? originalImage = img.decodeImage(bytes);
      if (originalImage == null) throw Exception("Falha ao decodificar imagem");

      img.Image resizedImage = img.copyResize(originalImage, width: 800);
      List<int> compressedBytes = img.encodeJpg(resizedImage, quality: 80);
      String base64Image = base64Encode(compressedBytes);

      Map envio = {
        'image': base64Image,
        'medidor_id': widget.medidor['id'],
        'tenant_id': widget.unidade['tenant_id'],
        'leitura_anterior': widget.medidor['leitura_anterior']
      };

      try {
        final response = await http.post(
          Uri.parse('$_baseUrl/api/leitura/processar-ia'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(envio),
        ).timeout(const Duration(seconds: 60));

        if (response.statusCode == 200) {
          _tratarRespostaIA(response.body);
        } else {
          // SE O SERVIDOR DEVOLVER ERRO (Ex: 500), VAMOS VER NA TELA!
          _mostrarErro("ERRO SERVIDOR: Código ${response.statusCode}");
          print("Corpo do Erro: ${response.body}"); // Joga no console do VS Code
          await Future.delayed(const Duration(seconds: 4)); // Pausa pra ler
          await _guardarOffline(base64Image, path);
        }
      } catch (e) {
        // SE A REDE FALHAR OU DER TIMEOUT, VAMOS VER O MOTIVO EXATO!
        _mostrarErro("FALHA DE REDE/APP: $e");
        await Future.delayed(const Duration(seconds: 4)); // Pausa pra ler
        await _guardarOffline(base64Image, path);
      }

    } catch (e) {
      _mostrarErro("Erro interno ao preparar foto: $e");
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _guardarOffline(String base64, String path) async {
     await DatabaseHelper().salvarLeituraOffline(
        unidadeId: widget.unidade['unidade_id'] ?? 0, 
        medidorId: widget.medidor['id'], 
        valor: 0.0, 
        fotoPath: path,
        leituraAnterior: widget.medidor['leitura_anterior'].toString(),
        tenantId: widget.unidade['tenant_id']
      );
      _mostrarAvisoOffline();
  }

  void _tratarRespostaIA(String corpo) {
    var leituraFinal = "Desconhecida";
    int casasDecimais = widget.medidor['digitos_vermelhos'] ?? 3;

    try {
      var data = jsonDecode(corpo);
      if (data is String) data = jsonDecode(data);

      if (data is Map) {
        double? parsedVal = double.tryParse(data['leitura'].toString());
        leituraFinal = parsedVal?.toStringAsFixed(casasDecimais) ?? data['leitura'].toString();
      }
      
      leituraFinal = leituraFinal.replaceAll('.', ',');
      _mostrarSucesso("A IA identificou o valor:\n\n$leituraFinal");
    } catch (e) {
      _mostrarSucesso("Leitura enviada! O sistema processará o valor.");
    }
  }

  void _mostrarAvisoOffline() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Row(children: [Icon(Icons.wifi_off, color: Colors.orange[800]), const SizedBox(width: 10), const Text("Fila de Envio")]),
        content: const Text("O sinal oscilou ou o servidor está iniciando. A foto foi salva com sucesso e será enviada em instantes pela sincronização!"),
        actions: [
          ElevatedButton(
            onPressed: () { Navigator.pop(context); Navigator.pop(context, true); },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange[800]),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Icon(Icons.check_circle, color: Colors.green, size: 60),
        content: Text(mensagem, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        actions: [
          ElevatedButton(
            onPressed: () { Navigator.pop(context); Navigator.pop(context, true); },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text("CONFIRMAR", style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }

  void _mostrarErro(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  @override
  Widget build(BuildContext context) {
    String leituraAnteriorFormatada = widget.medidor['leitura_anterior'].toString().replaceAll('.', ',');

    return Scaffold(
      backgroundColor: Colors.blue[50],
      appBar: AppBar(
        title: Text("Unidade ${widget.unidade['identificacao']}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.blue[900],
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text("MEDIDOR: ${widget.medidor['tipo_medidor'].toString().toUpperCase()}", style: TextStyle(color: Colors.blue[900], fontWeight: FontWeight.bold, fontSize: 20)),
          const SizedBox(height: 10),
          Text("Leitura Anterior: $leituraAnteriorFormatada", style: TextStyle(color: Colors.grey[700], fontSize: 16)),
          const SizedBox(height: 40),
          Center(
            child: _imageFile == null
                ? Icon(Icons.image_search, size: 150, color: Colors.blue[100])
                : Container(
                    height: 180, width: double.infinity, margin: const EdgeInsets.symmetric(horizontal: 20),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.blue[900]!, width: 3),
                      borderRadius: BorderRadius.circular(10),
                      image: DecorationImage(image: FileImage(_imageFile!), fit: BoxFit.cover),
                    ),
                  ),
          ),
          const SizedBox(height: 50),
          if (_isProcessing)
            Column(children: [CircularProgressIndicator(color: Colors.blue[900]), const SizedBox(height: 20), const Text("PROCESSANDO...", style: TextStyle(fontWeight: FontWeight.bold))] )
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: SizedBox(
                width: double.infinity, height: 70,
                child: ElevatedButton.icon(
                  onPressed: _capturarFoto,
                  icon: const Icon(Icons.camera_alt, size: 30, color: Colors.white),
                  label: const Text("TIRAR FOTO DO RELÓGIO", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[900], shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
