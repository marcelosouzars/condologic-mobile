// ==========================================>>> database_helper.dart
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'condologic_offline.db');
    return await openDatabase(
      path,
      version: 2, // Incrementei a versão para forçar a criação das novas tabelas
      onCreate: (db, version) async {
        // Tabela de Leituras (Para envio posterior)
        await db.execute('''
          CREATE TABLE leituras (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            tenant_id INTEGER,
            medidor_id INTEGER,
            valor_lido TEXT,
            data_leitura TEXT,
            foto_caminho TEXT,
            status TEXT
          )
        ''');

        // NOVAS TABELAS PARA NAVEGAÇÃO OFFLINE
        await db.execute('''
          CREATE TABLE blocos_offline (
            id INTEGER PRIMARY KEY,
            nome TEXT
          )
        ''');

        await db.execute('''
          CREATE TABLE unidades_offline (
            id INTEGER PRIMARY KEY,
            bloco_id INTEGER,
            identificacao TEXT,
            andar TEXT
          )
        ''');

        await db.execute('''
          CREATE TABLE medidores_offline (
            id INTEGER PRIMARY KEY,
            unidade_id INTEGER,
            tipo TEXT,
            leitura_anterior TEXT
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('CREATE TABLE IF NOT EXISTS blocos_offline (id INTEGER PRIMARY KEY, nome TEXT)');
          await db.execute('CREATE TABLE IF NOT EXISTS unidades_offline (id INTEGER PRIMARY KEY, bloco_id INTEGER, identificacao TEXT, andar TEXT)');
          await db.execute('CREATE TABLE IF NOT EXISTS medidores_offline (id INTEGER PRIMARY KEY, unidade_id INTEGER, tipo TEXT, leitura_anterior TEXT)');
        }
      },
    );
  }

  // Métodos para Salvar Estrutura
  Future<void> limparEstrutura() async {
    final db = await database;
    await db.delete('blocos_offline');
    await db.delete('unidades_offline');
    await db.delete('medidores_offline');
  }

  Future<void> inserirBloco(Map<String, dynamic> bloco) async {
    final db = await database;
    await db.insert('blocos_offline', {'id': bloco['id'], 'nome': bloco['nome']}, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> inserirUnidade(Map<String, dynamic> unidade) async {
    final db = await database;
    await db.insert('unidades_offline', {
      'id': unidade['id'],
      'bloco_id': unidade['bloco_id'],
      'identificacao': unidade['identificacao'],
      'andar': unidade['andar']
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> inserirMedidor(Map<String, dynamic> medidor) async {
    final db = await database;
    await db.insert('medidores_offline', {
      'id': medidor['id'],
      'unidade_id': medidor['unidade_id'],
      'tipo': medidor['tipo'],
      'leitura_anterior': medidor['leitura_anterior'].toString()
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // Métodos para Ler Estrutura (Offline)
  Future<List<Map<String, dynamic>>> getBlocosOffline() async {
    final db = await database;
    return await db.query('blocos_offline');
  }

  Future<List<Map<String, dynamic>>> getUnidadesOffline(int blocoId) async {
    final db = await database;
    return await db.query('unidades_offline', where: 'bloco_id = ?', whereArgs: [blocoId]);
  }

  Future<List<Map<String, dynamic>>> getMedidoresOffline(int unidadeId) async {
    final db = await database;
    return await db.query('medidores_offline', where: 'unidade_id = ?', whereArgs: [unidadeId]);
  }

  // Salvar Leitura Capturada
  Future<int> salvarLeitura(Map<String, dynamic> leitura) async {
    final db = await database;
    return await db.insert('leituras', leitura);
  }

  Future<List<Map<String, dynamic>>> getLeiturasPendentes() async {
    final db = await database;
    return await db.query('leituras', where: 'status = ?', whereArgs: ['pendente']);
  }

  Future<void> marcarComoEnviado(int id) async {
    final db = await database;
    await db.update('leituras', {'status': 'enviado'}, where: 'id = ?', whereArgs: [id]);
  }
}