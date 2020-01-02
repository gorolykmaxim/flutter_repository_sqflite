import 'package:flutter_repository/flutter_repository.dart';
import 'package:flutter_repository_sqflite/src/version.dart';
import 'package:sqflite/sqflite.dart';

import 'src/data_source.dart';
import 'src/migration.dart';

export 'src/persistence.dart';
export 'src/exceptions.dart';
export 'src/migration.dart';
export 'src/version.dart';
export 'src/data_source.dart' show defaultLimit, defaultOffset;

/// A connector, that is used to open a connection to a database.
///
/// The only purpose of this class is to stub call to [openDatabase(path)], so
/// just ignore this class.
class DatabaseConnector {
  /// Open a connection to the SQLite database, stored in the specified file.
  ///
  /// For arguments descriptions refer to [openDatabase(path)].
  Future<Database> connect(String path, {int version,
    OnDatabaseConfigureFn onConfigure, OnDatabaseCreateFn onCreate,
    OnDatabaseVersionChangeFn onUpgrade, OnDatabaseVersionChangeFn onDowngrade,
    OnDatabaseOpenFn onOpen, bool readOnly = false,
    bool singleInstance = true}) async {
    return await openDatabase(path, version: version, onConfigure: onConfigure,
        onCreate: onCreate, onUpgrade: onUpgrade, onDowngrade: onDowngrade,
        onOpen: onOpen, readOnly: readOnly, singleInstance: singleInstance);
  }
}

/// Builder used to construct [SqfliteDatabase] instance.
class SqfliteDatabaseBuilder {

  /// Connector, used to open connection to a database.
  DatabaseConnector connector = DatabaseConnector();
  List<MigrationInstructions> _migrationInstructionsList = [];

  /// Name of the file, where the database is/should be located.
  String databaseName = 'database.db';

  /// Current version of the database. When updating your application to use
  /// a new version of database schema - remember to specify a new version
  /// in the builder as well.
  Version version = Version(1);

  /// Add [MigrationInstructions], to be executed on connecting to the specified
  /// database for the first time.
  void instructions(MigrationInstructions instructions) {
    _migrationInstructionsList.add(instructions);
  }

  /// Build a [SqfliteDatabase] instance.
  Future<SqfliteDatabase> build() async {
    if (_migrationInstructionsList.isEmpty) {
      throw ArgumentError('No migration instructions were specified. '
          'This means that no tables will be created, '
          'which makes this database useless. '
          'Specify migration instructions using instruction().');
    }
    _migrationInstructionsList.sort();
    final database = await connector.connect(databaseName,
        version: version.toInt(),
        onUpgrade: (database, oldVersion, newVersion) async {
      for (MigrationInstructions instructions in _migrationInstructionsList) {
        if (instructions.shouldBeExecuted(oldVersion, newVersion)) {
          await instructions.execute(database);
        }
      }
    });
    return SqfliteDatabase(database, DatabaseExecutorProxy(database));
  }
}

/// Represents an SQLite database.
class SqfliteDatabase {
  final Database _database;
  final DatabaseExecutorProxy _proxy;

  /// Construct a database of an [SqfliteDatabase] [_database].
  ///
  /// Specify a [_proxy], which should be used to run all the queries to the
  /// [_database].
  SqfliteDatabase(this._database, this._proxy);

  /// Create a [ReadonlyDataSource], that will look for data in the [table],
  /// which can be a table or a view.
  ReadonlyDataSource readonlyTable(String table) => SqfliteReadonlyDataSource(table, _proxy);

  /// Create a [DataSource], that will provide access to the [table].
  DataSource table(String table) => SqfliteDataSource(table, _proxy);

  /// Execute [f] in scope of a single transaction and return it's result.
  ///
  /// All operations, executed by any [DataSource]s and [ReadonlyDataSource]s,
  /// created by this [SqfliteDatabase] and executed inside [f], will be
  /// executed in a single transaction.
  Future<T> transactional<T>(Future<T> f()) async {
    return await _database.transaction((transaction) async {
      try {
        _proxy.executor = transaction;
        return await f();
      } finally {
        _proxy.executor = _database;
      }
    });
  }
}
