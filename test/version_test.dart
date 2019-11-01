import 'package:flutter_repository_sqflite/flutter_repository_sqflite.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Version', () {
    test('fails to create a version with a negative value', () {
      expect(() => Version(-1), throwsA(isInstanceOf<ArgumentError>()));
    });
    test('fails to create a version with a 0 value', () {
      expect(() => Version(0), throwsA(isInstanceOf<ArgumentError>()));
    });
    test('creates a version object', () {
      expect(Version(1).toInt(), 1);
    });
  });
}