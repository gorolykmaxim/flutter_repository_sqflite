import 'package:flutter_repository_sqflite/src/version.dart';
import 'package:sqflite/sqflite.dart';

/// A set of [MigrationScript]s, that should be performed on a database in order
/// to migrate it from the earlier schema version to a newer schema version.
///
/// Each instance of [MigrationInstructions] targets specific schema version,
/// meaning that when an app needs to update it's schema from version 2 to
/// version 3, [MigrationInstructions] with [_targetVersion] set to 3 would
/// get executed.
///
/// Initial database initialization is also considered a migration, though
/// this case is a migration from version 0 to version 1.
class MigrationInstructions implements Comparable<MigrationInstructions> {
  Version _targetVersion;
  Iterable<MigrationScript> _migrationScripts;

  /// Create a migration instructions to migrate database to [_targetVersion]
  /// by executing [_migrationScripts].
  MigrationInstructions(this._targetVersion, this._migrationScripts);

  /// Return true if these [MigrationInstructions] should be executed during
  /// migration from [oldVersion] to [newVersion].
  bool shouldBeExecuted(int oldVersion, int newVersion) => _targetVersion.isBetween(oldVersion, newVersion);

  /// Execute these [MigrationInstructions] against a database using [executor].
  Future<void> execute(DatabaseExecutor executor) async {
    for (MigrationScript script in _migrationScripts) {
      await script.execute(executor);
    }
  }

  @override
  int compareTo(MigrationInstructions other) {
    return _targetVersion.compareTo(other._targetVersion);
  }
}

/// A single migration instruction, that performs one SQL statement.
///
/// In case you need to do some complex migration routines, like fetching
/// all records from an old table, dropping table, creating a new one and
/// populating it with fetched records, you can simply inherit [MigrationScript]
/// and override it's [execute] method.
class MigrationScript {
  String _sql;

  /// Create migration script, that will execute [_sql].
  MigrationScript(this._sql);

  /// Execute this [MigrationScript] using [executor].
  Future<void> execute(DatabaseExecutor executor) async {
    await executor.execute(_sql);
  }
}
