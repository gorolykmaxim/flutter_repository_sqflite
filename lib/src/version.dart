/// Version of a database.
class Version implements Comparable<Version> {
  int _value;

  /// Construct a version from the specified number.
  Version(int value) {
    if (value <= 0) {
      throw ArgumentError.value(value, 'value', 'Version number can only be a positive integer');
    }
    _value = value;
  }

  /// Return true if this [Version] is newer than the [olderVersion] and older
  /// or equal to the [newerVersion].
  bool isBetween(int olderVersion, int newerVersion) => _value > olderVersion && _value <= newerVersion;

  /// Convert this [Version] to an [int].
  int toInt() => _value;

  @override
  int compareTo(Version other) {
    return _value.compareTo(other.toInt());
  }
}
