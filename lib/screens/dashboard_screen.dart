import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'leitura_screen.dart';
import '../services/api_service.dart';

class DashboardScreen extends StatefulWidget {
  final Map user;
  DashboardScreen({required this.user});
  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<dynamic> unidades = [];
  bool isLoading = true;
  String baseUrl = "https://condologic-backend.onrender.com";

  @override
  void initState() {
    super.initState();
    _carregarDados();
  }

  Future<void> _carregarDados() async {
    setState(() => isLoading = true);
    try {
      final unidadesNuvemOuCache = await ApiService().getUnidades(widget.user['tenant_id']);
      setState(() {
        unidades = unidadesNuvemOuCache;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Erro crítico ao carregar as unidades.")));
    }
  }

  void _abrirModalAlterarSenha() {
    final senhaAtualCtrl = TextEditingController();
    final novaSenhaCtrl = TextEditingController();
    final confirmaSenhaCtrl = TextEditingController();
    bool isSaving = false;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateModal) {
          return AlertDialog(
            backgroundColor: const Color(0xFF1E1E1E),
            title: const Text("Alterar Minha Senha", style: TextStyle(color: Colors.white)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: senhaAtualCtrl, obscureText: true, style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(labelText: "Senha Atual (Ex: 123456)", labelStyle: TextStyle(color: Colors.grey), enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.blueAccent)))
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: novaSenhaCtrl, obscureText: true, style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(labelText: "Nova Senha", labelStyle: TextStyle(color: Colors.grey), enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.blueAccent)))
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: confirmaSenhaCtrl, obscureText: true, style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(labelText: "Confirmar Nova Senha", labelStyle: TextStyle(color: Colors.grey), enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.blueAccent)))
                  ),
                ]
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCELAR", style: TextStyle(color: Colors.grey))),
              ElevatedButton(
                onPressed: isSaving ? null : () async {
                  if (senhaAtualCtrl.text.isEmpty || novaSenhaCtrl.text.isEmpty || confirmaSenhaCtrl.text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Preencha todos os campos!", style: TextStyle(color: Colors.white)), backgroundColor: Colors.red));
                    return;
                  }
                  if (novaSenhaCtrl.text != confirmaSenhaCtrl.text) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("A confirmação não bate com a nova senha!", style: TextStyle(color: Colors.white)), backgroundColor: Colors.red));
                    return;
                  }

                  setStateModal(() => isSaving = true);
                  try {
                    final response = await http.post(
                      Uri.parse('$baseUrl/api/auth/alterar-senha'),
                      headers: {'Content-Type': 'application/json'},
                      body: jsonEncode({'id': widget.user['id'], 'senha_atual': senhaAtualCtrl.text, 'nova_senha': novaSenhaCtrl.text}),
                    ).timeout(const Duration(seconds: 15));
                    if (response.statusCode == 200) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Senha atualizada com sucesso!", style: TextStyle(color: Colors.white)), backgroundColor: Colors.green));
                    } else {
                      final erro = jsonDecode(response.body);
                      throw Exception(erro['error'] ?? "Erro ao alterar");
                    }
                  } catch (e) {
                    setStateModal(() => isSaving = false);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''), style: const TextStyle(color: Colors.white)), backgroundColor: Colors.red));
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
                child: isSaving ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text("SALVAR", style: TextStyle(color: Colors.white)),
              )
            ]
          );
        }
      )
    );
  }

  // ==============================================================
  // O NOVO CÉREBRO DA SINCRONIZAÇÃO EM AÇÃO
  // ==============================================================
  Future<void> _sincronizarPendencias() async {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Sincronizando leituras com a nuvem...", style: TextStyle(color: Colors.white))));
    
    try {
      // Executa o envio
      int quantidadeEnviada = await ApiService().sincronizarPendenciasOffline(widget.user['tenant_id']);
      
      if (quantidadeEnviada > 0) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("$quantidadeEnviada foto(s) enviada(s) e processada(s) com sucesso!", style: const TextStyle(color: Colors.white)), backgroundColor: Colors.green));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("O sistema está limpo. Nenhuma leitura offline pendente.", style: TextStyle(color: Colors.white)), backgroundColor: Colors.blueAccent));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro ao sincronizar: Tente novamente quando a internet melhorar.", style: const TextStyle(color: Colors.white)), backgroundColor: Colors.red));
    }
    
    // Atualiza a tela com as cores recarregadas
    await _carregarDados();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text("Unidades para Leitura", style: TextStyle(color: Colors.white)), 
        backgroundColor: Colors.blueAccent,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'senha') _abrirModalAlterarSenha();
              if (value == 'sync') _sincronizarPendencias();
            },
            itemBuilder: (BuildContext context) {
              return [
                const PopupMenuItem<String>(value: 'sync', child: Row(children: [Icon(Icons.sync, color: Colors.blueAccent), SizedBox(width: 10), Text("Sincronizar Dados")])),
                const PopupMenuItem<String>(value: 'senha', child: Row(children: [Icon(Icons.lock, color: Colors.blueAccent), SizedBox(width: 10), Text("Alterar Senha")])),
              ];
            },
          )
        ],
      ),
      body: isLoading 
        ? const Center(child: CircularProgressIndicator(color: Colors.blueAccent))
        : unidades.isEmpty
          ? const Center(child: Text("Nenhuma unidade encontrada.", style: TextStyle(color: Colors.grey)))
          : ListView.builder(
            itemCount: unidades.length,
            itemBuilder: (context, index) {
              final item = unidades[index];
              return Card(
                color: const Color(0xFF1E1E1E),
                margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                child: ListTile(
                  leading: const Icon(Icons.home, color: Colors.blueAccent),
                  title: Text("Unidade: ${item['identificacao']}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  subtitle: Text("Bloco: ${item['bloco_nome']}", style: const TextStyle(color: Colors.grey)),
                  trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                  onTap: () {
                    Map medidorData = {
                      'id': item['medidor_id'],
                      'tipo_medidor': item['tipo_medidor'] ?? 'Água',
                      'leitura_anterior': item['leitura_anterior'] ?? '0.0'
                    };
                    Navigator.push(
                      context, 
                      MaterialPageRoute(
                        builder: (context) => LeituraScreen(unidade: item, medidor: medidorData)
                      )
                    ).then((_) => _carregarDados());
                  },
                ),
              );
            },
          ),
    );
  }
}