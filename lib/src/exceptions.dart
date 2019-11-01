import 'package:flutter_repository/flutter_repository.dart';

/// [DataSource] or [ReadonlyDataSource] has failed to perform an operation
/// against an underlying database.
class DatabaseException implements Exception {

  /// Database action, that has failed.
  final String action;

  /// Name of the table against which the [action] was being executed.
  final String table;

  /// Auxiliary information about the failure.
  final dynamic context;

  /// Root cause of this [DatabaseException].
  final Exception cause;

  /// Construct an exception.
  DatabaseException(this.action, this.table, this.context, this.cause);

  /// Construct an exception of creating a record in the [table].
  DatabaseException.create(this.table, this.context, this.cause): action = 'create';

  /// Construct an exception of updating a record in the [table].
  DatabaseException.update(this.table, this.context, this.cause): action = 'update';

  /// Construct an exception of removing a record from the [table].
  DatabaseException.remove(this.table, this.context, this.cause): action = 'remove';

  /// Construct an exception of querying a [table].
  DatabaseException.query(this.table, this.context, this.cause): action = 'query';

  @override
  String toString() {
    return "Failed to do $action on table '$table'. Context: $context. Reason: $cause";
  }
}
