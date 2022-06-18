lists
=====

Collection of the lists (BitList, FilledList, GroupedRangeList, ListPointer, RangeList, SparseBoolList, SparseList, StepList, WrappedList).

Version: 0.1.6

```dart
import "package:lists/lists.dart";

void main() {
  bitList();
  filledList();
  rangeList();
  sparseBoolList();
  sparseList();
  stepList();
  wrappedList();
}

void bitList() {
  // The bit state list with 65536 elements
  // Real size of the list (in memory) 30 times less
  // Exact size 2185 elements of 'Smi' values
  var list = new BitList(65536);
  list.set(32767);
  print(list.get(32767));

  // The list with 65536 elements set to true
  list = new BitList(65536, true);
  print(list.get(32767));

  // The list with 1073741824 elements
  list = new BitList(1073741824);
}

void filledList() {
  // The read only list with 40 values of "="
  var list = new FilledList<String>(40, "=");
  print("${list.join()}");

  // The list with 10000000000000 values of "hello"
  list = new FilledList<String>(10000000000000, "hello");
}

void rangeList() {
  // The values from 0 to 10
  var list = new RangeList(0, 10);
  print("${list.join(", ")}");

  // The same values in reversed order
  var reversed = list.reversed;
  print("${reversed.join(", ")}");

  // The same list with step 2
  var list2 = list.toStepList(2);
  print("${list2.join(", ")}");

  //  The values from -10000000000000 to 10000000000000
  list = new RangeList(10000000000000, 10000000000000);
}

void sparseBoolList() {
  // Really big size
  var length = 2 * 1024 * 1024 * 1024;
  var list = new SparseBoolList(length: length);
  var groupCount = 0;
  var offset = 0;
  print("SparseBoolList: ${_format(length)} length.");
  var sw = new Stopwatch();
  sw.start();
  while (true) {
    var size = 128 * 1024;
    list.setGroup(new GroupedRangeList(offset, offset + size, true));
    offset += size + 128 * 1024;
    groupCount++;
    if (offset >= length) {
      break;
    }
  }
  //
  sw.stop();
  var elapsed = (sw.elapsedMilliseconds / 1000);
  print("SparseBoolList: ${_format(groupCount)} groups added in $elapsed sec.");
  //
  var accessed = 0;
  var elementCount = length / 10;
  //
  sw.reset();
  sw.start();
  for (var i = 0; i < length; i += 100) {
    var x = list[i];
    accessed++;
  }

  sw.stop();
  elapsed = (sw.elapsedMilliseconds / 1000);
  print(
      "SparseBoolList: ${_format(accessed)} elements accessed in $elapsed sec.");
}

void sparseList() {
  // Count is 50000 elements
  var count = 50000;
  var list = new SparseList();
  var offset = 0;
  var sw = new Stopwatch();
  sw.start();
  for (var i = 0; i < count; i++) {
    offset += 100;
    var size = 100;
    //list.addGroup(_grp(offset, offset + size, i));
    list.addGroup(new GroupedRangeList(offset, offset + size, i));
    offset += size;
  }

  sw.stop();
  var elapsed = (sw.elapsedMilliseconds / 1000);
  print("SparseList: ${_format(count)} groups added in $elapsed sec.");
  // Access all elements
  sw.reset();
  sw.start();
  var length = list.length;
  for (var i = 0; i < length; i++) {
    var x = list[i];
  }

  sw.stop();
  elapsed = (sw.elapsedMilliseconds / 1000);
  print("SparseList: ${_format(length)} elements accessed in $elapsed sec.");
}

void stepList() {
  // The values from 0 to 10
  var list = new StepList(0, 10);
  print("${list.join(", ")}");

  // The values from 10 to 0
  list = new StepList(10, 0);
  print("${list.join(", ")}");

  // The values from 0 to 10 with step 2
  list = new StepList(0, 10, 2);
  print("${list.join(", ")}");

  // The values from 10 to 0 with step -2
  list = new StepList(10, 0, -2);
  print("${list.join(", ")}");

  // The values from 0 to 255 with step 64
  const MIN_BYTE = 0;
  const MAX_BYTE = 255;
  list = new StepList(MIN_BYTE, MAX_BYTE, (MAX_BYTE >> 2) + 1);
  print("${list.join(", ")}");

  // The values from -10000000000000 to 10000000000000 with step 1
  list = new StepList(-10000000000000, 10000000000000);
}

void wrappedList() {
  // The read only wrapper for list
  var source = [0, 1, 2, 3];
  var list = new WrappedList<int>(source);
  try {
    list[0] = 0;
  } catch (e) {
    print("$e");
  }

  try {
    list.length = 0;
  } catch (e) {
    print("$e");
  }
}

String _format(int number) {
  var string = number.toString();
  var length = string.length;
  var list = <String>[];
  var count = 0;
  for (var i = length - 1; i >= 0; i--) {
    list.add(string[i]);
    if (count++ == 2) {
      list.add(" ");
      count = 0;
    }
  }

  return list.reversed.join();
}
```
