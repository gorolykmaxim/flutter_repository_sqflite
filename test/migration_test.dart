import 'package:flutter_repository_sqflite/flutter_repository_sqflite.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:sqflite/sqflite.dart';

import 'common.dart';

void main() {
  Database mockDatabase;
  DatabaseConnector connector;
  SqfliteDatabaseBuilder builder;
  setUp(() {
    mockDatabase = MockDatabase();
    connector = MockDatabaseConnector();
    when(connector.connect(any, version: anyNamed('version'), onUpgrade: anyNamed('onUpgrade')))
        .thenAnswer((_) => Future.value(mockDatabase));
    builder = SqfliteDatabaseBuilder();
    builder.connector = connector;
  });
  group('Migration', () {
    test('fails to build a database due to missing instructinos', () async {
      expect(builder.build(), throwsA(isInstanceOf<ArgumentError>()));
    });
    test('fully initializes database for the first time', () async {
      // when
      final database = await (builder
        ..databaseName = 'dummy.db'
        ..version = Version(2)
        ..instructions(MigrationInstructions(Version(2), [
          MigrationScript('ALTER TABLE USERS'),
          MigrationScript('CREATE TABLE LICENSES()')
        ]))
        ..instructions(MigrationInstructions(Version(1), [
          MigrationScript('CREATE TABLE USERS()'),
          MigrationScript('CREATE TABLE GROUP()')
        ])))
          .build();
      expect(database, isNotNull);
      final onUpgrade = verify(connector.connect('dummy.db',
          version: 2, onUpgrade: captureAnyNamed('onUpgrade')))
          .captured
          .single;
      await onUpgrade(mockDatabase, 0, 2);
      // then
      verifyInOrder([
        mockDatabase.execute('CREATE TABLE USERS()'),
        mockDatabase.execute('CREATE TABLE GROUP()'),
        mockDatabase.execute('ALTER TABLE USERS'),
        mockDatabase.execute('CREATE TABLE LICENSES()')
      ]);
    });
    test('updates existing database to a newer version', () async {
      // when
      final database = await (builder
        ..version = Version(4)
        ..instructions(MigrationInstructions(
            Version(1), [MigrationScript('CREATE TABLE MUFFIN()')]))
        ..instructions(MigrationInstructions(
            Version(2), [MigrationScript('CREATE TABLE PUMPKIN()')]))
        ..instructions(MigrationInstructions(
            Version(3), [MigrationScript('ALTER TABLE MUFFIN')]))
        ..instructions(MigrationInstructions(
            Version(4), [MigrationScript('DROP TABLE PUMPKIN')])))
          .build();
      expect(database, isNotNull);
      final onUpgrade = verify(connector.connect('database.db',
          version: 4, onUpgrade: captureAnyNamed('onUpgrade')))
          .captured
          .single;
      await onUpgrade(mockDatabase, 2, 4);
      // then
      verifyInOrder([
        mockDatabase.execute('ALTER TABLE MUFFIN'),
        mockDatabase.execute('DROP TABLE PUMPKIN')
      ]);
    });
  });
}