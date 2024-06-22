import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

// Classe che gestisce il database delle spese
class DatabaseHelper {
  // Singleton pattern per garantire un'unica istanza della classe
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  // Ottiene l'istanza del database, se non esiste la crea
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('expenses.db');
    return _database!;
  }

  // Inizializza il database
  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 2, // Incrementa la versione del database
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  // Crea la tabella 'expenses' nel database
  Future _createDB(Database db, int version) async {
    const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
    const textType = 'TEXT NOT NULL';
    const doubleType = 'REAL NOT NULL';

    // Crea la tabella
    await db.execute('''
      CREATE TABLE expenses (
        id $idType,
        amount $doubleType,
        date $textType,
        categories $textType,
        description $textType
      )
    ''');

    // Inserisce alcune voci di default nella tabella 'expenses'
    await db.insert('expenses', {
      'amount': 1.30,
      'date': '2024-05-24',
      'categories': 'divertimento, alimenti',
      'description': 'Caffè'
    });
    await db.insert('expenses', {
      'amount': 47.50,
      'date': '2024-05-25',
      'categories': 'alimenti',
      'description': 'Carne'
    });
    await db.insert('expenses', {
      'amount': 1099.99,
      'date': '2024-05-26',
      'categories': 'divertimento, shopping',
      'description': 'Comprato nuovo laptop'
    });
    await db.insert('expenses', {
      'amount': 71.99,
      'date': '2024-05-26',
      'categories': 'shopping',
      'description': 'Spese su e-commerce'
    });
  }
// Questa funzione viene chiamata da OpenDatabase solamente quando il db installato sul dispositivo dell'utente ha una versione inferiore a 2
// Questa funzione modifica il db della versione 1 aggiungendo la colonna 'categories'
  Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
    // Verifichiamo se la versione del database è stata cambianta (aggiornata)
    if (oldVersion < 2) {
      // Verifichiamo se la colonna 'categories' esiste già
      List<Map<String, dynamic>> columns = await db.rawQuery('PRAGMA table_info(expenses)');
      bool columnExists = columns.any((column) => column['name'] == 'categories');
      if (!columnExists) {
        await db.execute('ALTER TABLE expenses ADD COLUMN categories TEXT');
      }
    }
  }

  Future<int> createExpense(Map<String, dynamic> expense) async {
    final db = await instance.database;
    return await db.insert('expenses', {
      'amount': expense['amount'],
      'date': expense['date'],
      'categories': _joinCategories(expense['categories'] ?? []),
      'description': expense['description']
    });
  }

  Future<List<Map<String, dynamic>>> readAllExpenses() async {
    final db = await instance.database;
    final result = await db.query('expenses');
    return result.map((expense) {
      final mutableExpense = Map<String, dynamic>.from(expense);
      mutableExpense['categories'] = _splitCategories(mutableExpense['categories'] as String?);
      return mutableExpense;
    }).toList();
  }

  Future<List<Map<String, dynamic>>> readAllExpensesOrderedByDate() async {
    final db = await database;
    var result = await db.query('expenses', orderBy: 'date DESC');
    return result.map((expense) {
      // La mappa ritornata è organizzata come key(String) cioè l'id della riga e poi a quell'id 
      // viene assocaito una lista di attributi(dynamic) che saranno 'amount', 'date', 'categories', 'description'. 
      // Abbiamo necessita di modificarla questa mappa perche il campo categories è rappresentato come una stringa del tipo 
      // 'divertimento, alimenti' e non come una lista di stringhe. 
      final mutableExpense = Map<String, dynamic>.from(expense);
      mutableExpense['categories'] = _splitCategories(mutableExpense['categories'] as String?);
      return mutableExpense;
    }).toList();
  }

  Future<int> updateExpense(Map<String, dynamic> expense) async {
    final db = await instance.database;
    return db.update(
      'expenses',
      {
        'amount': expense['amount'],
        'date': expense['date'],
        'categories': _joinCategories(expense['categories'] ?? []),
        'description': expense['description']
      },
      where: 'id = ?',
      whereArgs: [expense['id']],
    );
  }

  Future<int> deleteExpense(int id) async {
    final db = await instance.database;
    return await db.delete(
      'expenses',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Chiude il database
  Future close() async {
    final db = await instance.database;
    db.close();
  }

  String _joinCategories(List<String> categories) {
    return categories.map((category) => category.trim()).join(',');
  }

  List<String>? _splitCategories(String? categories) {
    if (categories == null || categories.isEmpty) {
      return [];
    }
    return categories.split(',').map((category) => category.trim()).toList();
  }
}
