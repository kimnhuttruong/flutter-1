import 'dart:async';

import 'package:test/test.dart';

import 'package:rx_command/rx_command.dart';
import 'package:rxdart/rxdart.dart';

StreamMatcher crm<T>(Object data, bool hasError, bool isExceuting) {
  return StreamMatcher((x) async {
    final event = await x.next as CommandResult<T>;
    if (event.data != data) return "Wong data $data != ${event.data}";

    if (!hasError && event.error != null) return "Had error while not expected";

    if (hasError && !(event.error is Exception)) return "Wong error type";

    if (event.isExecuting != isExceuting)
      return "Wrong isExecuting ${event.toString()}";

    return null;
  }, "Wrong value emmited:");
}

void main() {
  test('Execute simple sync action', () {
    var command = RxCommand.createSyncNoParamNoResult(() => print("action"));

    expect(command.canExecute, emits(true));
    expect(command.isExecuting, emits(false));

    expect(command, emits(null));
    expect(command.results,
        emitsInOrder([crm(null, false, true), crm(null, false, false)]));

    command.execute();

    expect(command.canExecute, emits(true));
    expect(command.isExecuting, emits(false));
  });

  test('Execute simple sync action with emitInitialCommandResult: true', () {
    final command = RxCommand.createSyncNoParamNoResult(() => print("action"),
        emitInitialCommandResult: true);

    command.results.listen((result) => print(result.toString()));

    expect(command.canExecute, emits(true));
    expect(command.isExecuting, emits(false));

    expect(command, emits(null));
    expect(
        command.results,
        emitsInOrder([
          crm(null, false, false),
          crm(null, false, true),
          crm(null, false, false)
        ]));

    command.execute();

    expect(command.canExecute, emits(true));
    expect(command.isExecuting, emits(false));
  });

  test('Execute simple sync action with canExceute restriction', () async {
    final restriction = BehaviorSubject<bool>()..add(true);

    restriction.listen((b) => print("Restriction issued: $b"));

    var executionCount = 0;

    final command = RxCommand.createSyncNoParamNoResult(() => executionCount++,
        canExecute: restriction);

    expect(command.canExecute, emits(true));
    expect(command.isExecuting, emits(false));

    expect(command, emits(null));
    expect(command.results,
        emitsInOrder([crm(null, false, true), crm(null, false, false)]));

    command.execute();

    expect(executionCount, 1);

    expect(command.canExecute, emits(true));
    expect(command.isExecuting, emits(false));

    restriction.add(false);

    await Future.delayed(Duration(
        milliseconds:
            10)); // make sure the restriction Observable has time to emit a new value

    expect(command.canExecute, emits(true));
    expect(command.isExecuting, emits(false));

    command.execute();

    expect(executionCount, 1);

    await restriction.close();
  });

  test('Execute simple sync action with exception  throwExceptions==true', () {
    final command = RxCommand.createSyncNoParamNoResult(
        () => throw Exception("Intentional"))
      ..throwExceptions = true;

    expect(command.canExecute, emits(true));
    expect(command.isExecuting, emits(false));

    expect(command, emitsError(isException));

    command.execute();

    expect(command.canExecute, emits(true));
    expect(command.isExecuting, emits(false));
  });

  test('Execute simple sync action with exception and throwExceptions==false',
      () {
    final command = RxCommand.createSyncNoParamNoResult(
        () => throw Exception("Intentional"));

    expect(command.canExecute, emits(true));
    expect(command.isExecuting, emits(false));
    expect(command.results,
        emitsInOrder([crm(null, false, true), crm(null, true, false)]));

    command.execute();

    expect(command.canExecute, emits(true));
    expect(command.isExecuting, emits(false));
  });

  test('Execute simple sync action with parameter', () {
    final command = RxCommand.createSyncNoResult<String>((x) {
      print("action: " + x.toString());
      return null;
    });

    expect(command.canExecute, emits(true));
    expect(command.isExecuting, emits(false));

    expect(command.results,
        emitsInOrder([crm(null, false, true), crm(null, false, false)]));

    command.execute("Parameter");

    expect(command.canExecute, emits(true));
    expect(command.isExecuting, emits(false));
  });

  test('Execute simple sync function without parameter', () {
    final command = RxCommand.createSyncNoParam<String>(() {
      print("action: ");
      return "4711";
    });

    expect(command.canExecute, emits(true));
    expect(command.isExecuting, emits(false));

    expect(command, emits("4711"));

    expect(command.results,
        emitsInOrder([crm(null, false, true), crm("4711", false, false)]));

    command.execute();

    expect(command.canExecute, emits(true));
    expect(command.isExecuting, emits(false));
  });

  test('Execute simple sync function without parameter with lastResult=true',
      () {
    final command = RxCommand.createSyncNoParam<String>(() {
      print("action: ");
      return "4711";
    }, emitLastResult: true);

    expect(command.canExecute, emits(true));
    expect(command.isExecuting, emits(false));

    expect(command, emitsInOrder(["4711", "4711"]));

    expect(
        command.results,
        emitsInOrder([
          crm(null, false, true),
          crm("4711", false, false),
          crm("4711", false, true),
          crm("4711", false, false)
        ]));

    command.execute();
    command.execute();

    expect(command.canExecute, emits(true));
    expect(command.isExecuting, emits(false));
  });

  test('Execute simple sync function with parameter', () {
    final command = RxCommand.createSync<String, String>((s) {
      print("action: " + s);
      return s + s;
    });

    expect(command.canExecute, emits(true));
    expect(command.isExecuting, emits(false));

    expect(command, emits("47114711"));

    expect(command.results,
        emitsInOrder([crm(null, false, true), crm("47114711", false, false)]));

    command.execute("4711");

    expect(command.canExecute, emits(true));
    expect(command.isExecuting, emits(false));
  });

  Future<String> slowAsyncFunction(String s) async {
    print("___Start____Action__________");

    await Future.delayed(const Duration(milliseconds: 10));
    print("___End____Action__________");
    return s;
  }

  test('Execute simple async function with parameter', () async {
    var executionCount = 0;

    final command = RxCommand.createAsyncNoResult<String>((s) async {
      executionCount++;
      await slowAsyncFunction(s);
    });

    command.canExecute.listen((b) {
      print("Can execute:" + b.toString());
    });
    command.isExecuting.listen((b) {
      print("Is executing:" + b.toString());
    });

    expect(command.canExecute, emitsInOrder([true, false, true]),
        reason: "Canexecute before false");
    expect(command.isExecuting, emits(false),
        reason: "IsExecuting before true");

    expect(command.results,
        emitsInOrder([crm(null, false, true), crm(null, false, false)]));

    command.execute("Done");
    await Future.delayed(Duration(milliseconds: 50));

    expect(command.isExecuting, emits(false));
    expect(executionCount, 1);
  });

  test('Execute simple async function with parameter and return value',
      () async {
    var executionCount = 0;

    final command = RxCommand.createAsync<String, String>((s) async {
      executionCount++;
      return slowAsyncFunction(s);
    });

    command.canExecute.listen((b) {
      print("Can execute:" + b.toString());
    });
    command.isExecuting.listen((b) {
      print("Is executing:" + b.toString());
    });

    command.listen((s) {
      print("Results:" + s);
    });

    expect(command.canExecute, emitsInOrder([true, false, true]),
        reason: "Canexecute before false");
    expect(command.isExecuting, emits(false),
        reason: "IsExecuting before true");

    expect(command.results,
        emitsInOrder([crm(null, false, true), crm("Done", false, false)]));
    expect(command, emits("Done"));

    command.execute("Done");
    await Future.delayed(Duration(milliseconds: 50));

    expect(command.isExecuting, emits(false));
    expect(executionCount, 1);
  });

  test('Execute simple async function call while already running', () async {
    var executionCount = 0;

    final command = RxCommand.createAsync<String, String>((s) async {
      executionCount++;
      return slowAsyncFunction(s);
    });

    command.canExecute.listen((b) {
      print("Can execute:" + b.toString());
    });
    command.isExecuting.listen((b) {
      print("Is executing:" + b.toString());
    });

    command.listen((s) {
      print("Results:" + s);
    });

    expect(command.canExecute, emitsInOrder([true, false, true]),
        reason: "Canexecute before false");
    expect(command.isExecuting, emits(false),
        reason: "IsExecuting before true");

    expect(command.results,
        emitsInOrder([crm(null, false, true), crm("Done", false, false)]));
    expect(command, emits("Done"));

    command.execute("Done");
    command.execute("Done"); // should not execute

    await Future.delayed(Duration(milliseconds: 1000));

    expect(command.isExecuting, emits(false));
    expect(executionCount, 1);
  });

  test('Execute simple async function called twice with delay', () async {
    var executionCount = 0;

    final command = RxCommand.createAsync<String, String>((s) async {
      executionCount++;
      return slowAsyncFunction(s);
    });

    command.canExecute.listen((b) {
      print("Can execute:" + b.toString());
    });
    command.isExecuting.listen((b) {
      print("Is executing:" + b.toString());
    });

    command.listen((s) {
      print("Results:" + s);
    });

    expect(command.canExecute, emitsInOrder([true, false, true, false, true]),
        reason: "Canexecute wrong");
    expect(command.isExecuting, emits(false),
        reason: "IsExecuting before true");

    expect(
        command.results,
        emitsInOrder([
          crm(null, false, true),
          crm("Done", false, false),
          crm(null, false, true),
          crm("Done", false, false)
        ]));
    expect(command, emitsInOrder(["Done", "Done"]));

    command.execute("Done");
    await Future.delayed(Duration(milliseconds: 50));
    command.execute("Done"); // should not execute

    await Future.delayed(Duration(milliseconds: 50));

    expect(command.isExecuting, emits(false));
    expect(executionCount, 2);
  });

  test(
      'Execute simple async function called twice with delay and emitLastResult=true',
      () async {
    var executionCount = 0;

    final command = RxCommand.createAsync<String, String>((s) async {
      executionCount++;
      return slowAsyncFunction(s);
    }, emitLastResult: true);

    command.canExecute.listen((b) {
      print("Can execute:" + b.toString());
    });
    command.isExecuting.listen((b) {
      print("Is executing:" + b.toString());
    });

    command.listen((s) {
      print("Results:" + s);
    });

    expect(command.canExecute, emitsInOrder([true, false, true, false, true]),
        reason: "Canexecute wrong");
    expect(command.isExecuting, emits(false),
        reason: "IsExecuting before true");

    expect(
        command.results,
        emitsInOrder([
          crm(null, false, true),
          crm("Done", false, false),
          crm("Done", false, true),
          crm("Done", false, false)
        ]));

    command.execute("Done");
    await Future.delayed(Duration(milliseconds: 50));
    command.execute("Done"); // should not execute

    await Future.delayed(Duration(milliseconds: 50));

    expect(command.isExecuting, emits(false));
    expect(executionCount, 2);
  });

  Future<String> slowAsyncFunctionFail(String s) async {
    print("___Start____Action___Will throw_______");

    throw Exception("Intentionally");
  }

  test('async function with exception and throwExceptions==true', () async {
    final command =
        RxCommand.createAsync<String, String>(slowAsyncFunctionFail);
    command.throwExceptions = true;

    command.listen((s) => print('Listen: $s'),
        onError: (e) => print('OnError:$e'));

    expect(command.canExecute, emits(true));
    expect(command.isExecuting, emits(false));

    expect(command.results, emitsInOrder([crm(null, false, true)]));

    expect(command, emitsError(isException));
    expect(command, emitsError(isException));

    command.execute("Done");

    expect(command.canExecute, emits(true));
    expect(command.isExecuting, emits(false));

    await Future.delayed(Duration(milliseconds: 100));

    command.execute("Done2");

    expect(command, emitsError(isException));

    expect(command.canExecute, emits(true));
    expect(command.isExecuting, emits(false));

    await Future.delayed(Duration(milliseconds: 100));
  });

  test('async function with exception with and throwExceptions==false', () {
    final command =
        RxCommand.createAsync<String, String>(slowAsyncFunctionFail);

    command.thrownExceptions.listen((e) => print(e.toString()));

    expect(command.canExecute, emits(true));
    expect(command.isExecuting, emits(false));

    expect(command.results,
        emitsInOrder([crm(null, false, true), crm(null, true, false)]));
    expect(command.thrownExceptions, emits(isException));

    command.execute("Done");

    expect(command.canExecute, emits(true));
    expect(command.isExecuting, emits(false));
  });

  test("async function should be next'able", () async {
    final cmd = RxCommand.createAsync((_) async {
      await Future.delayed(Duration(milliseconds: 1));
      return 42;
    });

    cmd.execute();
    final result = await cmd.next;

    expect(result, 42);
  });

  test("async functions that throw should be next'able", () async {
    final cmd = RxCommand.createAsync((_) async {
      await Future.delayed(Duration(milliseconds: 1));
      throw Exception("oh no");
    });

    cmd.execute();
    var didntThrow = true;
    try {
      await cmd.next;
    } catch (e) {
      didntThrow = false;
    }

    expect(didntThrow, false);
  });

  Stream<int> testProvider(int i) async* {
    yield i;
    yield i + 1;
    yield i + 2;
  }

  test('RxCommand.createFromStream', () {
    final command = RxCommand.createFromStream<int, int>(testProvider);

    command.canExecute.listen((b) {
      print("Can execute:" + b.toString());
    });
    command.isExecuting.listen((b) {
      print("Is executing:" + b.toString());
    });

    command.listen((i) {
      print("Results:" + i.toString());
    });

    expect(command.canExecute, emits(true), reason: "Canexecute before false");
    expect(command.isExecuting, emits(false),
        reason: "IsExecuting before true");

    expect(
        command.results,
        emitsInOrder([
          crm(null, false, true),
          crm(1, false, true),
          crm(2, false, true),
          crm(3, false, true),
          crm(3, false, false)
        ]));
    expect(command, emitsInOrder([1, 2, 3]));

    command.execute(1);

    expect(command.canExecute, emits(true), reason: "Canexecute after false");
    expect(command.isExecuting, emits(false));
  });

  Stream<int> testProviderError(int i) async* {
    throw Exception();
  }

  test('RxCommand.createFromStreamWithException', () {
    final command = RxCommand.createFromStream<int, int>(testProviderError);

    command.canExecute.listen((b) {
      print("Can execute:" + b.toString());
    });
    command.isExecuting.listen((b) {
      print("Is executing:" + b.toString());
    });

    command.results.listen((i) {
      print("Results:" + i.toString());
    });

    expect(command.canExecute, emits(true), reason: "Canexecute before false");
    expect(command.isExecuting, emits(false),
        reason: "IsExecuting before true");

    expect(command.results,
        emitsInOrder([crm(null, false, true), crm(null, true, false)]));

    expect(command.thrownExceptions, emits(TypeMatcher<Exception>()));

    command.execute(1);

    expect(command.canExecute, emits(true), reason: "Canexecute after false");
    expect(command.isExecuting, emits(false));
  });

  test('RxCommand.createFromStreamWithException2', () {
    var streamController = StreamController<String>.broadcast();

    var command = RxCommand.createFromStream((_) {
      return streamController.stream.map((rideMap) {
        throw Exception();
      });
    });

    command.results.listen((r) {
      print(r.toString());
    });

    command.thrownExceptions.listen((e) {
      print(e.toString());
    });

    expect(command.thrownExceptions, emits(TypeMatcher<Exception>()));

    command.execute();

    streamController.add('test');

    print('Finished');
  });

  test('RxCommand.createFromStreamWithExceptionOnlyThrown once', () async{
    var command = RxCommand.createFromStream((_) {
      return Observable.just('test').map((rideMap) {
        throw Exception('TestException');
      });
    });

    var count = 0;
    command.thrownExceptions.listen((e) {
      count++;
      print(e.toString());
    });

    command.execute();

    await Future.delayed(Duration(seconds: 1));

    expect(count, 1);
  });

// No idea why it's not posible to catch the exception with     expect(command.results, emitsError(isException));
/*
    test('RxCommand.createFromStreamWithException throw exeption = true', () 
  {

    final command  = RxCommand.createFromStream<int,int>( testProviderError);
    command.throwExceptions = true;

    command.canExecute.listen((b){print("Can execute:" + b.toString());});
    command.isExecuting.listen((b){print("Is executing:" + b.toString());});

    command.results.listen((i){print("Results:" + i.toString());});


    expect(command.canExecute, emits(true),reason: "Canexecute before false");
    expect(command.isExecuting, emits(false),reason: "Canexecute before true");

    expect(command.results, emitsError(isException));
    expect(command, emitsError(isException));
    

    command.execute(1);

    expect(command.canExecute, emits(true),reason: "Canexecute after false");
    expect(command.isExecuting, emits(false));    
  });

*/
}
