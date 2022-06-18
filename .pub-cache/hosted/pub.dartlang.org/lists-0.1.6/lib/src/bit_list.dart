part of lists;

class BitList extends Object with ListMixin<bool> {
  int _length;

  List<int> _list;

  BitList(int length, [bool fill]) {
    if (length == null || length < 0) {
      throw ArgumentError('length: $length');
    }

    _length = length;
    final slots = (length - 1) ~/ 30 + 1;
    if (fill == true) {
      _list = List<int>.filled(slots, 0x3fffffff);
    } else {
      _list = List<int>.filled(slots, 0);
    }
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
  bool operator [](int index) {
    if (index == null) {
      throw ArgumentError('index: $index');
    }

    if (index < 0 || index >= _length) {
      throw RangeError(index);
    }

    final slot = index ~/ 30;
    final position = slot * 30;
    final mask = 1 << (index - position);
    return (_list[slot] & mask) != 0;
  }

  @override
  void operator []=(int index, bool value) {
    if (index == null) {
      throw ArgumentError('index: $index');
    }

    if (index < 0 || index >= _length) {
      throw RangeError(index);
    }

    if (value == null) {
      throw ArgumentError('value: $value');
    }

    final slot = index ~/ 30;
    final position = slot * 30;
    final mask = 1 << (index - position);
    if (value) {
      _list[slot] |= mask;
    } else {
      _list[slot] &= 0x3fffffff ^ mask;
    }
  }

  /// Returns the state at specified [index].
  bool get(int index) => this[index];

  /// Resets the state to false at specified [index].
  void reset(int index) {
    this[index] = false;
  }

  /// Sets the state to true at specified [index].
  void set(int index) {
    this[index] = true;
  }
}
