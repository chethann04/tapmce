import 'package:flutter_test/flutter_test.dart';
import 'package:placement_connect/core/utils/validators.dart';

void main() {
  group('AppValidators', () {
    group('email', () {
      test('returns null for valid email', () {
        expect(AppValidators.email('test@example.com'), isNull);
      });

      test('returns error for empty email', () {
        expect(AppValidators.email(''), isNotNull);
        expect(AppValidators.email(null), isNotNull);
      });

      test('returns error for missing @', () {
        expect(AppValidators.email('testexample.com'), isNotNull);
      });

      test('returns error for spaces in email', () {
        expect(AppValidators.email('test @example.com'), isNotNull);
      });
    });

    group('password', () {
      test('returns null for valid password', () {
        expect(AppValidators.password('Pass123!'), isNull);
      });

      test('returns error if less than 8 characters', () {
        expect(AppValidators.password('Pa1!'), contains('at least 8 characters'));
      });

      test('returns error if missing uppercase', () {
        expect(AppValidators.password('pass123!'), contains('uppercase'));
      });

      test('returns error if missing number', () {
        expect(AppValidators.password('Password!'), contains('number'));
      });

      test('returns error if missing special character', () {
        expect(AppValidators.password('Password123'), contains('special character'));
      });
    });

    group('name', () {
      test('returns null for valid name', () {
        expect(AppValidators.name('John Doe'), isNull);
        expect(AppValidators.name("Mary-Jane O'Connor"), isNull);
      });

      test('returns error for empty name', () {
        expect(AppValidators.name(''), isNotNull);
      });

      test('returns error for names with numbers', () {
        expect(AppValidators.name('John123'), contains('only contain letters'));
      });

      test('returns error for names with emojis', () {
        expect(AppValidators.name('John 😊'), contains('only contain letters'));
      });
    });

    group('otp', () {
      test('returns null for valid 6-digit OTP', () {
        expect(AppValidators.otp('123456'), isNull);
      });

      test('returns error if less than 6 digits', () {
        expect(AppValidators.otp('123'), contains('exactly 6 digits'));
      });

      test('returns error if contains letters', () {
        expect(AppValidators.otp('123abc'), contains('only numbers'));
      });
    });
  });
}