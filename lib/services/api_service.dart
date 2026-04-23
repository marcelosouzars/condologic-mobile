import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../database_helper.dart';

class ApiService {
  final String baseUrl = "https://condologic-backend.onrender.com";
  final DatabaseHelper dbHelper = DatabaseHelper();

  // 1. LEITURA INSTANTÂNEA LOCAL (Sem internet - Não trava mais o app)
  Future<List<dynamic>> getUnidadesLocais() async {
    return await dbHelper.getUnidadesCache();
  }

  // 2. DOWNLOAD DA CARGA DO SERVIDOR (Chamado no botão de Sincronizar)
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

        final response = await http.post(
          Uri.parse('$baseUrl/api/leitura/processar-ia'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'image': base64Image,
            'medidor_id': p['medidor_id'],
            'tenant_id': tenantId,
            'leitura_anterior': p['leitura_anterior'] ?? "0"
          }),
        ).timeout(const Duration(seconds: 15)); // Diminuído o tempo de espera

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