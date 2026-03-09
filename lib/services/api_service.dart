import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

// ========================================================
// 1. CLASSE DO BANCO DE DADOS LOCAL (OFFLINE)
// ========================================================
class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  Future<Database> _initDB() async {
    String path = join(await getDatabasesPath(), 'condologic_prod_v3.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE unidades (
            medidor_id INTEGER PRIMARY KEY,
            unidade_id INTEGER,
            identificacao TEXT,
            bloco_nome TEXT,
            andar TEXT,  
            status_cor TEXT,
            leitura_anterior REAL,
            media_consumo REAL,
            valor_lido REAL,
            tipo_medidor TEXT 
          )
        ''');

        await db.execute('''
          CREATE TABLE leituras_offline (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            unidade_id INTEGER,
            medidor_id INTEGER,
            valor_lido REAL,
            caminho_foto TEXT,
            data_leitura TEXT,
            enviado INTEGER DEFAULT 0
          )
        ''');
      },
    );
  }

  Future<void> salvarUnidadesCache(List<dynamic> unidades) async {
    final db = await database;
    await db.delete('unidades');
    Batch batch = db.batch();
    for (var u in unidades) {
      double leituraAnt = double.tryParse(u['leitura_anterior'].toString()) ?? 0.0;
      double mediaCons = double.tryParse(u['media_consumo'].toString()) ?? 0.0;
      double? valorLido;
      
      if (u['valor_lido'] != null) {
        valorLido = double.tryParse(u['valor_lido'].toString());
      }

      batch.insert('unidades', {
        'medidor_id': u['medidor_id'],
        'unidade_id': u['unidade_id'],
        'identificacao': u['identificacao'],
        'bloco_nome': u['bloco_nome'],
        'andar': u['andar'] ?? 'Térreo',
        'status_cor': u['status_cor'],
        'leitura_anterior': leituraAnt,
        'media_consumo': mediaCons,
        'valor_lido': valorLido,
        'tipo_medidor': u['tipo_medidor'] ?? 'Medidor'
      });
    }
    await batch.commit(noResult: true);
  }

  Future<List<Map<String, dynamic>>> getUnidadesCache() async {
    final db = await database;
    return await db.query('unidades', orderBy: 'identificacao ASC');
  }

  Future<int> salvarLeituraOffline(int unidadeId, int medidorId, double valor, String fotoPath) async {
    final db = await database;
    int id = await db.insert('leituras_offline', {
      'unidade_id': unidadeId,
      'medidor_id': medidorId,
      'valor_lido': valor,
      'caminho_foto': fotoPath,
      'data_leitura': DateTime.now().toIso8601String(),
      'enviado': 0
    });

    await db.update(
      'unidades', 
      {'status_cor': 'amarelo', 'valor_lido': valor}, 
      where: 'medidor_id = ?', 
      whereArgs: [medidorId]
    );
    return id;
  }

  Future<List<Map<String, dynamic>>> getLeiturasOfflinePendentes() async {
    final db = await database;
    return await db.query('leituras_offline', where: 'enviado = 0');
  }

  Future<void> deletarLeituraOffline(int id) async {
    final db = await database;
    await db.delete('leituras_offline', where: 'id = ?', whereArgs: [id]);
  }
}

// ========================================================
// 2. CLASSE DE COMUNICAÇÃO COM A NUVEM (API)
// ========================================================
class ApiService {
  final String baseUrl = "https://condologic-backend.onrender.com";
  final DatabaseHelper dbHelper = DatabaseHelper();

  Future<List<dynamic>> getUnidades(int tenantId) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/api/dashboard/unidades?tenant_id=$tenantId')).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final List<dynamic> unidades = jsonDecode(response.body);
        await dbHelper.salvarUnidadesCache(unidades);
        return unidades;
      } else {
        throw Exception("Erro no servidor");
      }
    } catch (e) {
      print("Aviso: Carregando unidades do modo Offline devido a falha de rede.");
      return await dbHelper.getUnidadesCache();
    }
  }

  Future<int> sincronizarPendenciasOffline(int tenantId) async {
    final pendencias = await dbHelper.getLeiturasOfflinePendentes();
    if (pendencias.isEmpty) return 0; 

    int enviosComSucesso = 0;
    for (var p in pendencias) {
      try {
        File foto = File(p['caminho_foto']);
        if (!await foto.exists()) {
          await dbHelper.deletarLeituraOffline(p['id']);
          continue;
        }

        final bytes = await foto.readAsBytes();
        String base64Image = base64Encode(bytes);

        final db = await dbHelper.database;
        final unidadeData = await db.query('unidades', where: 'medidor_id = ?', whereArgs: [p['medidor_id']]);
        double leituraAnterior = 0.0;
        if (unidadeData.isNotEmpty) {
          leituraAnterior = (unidadeData.first['leitura_anterior'] as num?)?.toDouble() ?? 0.0;
        }

        final response = await http.post(
          Uri.parse('$baseUrl/api/leitura/processar-ia'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'image': base64Image,
            'medidor_id': p['medidor_id'],
            'tenant_id': tenantId,
            'leitura_anterior': leituraAnterior
          }),
        ).timeout(const Duration(seconds: 25));

        if (response.statusCode == 200) {
          await dbHelper.deletarLeituraOffline(p['id']);
          enviosComSucesso++;
        }
      } catch (e) {
        print("Falha silenciada ao sincronizar registro ID ${p['id']}: $e");
      }
    }
    return enviosComSucesso;
  }
}