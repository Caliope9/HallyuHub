import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hallyuhub/src/services/content_moderation_service.dart';
import 'package:hallyuhub/src/services/local_safety_service.dart';

void main() {
  test('child safety report reason is visible and distinct', () {
    final reason = safetyReportReasons.firstWhere(
      (item) => item.key == 'child_safety',
    );
    expect(reason.label, 'Explotación o abuso sexual infantil');
    expect(safetyReportReasons.any((item) => item.key == 'spam'), isTrue);
  });

  test('moderation identifies critical child safety metadata', () {
    final report = ContentReport(
      id: 'report',
      contentType: 'post',
      contentId: 'content',
      reportedUserId: 'user',
      reporterId: 'reporter',
      reason: 'child_safety',
      details: '',
      status: 'pending',
      createdAt: DateTime(2026),
      reviewedAt: null,
      reviewerId: '',
      resolutionAction: '',
      resolutionNote: '',
      metadata: const {
        'safety_category': 'child_safety',
        'severity': 'critical',
        'priority': 'urgent',
      },
    );
    expect(report.isChildSafety, isTrue);
  });

  test('public child safety page contains required policy and contact', () {
    final html = File('web/child-safety/index.html').readAsStringSync();
    expect(html, contains('Estándares de seguridad infantil de HallyuHub'));
    expect(html, contains('CSAE'));
    expect(html, contains('CSAM'));
    expect(html, contains('grooming'));
    expect(html, contains('sextorsión'));
    expect(html, contains('NCMEC'));
    expect(html, contains('leopaletta9@gmail.com'));
  });

  test('operational response document avoids claiming automatic detection', () {
    final document = File('../docs/child_safety_response_v1.md')
        .readAsStringSync();
    expect(document, contains('No se promete una clasificación automática'));
    expect(document, contains('autoridad competente'));
    expect(document, contains('moderation_actions'));
  });
}
