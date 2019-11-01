import 'package:flutter_repository/flutter_repository.dart';
import 'package:flutter_repository_sqflite/flutter_repository_sqflite.dart';
import 'package:sqflite/sqflite.dart';

import 'exceptions.dart' as exceptions;

/// In case a [Specification] is passed to either a [SqfliteReadonlyDataSource]
/// or [SqfliteDataSource] without a limit value specified, this default value
/// will be used.
const defaultLimit = 100;

/// In case a [Specification] is passed to either a [SqfliteReadonlyDataSource]
/// or [SqfliteDataSource] without an offset value specified, this default value
/// will be used.
const defaultOffset = 0;

/// Proxy to the actual [DatabaseExecutor].
///
/// A single instance of this [DatabaseExecutorProxy] is used by all created
/// [SqfliteDataSource]s and [SqfliteReadonlyDataSource]s. The actual [executor]
/// can be either a [Database] or a [Transaction].
///
/// Having [DatabaseExecutorProxy] allows to choose appropriate [executor]
/// globally for all created [SqfliteDataSource]s and
/// [SqfliteReadonlyDataSource]s at a runtime. [SqfliteDatabase.transactional]
/// is based of this principle.
class DatabaseExecutorProxy implements DatabaseExecutor {

  /// Currently used [DatabaseExecutor] to run all SQL commands.
  DatabaseExecutor executor;

  /// Create [DatabaseExecutorProxy] for the specified [executor].
  DatabaseExecutorProxy(this.executor);

  @override
  Batch batch() {
    return executor.batch();
  }

  @override
  Future<int> delete(String table, {String where, List whereArgs}) {
    return executor.delete(table, where: where, whereArgs: whereArgs);
  }

  @override
  Future<void> execute(String sql, [List arguments]) {
    return executor.execute(sql, arguments);
  }

  @override
  Future<int> insert(String table, Map<String, dynamic> values,
      {String nullColumnHack, ConflictAlgorithm conflictAlgorithm}) {
    return executor.insert(table, values, nullColumnHack: nullColumnHack,
        conflictAlgorithm: conflictAlgorithm);
  }

  @override
  Future<List<Map<String, dynamic>>> query(String table,
      {bool distinct, List<String> columns, String where, List whereArgs,
        String groupBy, String having, String orderBy, int limit, int offset}) {
    return executor.query(table, distinct: distinct, columns: columns,
        where: where, whereArgs: whereArgs, groupBy: groupBy, having: having,
        orderBy: orderBy, limit: limit, offset: offset);
  }

  @override
  Future<int> rawDelete(String sql, [List arguments]) {
    return executor.rawDelete(sql, arguments);
  }

  @override
  Future<int> rawInsert(String sql, [List arguments]) {
    return executor.rawInsert(sql, arguments);
  }

  @override
  Future<List<Map<String, dynamic>>> rawQuery(String sql, [List arguments]) {
    return executor.rawQuery(sql, arguments);
  }

  @override
  Future<int> rawUpdate(String sql, [List arguments]) {
    return executor.rawUpdate(sql, arguments);
  }

  @override
  Future<int> update(String table, Map<String, dynamic> values,
      {String where, List whereArgs, ConflictAlgorithm conflictAlgorithm}) {
    return executor.update(table, values, where: where, whereArgs: whereArgs,
        conflictAlgorithm: conflictAlgorithm);
  }
}

const _conditionTypeToSqlValue = {
  ConditionType.and: 'AND',
  ConditionType.or: 'OR'
};

class _Where {
  final String statement;
  final List<dynamic> arguments;

  factory _Where.fromEntity(EntityContext context) {
    final List<String> statements = [];
    final values = [];
    final Map<String, dynamic> entity = context.entity;
    for (String idField in context.idFieldNames) {
      statements.add('$idField = ?');
      values.add(entity[idField]);
    }
    final statement = '(${statements.join(' AND ')})';
    return _Where(statement.isNotEmpty ? statement : null,
        values.isNotEmpty ? values : null);
  }

  factory _Where.fromSpecification(Specification specification) {
    Condition rootCondition = Condition.and(specification.conditions);
    final values = [];
    final statements = _toSql(rootCondition, values);
    return _Where(statements.isNotEmpty ? statements : null,
        values.isNotEmpty ? values : null);
  }

  _Where(this.statement, this.arguments);

  static String _toSql(Condition condition, List<dynamic> values) {
    // This recursive graph traversal might become performance bottleneck
    // one day. DFS version was very tricky to implement at a time.
    if (condition.children.isEmpty) {
      // We are processing a simple condition.
      String statement;
      switch (condition.type) {
        case ConditionType.equals:
          statement = '${condition.field} = ?';
          break;
        case ConditionType.lessThan:
          statement = '${condition.field} < ?';
          break;
        case ConditionType.greaterThan:
          statement = '${condition.field} > ?';
          break;
        case ConditionType.contains:
          statement = '${condition.field} LIKE ?';
          break;
        case ConditionType.containsIgnoreCase:
          statement = 'LOWER(${condition.field}) LIKE LOWER(?)';
          break;
        default:
          statement = null; // Ignore other unsupported condition types
      }
      if (statement != null) {
        values.add(condition.value);
        return statement;
      } else {
        return '';
      }
    } else {
      // We are processing a group of either groups or simple conditions.
      return '(${condition.children.map((c) => _toSql(c, values)).where((c) => c.isNotEmpty).join(' ${_conditionTypeToSqlValue[condition.type]} ')})';
    }
  }
}

const _orderTypeToSqlValue = {OrderType.asc: 'ASC', OrderType.desc: "DESC"};

class _OrderBy {
  final String statement;

  factory _OrderBy.from(Specification specification) {
    final List<String> statements = [];
    for (Order order in specification.orderDefinitions) {
      statements.add('${order.field} ${_orderTypeToSqlValue[order.type]}');
    }
    final statement = statements.join(', ');
    return _OrderBy(statement.isNotEmpty ? statement : null);
  }

  _OrderBy(this.statement);
}

/// sqflite-based implementation of [ReadonlyDataSource].
///
/// Useful when you need to provide a read-only access to a various relational
/// database entities, like views.
class SqfliteReadonlyDataSource implements ReadonlyDataSource {
  final String _table;
  final DatabaseExecutorProxy _proxy;

  /// Construct [SqfliteReadonlyDataSource] for the [_table], that should
  /// execute all of it's queries via the [_proxy].
  SqfliteReadonlyDataSource(this._table, this._proxy);

  @override
  Future<List<Map<String, dynamic>>> find(Specification specification) async {
    try {
      final where = _Where.fromSpecification(specification);
      final orderBy = _OrderBy.from(specification);
      return await _proxy.query(_table, where: where.statement,
          whereArgs: where.arguments, limit: specification.limit ?? 100,
          offset: specification.offset ?? 0, orderBy: orderBy.statement);
    } on Exception catch (e) {
      throw exceptions.DatabaseException.query(_table, specification, e);
    }
  }
}

/// sqflite-based implementation of [DataSource].
///
/// Should be used in most cases against a database entities, that can be
/// both queried and modified (like normal tables).
class SqfliteDataSource extends SqfliteReadonlyDataSource implements DataSource {
  final ConflictAlgorithm _conflictAlgorithm;

  /// Construct [SqfliteDataSource] for the [table], that should execute all
  /// of it's commands via the [proxy].
  ///
  /// You can also specify [ConflictAlgorithm] for all modifying queries,
  /// via [conflictAlgorithm].
  SqfliteDataSource(String table, DatabaseExecutorProxy proxy,
      {ConflictAlgorithm conflictAlgorithm = ConflictAlgorithm.rollback})
      : _conflictAlgorithm = conflictAlgorithm, super(table, proxy);

  @override
  Future<void> create(Iterable<EntityContext> entityContexts) async {
    try {
      final batch = _proxy.batch();
      for (EntityContext context in entityContexts) {
        batch.insert(_table, context.entity, conflictAlgorithm: _conflictAlgorithm);
      }
      await batch.commit(noResult: true);
    } on Exception catch (e) {
      throw exceptions.DatabaseException.create(_table, entityContexts, e);
    }
  }

  @override
  Future<void> remove(Iterable<EntityContext> entityContexts) async {
    try {
      final batch = _proxy.batch();
      for (EntityContext context in entityContexts) {
        final where = _Where.fromEntity(context);
        batch.delete(_table, where: where.statement, whereArgs: where.arguments);
      }
      await batch.commit(noResult: true);
    } on Exception catch (e) {
      throw exceptions.DatabaseException.remove(_table, entityContexts, e);
    }
  }

  @override
  Future<void> removeMatching(Specification specification) async {
    try {
      final where = _Where.fromSpecification(specification);
      await _proxy.delete(_table, where: where.statement, whereArgs: where.arguments);
    } on Exception catch (e) {
      throw exceptions.DatabaseException.remove(_table, specification, e);
    }
  }

  @override
  Future<void> update(EntityContext entityContext) async {
    try {
      final where = _Where.fromEntity(entityContext);
      // Do not try to update ID fields of entity.
      final entity = Map.of(entityContext.entity);
      for (String idField in entityContext.idFieldNames) {
        entity.remove(idField);
      }
      await _proxy.update(_table, entity, where: where.statement,
          whereArgs: where.arguments, conflictAlgorithm: _conflictAlgorithm);
    } on Exception catch (e) {
      throw exceptions.DatabaseException.update(_table, entityContext, e);
    }
  }
}
