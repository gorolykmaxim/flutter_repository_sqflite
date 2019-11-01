import 'package:flutter_repository_sqflite/flutter_repository_sqflite.dart';
import 'package:mockito/mockito.dart';
import 'package:sqflite/sqflite.dart';

class MockException extends Mock implements Exception {}

class MockDatabase extends Mock implements Database {}

class MockDatabaseConnector extends Mock implements DatabaseConnector {}

Future<SqfliteDatabase> createDatabase(Database mockDatabase) {
  final connector = MockDatabaseConnector();
  when(connector.connect(any, version: anyNamed('version'), onUpgrade: anyNamed('onUpgrade')))
      .thenAnswer((_) => Future.value(mockDatabase));
  return (SqfliteDatabaseBuilder()
    ..connector = connector
    ..instructions(MigrationInstructions(Version(1), [])))
      .build();
}