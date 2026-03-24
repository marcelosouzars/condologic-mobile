import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'leitura_screen.dart';
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

  @override
  void initState() {
    super.initState();
    _carregarDados();
    _syncTimer = Timer.periodic(const Duration(seconds: 60), (_) => _sincronizarAutomaticamente());
  }

  @override
  void dispose() {
    _syncTimer?.cancel(); 
    super.dispose();
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
    } catch (e) {
      // Falha silenciosa
    }
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
        title: const Column(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 60),
            SizedBox(height: 10),
            Text("Unidade Concluída!", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
          ]
        ),
        content: Text("Todas as medições deste apartamento foram feitas.\n\nDeseja ir direto para o Apto $proximoApto?", textAlign: TextAlign.center, style: const TextStyle(fontSize: 16)),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() => _unidadeSelecionada = null); 
            }, 
            child: const Text("VOLTAR PARA LISTA", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold))
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[900], padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10)),
            onPressed: () {
              Navigator.pop(ctx);
              setState(() => _unidadeSelecionada = proximoApto); 
            },
            child: const Text("IR PARA O PRÓXIMO", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          )
        ]
      )
    );
  }

  void _voltarNivel() {
    setState(() {
      if (_unidadeSelecionada != null) {
        _unidadeSelecionada = null; 
      } else if (_andarSelecionado != null) {
        _andarSelecionado = null; 
      } else if (_blocoSelecionado != null) {
        _blocoSelecionado = null; 
      } else if (_condominioSelecionado) {
        _condominioSelecionado = false; 
      }
    });
  }

  String _formatarAndar(String andarRaw) {
    String limpo = andarRaw.trim();

    if (limpo.toLowerCase() == 'térreo' || limpo.toLowerCase() == 'terreo') {
      return 'Térreo';
    }
    int? numero = int.tryParse(limpo);
    if (numero != null) {
      return "${numero}º Andar";
    }
    return limpo.toUpperCase();
  }

  Widget _buildListaCondominios() {
    String nomeCondominio = "CONDOMÍNIO VINCULADO";

    if (widget.user['tenant_nome'] != null) {
      nomeCondominio = widget.user['tenant_nome'].toString().toUpperCase();
    } else if (_todasUnidades.isNotEmpty && _todasUnidades.first['condominio_nome'] != null) {
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
            title: Text(nomeCondominio, style: TextStyle(color: Colors.blue[900], fontWeight: FontWeight.bold, fontSize: 20)),
            subtitle: const Text("Toque para acessar os blocos e torres", style: TextStyle(color: Colors.grey)),
            trailing: const Icon(Icons.chevron_right, color: Colors.grey, size: 30),
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
            leading: Icon(Icons.apartment, color: Colors.blue[900], size: 30),
            title: Text(_blocos[i], style: TextStyle(color: Colors.blue[900], fontWeight: FontWeight.bold, fontSize: 18)),
            trailing: const Icon(Icons.chevron_right, color: Colors.grey),
            onTap: () => setState(() => _blocoSelecionado = _blocos[i]),
          ),
        );
      },
    );
  }

  Widget _buildListaAndares() {
    final unidadesDoBloco = _todasUnidades.where((u) => u['bloco_nome'] == _blocoSelecionado).toList();
    final andaresUnicos = unidadesDoBloco.map((u) => u['andar']?.toString() ?? 'Térreo').toSet().toList();
    
    andaresUnicos.sort((a, b) {
      int extrairNumero(String andar) {
        String limpo = andar.toLowerCase();
        if (limpo.contains('térreo') || limpo.contains('terreo')) return 0; 
        final regex = RegExp(r'\d+');
        final match = regex.firstMatch(andar);
        return match != null ? int.parse(match.group(0)!) : 999; 
      }
      return extrairNumero(a).compareTo(extrairNumero(b));
    });

    return ListView.builder(
      itemCount: andaresUnicos.length,
      itemBuilder: (ctx, i) {
        final andar = andaresUnicos[i];
        final qtd = unidadesDoBloco.where((u) => (u['andar'] ?? 'Térreo') == andar).length;

        final andarExibicao = _formatarAndar(andar);

        return Card(
          color: Colors.white, margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          child: ListTile(
            leading: Icon(Icons.layers, color: Colors.orange[800], size: 30),
            title: Text(andarExibicao, style: TextStyle(color: Colors.blue[900], fontWeight: FontWeight.bold, fontSize: 16)),
            subtitle: Text("$qtd medidores neste piso", style: const TextStyle(color: Colors.grey)),
            trailing: const Icon(Icons.chevron_right, color: Colors.grey),
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

        Color corStatus = Colors.red;
        
        if (qtdLidos == total) corStatus = Colors.green;
        else if (qtdLidos > 0) corStatus = Colors.amber;

        return Card(
          color: Colors.white, margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          child: ListTile(
            leading: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(color: corStatus.withOpacity(0.2), shape: BoxShape.circle),
              child: Icon(Icons.meeting_room, color: corStatus),
            ),
            title: Text("Apto $apto", style: TextStyle(color: Colors.blue[900], fontWeight: FontWeight.bold, fontSize: 18)),
            subtitle: Text("$qtdLidos de $total relógios lidos", style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
            trailing: const Icon(Icons.chevron_right, color: Colors.grey),
            onTap: () => setState(() => _unidadeSelecionada = apto),
          ),
        );
      },
    );
  }

  Widget _buildListaRelogiosDoApto() {
    final relogios = _todasUnidades.where((u) => 
      u['bloco_nome'] == _blocoSelecionado && 
      (u['andar'] ?? 'Térreo') == _andarSelecionado &&
      u['identificacao'].toString() == _unidadeSelecionada
    ).toList();

    return ListView.builder(
      itemCount: relogios.length,
      itemBuilder: (ctx, i) {
        final item = relogios[i];
        
        Color corBolinha = Colors.red;
        if (item['status_cor'] == 'verde' || item['valor_lido'] != null) corBolinha = Colors.green;
        if (item['status_cor'] == 'amarelo') corBolinha = Colors.amber;

        String tipo = item['tipo_medidor']?.toString().toUpperCase() ?? 'MEDIDOR';
        
        IconData icone = Icons.speed;
        if (tipo.contains('FRIO') || tipo.contains('FRIA')) icone = Icons.water_drop;
        if (tipo.contains('QUENTE')) icone = Icons.local_fire_department;
        if (tipo.contains('GÁS') || tipo.contains('GAS')) icone = Icons.propane;

        // =========================================================
        // MÁGICA DINÂMICA: Exibir as casas decimais corretas
        // =========================================================
        int casasDecimais = item['digitos_vermelhos'] ?? 3; 

        String valorExibicao = 'Aguardando foto';
        if (item['valor_lido'] != null) {
          double? valParsed = double.tryParse(item['valor_lido'].toString());
          if (valParsed != null) {
            valorExibicao = 'Valor: ${valParsed.toStringAsFixed(casasDecimais).replaceAll('.', ',')}';
          } else {
            valorExibicao = 'Valor: ${item['valor_lido'].toString().replaceAll('.', ',')}';
          }
        }

        return Card(
          color: Colors.white, margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          child: ListTile(
            leading: Icon(icone, color: corBolinha, size: 35),
            title: Text(tipo, style: TextStyle(color: Colors.blue[900], fontWeight: FontWeight.bold, fontSize: 16)),
            subtitle: Text(valorExibicao, style: const TextStyle(color: Colors.grey)),
            trailing: Icon(Icons.camera_alt, color: Colors.blue[900]),
            onTap: () {
              Map medidorData = {
                'id': item['medidor_id'],
                'tipo_medidor': tipo,
                'leitura_anterior': item['leitura_anterior'] ?? '0.0',
                'digitos_vermelhos': casasDecimais 
              };

              item['tenant_id'] = widget.user['tenant_id'];

              Navigator.push(
                context, 
                MaterialPageRoute(builder: (context) => LeituraScreen(unidade: item, medidor: medidorData))
              ).then((_) => _carregarDados(checarProximo: true));
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    String tituloApp = "CondoLogic";

    if (_condominioSelecionado) tituloApp = "Blocos / Torres";
    if (_blocoSelecionado != null) tituloApp = _blocoSelecionado!;
    if (_andarSelecionado != null) tituloApp = "$_blocoSelecionado - ${_formatarAndar(_andarSelecionado!)}";
    if (_unidadeSelecionada != null) tituloApp = "Apto $_unidadeSelecionada";

    bool mostrarBotaoVoltar = _condominioSelecionado || _blocoSelecionado != null;

    return Scaffold(
      backgroundColor: Colors.blue[50],
      appBar: AppBar(
        title: Text(tituloApp, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.blue[900],
        iconTheme: const IconThemeData(color: Colors.white),
        leading: mostrarBotaoVoltar ? IconButton(icon: const Icon(Icons.arrow_back), onPressed: _voltarNivel) : null,
      ),
      body: isLoading 
        ? Center(child: CircularProgressIndicator(color: Colors.blue[900]))
        : RefreshIndicator(
            onRefresh: () => _carregarDados(),
            color: Colors.blue[900],
            child: _unidadeSelecionada != null
              ? _buildListaRelogiosDoApto()
              : _andarSelecionado != null
                  ? _buildListaApartamentos()
                : _blocoSelecionado != null
                  ? _buildListaAndares()
                  : _condominioSelecionado
                    ? _buildListaBlocos()
                    : _buildListaCondominios()
          ),
    );
  }
}