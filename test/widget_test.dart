import 'package:flutter_test/flutter_test.dart';
import 'package:energyiq/core/utils/validator.dart';

void main() {
  group('FormValidators', () {

    // --- Full Name Tests ---
    group('validateFullName', () {
      test('empty name returns error', () {
        expect(FormValidators.validateFullName(''), 'Please enter your full name');
      });
      test('null name returns error', () {
        expect(FormValidators.validateFullName(null), 'Please enter your full name');
      });
      test('numbers only returns error', () {
        expect(FormValidators.validateFullName('12345'), 'Full name cannot be just numbers');
      });
      test('valid name returns null', () {
        expect(FormValidators.validateFullName('Ahmad Al-Harthy'), null);
      });
    });

    // --- Email Tests ---
    group('validateEmail', () {
      test('empty email returns error', () {
        expect(FormValidators.validateEmail(''), 'Email address is required');
      });
      test('invalid email returns error', () {
        expect(FormValidators.validateEmail('notanemail'), 'Invalid email address');
      });
      test('valid email returns null', () {
        expect(FormValidators.validateEmail('ahmad@gmail.com'), null);
      });
    });

    // --- Password Tests ---
    group('validatePassword', () {
      test('empty password returns error', () {
        expect(FormValidators.validatePassword(''), 'Password is required');
      });
      test('short password returns error', () {
        expect(FormValidators.validatePassword('Test123'), 'Password must be at least 8 characters');
      });
      test('valid password returns null', () {
        expect(FormValidators.validatePassword('Test1234'), null);
      });
    });

  });
}
