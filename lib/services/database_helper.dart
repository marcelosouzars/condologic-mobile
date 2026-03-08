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
    // MUDANÇA 1: Mudamos o nome do arquivo para forçar a recriação do banco do zero!
    String path = join(await getDatabasesPath(), 'condologic_prod_v3.db'); 
    return await openDatabase(
      path,
      version: 1, 
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE unidades (
            medidor_id INTEGER PRIMARY KEY, -- MUDANÇA 2: A chave primária agora é o medidor!
            unidade_id INTEGER,
            identificacao TEXT,
            bloco_nome TEXT,
            andar TEXT,  
            status_cor TEXT,
            leitura_anterior REAL,
            media_consumo REAL,
            valor_lido REAL,
            tipo_medidor TEXT -- MUDANÇA 3: Adicionado para os ícones funcionarem offline
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

  // --- MÉTODOS DE CACHE ---
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
    
    // Atualiza apenas a "bolinha amarela" do medidor específico que foi lido
    await db.update(
      'unidades', 
      {'status_cor': 'amarelo', 'valor_lido': valor}, 
      where: 'medidor_id = ?', 
      whereArgs: [medidorId]
    );
    return id;
  }
}