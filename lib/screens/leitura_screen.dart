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
      setState(() => _imageFile = File(path));
      _processarIA(path);
    }
  }

  // ETAPA 1: APENAS LÊ O NÚMERO COM A IA
  Future<void> _processarIA(String path) async {
    setState(() => _isProcessing = true);
    try {
      final bytes = await File(path).readAsBytes();
      img.Image? originalImage = img.decodeImage(bytes);
      if (originalImage == null) throw Exception("Falha ao decodificar imagem");

      img.Image resizedImage = img.copyResize(originalImage, width: 800);
      String base64Image = base64Encode(img.encodeJpg(resizedImage, quality: 80));
      
      Map envio = {
        'image': base64Image,
        'medidor_id': widget.medidor['id'],
        'apenas_ler': true // AVISA O BACKEND PARA NÃO SALVAR AINDA
      };

      try {
        final response = await http.post(
          Uri.parse('$_baseUrl/api/leitura/processar-ia'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(envio),
        ).timeout(const Duration(seconds: 40));

        if (response.statusCode == 200) {
          var data = jsonDecode(response.body);
          double valorIA = double.tryParse(data['leitura'].toString()) ?? 0.0;
          if (mounted) _mostrarDialogoConfirmacao(valorIA, base64Image, path);
        } else {
          _mostrarErro("Erro na IA: Código ${response.statusCode}");
        }
      } on SocketException catch (e) {
        _mostrarErro("Sem internet. Guardando para ler e salvar depois...");
        await Future.delayed(const Duration(seconds: 2));
        await _guardarOffline(base64Image, path, 0.0);
      } on TimeoutException catch (_) {
        _mostrarErro("Sinal fraco. Guardando para ler e salvar depois...");
        await Future.delayed(const Duration(seconds: 2));
        await _guardarOffline(base64Image, path, 0.0);
      } catch (e) {
        _mostrarErro("Erro de rede: $e");
      }
    } catch (e) {
      _mostrarErro("Erro interno: $e");
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  // ETAPA 2: A JANELA INTERATIVA (CONFIRMAR, EDITAR OU REPETIR)
  void _mostrarDialogoConfirmacao(double valorIA, String base64Image, String path) {
    int casasDecimais = widget.medidor['digitos_vermelhos'] ?? 3;
    TextEditingController controller = TextEditingController(text: valorIA.toStringAsFixed(casasDecimais).replaceAll('.', ','));

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        bool isSaving = false;
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text("Confirme a Leitura", textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text("Você pode digitar para corrigir:"),
                  const SizedBox(height: 15),
                  TextField(
                    controller: controller,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blue),
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      suffixText: "m³"
                    ),
                  ),
                  const SizedBox(height: 15),
                  if (isSaving) const CircularProgressIndicator()
                ],
              ),
              actionsAlignment: MainAxisAlignment.center,
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () {
                    Navigator.pop(context); // Fecha janela
                    _capturarFoto(); // Tira outra foto
                  },
                  child: const Text("REPETIR FOTO", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                ),
                ElevatedButton(
                  onPressed: isSaving ? null : () async {
                    setStateDialog(() => isSaving = true);
                    String valText = controller.text.replaceAll(',', '.');
                    double valorFinal = double.tryParse(valText) ?? valorIA;
                    
                    bool sucesso = await _salvarDefinitivo(valorFinal, base64Image, path);
                    if (sucesso && mounted) {
                      Navigator.pop(context); // Fecha janela
                      Navigator.pop(context, true); // Volta pra lista (destrava a tela)
                    } else {
                      setStateDialog(() => isSaving = false);
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10)),
                  child: const Text("SALVAR LEITURA", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                )
              ],
            );
          }
        );
      }
    );
  }

  // ETAPA 3: ROTA DE SALVAMENTO NO BANCO
  Future<bool> _salvarDefinitivo(double valorFinal, String base64Image, String path) async {
    Map envio = {
      'valor_lido': valorFinal,
      'image': base64Image,
      'medidor_id': widget.medidor['id'],
      'tenant_id': widget.unidade['tenant_id'],
      'leitura_anterior': widget.medidor['leitura_anterior']
    };

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/leitura/salvar'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(envio),
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Leitura salva com sucesso!"), backgroundColor: Colors.green));
        return true;
      } else {
        _mostrarErro("Falha ao salvar no banco.");
        return false;
      }
    } on SocketException catch (_) {
      _mostrarErro("Ficou Offline. Guardando o valor digitado na fila...");
      await Future.delayed(const Duration(seconds: 2));
      await _guardarOffline(base64Image, path, valorFinal); // Salva o valor confirmado!
      return true;
    } catch (e) {
      _mostrarErro("Erro de rede ao salvar.");
      return false;
    }
  }

  Future<void> _guardarOffline(String base64, String path, double valorManual) async {
     await DatabaseHelper().salvarLeituraOffline(
        unidadeId: widget.unidade['unidade_id'] ?? 0, 
        medidorId: widget.medidor['id'], 
        valor: valorManual, // Agora salva o valor real
        fotoPath: path,
        leituraAnterior: widget.medidor['leitura_anterior'].toString(),
        tenantId: widget.unidade['tenant_id']
      );
     _mostrarAvisoOffline();
  }

  void _mostrarAvisoOffline() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Row(children: [Icon(Icons.wifi_off, color: Colors.orange[800]), const SizedBox(width: 10), const Text("Fila de Envio")]),
        content: const Text("Salvo no celular! Será enviado automaticamente quando recuperar a internet."),
        actions: [ElevatedButton(onPressed: () { Navigator.pop(context); Navigator.pop(context, true); }, style: ElevatedButton.styleFrom(backgroundColor: Colors.orange[800]), child: const Text("OK", style: TextStyle(color: Colors.white)))]
      ),
    );
  }

  void _mostrarErro(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg, style: const TextStyle(fontWeight: FontWeight.bold)), backgroundColor: Colors.red, duration: const Duration(seconds: 4)));
  }

  @override
  Widget build(BuildContext context) {
    String leituraAnteriorFormatada = widget.medidor['leitura_anterior'].toString().replaceAll('.', ',');
    return Scaffold(
      backgroundColor: Colors.blue[50],
      appBar: AppBar(title: Text("Unidade ${widget.unidade['identificacao']}", style: const TextStyle(color: Colors.white)), backgroundColor: Colors.blue[900], iconTheme: const IconThemeData(color: Colors.white)),
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
            Column(children: [CircularProgressIndicator(color: Colors.blue[900]), const SizedBox(height: 20), const Text("EXTRAINDO LEITURA...", style: TextStyle(fontWeight: FontWeight.bold))])
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