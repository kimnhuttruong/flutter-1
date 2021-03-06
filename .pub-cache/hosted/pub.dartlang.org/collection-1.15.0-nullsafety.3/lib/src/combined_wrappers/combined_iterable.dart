// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:collection';

/// A view of several iterables combined sequentially into a single iterable.
///
/// All methods and accessors treat the [CombinedIterableView] as if it were a
/// single concatenated iterable, but the underlying implementation is based on
/// lazily accessing individual iterable instances. This means that if the
/// underlying iterables change, the [CombinedIterableView] will reflect those
/// changes.
class CombinedIterableView<T> extends IterableBase<T> {
  /// The iterables that this combines.
  final Iterable<Iterable<T>> _iterables;

  /// Creates a combined view of [iterables].
  const CombinedIterableView(this._iterables);

  @override
  Iterator<T> get iterator =>
      _CombinedIterator<T>(_iterables.map((i) => i.iterator).iterator);

  // Special cased contains/isEmpty/length since many iterables have an
  // efficient implementation instead of running through the entire iterator.

  @override
  bool contains(Object? element) => _iterables.any((i) => i.contains(element));

  @override
  bool get isEmpty => _iterables.every((i) => i.isEmpty);

  @override
  int get length => _iterables.fold(0, (length, i) => length + i.length);
}

/// The iterator for [CombinedIterableView].
///
/// This moves through each iterable's iterators in sequence.
class _CombinedIterator<T> implements Iterator<T> {
  /// The iterators that this combines.
  ///
  /// Because this comes from a call to [Iterable.map], it's lazy and will
  /// avoid instantiating unnecessary iterators.
  final Iterator<Iterator<T>> _iterators;

  /// The current iterator in [_iterators], or `null` if done iterating.
  Iterator<T>? _currentItr;

  _CombinedIterator(this._iterators) {
    _advance();
  }

  @override
  T get current => _iterators.current.current;

  @override
  bool moveNext() {
    if (_currentItr == null) return false;
    if (_currentItr!.moveNext()) {
      return true;
    } else {
      _advance();
    }
    return moveNext();
  }

  /// Advances [_currentItr] or sets it to `null` if there are no more entries
  /// in [_iterators].
  void _advance() {
    _currentItr = _iterators.moveNext() ? _iterators.current : null;
  }
}
