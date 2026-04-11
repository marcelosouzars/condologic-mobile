import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

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
            enviado INTEGER DEFAULT 0,
            leitura_anterior TEXT,
            tenant_id INTEGER
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
      double leituraAnt = double.tryParse(u['leitura_anterior']?.toString() ?? '0.0') ?? 0.0;
      double mediaCons = double.tryParse(u['media_consumo']?.toString() ?? '0.0') ?? 0.0;
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

  // ESSA É A FUNÇÃO QUE ESTAVA DANDO ERRO DE ARGUMENTOS
  Future<int> salvarLeituraOffline({
    required int unidadeId, 
    required int medidorId, 
    required double valor, 
    required String fotoPath,
    required String leituraAnterior,
    required int tenantId
  }) async {
    final db = await database;
    int id = await db.insert('leituras_offline', {
      'unidade_id': unidadeId,
      'medidor_id': medidorId,
      'valor_lido': valor,
      'caminho_foto': fotoPath,
      'data_leitura': DateTime.now().toIso8601String(),
      'enviado': 0,
      'leitura_anterior': leituraAnterior,
      'tenant_id': tenantId
    });
    
    await db.update(
      'unidades', 
      {'status_cor': 'amarelo', 'valor_lido': valor}, 
      where: 'medidor_id = ?', 
      whereArgs: [medidorId]
    );
    return id;
  }

  Future<List<Map<String, dynamic>>> buscarPendentes() async {
    final db = await database;
    return await db.query('leituras_offline', where: 'enviado = 0');
  }

  Future<void> marcarComoEnviado(int id) async {
    final db = await database;
    await db.update('leituras_offline', {'enviado': 1}, where: 'id = ?', whereArgs: [id]);
  }
}