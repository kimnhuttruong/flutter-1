@TestOn("vm")

import 'package:test/test.dart';
import 'package:validate/validate.dart';

main() {
    // final _logger = new Logger('validate.testValidate');
    // configLogging();

    // JS does not support double
    group('JS-only-Test', () {
        test('> isInstanceOf', () {
            expect(() => (Validate.isInstance(new instanceCheck<double>(), 29.0)), returnsNormally);
            expect(() => (Validate.isInstance(new instanceCheck<double>(), 29)),
                throwsArgumentError);
        });
    });
}
