import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:async'; 
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
  // Dados do sistema de navegação (Drill-down)
  List<dynamic> _todasUnidades = [];
  List<String> _blocos = [];
  
  // Controle de Níveis
  bool _condominioSelecionado = false; // <--- NOVO NÍVEL 0
  String? _blocoSelecionado;           // Nível 1
  String? _andarSelecionado;           // Nível 2

  bool isLoading = true;
  String baseUrl = "https://condologic-backend.onrender.com";
  Timer? _syncTimer; 

  @override
  void initState() {
    super.initState();
    _carregarDados();
    
    // Inicia a verificação silenciosa a cada 60 segundos
    _syncTimer = Timer.periodic(const Duration(seconds: 60), (_) => _sincronizarAutomaticamente());
  }

  @override
  void dispose() {
    _syncTimer?.cancel(); 
    super.dispose();
  }

  Future<void> _carregarDados() async {
    setState(() => isLoading = true);
    try {
      final dados = await ApiService().getUnidades(widget.user['tenant_id']);
      
      final blocosUnicos = dados.map((u) => u['bloco_nome'].toString()).toSet().toList();
      blocosUnicos.sort();

      if (mounted) {
        setState(() {
          _todasUnidades = dados;
          _blocos = blocosUnicos;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Carregando em modo offline.")));
    }
  }

  // ==============================================================
  // SINCRONIZAÇÃO AUTOMÁTICA
  // ==============================================================
  Future<void> _sincronizarAutomaticamente() async {
    try {
      int quantidadeEnviada = await ApiService().sincronizarPendenciasOffline(widget.user['tenant_id']);
      if (quantidadeEnviada > 0 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("🔄 Auto-Sync: $quantidadeEnviada foto(s) enviada(s) para a nuvem!", style: const TextStyle(color: Colors.white)), 
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          )
        );
        _carregarDados(); 
      }
    } catch (e) {
      print("Auto-sync aguardando internet...");
    }
  }

  // ==============================================================
  // CONTROLE DE VOLTAR (BREADCRUMB)
  // ==============================================================
  void _voltarNivel() {
    setState(() {
      if (_andarSelecionado != null) {
        _andarSelecionado = null; // Volta pro Bloco
      } else if (_blocoSelecionado != null) {
        _blocoSelecionado = null; // Volta pros Condomínios
      } else if (_condominioSelecionado) {
        _condominioSelecionado = false; // Volta pra raiz (Card do Condomínio)
      }
    });
  }

  // ==============================================================
  // CONSTRUTORES DE LISTA (CASCATA)
  // ==============================================================

  // NÍVEL 0: CONDOMÍNIO
  Widget _buildListaCondominios() {
    return ListView(
      padding: const EdgeInsets.all(10),
      children: [
        Card(
          color: Colors.white,
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          child: ListTile(
            contentPadding: const EdgeInsets.all(20),
            leading: Icon(Icons.location_city, color: Colors.blue[900], size: 45),
            title: Text("Condomínio Vinculado", style: TextStyle(color: Colors.blue[900], fontWeight: FontWeight.bold, fontSize: 20)),
            subtitle: const Text("Toque para acessar os blocos e torres", style: TextStyle(color: Colors.grey)),
            trailing: const Icon(Icons.chevron_right, color: Colors.grey, size: 30),
            onTap: () => setState(() => _condominioSelecionado = true),
          ),
        )
      ],
    );
  }

  // NÍVEL 1: BLOCOS
  Widget _buildListaBlocos() {
    if (_blocos.isEmpty) return const Center(child: Text("Nenhuma estrutura encontrada.", style: TextStyle(color: Colors.grey)));
    
    return ListView.builder(
      itemCount: _blocos.length,
      itemBuilder: (ctx, i) {
        final bloco = _blocos[i];
        return Card(
          color: Colors.white,
          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          child: ListTile(
            leading: Icon(Icons.apartment, color: Colors.blue[900], size: 30),
            title: Text(bloco, style: TextStyle(color: Colors.blue[900], fontWeight: FontWeight.bold, fontSize: 18)),
            subtitle: const Text("Toque para ver os andares", style: TextStyle(color: Colors.grey)),
            trailing: const Icon(Icons.chevron_right, color: Colors.grey),
            onTap: () => setState(() => _blocoSelecionado = bloco),
          ),
        );
      },
    );
  }

  // NÍVEL 2: ANDARES
  Widget _buildListaAndares() {
    final unidadesDoBloco = _todasUnidades.where((u) => u['bloco_nome'] == _blocoSelecionado).toList();
    final andaresUnicos = unidadesDoBloco.map((u) => u['andar']?.toString() ?? 'Térreo').toSet().toList();
    
    andaresUnicos.sort();

    return ListView.builder(
      itemCount: andaresUnicos.length,
      itemBuilder: (ctx, i) {
        final andar = andaresUnicos[i];
        final qtd = unidadesDoBloco.where((u) => (u['andar'] ?? 'Térreo') == andar).length;

        return Card(
          color: Colors.white,
          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          child: ListTile(
            leading: Icon(Icons.layers, color: Colors.orange[800], size: 30),
            title: Text(andar, style: TextStyle(color: Colors.blue[900], fontWeight: FontWeight.bold, fontSize: 16)),
            subtitle: Text("$qtd medidores neste piso", style: const TextStyle(color: Colors.grey)),
            trailing: const Icon(Icons.chevron_right, color: Colors.grey),
            onTap: () => setState(() => _andarSelecionado = andar),
          ),
        );
      },
    );
  }

  // NÍVEL 3: UNIDADES
  Widget _buildListaUnidades() {
    final unidadesFinais = _todasUnidades.where((u) => 
      u['bloco_nome'] == _blocoSelecionado && 
      (u['andar'] ?? 'Térreo') == _andarSelecionado
    ).toList();
    
    unidadesFinais.sort((a, b) => a['identificacao'].toString().compareTo(b['identificacao'].toString()));

    return ListView.builder(
      itemCount: unidadesFinais.length,
      itemBuilder: (ctx, i) {
        final item = unidadesFinais[i];
        
        Color corBolinha = Colors.grey.shade400;
        if (item['status_cor'] == 'verde') corBolinha = Colors.green;
        if (item['status_cor'] == 'vermelho') corBolinha = Colors.red;
        if (item['status_cor'] == 'amarelo') corBolinha = Colors.amber;

        return Card(
          color: Colors.white,
          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          child: ListTile(
            leading: Container(
              width: 20, height: 20,
              decoration: BoxDecoration(color: corBolinha, shape: BoxShape.circle, border: Border.all(color: Colors.grey)),
            ),
            title: Text("Apto ${item['identificacao']}", style: TextStyle(color: Colors.blue[900], fontWeight: FontWeight.bold, fontSize: 18)),
            subtitle: Text(item['valor_lido'] != null ? 'Valor lido: ${item['valor_lido']}' : 'Aguardando leitura', style: const TextStyle(color: Colors.grey)),
            trailing: Icon(Icons.camera_alt, color: Colors.blue[900]),
            onTap: () {
              Map medidorData = {
                'id': item['medidor_id'],
                'tipo_medidor': item['tipo_medidor'] ?? 'Água',
                'leitura_anterior': item['leitura_anterior'] ?? '0.0'
              };
              Navigator.push(
                context, 
                MaterialPageRoute(builder: (context) => LeituraScreen(unidade: item, medidor: medidorData))
              ).then((_) => _carregarDados());
            },
          ),
        );
      },
    );
  }

  // ==============================================================
  // MENU DO USUÁRIO
  // ==============================================================
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
            backgroundColor: Colors.white,
            title: Text("Alterar Minha Senha", style: TextStyle(color: Colors.blue[900], fontWeight: FontWeight.bold)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: senhaAtualCtrl, obscureText: true, decoration: const InputDecoration(labelText: "Senha Atual (Ex: 123456)")),
                  const SizedBox(height: 10),
                  TextField(controller: novaSenhaCtrl, obscureText: true, decoration: const InputDecoration(labelText: "Nova Senha")),
                  const SizedBox(height: 10),
                  TextField(controller: confirmaSenhaCtrl, obscureText: true, decoration: const InputDecoration(labelText: "Confirmar Nova Senha")),
                ]
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCELAR", style: TextStyle(color: Colors.grey))),
              ElevatedButton(
                onPressed: isSaving ? null : () async {
                  if (senhaAtualCtrl.text.isEmpty || novaSenhaCtrl.text.isEmpty || confirmaSenhaCtrl.text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Preencha todos os campos!"), backgroundColor: Colors.red));
                    return;
                  }
                  if (novaSenhaCtrl.text != confirmaSenhaCtrl.text) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("A confirmação não bate com a nova senha!"), backgroundColor: Colors.red));
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
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Senha atualizada!"), backgroundColor: Colors.green));
                    } else {
                      throw Exception("Erro ao alterar");
                    }
                  } catch (e) {
                    setStateModal(() => isSaving = false);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Erro de conexão."), backgroundColor: Colors.red));
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[900]),
                child: isSaving ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text("SALVAR", style: TextStyle(color: Colors.white)),
              )
            ]
          );
        }
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    // Lógica do Título da Tela
    String tituloApp = "CondoLogic";
    if (_condominioSelecionado) tituloApp = "Blocos / Torres";
    if (_blocoSelecionado != null) tituloApp = _blocoSelecionado!;
    if (_andarSelecionado != null) tituloApp = "$_blocoSelecionado - $_andarSelecionado";

    // Mostra o botão de voltar somente se saiu da tela inicial (Nível 0)
    bool mostrarBotaoVoltar = _condominioSelecionado || _blocoSelecionado != null;

    return Scaffold(
      backgroundColor: Colors.blue[50],
      appBar: AppBar(
        title: Text(tituloApp, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.blue[900],
        iconTheme: const IconThemeData(color: Colors.white),
        leading: mostrarBotaoVoltar 
          ? IconButton(icon: const Icon(Icons.arrow_back), onPressed: _voltarNivel)
          : null,
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'senha') _abrirModalAlterarSenha();
              if (value == 'forcar_sync') _sincronizarAutomaticamente(); 
            },
            itemBuilder: (BuildContext context) {
              return [
                PopupMenuItem<String>(value: 'forcar_sync', child: Row(children: [Icon(Icons.sync, color: Colors.blue[900]), const SizedBox(width: 10), const Text("Forçar Sincronização")])),
                PopupMenuItem<String>(value: 'senha', child: Row(children: [Icon(Icons.lock, color: Colors.blue[900]), const SizedBox(width: 10), const Text("Alterar Senha")])),
              ];
            },
          )
        ],
      ),
      body: isLoading 
        ? Center(child: CircularProgressIndicator(color: Colors.blue[900]))
        : RefreshIndicator(
            onRefresh: _carregarDados,
            color: Colors.blue[900],
            child: _andarSelecionado != null
              ? _buildListaUnidades()
              : _blocoSelecionado != null
                ? _buildListaAndares()
                : _condominioSelecionado
                  ? _buildListaBlocos()
                  : _buildListaCondominios() // Começa renderizando aqui!
          ),
    );
  }
}