import 'dart:convert';
import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite/sqflite.dart';

/// 汎用CRUD API サーバー
class AppServer {
  Database? _database;
  late final Router _router;
  final String _apiKey;
  final String _dbPath;

  AppServer(this._apiKey, {String? dbPath})
      : _dbPath = dbPath ?? './h-1_server.db' {
    _router = Router()
      ..get('/health', _health)
      ..get('/tables', _tables)
      ..get('/api/<table>', _handleList)
      ..get('/api/<table>/<id>', _handleGet)
      ..post('/api/<table>', _handleCreate)
      ..put('/api/<table>/<id>', _handleUpdate)
      ..delete('/api/<table>/<id>', _handleDelete);
  }

  Future<Database> get db async {
    if (_database != null) return _database!;
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    _database = await openDatabase(
      _dbPath,
      version: 1,
      onCreate: (db2, version) async {
        await db2.execute('''
          CREATE TABLE IF NOT EXISTS sync_meta (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
          )
        ''');
      },
    );
    return _database!;
  }

  Middleware get _auth {
    return (innerHandler) {
      return (request) async {
        if (request.url.path == '/health' || request.url.path == '/') {
          return innerHandler(request);
        }
        final key = request.headers['x-api-key'];
        if (key != _apiKey) {
          return Response(401, body: jsonEncode({'error': 'Invalid API key'}),
              headers: {'Content-Type': 'application/json'});
        }
        return innerHandler(request);
      };
    };
  }

  Future<HttpServer> start(String host, int port) async {
    final handler = const Pipeline()
        .addMiddleware(logRequests())
        .addMiddleware(_auth)
        .addHandler(_router.call);
    return await serve(handler, host, port);
  }

  Future<Response> _health(Request req) async {
    try {
      await db;
      return Response.ok(jsonEncode({'status': 'ok', 'version': '1.5.32+190'}),
          headers: {'Content-Type': 'application/json'});
    } catch (e) {
      return Response(500, body: jsonEncode({'error': e.toString()}),
          headers: {'Content-Type': 'application/json'});
    }
  }

  Future<Response> _tables(Request req) async {
    final d = await db;
    final rows = await d.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name");
    return Response.ok(jsonEncode(rows.map((r) => r['name']).toList()),
        headers: {'Content-Type': 'application/json'});
  }

  Future<Response> _handleList(Request req) async {
    final table = req.params['table']!;
    final limit = int.tryParse(req.url.queryParameters['limit'] ?? '') ?? 100;
    final offset = int.tryParse(req.url.queryParameters['offset'] ?? '') ?? 0;
    try {
      final d = await db;
      final rows = await d.query(table, limit: limit, offset: offset);
      return Response.ok(jsonEncode(rows),
          headers: {'Content-Type': 'application/json'});
    } catch (e) {
      return Response(404, body: jsonEncode({'error': 'Table "$table" not found'}),
          headers: {'Content-Type': 'application/json'});
    }
  }

  Future<Response> _handleGet(Request req) async {
    final table = req.params['table']!;
    final id = req.params['id']!;
    if (id == 'schema') {
      try {
        final d = await db;
        final rows = await d.rawQuery('PRAGMA table_info($table)');
        return Response.ok(jsonEncode(rows),
            headers: {'Content-Type': 'application/json'});
      } catch (e) {
        return Response(404, body: jsonEncode({'error': 'Table "$table" not found'}),
            headers: {'Content-Type': 'application/json'});
      }
    }
    try {
      final d = await db;
      final rows = await d.query(table, where: 'id = ?', whereArgs: [id], limit: 1);
      if (rows.isEmpty) {
        return Response(404, body: jsonEncode({'error': 'Not found'}),
            headers: {'Content-Type': 'application/json'});
      }
      return Response.ok(jsonEncode(rows.first),
          headers: {'Content-Type': 'application/json'});
    } catch (e) {
      return Response(500, body: jsonEncode({'error': e.toString()}),
          headers: {'Content-Type': 'application/json'});
    }
  }

  Future<Response> _handleCreate(Request req) async {
    final table = req.params['table']!;
    try {
      final body = jsonDecode(await req.readAsString()) as Map<String, dynamic>;
      final d = await db;
      await d.insert(table, body, conflictAlgorithm: ConflictAlgorithm.replace);
      return Response.ok(jsonEncode({'ok': true}),
          headers: {'Content-Type': 'application/json'});
    } catch (e) {
      return Response(500, body: jsonEncode({'error': e.toString()}),
          headers: {'Content-Type': 'application/json'});
    }
  }

  Future<Response> _handleUpdate(Request req) async {
    final table = req.params['table']!;
    final id = req.params['id']!;
    try {
      final body = jsonDecode(await req.readAsString()) as Map<String, dynamic>;
      final d = await db;
      body.remove('id');
      await d.update(table, body, where: 'id = ?', whereArgs: [id]);
      return Response.ok(jsonEncode({'ok': true}),
          headers: {'Content-Type': 'application/json'});
    } catch (e) {
      return Response(500, body: jsonEncode({'error': e.toString()}),
          headers: {'Content-Type': 'application/json'});
    }
  }

  Future<Response> _handleDelete(Request req) async {
    final table = req.params['table']!;
    final id = req.params['id']!;
    try {
      final d = await db;
      await d.delete(table, where: 'id = ?', whereArgs: [id]);
      return Response.ok(jsonEncode({'ok': true}),
          headers: {'Content-Type': 'application/json'});
    } catch (e) {
      return Response(500, body: jsonEncode({'error': e.toString()}),
          headers: {'Content-Type': 'application/json'});
    }
  }
}
