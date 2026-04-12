import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../database_helper.dart';

class ApiService {
  final String baseUrl = "https://condologic-backend.onrender.com";
  final DatabaseHelper dbHelper = DatabaseHelper();

  Future<List<dynamic>> getUnidades(int tenantId) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/api/dashboard/unidades?tenant_id=$tenantId')).timeout(const Duration(seconds: 12));
      if (response.statusCode == 200) {
        final List<dynamic> unidades = jsonDecode(response.body);
        await dbHelper.salvarUnidadesCache(unidades);
        return unidades;
      } else {
        throw Exception("Erro no servidor");
      }
    } catch (e) {
      return await dbHelper.getUnidadesCache();
    }
  }

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
        ).timeout(const Duration(seconds: 20));

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