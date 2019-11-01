import 'package:flutter_repository/flutter_repository.dart';
import 'package:flutter_repository_sqflite/flutter_repository_sqflite.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:sqflite/sqflite.dart' as sqflite;

import 'common.dart';

class MockBatch extends Mock implements sqflite.Batch {}

void main() {
  const table = 'users';
  const userName = 'Tom';
  const expectedResults = [{'name': userName}];
  MockBatch batch;
  sqflite.Database database;
  Specification specification;
  group('ReadonlyDataSource', () {
    ReadonlyDataSource dataSource;
    setUp(() async {
      specification = Specification();
      database = MockDatabase();
      dataSource = (await createDatabase(database)).readonlyTable(table);
    });
    test('queries data source with a complex nested query', () async {
      // given
      const expectedWhere = '(name = ? AND (age > ? OR (age > ? AND hasFamily = ?) OR ((hasPermission = ? OR needsPermission = ?) AND funds > ?)))';
      when(database.query(table, where: expectedWhere, whereArgs: ['Tom', 15, 18, true, true, false, 125], limit: defaultLimit, offset: defaultOffset))
          .thenAnswer((_) => Future.value(expectedResults));
      specification.equals('name', userName);
      specification.add(Condition.or([
        Condition.greaterThan('age', 15),
        Condition.and([Condition.greaterThan('age', 18), Condition.equals('hasFamily', true)]),
        Condition.and([
          Condition.or([
            Condition.equals('hasPermission', true),
            Condition.equals('needsPermission', false),
          ]),
          Condition.greaterThan('funds', 125)
        ])
      ]));
      // when
      final results = await dataSource.find(specification);
      // then
      expect(results, expectedResults);
    });
    test('queries data source with limit and offset unspecified', () async {
      // given
      when(database.query(table, where: '(name = ?)', whereArgs: [userName], limit: defaultLimit, offset: defaultOffset))
          .thenAnswer((_) => Future.value(expectedResults));
      specification.equals('name', userName);
      // when
      final results = await dataSource.find(specification);
      // then
      expect(results, expectedResults);
    });
    test('queries data souce with limit and offset specified', () async {
      // given
      const limit = 25;
      const offset = 50;
      when(database.query(table, where: '(name = ?)', whereArgs: [userName], limit: limit, offset: offset))
          .thenAnswer((_) => Future.value(expectedResults));
      specification.equals('name', userName);
      specification.limit = limit;
      specification.offset = offset;
      // when
      final results = await dataSource.find(specification);
      // then
      expect(results, expectedResults);
    });
    test('queries data source without building WHERE statement', () async {
      // given
      when(database.query(table, limit: defaultLimit, offset: defaultOffset))
          .thenAnswer((_) => Future.value(expectedResults));
      // when
      final results = await dataSource.find(specification);
      // then
      expect(results, expectedResults);
    });
    test('queries data source with ORDER BY specified', () async {
      // given
      when(database.query(table, orderBy: 'name ASC, age DESC', limit: defaultLimit, offset: defaultOffset))
          .thenAnswer((_) => Future.value(expectedResults));
      specification.appendOrderDefinition(Order.ascending('name'));
      specification.appendOrderDefinition(Order.descending('age'));
      // when
      final results = await dataSource.find(specification);
      // then
      expect(results, expectedResults);
    });
    test('fails to query database', () async {
      // given
      when(database.query(table, limit: defaultLimit, offset: defaultOffset))
          .thenAnswer((_) => Future.error(MockException()));
      // when
      expect(dataSource.find(specification), throwsA(isInstanceOf<DatabaseException>()));
    });
  });
  group('DataSource', () {
    DataSource dataSource;
    EntityContext context;
    Map<String, dynamic> updateEntity;
    setUp(() async {
      database = MockDatabase();
      batch = MockBatch();
      specification = Specification();
      context = EntityContext({'id': 15, 'name': 'Tom', 'age': 15}, ['id']);
      updateEntity = {
        'name': context.entity['name'],
        'age': context.entity['age']
      };
      when(database.batch()).thenReturn(batch);
      dataSource = (await createDatabase(database)).table(table);
    });
    test('creates a batch of entities', () async {
      // when
      await dataSource.create([context]);
      // then
      verifyInOrder([
        batch.insert(table, context.entity, conflictAlgorithm: sqflite.ConflictAlgorithm.rollback),
        batch.commit(noResult: true)
      ]);
    });
    test('fails to create a batch of entities', () async {
      // given
      when(batch.commit(noResult: true)).thenAnswer((_) => Future.error(MockException()));
      // when
      expect(dataSource.create([context]), throwsA(isInstanceOf<DatabaseException>()));
    });
    test('removes a batch of entities', () async {
      // when
      await dataSource.remove([context]);
      // then
      verifyInOrder([
        batch.delete(table, where: '(id = ?)', whereArgs: [context.entity['id']]),
        batch.commit(noResult: true)
      ]);
    });
    test('fails to remove a batch of entities', () async {
      // given
      when(batch.commit(noResult: true)).thenAnswer((_) => Future.error(MockException()));
      // when
      expect(dataSource.remove([context]), throwsA(isInstanceOf<DatabaseException>()));
    });
    test('removes all entities, matching the specification', () async {
      // given
      const age = 14;
      specification.greaterThan('age', age);
      // when
      await dataSource.removeMatching(specification);
      // then
      verify(database.delete(table, where: '(age > ?)', whereArgs: [age])).called(1);
    });
    test('removes all entities', () async {
      // when
      await dataSource.removeMatching(specification);
      // then
      verify(database.delete(table)).called(1);
    });
    test('fails to remove entities, matching the specification', () async {
      // given
      const name = 'Tom';
      specification.equals('name', name);
      when(database.delete(table, where: '(name = ?)', whereArgs: [name]))
          .thenAnswer((_) => Future.error(MockException()));
      // when
      expect(dataSource.removeMatching(specification), throwsA(isInstanceOf<DatabaseException>()));
    });
    test('updates entity', () async {
      // when
      await dataSource.update(context);
      // then
      verify(database.update(table, updateEntity, where: '(id = ?)',
          whereArgs: [context.entity['id']],
          conflictAlgorithm: sqflite.ConflictAlgorithm.rollback)).called(1);
    });
    test('fails to update entity', () async {
      // given
      when(database.update(table, updateEntity, where: '(id = ?)',
          whereArgs: [context.entity['id']],
          conflictAlgorithm: sqflite.ConflictAlgorithm.rollback))
          .thenAnswer((_) => Future.error(MockException()));
      // when
      expect(dataSource.update(context), throwsA(isInstanceOf<DatabaseException>()));
    });
  });
}