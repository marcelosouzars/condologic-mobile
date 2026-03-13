// ==========================================>>> leitura_screen.dart

import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'camera_screen.dart';
import '../services/api_service.dart';

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

  // --- FUNÇÃO PARA CHECAR A INTERNET REAL ---
  Future<bool> _temInternet() async {
    try {
      final result = await InternetAddress.lookup('google.com').timeout(const Duration(seconds: 5));
      if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
        return true;
      }
    } on SocketException catch (_) {
      return false;
    } on TimeoutException catch (_) {
      return false;
    }
    return false;
  }

  Future<void> _processarOuSalvar(String path) async {
    setState(() => _isProcessing = true);

    try {
      // COMPRESSÃO DA IMAGEM PARA EVITAR TRAVAMENTO NO SERVIDOR
      final bytes = await File(path).readAsBytes();
      img.Image? originalImage = img.decodeImage(bytes);
      
      if (originalImage == null) throw Exception("Falha ao decodificar imagem");

      img.Image resizedImage = img.copyResize(originalImage, width: 800);
      List<int> compressedBytes = img.encodeJpg(resizedImage, quality: 70);
      String base64Image = base64Encode(compressedBytes);

      bool online = await _temInternet();

      if (!online) {
        print("Sem conexão real. Salvando offline.");
        await DatabaseHelper().salvarLeituraOffline(
          widget.unidade['id'] ?? widget.unidade['unidade_id'] ?? 0, 
          widget.medidor['id'], 
          0.0, 
          path 
        );
        _mostrarAvisoOffline();
        return;
      }

      // ENVIO PARA O SERVIDOR
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
        ).timeout(const Duration(seconds: 30));

        if (response.body.trim().startsWith('<')) {
          throw Exception("O servidor bloqueou a conexão (HTML). A foto pode estar muito pesada.");
        }

        if (response.statusCode == 200 || response.statusCode == 201) {
          // ==============================================================
          // AMORTECEDOR DE JSON (A MÁGICA QUE RESOLVE O ERRO DA TELA)
          // ==============================================================
          dynamic decodedData;
          try {
            decodedData = jsonDecode(response.body);
          } catch (e) {
            decodedData = response.body; // Se falhar no parse, usa a string bruta
          }

          // Trata o cenário onde a API devolve uma String duplamente codificada
          if (decodedData is String) {
            try {
              var temp = jsonDecode(decodedData);
              decodedData = temp;
            } catch (_) {}
          }

          // Extração Flexível do Valor
          String leituraFinal = "Não identificado";
          if (decodedData is Map) {
             leituraFinal = decodedData['leitura']?.toString() ?? decodedData['valor']?.toString() ?? decodedData.toString();
          } else {
             leituraFinal = decodedData.toString();
          }

          _mostrarSucesso("A IA identificou o valor:\n$leituraFinal");
        } else {
          // Trata também mensagens de erro bagunçadas que vêm do backend
          dynamic erroData;
          try {
            erroData = jsonDecode(response.body);
          } catch (_) {
            erroData = response.body;
          }
          
          String msgErro = "Erro na API";
          if (erroData is Map) {
             msgErro = erroData['error']?.toString() ?? erroData['mensagem']?.toString() ?? erroData.toString();
          } else {
             msgErro = erroData.toString();
          }
          throw Exception(msgErro);
        }

      } catch (e) {
         _mostrarErro("Falha de comunicação: ${e.toString().replaceAll('Exception: ', '')}");
      }

    } catch (e) {
      _mostrarErro("Falha ao processar foto: ${e.toString().replaceAll('Exception: ', '')}");
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _mostrarAvisoOffline() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: Row(
          children: [
            Icon(Icons.wifi_off, color: Colors.orange[800], size: 30),
            const SizedBox(width: 10),
            Text("Salvo Offline", style: TextStyle(color: Colors.orange[800], fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          "Você está sem sinal de internet no momento.\n\nA foto foi gravada com segurança no seu celular e será enviada automaticamente assim que a conexão retornar.",
          style: TextStyle(color: Colors.black87),
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); 
              Navigator.pop(context, true); 
            },
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
        backgroundColor: Colors.white,
        title: const Icon(Icons.check_circle, color: Colors.green, size: 60),
        content: Text(
          "LEITURA PROCESSADA!\n\n$mensagem\n\nO consumo foi calculado e salvo com sucesso no servidor.",
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.black87, fontSize: 16),
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); 
              Navigator.pop(context, true); 
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text("OK, PRÓXIMA", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }

  void _mostrarErro(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(color: Colors.white)), 
        backgroundColor: Colors.red, 
        duration: const Duration(seconds: 6) 
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue[50], 
      appBar: AppBar(
        title: Text("Unidade ${widget.unidade['identificacao']}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.blue[900],
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            "MEDIDOR: ${widget.medidor['tipo_medidor'].toString().toUpperCase()}",
            style: TextStyle(color: Colors.blue[900], fontWeight: FontWeight.bold, fontSize: 20),
          ),
          const SizedBox(height: 10),
          Text(
            "Leitura Anterior: ${widget.medidor['leitura_anterior']}",
            style: TextStyle(color: Colors.grey[700], fontSize: 16),
          ),
          const SizedBox(height: 40),
          
          Center(
            child: _imageFile == null
                ? Icon(Icons.image_search, size: 150, color: Colors.blue[100])
                : Container(
                    height: 180,
                    width: double.infinity,
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.blue[900]!, width: 3),
                      borderRadius: BorderRadius.circular(10),
                      image: DecorationImage(image: FileImage(_imageFile!), fit: BoxFit.cover),
                    ),
                  ),
          ),
          
          const SizedBox(height: 50),
          
          if (_isProcessing)
            Column(
              children: [
                CircularProgressIndicator(color: Colors.blue[900]),
                const SizedBox(height: 20),
                Text("ENVIANDO PARA A IA...", style: TextStyle(color: Colors.blue[900], fontWeight: FontWeight.bold, letterSpacing: 1.5)),
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
                    backgroundColor: Colors.blue[900],
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