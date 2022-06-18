import 'package:validations/validators/basic.dart';

import '../../test_validator.dart';

void main() {
  TestValidator(IsTrueValidator())
    ..isValid({
      true,
    })
    ..isInvalid({
      null,
      false,
      '',
    });
}
