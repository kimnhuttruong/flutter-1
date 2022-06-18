part of lists;

/// Sparse bool list based on the grouped range lists.
class SparseBoolList extends SparseList<bool> {
  SparseBoolList({int length}) : super(length: length, defaultValue: false);

  /// Sets the values ​​in accordance with the specified [group] and increases
  /// (if required) the length up to (range.end + 1).
  @override
  void addGroup(GroupedRangeList<bool> group) {
    if (group == null) {
      throw ArgumentError('group: $group');
    }

    if (group.key is! bool) {
      throw ArgumentError("Key '${group.key}' must be of type 'bool'.");
    }

    super.addGroup(group);
  }

  /// Sets the values ​​in accordance with the specified [group].
  @override
  void setGroup(GroupedRangeList<bool> group) {
    if (group == null) {
      throw ArgumentError('group: $group');
    }

    if (group.key is! bool) {
      throw ArgumentError("Key '${group.key}' must be of type 'bool'.");
    }

    super.setGroup(group);
  }
}
