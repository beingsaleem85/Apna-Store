import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Task 2 — Zero Client-Side Secrets Audit Tests', () {
    test('1. No file under lib/ contains hardcoded API keys, secrets, or service_role tokens', () {
      final libDir = Directory('lib');
      expect(libDir.existsSync(), isTrue, reason: 'lib directory must exist');

      final forbiddenPatterns = [
        RegExp(r'pk_live_[a-zA-Z0-9]+'),
        RegExp(r'sk_live_[a-zA-Z0-9]+'),
        RegExp(r'sk_test_[a-zA-Z0-9]+'),
        RegExp(r'aws_s3_key_[a-zA-Z0-9]+'),
        RegExp(r'sec_jc_live_[a-zA-Z0-9]+'),
        RegExp(r'sec_ep_live_[a-zA-Z0-9]+'),
        RegExp(r'sec_1link_live_[a-zA-Z0-9]+'),
        RegExp(r'tcs_api_key_[a-zA-Z0-9]+'),
        RegExp(r'tcs_live_pk_[a-zA-Z0-9]+'),
        RegExp(r'lcs_sec_[a-zA-Z0-9]+'),
        RegExp(r'leopard_sec_[a-zA-Z0-9]+'),
        RegExp(r'trax_live_[a-zA-Z0-9]+'),
        RegExp(r'sms_live_key_[a-zA-Z0-9]+'),
        RegExp(r'fbr_live_pos_[a-zA-Z0-9]+'),
        RegExp(r'call_live_[a-zA-Z0-9]+'),
        RegExp(r'service_role'),
      ];

      final violations = <String>[];

      final files = libDir.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'));

      for (final file in files) {
        final content = file.readAsStringSync();
        for (final pattern in forbiddenPatterns) {
          final matches = pattern.allMatches(content);
          for (final match in matches) {
            violations.add('${file.path}: Matched forbidden secret pattern "${pattern.pattern}" -> "${match.group(0)}"');
          }
        }
      }

      expect(
        violations,
        isEmpty,
        reason: 'Client-side code must NEVER contain secrets or fake production keys:\n${violations.join('\n')}',
      );
    });

    test('2. docs/SECRETS_SETUP.md exists and documents server secret configuration commands', () {
      final file = File('docs/SECRETS_SETUP.md');
      expect(file.existsSync(), isTrue, reason: 'docs/SECRETS_SETUP.md must exist');
      final content = file.readAsStringSync();

      expect(content, contains('supabase secrets set'));
      expect(content, contains('JAZZCASH'));
      expect(content, contains('EASYPAISA'));
      expect(content, contains('STRIPE'));
      expect(content, contains('TCS'));
      expect(content, contains('LEOPARD'));
      expect(content, contains('TRAX'));
      expect(content, contains('S3'));
      expect(content, contains('FBR'));
    });
  });
}
