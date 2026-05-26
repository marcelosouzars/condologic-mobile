// ==========================================>>> leitura_screen.dart
import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:connectivity_plus/connectivity_plus.dart'; 
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

  Future<bool> _temInternetReal() async {
    try {
      var conectividade = await Connectivity().checkConnectivity();
      if (conectividade.isEmpty || conectividade.every((e) => e == ConnectivityResult.none)) {
        return false;
      }

      final response = await http.get(
        Uri.parse('https://clients3.google.com/generate_204')
      ).timeout(const Duration(seconds: 5));

      return response.statusCode == 204 || response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<void> _capturarFoto() async {
    final String? path = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CameraScreen()),
    );

    if (path != null) {
      setState(() => _imageFile = File(path));
      _processarIA(path);
    }
  }

  Future<void> _processarIA(String path) async {
    setState(() => _isProcessing = true);

    try {
      final bytes = await File(path).readAsBytes();
      img.Image? originalImage = img.decodeImage(bytes);
      if (originalImage == null) throw Exception("Falha ao decodificar imagem");

      img.Image resizedImage = img.copyResize(originalImage, width: 800);
      String base64Image = base64Encode(img.encodeJpg(resizedImage, quality: 80));
      
      bool internetOK = await _temInternetReal();
      
      if (!internetOK) {
        if (mounted) {
          setState(() => _isProcessing = false);
          _mostrarErro("DIAGNÓSTICO: O app achou que está sem internet (Ping Falhou).");
          _mostrarDialogoConfirmacao(0.0, base64Image, path, isOffline: true);
        }
        return;
      }

      Map envio = {
        'image': base64Image,
        'medidor_id': widget.medidor['id'],
        'apenas_ler': true 
      };

      try {
        final response = await http.post(
          Uri.parse('$_baseUrl/api/leitura/processar-ia'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(envio),
        ).timeout(const Duration(seconds: 30));

        if (response.statusCode == 200) {
          var data = jsonDecode(response.body);
          double valorIA = double.tryParse(data['leitura'].toString()) ?? 0.0;
          if (mounted) {
            setState(() => _isProcessing = false);
            _mostrarDialogoConfirmacao(valorIA, base64Image, path, isOffline: false);
          }
        } else {
          if (mounted) {
            setState(() => _isProcessing = false);
            // DIAGNÓSTICO ATIVO: Vai mostrar o erro exato do Render/Gemini na tela
            _mostrarErro("ERRO DO SERVIDOR (${response.statusCode}): ${response.body}");
            _mostrarDialogoConfirmacao(0.0, base64Image, path, isOffline: true);
          }
        }
      } on TimeoutException catch (_) {
        if (mounted) { 
          setState(() => _isProcessing = false); 
          _mostrarErro("DIAGNÓSTICO: Timeout de 30s. O Render demorou demais.");
          _mostrarDialogoConfirmacao(0.0, base64Image, path, isOffline: true); 
        }
      } catch (e) {
        if (mounted) { 
          setState(() => _isProcessing = false); 
          _mostrarErro("DIAGNÓSTICO ERRO DE REDE: $e");
          _mostrarDialogoConfirmacao(0.0, base64Image, path, isOffline: true); 
        }
      }
    } catch (e) {
      _mostrarErro("DIAGNÓSTICO ERRO INTERNO: $e");
      if (mounted) setState(() => _isProcessing = false);
    } 
  }

  void _mostrarDialogoConfirmacao(double valorIA, String base64Image, String path, {required bool isOffline}) {
    int casasDecimais = widget.medidor['digitos_vermelhos'] ?? 3;
    TextEditingController controller = TextEditingController(text: (valorIA > 0 && !isOffline) ? valorIA.toStringAsFixed(casasDecimais).replaceAll('.', ',') : "");

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        bool isSaving = false;
        bool houveTrocaRelogio = false;

        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Column(
                children: [
                  if (isOffline)
                    Container(
                      padding: const EdgeInsets.all(5),
                      color: Colors.red[100],
                      child: const Text("OFFLINE (LENTO/SEM SINAL)", style: TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  const SizedBox(height: 5),
                  Text(isOffline ? "Informe a Leitura Manual" : "Confirme a Leitura da IA", textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold)),
                ]
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text((!isOffline && valorIA > 0) ? "Valor lido pela IA. Você pode corrigir:" : "Digite o valor que está no relógio:"),
                    const SizedBox(height: 15),
                    TextField(
                      controller: controller,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 24, 
                        fontWeight: FontWeight.bold, 
                        color: isOffline ? Colors.black : Colors.green[700]
                      ),
                      decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        suffixText: "m³",
                        fillColor: isOffline ? Colors.grey[200] : Colors.green[50],
                        filled: true
                      ),
                    ),
                    const SizedBox(height: 15),
                    
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text("Houve Troca de Relógio?", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                      subtitle: const Text("Ative se o relógio zerou.", style: TextStyle(fontSize: 12)),
                      value: houveTrocaRelogio,
                      activeColor: Colors.blue[900],
                      onChanged: (bool value) {
                        setStateDialog(() {
                          houveTrocaRelogio = value;
                        });
                      },
                    ),

                    const SizedBox(height: 10),
                    if (isSaving) const CircularProgressIndicator()
                  ],
                ),
              ),
              actionsAlignment: MainAxisAlignment.center,
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () {
                    Navigator.pop(context);
                    _capturarFoto(); 
                  },
                  child: const Text("REPETIR FOTO", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                ),
                ElevatedButton(
                  onPressed: isSaving ? null : () async {
                    if(controller.text.isEmpty) {
                      _mostrarErro("Digite um valor válido!");
                      return;
                    }
                    setStateDialog(() => isSaving = true);
                    
                    String valText = controller.text.replaceAll(',', '.');
                    double valorFinal = double.tryParse(valText) ?? 0.0;
                    
                    String origemDado = 'MANUAL_OFFLINE';
                    if (!isOffline) {
                      origemDado = (valorFinal != valorIA) ? 'IA_CORRIGIDA' : 'IA_PURA';
                    }
                    
                    bool sucesso = await _salvarDefinitivo(valorFinal, base64Image, path, origemDado, valorIA, houveTrocaRelogio, isOffline);
                    
                    if (sucesso && mounted) {
                      Navigator.pop(context); 
                      Navigator.pop(context, true); 
                    } else {
                      setStateDialog(() => isSaving = false);
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[900], padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10)),
                  child: const Text("SALVAR", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                )
              ],
            );
          }
        );
      }
    );
  }

  Future<bool> _salvarDefinitivo(double valorFinal, String base64Image, String path, String origemDado, double valorIA, bool trocaRelogio, bool forcarOffline) async {
    if (forcarOffline) {
      await _guardarOffline(base64Image, path, valorFinal, origemDado, valorIA, trocaRelogio);
      return true;
    }

    Map envio = {
      'valor_lido': valorFinal,
      'image': base64Image,
      'medidor_id': widget.medidor['id'],
      'tenant_id': widget.unidade['tenant_id'],
      'leitura_anterior': widget.medidor['leitura_anterior'],
      'origem_dado': origemDado,
      'valor_ia': valorIA,
      'troca_relogio': trocaRelogio
    };

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/leitura/salvar'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(envio),
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Leitura salva na nuvem!"), backgroundColor: Colors.green));
        return true;
      } else {
        await _guardarOffline(base64Image, path, valorFinal, origemDado, valorIA, trocaRelogio);
        return true;
      }
    } catch (e) {
      await _guardarOffline(base64Image, path, valorFinal, origemDado, valorIA, trocaRelogio); 
      return true;
    }
  }

  Future<void> _guardarOffline(String base64, String path, double valorManual, String origemDado, double valorIA, bool trocaRelogio) async {
     await DatabaseHelper().salvarLeituraOffline(
        unidadeId: widget.unidade['unidade_id'] ?? 0, 
        medidorId: widget.medidor['id'], 
        valor: valorManual, 
        fotoPath: path,
        leituraAnterior: widget.medidor['leitura_anterior'].toString(),
        tenantId: widget.unidade['tenant_id'],
        origemDado: origemDado,
        valorIa: valorIA,
        trocaRelogio: trocaRelogio
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Foto salva! Ela será enviada em breve."), 
            backgroundColor: Colors.orange, 
            duration: Duration(seconds: 3)
          )
        );
      }
  }

  void _mostrarErro(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)), backgroundColor: Colors.red, duration: const Duration(seconds: 8)));
  }

  @override
  Widget build(BuildContext context) {
    String leituraAnteriorFormatada = widget.medidor['leitura_anterior'].toString().replaceAll('.', ',');

    return Scaffold(
      backgroundColor: Colors.blue[50],
      appBar: AppBar(
        title: Text(
          "Apto ${widget.unidade['identificacao']} - ${(widget.unidade['bloco_nome'] ?? '').toString().toLowerCase().contains('bloco') ? widget.unidade['bloco_nome'] : 'Bloco ${widget.unidade['bloco_nome']}'}",
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
        ),
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
                : Container(height: 180, width: double.infinity, margin: const EdgeInsets.symmetric(horizontal: 20), decoration: BoxDecoration(border: Border.all(color: Colors.blue[900]!, width: 3), borderRadius: BorderRadius.circular(10), image: DecorationImage(image: FileImage(_imageFile!), fit: BoxFit.cover))),
          ),
          const SizedBox(height: 50),
          if (_isProcessing)
            Column(children: [CircularProgressIndicator(color: Colors.blue[900]), const SizedBox(height: 20), const Text("PROCESSANDO...", style: TextStyle(fontWeight: FontWeight.bold))])
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: SizedBox(width: double.infinity, height: 70, child: ElevatedButton.icon(onPressed: _capturarFoto, icon: const Icon(Icons.camera_alt, size: 30, color: Colors.white), label: const Text("TIRAR FOTO", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)), style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[900], shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))))),
            ),
        ],
      ),
    );
  }
}