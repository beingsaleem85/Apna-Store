import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Task 7: Security Hardening & Web Policies', () {
    test('vercel.json exists and enforces strict security headers', () {
      final file = File('vercel.json');
      expect(file.existsSync(), isTrue, reason: 'vercel.json must exist in project root');

      final content = file.readAsStringSync();
      final json = jsonDecode(content) as Map<String, dynamic>;

      expect(json.containsKey('headers'), isTrue);
      final headersList = json['headers'] as List;
      expect(headersList.isNotEmpty, isTrue);

      final rootHeaders = (headersList.first['headers'] as List).cast<Map<String, dynamic>>();
      final headerMap = {
        for (final h in rootHeaders) h['key'] as String: h['value'] as String
      };

      expect(headerMap['X-Frame-Options'], equals('DENY'));
      expect(headerMap['X-Content-Type-Options'], equals('nosniff'));
      expect(headerMap['Referrer-Policy'], equals('strict-origin-when-cross-origin'));
      expect(headerMap['Permissions-Policy'], contains('camera=()'));
      expect(headerMap['Content-Security-Policy'], contains("default-src 'self'"));
      expect(headerMap['Content-Security-Policy'], contains('connect-src'));
    });

    test('web/robots.txt disallows sensitive administrative paths', () {
      final file = File('web/robots.txt');
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();

      expect(content, contains('Disallow: /admin/'));
      expect(content, contains('Disallow: /super-admin/'));
      expect(content, contains('Disallow: /seller/'));
    });

    test('web/index.html includes security, viewport, and OpenGraph meta tags', () {
      final file = File('web/index.html');
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();

      expect(content, contains('viewport'));
      expect(content, contains('og:title'));
      expect(content, contains('og:description'));
      expect(content, contains('Apna Store'));
    });
  });
}
