part of lists;

/// List which are points to the other list at the specified index.
/// var plist = new ListPointer(base, 20);
/// print(plist[-1]); // base[19]
/// print(plist[0]);  // base[20]
class ListPointer<T> extends Object with ListMixin<T> {
  final List<T> base;

  int _offset = 0;

  /// Creates the list pointer.
  ///
  /// Parameters:
  ///   [List] base
  ///   Base list to be pointed.
  ///
  ///   [int] offset
  ///   Offset in the base list.
  ListPointer(this.base, [int offset = 0]) {
    if (base == null) {
      throw ArgumentError.notNull('base');
    }

    if (offset == null) {
      throw ArgumentError.notNull('offset');
    }

    _offset = offset;
  }

  @override
  int get length => base.length - _offset;

  @override
  set length(int length) {
    throw UnsupportedError('set length');
  }

  /// Gets the offset.
  int get offset => _offset;

  /// Sets the offset.
  set offset(int offset) {
    if (offset == null) {
      throw ArgumentError.notNull('offset');
    }

    _offset = offset;
  }

  @override
  ListPointer<T> operator +(other) {
    if (other is int) {
      final i = other as int;
      return ListPointer<T>(base, offset + i);
    }

    throw ArgumentError.value(other, 'other');
  }

  ListPointer<T> operator -(other) {
    if (other is int) {
      return ListPointer<T>(base, offset - other);
    }

    throw ArgumentError.value(other, 'other');
  }

  bool operator <(other) {
    if (other is ListPointer) {
      if (identical(base, other.base)) {
        return offset < other.offset;
      }
    } else if (other is List) {
      if (identical(base, other)) {
        return offset < 0;
      }
    }

    return false;
  }

  bool operator <=(other) {
    if (other is ListPointer) {
      if (identical(base, other.base)) {
        return offset <= other.offset;
      }
    } else if (other is List) {
      if (identical(base, other)) {
        return offset <= 0;
      }
    }

    return false;
  }

  @override
  bool operator ==(other) {
    if (other is ListPointer) {
      if (identical(base, other.base)) {
        if (offset == other.offset) {
          return true;
        }
      }
    } else if (other is List) {
      if (identical(base, other)) {
        if (offset == 0) {
          return true;
        }
      }
    }

    return false;
  }

  bool operator >(other) {
    if (other is ListPointer) {
      if (identical(base, other.base)) {
        return offset > other.offset;
      }
    } else if (other is List) {
      if (identical(base, other)) {
        return offset > 0;
      }
    }

    return false;
  }

  bool operator >=(other) {
    if (other is ListPointer) {
      if (identical(base, other.base)) {
        return offset >= other.offset;
      }
    } else if (other is List) {
      if (identical(base, other)) {
        return offset >= 0;
      }
    }

    return false;
  }

  @override
  T operator [](int index) {
    if (index == null) {
      throw ArgumentError.notNull('index');
    }

    return base[_offset + index];
  }

  @override
  void operator []=(int index, value) {
    base[_offset + index] = value;
  }

  ListPointer<T> increment(int n) {
    return ListPointer<T>(base, offset + n);
  }
}
