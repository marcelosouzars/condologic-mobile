// ==========================================>>> api_service.dart (MOBILE)
import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:http/http.dart' as http;
import '../database_helper.dart';

class ApiService {
  final String baseUrl = "https://condologic-backend.onrender.com";
  final DatabaseHelper dbHelper = DatabaseHelper();

  Future<List<dynamic>> getCondominiosUsuario(int usuarioId, String nivel) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/admin/condominios?usuario_id=$usuarioId&nivel=$nivel')
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<List<dynamic>> getUnidadesLocais() async {
    return await dbHelper.getUnidadesCache();
  }

  Future<bool> baixarCargaDoServidor(int tenantId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/dashboard/unidades?tenant_id=$tenantId')
      ).timeout(const Duration(seconds: 15));
      
      if (response.statusCode == 200) {
        final List<dynamic> unidades = jsonDecode(response.body);
        await dbHelper.salvarUnidadesCache(unidades);
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  // 3. ENVIO EM LOTE (Fundo de tela)
  Future<int> sincronizarPendenciasOffline(int tenantId) async {
    final pendencias = await dbHelper.buscarPendentes();
    if (pendencias.isEmpty) return 0; 

    int enviosComSucesso = 0;
    for (var p in pendencias) {
      try {
        File foto = File(p['caminho_foto']);
        if (!await foto.exists()) {
          await dbHelper.marcarComoEnviado(p['id']); 
          continue;
        }

        final bytes = await foto.readAsBytes();
        String base64Image = base64Encode(bytes);

        // MUDANÇA AQUI: Enviando direto para o salvar com o contexto offline
        final response = await http.post(
          Uri.parse('$baseUrl/api/leitura/salvar'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'image': base64Image,
            'medidor_id': p['medidor_id'],
            'tenant_id': tenantId,
            'leitura_anterior': p['leitura_anterior'] ?? "0",
            'valor_lido': p['valor_lido'],
            'origem_dado': p['origem_dado'] ?? 'MANUAL_OFFLINE',
            'valor_ia': p['valor_ia'] ?? 0.0,
            'troca_relogio': p['troca_relogio'] == 1
          }),
        ).timeout(const Duration(seconds: 15)); 

        if (response.statusCode == 200) {
          await dbHelper.marcarComoEnviado(p['id']);
          enviosComSucesso++;
        }
      } catch (e) {
        print("Aguardando melhor sinal para o ID ${p['id']}");
      }
    }
    return enviosComSucesso;
  }
}