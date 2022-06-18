# Validations for Dart.
<!-- Badges -->

[![Pub Package](https://img.shields.io/pub/v/validations.svg)](https://pub.dev/packages/validations)
[![Build Status](https://travis-ci.org/dartlib/validations.svg?branch=master)](https://travis-ci.org/dartlib/validations)
[![codecov](https://codecov.io/gh/dartlib/validations/branch/master/graph/badge.svg)](https://codecov.io/gh/dartlib/validations)


## Validator setup

You should add [validations_generator](https://pub.dev/packages/validations_generator) as a dependency:
```dart
dev_dependencies:
  build_runner:
  validations_generator:
```

First declare your model and assign a generator class to validate the model.

`car.dart`:
```dart
import 'package:decimal/decimal.dart';
import 'package:validations/validations.dart';

part 'car.g.dart';

class Driver {
  Driver({this.name});
  @NotNull()
  String name;
}

class Car {
  Car({
    this.manufacturer,
    this.licensePlate,
    this.seatCount,
    this.topSpeed,
    this.price,
    this.isRegistered,
  });

  @NotNull()
  String manufacturer;

  @Valid(message: 'There should be a valid driver!')
  Driver driver;

  @Size(
    min: 2,
    max: 14,
    message:
        r'The license plate ${validatedValue} must be between ${min} and ${max} characters long',
  )
  @NotNull()
  String licensePlate;

  @Min(
    value: 1,
    message: r'Car must at least have ${value} seats available',
  )
  @Max(
    value: 2,
    message: r'Car cannot have more than ${value} seats',
  )
  int seatCount;

  @Max(
    value: 350,
    message: r'The top speed ${validatedValue} is higher than ${value}',
  )
  int topSpeed;

  @DecimalMax(
    value: '100.00',
    message: r'Price must not be lower than ${value}',
  )
  @DecimalMin(
    value: '49.99',
    message: r'Price must not be higher than ${value}',
  )
  Decimal price;

  @IsTrue(message: 'Car must be registered!')
  bool isRegistered;
}

@GenValidator()
class TestCarValidator extends Validator<Car> with _$TestCarValidator {}

@GenValidator()
class TestDriverValidator extends Validator<Driver> with _$TestDriverValidator {}
```

## Generate the validators

After the models have been annotated the validators should be generated:
```bash
# Dart
pub run build_runner build

# Flutter
flutter pub run build_runner build
```

## Usage

```dart
import 'car.dart';

final car = Car();

car.driver = Driver(name: 'TestDriver');
car.price = Decimal.parse('99.99');
car.isRegistered = true;
car.licensePlate = 'DY28-38';
car.manufacturer = 'VEB Sachsenring';
car.seatCount = 2;
car.topSpeed = 100;

final validator = TestCarValidator();

// Full validation of the model
validator.validate(car);

// Validates only a specific property returning all violations
validator.validateProperty(car, 'price');

// Check violations given an arbitrary value using the validators defined for `manufacturer`
validator.validateValue('manufacturer', null);

// Returns first error message as a string or null if there are no errors.
validator.errorCheck('isRegistered', false);

// Convenience methods are also generated which can be assigned directly to form validators in
// flutter e.g. validator: validator.validateLicensePlate,
// Internally it performs an errorCheck and thus also either returns an error message or [null];
validator.validateLicensePlate('DX');
validator.validateRegistered(true);
...etc
```

## Test Coverage

To run test coverage locally.

```bash
pub run test_coverage
# To install genhtml: apt|brew install lcov
genhtml -o coverage coverage/lcov.info
open coverage/index.html
```

## Features and bugs

Please file feature requests and bugs at the [issue tracker][tracker].

[tracker]: http://github.com/dartlib/validations/issues
