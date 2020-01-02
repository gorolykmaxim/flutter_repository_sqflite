import 'package:flutter_repository_sqflite/flutter_repository_sqflite.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

class SqfliteDatabaseMock extends Mock implements SqfliteDatabase {}

class SqfliteDatabaseBuilderMock extends Mock implements SqfliteDatabaseBuilder {}

class PersistenceMock extends Mock implements Persistence {}

void main() {
  group('ApplicationPersistence', () {
    final version = Version(1);
    SqfliteDatabase database;
    SqfliteDatabaseBuilder builder;
    List<Persistence> persistenceUnits;
    ApplicationPersistence applicationPersistence;
    setUp(() {
      database = SqfliteDatabaseMock();
      builder = SqfliteDatabaseBuilderMock();
      when(builder.build()).thenAnswer((_) => Future.value(database));
      persistenceUnits = [
        PersistenceMock(),
        PersistenceMock()
      ];
      applicationPersistence = ApplicationPersistence(
          version,
          persistenceUnits,
          builder: builder
      );
    });
    test('builds database by applying all persistence units to builder', () async {
      // when
      await applicationPersistence.initialize();
      // then
      for (var persistence in persistenceUnits) {
        verify(persistence.initializeIn(builder));
      }
    });
    test('notifies each persistence unit about created database', () async {
      // when
      await applicationPersistence.initialize();
      // then
      for (var persistence in persistenceUnits) {
        verify(persistence.setDatabase(database));
      }
    });
    test('sets specified version to builder', () async {
      // when
      await applicationPersistence.initialize();
      // then
      verify(builder.version = version);
    });
    test('sets database name to builder, if it is specified', () async {
      // given
      const name = 'my-database';
      applicationPersistence = ApplicationPersistence(
          version,
          persistenceUnits,
          builder: builder,
          databaseName: name
      );
      // when
      await applicationPersistence.initialize();
      // then
      verify(builder.databaseName = name);
    });
    test('does not set database name to builder, if it is not specified', () async {
      // when
      await applicationPersistence.initialize();
      // then
      verifyNever(builder.databaseName = null);
    });
    test('does not allow creating application persistence without specifying a version', () {
      expect(() => ApplicationPersistence(null, persistenceUnits), throwsA(isInstanceOf<AssertionError>()));
    });
    test('does not allow creating application persistence without specifying persitence units', () {
      expect(() => ApplicationPersistence(version, null), throwsA(isInstanceOf<AssertionError>()));
    });
    test('does not allow creating application persistence specifying no persistence units', () {
      expect(() => ApplicationPersistence(version, []), throwsA(isInstanceOf<AssertionError>()));
    });
  });
}