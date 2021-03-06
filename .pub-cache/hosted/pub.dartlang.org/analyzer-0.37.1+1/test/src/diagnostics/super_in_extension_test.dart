// Copyright (c) 2019, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/src/error/codes.dart';
import 'package:analyzer/src/generated/engine.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import '../dart/resolution/driver_resolution.dart';

main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(SuperInExtensionTest);
  });
}

@reflectiveTest
class SuperInExtensionTest extends DriverResolutionTest {
  @override
  AnalysisOptionsImpl get analysisOptions => AnalysisOptionsImpl()
    ..contextFeatures = new FeatureSet.forTesting(
        sdkVersion: '2.3.0', additionalFeatures: [Feature.extension_methods]);

  test_binaryOperator_inMethod() async {
    // TODO(brianwilkerson) Ensure that only one diagnostic is produced.
    await assertErrorsInCode('''
extension E on int {
  int plusOne() => super + 1;
}
''', [
      error(CompileTimeErrorCode.SUPER_IN_EXTENSION, 40, 5),
      error(StaticTypeWarningCode.UNDEFINED_SUPER_OPERATOR, 46, 1),
    ]);
  }

  test_getter_inSetter() async {
    await assertErrorsInCode('''
class C {
  int get value => 0;
  set value(int newValue) {}
}
extension E on C {
  set sign(int sign) {
    value = super.value * sign;
  }
}
''', [
      error(CompileTimeErrorCode.SUPER_IN_EXTENSION, 117, 5),
    ]);
  }

  test_indexOperator_inMethod() async {
    // TODO(brianwilkerson) Ensure that only one diagnostic is produced.
    await assertErrorsInCode('''
class C {
  int operator[](int i) => 0;
}
extension E on C {
  int at(int i) => super[i];
}
''', [
      error(CompileTimeErrorCode.SUPER_IN_EXTENSION, 80, 5),
      error(StaticTypeWarningCode.UNDEFINED_SUPER_OPERATOR, 85, 3),
    ]);
  }

  test_method_inGetter() async {
    await assertErrorsInCode('''
extension E on int {
  int get displayTest => super.toString();
}
''', [
      error(CompileTimeErrorCode.SUPER_IN_EXTENSION, 46, 5),
    ]);
  }

  test_prefixOperator_inGetter() async {
    // TODO(brianwilkerson) Ensure that only one diagnostic is produced.
    await assertErrorsInCode('''
class C {
  C operator-() => this;
}
extension E on C {
  C get negated => -super;
}
''', [
      error(StaticTypeWarningCode.UNDEFINED_SUPER_OPERATOR, 75, 1),
      error(CompileTimeErrorCode.SUPER_IN_EXTENSION, 76, 5),
    ]);
  }
}
