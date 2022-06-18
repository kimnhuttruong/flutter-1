// Copyright (c) 2019, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:analyzer/src/dart/error/hint_codes.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import '../dart/resolution/context_collection_resolution.dart';

main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(DuplicateShownNameTest);
  });
}

@reflectiveTest
class DuplicateShownNameTest extends PubPackageResolutionTest {
  test_hidden() async {
    newFile('$testPackageLibPath/lib1.dart', content: r'''
class A {}
class B {}
''');
    await assertErrorsInCode('''
export 'lib1.dart' show A, B, A;
''', [
      error(HintCode.DUPLICATE_SHOWN_NAME, 30, 1),
    ]);
  }
}
