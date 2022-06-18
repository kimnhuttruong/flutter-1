// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/*@testedFeatures=inference*/
library test;

main() {
  var /*@type=() -> Iterable<Null>*/ f = /*@returnType=Iterable<Null>*/ () sync* {
    yield null;
  };
  Iterable y = f();
  Iterable<String> z = f();
  String s = f(). /*@target=Iterable::first*/ first;
}
