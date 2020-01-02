import 'package:flutter_repository/flutter_repository.dart';
import 'package:flutter_repository_sqflite/flutter_repository_sqflite.dart';

/// Persistent representation of a domain entity or a group of domain entities.
///
/// Persistences know how domain entities are stored in the database.
/// Two major responsibilities of a persistence are:
/// - initialize all database structures, necessary to properly store it's
/// entities
/// - construct [ImmutableCollection]s and [Collection]s that would provide
/// application an access to the underlying database
abstract class Persistence {
  /// Pass all the [MigrationInstructions] to [builder], that are necessary to
  /// store corresponding entities in the constructed database.
  void initializeIn(SqfliteDatabaseBuilder builder);
  /// Receive reference to the constructed [database], that is ready to store
  /// data.
  void setDatabase(SqfliteDatabase database);
}

/// Global application-level persistence that unites all [Persistence]s together.
///
/// Use this abstraction in mid-to-large applications were more than one
/// [Persistence] exists: it will help you organize your code better.
class ApplicationPersistence {
  final Version _currentVersion;
  final Iterable<Persistence> _persistenceUnits;
  final String _databaseName;
  final SqfliteDatabaseBuilder _builder;

  /// Create application-level persistence.
  /// Underlying database will be initialized with [_currentVersion] while
  /// initializing all [_persistenceUnits] using it.
  ApplicationPersistence(
      this._currentVersion,
      this._persistenceUnits,
      {
        String databaseName,
        SqfliteDatabaseBuilder builder,
      }
  ) : assert(_currentVersion != null, 'current version must always be specified'),
      assert(_persistenceUnits != null && _persistenceUnits.isNotEmpty, 'Persistence units are used to populate database with tables. Specifying no persistence units will create an empty database, which is pointless.'),
      this._databaseName = databaseName,
      this._builder = builder ?? SqfliteDatabaseBuilder();

  /// Initialize application persistence and create a database.
  Future<void> initialize() async {
    _builder.version = _currentVersion;
    if (_databaseName != null) {
      _builder.databaseName = _databaseName;
    }
    _persistenceUnits.forEach((p) => p.initializeIn(_builder));
    final database = await _builder.build();
    _persistenceUnits.forEach((p) => p.setDatabase(database));
  }
}