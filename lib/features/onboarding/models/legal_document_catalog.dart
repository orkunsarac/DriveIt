import 'dart:convert';

import 'package:flutter/services.dart';

enum LegalDocumentStatus { pendingLegalReview, approved }

class LegalDocumentContent {
  const LegalDocumentContent({
    required this.id,
    required this.title,
    required this.status,
    required this.body,
    this.version,
    this.approvalReference,
    this.approvedAt,
  });

  final String id;
  final String title;
  final LegalDocumentStatus status;
  final String body;
  final String? version;
  final String? approvalReference;
  final DateTime? approvedAt;

  bool get canBeAccepted {
    final parsed = approvedAt;
    final normalizedBody = body.toLowerCase();
    return status == LegalDocumentStatus.approved &&
        body.trim().isNotEmpty &&
        !normalizedBody.contains('onay bekliyor') &&
        !normalizedBody.contains('hukuki inceleme') &&
        !normalizedBody.contains('placeholder') &&
        version?.trim().isNotEmpty == true &&
        approvalReference?.trim().isNotEmpty == true &&
        parsed != null;
  }

  factory LegalDocumentContent.fromJson(Map<String, dynamic> json) {
    final status = switch (json['status']) {
      'approved' => LegalDocumentStatus.approved,
      'pending_legal_review' => LegalDocumentStatus.pendingLegalReview,
      _ => throw const FormatException('Unknown legal document status'),
    };
    final approval = json['approval'] is Map
        ? Map<String, dynamic>.from(json['approval'] as Map)
        : const <String, dynamic>{};
    return LegalDocumentContent(
      id: _requiredString(json, 'id'),
      title: _requiredString(json, 'title'),
      status: status,
      body: _requiredString(json, 'body'),
      version: json['version'] as String?,
      approvalReference: approval['reference'] as String?,
      approvedAt: DateTime.tryParse(approval['approved_at'] as String? ?? ''),
    );
  }

  static String _requiredString(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is! String || value.trim().isEmpty) {
      throw FormatException('Legal document field "$key" is required');
    }
    return value;
  }
}

class LegalDocumentCatalog {
  LegalDocumentCatalog(Iterable<LegalDocumentContent> source)
    : documents = _indexAndValidate(source);

  final Map<String, LegalDocumentContent> documents;

  static Map<String, LegalDocumentContent> _indexAndValidate(
    Iterable<LegalDocumentContent> source,
  ) {
    final indexed = <String, LegalDocumentContent>{};
    for (final document in source) {
      if (indexed.containsKey(document.id)) {
        throw FormatException('Duplicate legal document: ${document.id}');
      }
      indexed[document.id] = document;
    }
    const required = {'kvkk', 'privacy', 'terms', 'consent'};
    if (!indexed.keys.toSet().containsAll(required)) {
      throw const FormatException('Required legal documents are missing');
    }
    return Map.unmodifiable(indexed);
  }

  LegalDocumentContent operator [](String id) =>
      documents[id] ?? (throw FormatException('Missing legal document: $id'));

  static Future<LegalDocumentCatalog> loadFromAssets() async {
    final decoded = jsonDecode(
      await rootBundle.loadString('assets/legal/legal_documents.json'),
    );
    if (decoded is! Map || decoded['documents'] is! List) {
      throw const FormatException('Invalid legal document catalog');
    }
    final rows = (decoded['documents'] as List).map((row) {
      if (row is! Map) throw const FormatException('Invalid legal document');
      return LegalDocumentContent.fromJson(Map<String, dynamic>.from(row));
    });
    return LegalDocumentCatalog(rows);
  }
}
