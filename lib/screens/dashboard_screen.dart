import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'leitura_screen.dart';
import 'login_screen.dart';
import 'selecao_condominio_screen.dart';
import '../services/api_service.dart';

class DashboardScreen extends StatefulWidget {
  final Map user;
  const DashboardScreen({super.key, required this.user});
  
  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<dynamic> _todasUnidades = [];
  List<String> _blocos = [];
  
  bool _condominioSelecionado = false; 
  String? _blocoSelecionado;
  String? _andarSelecionado;          
  String? _unidadeSelecionada;        

  bool isLoading = true;
  String baseUrl = "https://condologic-backend.onrender.com";
  Timer? _syncTimer;
  late StreamSubscription<List<ConnectivityResult>> _subscription;

  @override
  void initState() {
    super.initState();
    _carregarDados();
    
    // Timer para forçar sync a cada 60s
    _syncTimer = Timer.periodic(const Duration(seconds: 60), (_) => _sincronizarAutomaticamente());
    
    // AUTO-SYNC: Escuta a volta da internet em tempo real
    _subscription = Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) {
      if (results.isNotEmpty && !results.contains(ConnectivityResult.none)) {
        _sincronizarAutomaticamente();
      }
    });
  }

  @override
  void dispose() {
    _syncTimer?.cancel(); 
    _subscription.cancel();
    super.dispose();
  }

  // ==========================================
  // FUNÇÃO DE LOGOUT SEGURO
  // ==========================================
  Future<void> _fazerLogout() async {
    final listaPendentes = await ApiService().dbHelper.buscarPendentes();
    int pendentes = listaPendentes.length;
    
    if (pendentes > 0) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(children: [Icon(Icons.warning, color: Colors.red), SizedBox(width: 10), Text("Atenção!")]),
          content: Text("Você tem $pendentes foto(s) na fila aguardando internet. Aguarde o envio automático antes de sair para não perder os dados."),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("OK", style: TextStyle(fontWeight: FontWeight.bold)))
          ],
        )
      );
    } else {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      if (mounted) {
        Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => LoginScreen()), (Route<dynamic> route) => false);
      }
    }
  }

  Future<void> _carregarDados({bool checarProximo = false}) async {
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

        if (checarProximo && _unidadeSelecionada != null) {
          _verificarConclusaoUnidade();
        }
      }
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Modo Offline ativado.")));
    }
  }

  Future<void> _sincronizarAutomaticamente() async {
    try {
      int quantidadeEnviada = await ApiService().sincronizarPendenciasOffline(widget.user['tenant_id']);
      if (quantidadeEnviada > 0 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("🔄 Auto-Sync: $quantidadeEnviada foto(s) enviada(s)!"), backgroundColor: Colors.green)
        );
        _carregarDados(); 
      }
    } catch (e) {}
  }

  void _verificarConclusaoUnidade() {
    final relogiosDoApto = _todasUnidades.where((u) => 
      u['bloco_nome'] == _blocoSelecionado && 
      (u['andar'] ?? 'Térreo') == _andarSelecionado &&
      u['identificacao'].toString() == _unidadeSelecionada
    ).toList();

    bool todosLidos = relogiosDoApto.isNotEmpty && relogiosDoApto.every((r) => r['valor_lido'] != null || r['status_cor'] == 'amarelo');

    if (todosLidos) {
      final todasAsUnidadesDoAndar = _todasUnidades.where((u) => u['bloco_nome'] == _blocoSelecionado && (u['andar'] ?? 'Térreo') == _andarSelecionado).toList();
      final aptosUnicos = todasAsUnidadesDoAndar.map((u) => u['identificacao'].toString()).toSet().toList();
      aptosUnicos.sort((a, b) => a.compareTo(b)); 

      int indexAtual = aptosUnicos.indexOf(_unidadeSelecionada!);

      if (indexAtual >= 0 && indexAtual < aptosUnicos.length - 1) {
        String proximoApto = aptosUnicos[indexAtual + 1];
        _mostrarDialogoProximaUnidade(proximoApto);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Andar finalizado!"), backgroundColor: Colors.blue));
        setState(() => _unidadeSelecionada = null);
      }
    }
  }

  void _mostrarDialogoProximaUnidade(String proximoApto) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Column(children: [
            Icon(Icons.check_circle, color: Colors.green, size: 60),
            SizedBox(height: 10),
            Text("Concluído!", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
        ]),
        content: Text("Deseja ir para o Apto $proximoApto?"),
        actions: [
          TextButton(onPressed: () { Navigator.pop(ctx); setState(() => _unidadeSelecionada = null); }, child: const Text("LISTA")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[900]),
            onPressed: () { 
              Navigator.pop(ctx); 
              Future.delayed(const Duration(milliseconds: 100), () {
                if(mounted) setState(() => _unidadeSelecionada = proximoApto); 
              });
            },
            child: const Text("PRÓXIMO"),
          )
        ]
      )
    );
  }

  void _voltarNivel() {
    setState(() {
      if (_unidadeSelecionada != null) _unidadeSelecionada = null; 
      else if (_andarSelecionado != null) _andarSelecionado = null; 
      else if (_blocoSelecionado != null) _blocoSelecionado = null; 
      else if (_condominioSelecionado) _condominioSelecionado = false; 
    });
  }

  String _formatarAndar(String andarRaw) {
    String limpo = andarRaw.trim();
    if (limpo.toLowerCase().contains('térreo') || limpo.toLowerCase().contains('terreo')) return 'Térreo';
    int? numero = int.tryParse(limpo.replaceAll(RegExp(r'[^0-9]'), ''));
    if (numero != null) return "${numero}º Andar";
    return limpo.toUpperCase();
  }

  Widget _buildListaCondominios() {
    String nomeCondominio = "CONDOMÍNIO";
    if (_todasUnidades.isNotEmpty && _todasUnidades.first['condominio_nome'] != null) {
      nomeCondominio = _todasUnidades.first['condominio_nome'].toString().toUpperCase();
    }

    return ListView(
      padding: const EdgeInsets.all(10),
      children: [
        Card(
          color: Colors.white, elevation: 4, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          child: ListTile(
            contentPadding: const EdgeInsets.all(20),
            leading: Icon(Icons.location_city, color: Colors.blue[900], size: 45),
            title: Text(nomeCondominio, style: TextStyle(color: Colors.blue[900], fontWeight: FontWeight.bold, fontSize: 18)),
            subtitle: const Text("Toque para ver os blocos"),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => setState(() => _condominioSelecionado = true),
          ),
        )
      ],
    );
  }

  Widget _buildListaBlocos() {
    return ListView.builder(
      itemCount: _blocos.length,
      itemBuilder: (ctx, i) {
        return Card(
          color: Colors.white, margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          child: ListTile(
            leading: Icon(Icons.apartment, color: Colors.blue[900]),
            title: Text(_blocos[i], style: const TextStyle(fontWeight: FontWeight.bold)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => setState(() => _blocoSelecionado = _blocos[i]),
          ),
        );
      },
    );
  }

  Widget _buildListaAndares() {
    final unidadesDoBloco = _todasUnidades.where((u) => u['bloco_nome'] == _blocoSelecionado).toList();
    final andaresUnicos = unidadesDoBloco.map((u) => u['andar']?.toString() ?? 'Térreo').toSet().toList();
    
    // CORRIGIDO: Erro de digitação no extrairNum
    andaresUnicos.sort((a, b) {
      int extrairNum(String s) => int.tryParse(s.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
      return extrairNum(a).compareTo(extrairNum(b));
    });

    return ListView.builder(
      itemCount: andaresUnicos.length,
      itemBuilder: (ctx, i) {
        final andar = andaresUnicos[i];
        final qtd = unidadesDoBloco.where((u) => (u['andar'] ?? 'Térreo') == andar).length;
        return Card(
          color: Colors.white, margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          child: ListTile(
            leading: Icon(Icons.layers, color: Colors.orange[800]),
            title: Text(_formatarAndar(andar), style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text("$qtd medidores"),
            onTap: () => setState(() => _andarSelecionado = andar),
          ),
        );
      },
    );
  }

  Widget _buildListaApartamentos() {
    final relogiosDoAndar = _todasUnidades.where((u) => 
      u['bloco_nome'] == _blocoSelecionado && (u['andar'] ?? 'Térreo') == _andarSelecionado
    ).toList();
    final aptosUnicos = relogiosDoAndar.map((u) => u['identificacao'].toString()).toSet().toList();
    aptosUnicos.sort((a, b) => a.compareTo(b));

    return ListView.builder(
      itemCount: aptosUnicos.length,
      itemBuilder: (ctx, i) {
        final apto = aptosUnicos[i];
        final relogiosDesteApto = relogiosDoAndar.where((r) => r['identificacao'].toString() == apto).toList();
        final qtdLidos = relogiosDesteApto.where((r) => r['valor_lido'] != null || r['status_cor'] == 'amarelo').length;
        final total = relogiosDesteApto.length;
        Color corStatus = qtdLidos == total ? Colors.green : (qtdLidos > 0 ? Colors.amber : Colors.red);

        return Card(
          color: Colors.white, margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          child: ListTile(
            leading: Icon(Icons.meeting_room, color: corStatus),
            title: Text("Apto $apto", style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text("$qtdLidos de $total concluídos"),
            onTap: () => setState(() => _unidadeSelecionada = apto),
          ),
        );
      },
    );
  }

  Widget _buildListaRelogiosDoApto() {
    final relogios = _todasUnidades.where((u) => 
      u['bloco_nome'] == _blocoSelecionado && (u['andar'] ?? 'Térreo') == _andarSelecionado && u['identificacao'].toString() == _unidadeSelecionada
    ).toList();

    return ListView.builder(
      itemCount: relogios.length,
      itemBuilder: (ctx, i) {
        final item = relogios[i];
        Color cor = (item['valor_lido'] != null || item['status_cor'] == 'verde') ? Colors.green : (item['status_cor'] == 'amarelo' ? Colors.amber : Colors.red);
        String valor = item['valor_lido'] != null ? "Valor: ${item['valor_lido'].toString().replaceAll('.', ',')}" : "Pendente";

        return Card(
          color: Colors.white, margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          child: ListTile(
            leading: Icon(Icons.speed, color: cor),
            title: Text(item['tipo_medidor'].toString().toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(valor),
            trailing: const Icon(Icons.camera_alt),
            onTap: () {
              Map medidorData = {
                'id': item['medidor_id'],
                'tipo_medidor': item['tipo_medidor'],
                'leitura_anterior': item['leitura_anterior'] ?? '0.0',
                'digitos_vermelhos': item['digitos_vermelhos'] ?? 3
              };
              item['tenant_id'] = widget.user['tenant_id'];
              Navigator.push(context, MaterialPageRoute(builder: (context) => LeituraScreen(unidade: item, medidor: medidorData))).then((_) {
                 if(mounted) _carregarDados(checarProximo: true);
              });
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    String titulo = "CondoLogic";
    if (_unidadeSelecionada != null) titulo = "Apto $_unidadeSelecionada";
    else if (_andarSelecionado != null) titulo = "$_blocoSelecionado - ${_formatarAndar(_andarSelecionado!)}";
    else if (_blocoSelecionado != null) titulo = _blocoSelecionado!;
    else if (_condominioSelecionado) titulo = "Blocos";

    return Scaffold(
      backgroundColor: Colors.blue[50],
      appBar: AppBar(
        title: Text(titulo, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.blue[900],
        iconTheme: const IconThemeData(color: Colors.white),
        leading: (_condominioSelecionado) ? IconButton(icon: const Icon(Icons.arrow_back), onPressed: _voltarNivel) : null,
        actions: [
          IconButton(icon: const Icon(Icons.exit_to_app, color: Colors.redAccent), onPressed: _fazerLogout)
        ],
      ),
      body: isLoading 
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: () => _carregarDados(),
            child: _unidadeSelecionada != null ? _buildListaRelogiosDoApto() : (_andarSelecionado != null ? _buildListaApartamentos() : (_blocoSelecionado != null ? _buildListaAndares() : (_condominioSelecionado ? _buildListaBlocos() : _buildListaCondominios())))
          ),
    );
  }
}