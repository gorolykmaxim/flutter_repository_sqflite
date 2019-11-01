import 'package:flutter_repository/flutter_repository.dart';
import 'package:flutter_repository_sqflite/flutter_repository_sqflite.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:sqflite/sqflite.dart';

import 'common.dart';

class MockTransaction extends Mock implements Transaction {}

void main() {
  group('Transaction', () {
    const table = 'objects';
    const id = 12356;
    const objectData = "Object's data";
    final object = {'id': id, 'data': objectData};
    Transaction transaction;
    Database mockDatabase;
    SqfliteDatabase database;
    DataSource dataSource;
    setUp(() async {
      mockDatabase = MockDatabase();
      transaction = MockTransaction();
      database = await createDatabase(mockDatabase);
      dataSource = database.table(table);
    });
    test('runs all database operations in a transaction', () async {
      // given
      final expectedTransactionResponse = object;
      const newData = 'Updated data';
      when(transaction.query(table, where: '(id = ?)', whereArgs: [id], limit: defaultLimit, offset: defaultOffset))
          .thenAnswer((_) => Future.value([object]));
      when(mockDatabase.transaction<Map<String, dynamic>>(any))
          .thenAnswer((_) => Future.value(expectedTransactionResponse));
      // when
      final transactionResponse = await database.transactional(() async {
        final specification = Specification()
            .equals('id', id);
        final objects = await dataSource.find(specification);
        final actualObject = objects[0];
        actualObject['data'] = newData;
        await dataSource.update(EntityContext(actualObject, ['id']));
        return actualObject;
      });
      final executeTransaction = verify(mockDatabase.transaction(captureAny)).captured.single;
      final actualObject = await executeTransaction(transaction);
      // then
      expect(transactionResponse, expectedTransactionResponse);
      expect(actualObject, object);
      expect(actualObject['data'], newData);
      verify(transaction.update(table, {'data': newData}, where: '(id = ?)',
          whereArgs: [id], conflictAlgorithm: ConflictAlgorithm.rollback)).called(1);
      verifyNever(mockDatabase.query(table, where: '(id = ?)', whereArgs: [id], 
          limit: defaultLimit, offset: defaultOffset));
      verifyNever(mockDatabase.update(table, {'data': newData},
          where: '(id = ?)', whereArgs: [id],
          conflictAlgorithm: ConflictAlgorithm.rollback));
    });
  });
}