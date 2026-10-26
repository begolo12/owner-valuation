import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

/// Ganti setelah deploy Vercel.
const kDefaultBaseUrl = 'https://owner-valuation.vercel.app';

/// Token bawaan supaya aplikasi langsung terpakai tanpa isi manual.
/// Ini gate lunak, bukan autentikasi: nilainya ada di bundle JS publik.
/// Ganti lewat layar Pengaturan kalau perlu rotasi.
const kDefaultToken = '539ddf572633b2f47e101b5e2efd06505133ee009e93fdf0';

class ApiException implements Exception {
  ApiException(this.status, this.message);
  final int status;
  final String message;
  @override
  String toString() => message;
}

class Meta {
  Meta({
    required this.models,
    required this.weights,
    required this.paymentMethods,
    required this.currentQuarter,
  });

  final List<String> models;
  final Map<String, Map<String, double>> weights;
  final List<String> paymentMethods;
  final String currentQuarter;

  factory Meta.fromJson(Map<String, dynamic> j) => Meta(
        models: (j['models'] as List).cast<String>(),
        weights: (j['weights'] as Map).map(
          (k, v) => MapEntry(
            k as String,
            (v as Map).map((k2, v2) => MapEntry(k2 as String, (v2 as num).toDouble())),
          ),
        ),
        paymentMethods: (j['paymentMethods'] as List).cast<String>(),
        currentQuarter: j['currentQuarter'] as String,
      );

  /// Hitung skor di klien untuk pratinjau. Server tetap otoritatif.
  ({double total, String grade}) score(String model, Map<String, double> s) {
    final w = weights[model]!;
    final total = s['holding']! * w['holding']! +
        s['payment']! * w['payment']! +
        s['tenor']! * w['tenor']! +
        s['projection']! * w['projection']!;
    final rounded = (total * 100).round() / 100;
    return (total: rounded, grade: gradeOf(rounded));
  }
}

String gradeOf(double total) {
  if (total >= 85) return 'A';
  if (total >= 70) return 'B';
  if (total >= 55) return 'C';
  if (total >= 40) return 'D';
  return 'E';
}

class Holding {
  Holding({required this.id, required this.name, this.notes, this.ownerCount = 0});
  final String id;
  final String name;
  final String? notes;
  final int ownerCount;

  factory Holding.fromJson(Map<String, dynamic> j) => Holding(
        id: j['id'] as String,
        name: j['name'] as String,
        notes: j['notes'] as String?,
        ownerCount: (j['ownerCount'] as num?)?.toInt() ?? 0,
      );
}

class LatestScore {
  LatestScore({required this.model, required this.quarter, required this.total, required this.grade});
  final String model;
  final String quarter;
  final double total;
  final String grade;

  factory LatestScore.fromJson(Map<String, dynamic> j) => LatestScore(
        model: j['model'] as String,
        quarter: j['quarter'] as String,
        total: (j['total'] as num).toDouble(),
        grade: j['grade'] as String,
      );
}

class Owner {
  Owner({
    required this.id,
    required this.holdingId,
    required this.name,
    this.project,
    this.notes,
    this.holdingName,
    this.latest = const [],
    this.history = const [],
  });

  final String id;
  final String holdingId;
  final String name;
  final String? project;
  final String? notes;
  final String? holdingName;
  final List<LatestScore> latest;
  final List<LatestScore> history;

  factory Owner.fromJson(Map<String, dynamic> j) => Owner(
        id: j['id'] as String,
        holdingId: j['holdingId'] as String,
        name: j['name'] as String,
        project: j['project'] as String?,
        notes: j['notes'] as String?,
        holdingName: j['holdingName'] as String?,
        latest: (j['latest'] as List? ?? const [])
            .map((e) => LatestScore.fromJson(e as Map<String, dynamic>))
            .toList(),
        history: (j['history'] as List? ?? const [])
            .map((e) => LatestScore.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class Assessment {
  Assessment({
    required this.id,
    required this.quarter,
    required this.model,
    required this.paymentMethod,
    required this.paymentTenor,
    required this.paidAmount,
    required this.projectionValue,
    this.projectionNotes,
    required this.scores,
    required this.total,
    required this.grade,
  });

  final String id;
  final String quarter;
  final String model;
  final String paymentMethod;
  final int paymentTenor;
  final double paidAmount;
  final double projectionValue;
  final String? projectionNotes;
  final Map<String, double> scores;
  final double total;
  final String grade;

  factory Assessment.fromJson(Map<String, dynamic> j) {
    final s = (j['scores'] as Map).map((k, v) => MapEntry(k as String, (v as num).toDouble()));
    return Assessment(
      id: j['id'] as String,
      quarter: j['quarter'] as String,
      model: j['model'] as String,
      paymentMethod: j['paymentMethod'] as String,
      paymentTenor: (j['paymentTenor'] as num).toInt(),
      paidAmount: (j['paidAmount'] as num).toDouble(),
      projectionValue: (j['projectionValue'] as num).toDouble(),
      projectionNotes: j['projectionNotes'] as String?,
      scores: s,
      total: (j['total'] as num).toDouble(),
      grade: j['grade'] as String,
    );
  }
}

class Dashboard {
  Dashboard({
    required this.quarter,
    required this.holdings,
    required this.owners,
    required this.assessed,
    required this.missing,
    required this.byModel,
    required this.trend,
    required this.top,
  });

  final String quarter;
  final int holdings;
  final int owners;
  final int assessed;
  final int missing;
  final List<({String model, int count, double avg})> byModel;
  final List<({String quarter, String model, int count, double avg})> trend;
  final List<({String name, String? project, String holding, String model, double total, String grade})>
      top;

  factory Dashboard.fromJson(Map<String, dynamic> j) {
    final t = j['totals'] as Map<String, dynamic>;
    return Dashboard(
      quarter: j['quarter'] as String,
      holdings: (t['holdings'] as num).toInt(),
      owners: (t['owners'] as num).toInt(),
      assessed: (t['assessed'] as num).toInt(),
      missing: (t['missing'] as num).toInt(),
      byModel: (j['byModel'] as List)
          .map((e) => (
                model: e['model'] as String,
                count: (e['count'] as num).toInt(),
                avg: (e['avg'] as num).toDouble(),
              ))
          .toList(),
      trend: (j['trend'] as List)
          .map((e) => (
                quarter: e['quarter'] as String,
                model: e['model'] as String,
                count: (e['count'] as num).toInt(),
                avg: (e['avg'] as num).toDouble(),
              ))
          .toList(),
      top: (j['top'] as List)
          .map((e) => (
                name: e['name'] as String,
                project: e['project'] as String?,
                holding: e['holding'] as String,
                model: e['model'] as String,
                total: (e['total'] as num).toDouble(),
                grade: e['grade'] as String,
              ))
          .toList(),
    );
  }
}

class Api {
  Api._();
  static final Api i = Api._();

  static const _storage = FlutterSecureStorage();
  static const _kBase = 'base_url';
  static const _kToken = 'app_token';

  String baseUrl = kDefaultBaseUrl;
  String token = kDefaultToken;
  Meta? meta;

  Future<void> load() async {
    baseUrl = await _storage.read(key: _kBase) ?? kDefaultBaseUrl;
    token = await _storage.read(key: _kToken) ?? kDefaultToken;
  }

  Future<void> save({String? baseUrl, String? token}) async {
    if (baseUrl != null && baseUrl.isNotEmpty) {
      this.baseUrl = baseUrl.replaceAll(RegExp(r'/+$'), '');
      await _storage.write(key: _kBase, value: this.baseUrl);
    }
    if (token != null && token.isNotEmpty) {
      this.token = token;
      await _storage.write(key: _kToken, value: token);
    }
  }

  Uri _uri(String path, [Map<String, String>? query]) =>
      Uri.parse('$baseUrl/api/$path').replace(queryParameters: query?.isEmpty ?? true ? null : query);

  Future<dynamic> _send(String method, String path,
      {Map<String, String>? query, Object? body}) async {
    final req = http.Request(method, _uri(path, query))
      ..headers['x-app-token'] = token
      ..headers['content-type'] = 'application/json';
    if (body != null) req.body = jsonEncode(body);
    final res = await http.Response.fromStream(await req.send().timeout(const Duration(seconds: 20)));
    final text = res.body.isEmpty ? '{}' : res.body;
    dynamic data;
    try {
      data = jsonDecode(text);
    } on FormatException {
      throw ApiException(res.statusCode, 'Respons server bukan JSON (${res.statusCode})');
    }
    if (res.statusCode >= 400) {
      throw ApiException(res.statusCode, (data['error'] as String?) ?? 'Gagal (${res.statusCode})');
    }
    return data;
  }

  Future<Meta> fetchMeta() async {
    meta = Meta.fromJson(await _send('GET', 'meta') as Map<String, dynamic>);
    return meta!;
  }

  Future<Dashboard> dashboard({String? quarter}) async =>
      Dashboard.fromJson(await _send('GET', 'dashboard', query: {if (quarter != null) 'quarter': quarter})
          as Map<String, dynamic>);

  Future<List<Holding>> holdings() async {
    final data = await _send('GET', 'holdings') as Map<String, dynamic>;
    return (data['items'] as List).map((e) => Holding.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Holding> createHolding(String name, {String? notes}) async => Holding.fromJson(
      await _send('POST', 'holdings', body: {'name': name, 'notes': notes}) as Map<String, dynamic>);

  Future<void> deleteHolding(String id) => _send('DELETE', 'holdings/$id');

  Future<({Holding holding, List<Owner> owners})> holdingDetail(String id) async {
    final data = await _send('GET', 'holdings/$id') as Map<String, dynamic>;
    return (
      holding: Holding.fromJson(data['holding'] as Map<String, dynamic>),
      owners: (data['owners'] as List).map((e) => Owner.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }

  Future<Owner> createOwner(String holdingId, String name, {String? project, String? notes}) async =>
      Owner.fromJson(await _send('POST', 'holdings/$holdingId/owners',
          body: {'name': name, 'project': project, 'notes': notes}) as Map<String, dynamic>);

  Future<void> deleteOwner(String id) => _send('DELETE', 'owners/$id');

  Future<({Owner owner, List<Assessment> assessments})> ownerDetail(String id) async {
    final data = await _send('GET', 'owners/$id') as Map<String, dynamic>;
    return (
      owner: Owner.fromJson(data['owner'] as Map<String, dynamic>),
      assessments: (data['assessments'] as List)
          .map((e) => Assessment.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Future<Assessment> saveAssessment(
    String ownerId, {
    required String quarter,
    required String model,
    required String paymentMethod,
    required int paymentTenor,
    required double paidAmount,
    required double projectionValue,
    String? projectionNotes,
    required Map<String, double> scores,
  }) async =>
      Assessment.fromJson(await _send('PUT', 'owners/$ownerId/assessments', body: {
        'quarter': quarter,
        'model': model,
        'paymentMethod': paymentMethod,
        'paymentTenor': paymentTenor,
        'paidAmount': paidAmount,
        'projectionValue': projectionValue,
        'projectionNotes': projectionNotes,
        'scores': scores,
      }) as Map<String, dynamic>);

  Future<void> deleteAssessment(String ownerId, String id) =>
      _send('DELETE', 'owners/$ownerId/assessments/$id');

  /// Rilis terbaru dari GitHub. Null kalau 404 / offline.
  Future<Map<String, dynamic>?> releaseLatest(String repo) async {
    try {
      final res = await http
          .get(Uri.parse('https://api.github.com/repos/$repo/releases/latest'),
              headers: {'accept': 'application/vnd.github+json'})
          .timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) return null;
      return jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }
}

