part of lists;

class FilledList<E> extends Object with ListMixin<E> {
  E _fill;

  int _length;

  FilledList(int length, E fill) {
    if (length == null || length < 0) {
      throw ArgumentError('length: $length');
    }

    _fill = fill;
    _length = length;
  }

  /// Returns the length of list.
  @override
  int get length => _length;

  /// Sets the length of list.
  @override
  set length(int length) {
    throw UnsupportedError('length=');
  }

  @override
  E operator [](int index) {
    if (index == null) {
      throw ArgumentError('index: $index');
    }

    if (index < 0 || index >= _length) {
      throw RangeError(index);
    }

    return _fill;
  }

  @override
  void operator []=(int index, E value) {
    throw UnsupportedError('operator []=');
  }
}
