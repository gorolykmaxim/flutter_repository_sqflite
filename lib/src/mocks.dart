import 'package:mockito/mockito.dart';
import 'package:sqflite/sqflite.dart';

import '../flutter_repository_sqflite.dart';

class SqfliteDatabaseMock extends Mock implements SqfliteDatabase {}

class SqfliteDatabaseBuilderMock extends Mock implements SqfliteDatabaseBuilder {}

class DatabaseExecutorMock extends Mock implements DatabaseExecutor {}