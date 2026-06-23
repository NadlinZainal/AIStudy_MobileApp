import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class VectorDbService {
  static final VectorDbService instance = VectorDbService._();
  VectorDbService._();

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDb();
    return _database!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'vector_store.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE document_chunks (
            id TEXT PRIMARY KEY,
            document_id TEXT,
            document_name TEXT,
            chunk_text TEXT,
            embedding TEXT
          )
        ''');
      },
    );
  }

  Future<void> saveChunk({
    required String id,
    required String documentId,
    required String documentName,
    required String chunkText,
    required List<double> embedding,
  }) async {
    final db = await database;
    await db.insert(
      'document_chunks',
      {
        'id': id,
        'document_id': documentId,
        'document_name': documentName,
        'chunk_text': chunkText,
        'embedding': jsonEncode(embedding),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getChunksForDocument(String documentId) async {
    final db = await database;
    return await db.query(
      'document_chunks',
      where: 'document_id = ?',
      whereArgs: [documentId],
    );
  }

  Future<void> deleteDocumentChunks(String documentId) async {
    final db = await database;
    await db.delete(
      'document_chunks',
      where: 'document_id = ?',
      whereArgs: [documentId],
    );
  }

  Future<void> clearAll() async {
    final db = await database;
    await db.delete('document_chunks');
  }
}
