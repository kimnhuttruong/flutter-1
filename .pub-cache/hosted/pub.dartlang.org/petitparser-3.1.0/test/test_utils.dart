library petitparser.test.test_utils;

import 'package:petitparser/petitparser.dart';
import 'package:test/test.dart';

void expectSuccess(Parser parser, String input, Object expected,
    [int position]) {
  final result = parser.parse(input);
  expect(result.isSuccess, isTrue,
      reason: 'Expected Result.isSuccess to be true.');
  expect(result.isFailure, isFalse,
      reason: 'Expected Result.isFailure to be false.');
  expect(result.value, expected,
      reason: 'Expected Result.value to match $expected.');
  expect(result.position, position ?? input.length,
      reason: 'Expected Result.position to match ${position ?? input.length}.');
  expect(parser.fastParseOn(input, 0), result.position,
      reason: 'Expected fast parsed result to succeed at same position.');
  expect(parser.accept(input), isTrue,
      reason: 'Expected input to be accepted.');
}

void expectFailure(Parser parser, String input,
    [int position = 0, String message]) {
  final result = parser.parse(input);
  expect(result.isFailure, isTrue,
      reason: 'Expected Result.isFailure to be true.');
  expect(result.isSuccess, isFalse,
      reason: 'Expected Result.isSuccess to be false.');
  expect(result.position, position,
      reason: 'Expected Result.position to match $position.');
  if (message != null) {
    expect(result.message, message,
        reason: 'Expected Result.message to match $message.');
  }
  expect(parser.fastParseOn(input, 0), -1,
      reason: 'Expected fast parse to fail.');
  expect(parser.accept(input), isFalse,
      reason: 'Expected input to be rejected.');
  try {
    result.value;
  } on ParserException catch (exception) {
    expect(exception.failure, result, reason: 'Expected exception to match.');
    return;
  }
  fail('Result#value did not throw a ParserException.');
}
