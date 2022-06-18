part of lists;

class WrappedList<E> extends Object with ListMixin<E> {
  List<E> _source;

  WrappedList(List<E> source) {
    if (source == null) {
      throw ArgumentError('source: $source');
    }

    _source = source;
  }

  /// Returns the length of list.
  @override
  int get length => _source.length;

  /// Sets the length of list.
  @override
  set length(int length) {
    throw UnsupportedError('length=');
  }

  @override
  E operator [](int index) => _source[index];

  @override
  void operator []=(int index, E value) {
    throw UnsupportedError('operator []=');
  }

  /// Returns the string representation of range.
  @override
  String toString() => _source.toString();
}
