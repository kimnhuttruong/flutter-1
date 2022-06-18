@TestOn('vm')
library process_run.process_run_test;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:process_run/shell.dart';
import 'package:process_run/src/shell_utils.dart'
    show envPathKey, envPathSeparator;
import 'package:test/test.dart';
import 'package:path/path.dart';
import 'package:process_run/dartbin.dart';
import 'package:process_run/process_run.dart';

import 'process_run_test_common.dart';

void main() {
  group('toString', () {
    test('argumentsToString', () {
      expect(argumentToString(''), '""');
      expect(argumentToString('a'), 'a');
      expect(argumentToString(' '), '" "');
      expect(argumentToString('\t'), '"\t"');
      expect(argumentToString('\n'), '"\n"');
      expect(argumentToString('\''), '"\'"');
      expect(argumentToString('"'), '\'"\'');
    });
    test('argumentsToString', () {
      expect(argumentsToString([]), '');
      expect(argumentsToString(['a']), 'a');
      expect(argumentsToString(['a', 'b']), 'a b');
      expect(argumentsToString([' ']), '" "');
      expect(argumentsToString(['" ']), '\'" \'');
      expect(argumentsToString(['""\'']), '"\\"\\"\'"');
      expect(argumentsToString(['\t']), '"\t"');
      expect(argumentsToString(['\n']), '"\n"');
      expect(argumentsToString(['a', 'b\nc', 'd']), 'a "b\nc" d');
    });

    test('executableArgumentsToString', () {
      expect(executableArgumentsToString('cmd', null), 'cmd');
      expect(executableArgumentsToString('cmd', []), 'cmd');
      expect(executableArgumentsToString('cmd', ['a']), 'cmd a');
      expect(executableArgumentsToString('cmd', ['a', 'b']), 'cmd a b');
      expect(executableArgumentsToString('cmd', [' ']), 'cmd " "');
      expect(executableArgumentsToString('cmd', [' ']), 'cmd " "');
      expect(executableArgumentsToString('cmd', ['"']), 'cmd \'"\'');
    });
  });

  group('run', () {
    Future _runCheck(
      Function(ProcessResult result) check,
      String executable,
      List<String> arguments, {
      String workingDirectory,
      Map<String, String> environment,
      bool includeParentEnvironment = true,
      bool runInShell = false,
      Encoding stdoutEncoding = systemEncoding,
      Encoding stderrEncoding = systemEncoding,
      StreamSink<List<int>> stdout,
    }) async {
      var result = await Process.run(
        executable,
        arguments,
        workingDirectory: workingDirectory,
        environment: environment,
        includeParentEnvironment: includeParentEnvironment,
        runInShell: runInShell,
        stdoutEncoding: stdoutEncoding,
        stderrEncoding: stderrEncoding,
      );
      check(result);
      result = await run(executable, arguments,
          workingDirectory: workingDirectory,
          environment: environment,
          includeParentEnvironment: includeParentEnvironment,
          runInShell: runInShell,
          stdoutEncoding: stdoutEncoding,
          stderrEncoding: stderrEncoding,
          stdout: stdout);
      check(result);
    }

    test('stdout', () async {
      void checkOut(ProcessResult result) {
        expect(result.stderr, '');
        expect(result.stdout, 'out');
        expect(result.pid, isNotNull);
        expect(result.exitCode, 0);
      }

      void checkEmpty(ProcessResult result) {
        expect(result.stderr, '');
        expect(result.stdout, '');
        expect(result.pid, isNotNull);
        expect(result.exitCode, 0);
      }

      await _runCheck(
          checkOut, dartExecutable, [echoScriptPath, '--stdout', 'out']);
      await _runCheck(checkEmpty, dartExecutable, [echoScriptPath]);
    });

    test('stdout_bin', () async {
      void check123(ProcessResult result) {
        expect(result.stderr, '');
        expect(result.stdout, [1, 2, 3]);
        expect(result.pid, isNotNull);
        expect(result.exitCode, 0);
      }

      void checkEmpty(ProcessResult result) {
        expect(result.stderr, '');
        expect(result.stdout, []);
        expect(result.pid, isNotNull);
        expect(result.exitCode, 0);
      }

      await _runCheck(
          check123, dartExecutable, [echoScriptPath, '--stdout-hex', '010203'],
          stdoutEncoding: null);
      await _runCheck(checkEmpty, dartExecutable, [echoScriptPath],
          stdoutEncoding: null);
    });

    test('stderr', () async {
      void checkErr(ProcessResult result) {
        expect(result.stdout, '');
        expect(result.stderr, 'err');
        expect(result.pid, isNotNull);
        expect(result.exitCode, 0);
      }

      void checkEmpty(ProcessResult result) {
        expect(result.stderr, '');
        expect(result.stdout, '');
        expect(result.pid, isNotNull);
        expect(result.exitCode, 0);
      }

      await _runCheck(
          checkErr, dartExecutable, [echoScriptPath, '--stderr', 'err'],
          stdout: stdout);
      await _runCheck(checkEmpty, dartExecutable, [echoScriptPath]);
    });

    test('stdin', () async {
      final inCtrl = StreamController<List<int>>();
      final processResultFuture = run(
          dartExecutable, [echoScriptPath, '--stdin'],
          stdin: inCtrl.stream);
      inCtrl.add('in'.codeUnits);
      await inCtrl.close();
      final result = await processResultFuture;

      expect(result.stdout, 'in');
      expect(result.stderr, '');
      expect(result.pid, isNotNull);
      expect(result.exitCode, 0);
    });

    test('stderr_bin', () async {
      void check123(ProcessResult result) {
        expect(result.stdout, '');
        expect(result.stderr, [1, 2, 3]);
        expect(result.pid, isNotNull);
        expect(result.exitCode, 0);
      }

      void checkEmpty(ProcessResult result) {
        expect(result.stdout, '');
        expect(result.stderr, []);
        expect(result.pid, isNotNull);
        expect(result.exitCode, 0);
      }

      await _runCheck(
          check123, dartExecutable, [echoScriptPath, '--stderr-hex', '010203'],
          stderrEncoding: null);
      await _runCheck(checkEmpty, dartExecutable, [echoScriptPath],
          stderrEncoding: null);
    });

    test('exitCode', () async {
      void check123(ProcessResult result) {
        expect(result.stdout, '');
        expect(result.stderr, '');
        expect(result.pid, isNotNull);
        expect(result.exitCode, 123);
      }

      void check0(ProcessResult result) {
        expect(result.stdout, '');
        expect(result.stderr, '');
        expect(result.pid, isNotNull);
        expect(result.exitCode, 0);
      }

      await _runCheck(
          check123, dartExecutable, [echoScriptPath, '--exit-code', '123']);
      await _runCheck(check0, dartExecutable, [echoScriptPath]);
    });

    test('crash', () async {
      void check(ProcessResult result) {
        expect(result.stdout, '');
        expect(result.stderr, isNotEmpty);
        expect(result.pid, isNotNull);
        expect(result.exitCode, 255);
      }

      await _runCheck(
          check, dartExecutable, [echoScriptPath, '--exit-code', 'crash']);
    });

    test('no_argument', () async {
      try {
        await Process.run(dartExecutable, null);
      } on ArgumentError catch (_) {
        // Invalid argument(s): Arguments is not a List: null
      }
      try {
        await run(dartExecutable, null);
      } on ArgumentError catch (_) {
        // Invalid argument(s): Arguments is not a List: null
      }
    });

    test('invalid_executable', () async {
      try {
        await Process.run(dummyExecutable, []);
      } on ProcessException catch (_) {
        // ProcessException: No such file or directory
      }

      try {
        await run(dummyExecutable, []);
      } on ProcessException catch (_) {
        // ProcessException: No such file or directory
      }
    });

    test('invalid_command', () async {
      try {
        await Process.run(dummyCommand, []);
      } on ProcessException catch (_) {
        // ProcessException: No such file or directory
      }

      try {
        await run(dummyCommand, []);
      } on ProcessException catch (_) {
        // ProcessException: No such file or directory
      }
    });

    test('echo', () async {
      // Fortunately this work on all platform
      var result = await run('echo', ['value']);
      expect(result.exitCode, 0);
      expect(result.stdout.toString().trim(), 'value');
    });

    test('dart', () async {
      var result = await run('dart', ['--version']);
      expect(result.exitCode, 0);
    });

    test('relative', () async {
      if (Platform.isWindows) {
        var result = await run(join('test', 'src', 'current_dir.bat'), []);
        expect(result.exitCode, 0);
        expect(result.stdout.toString().trim(), Directory.current.path);
      } else {
        var result = await run(join('test', 'src', 'current_dir'), []);
        expect(result.exitCode, 0);
        expect(result.stdout.toString().trim(), Directory.current.path);
      }
    });

    test('system_command', () async {
      // read pubspec.yaml
      final lines = const LineSplitter()
          .convert(await File(join(projectTop, 'pubspec.yaml')).readAsString());

      void check(ProcessResult result) {
        expect(const LineSplitter().convert(result.stdout.toString()), lines);
        expect(result.stderr, '');
        expect(result.pid, isNotNull);
        expect(result.exitCode, 0);
      }

      // use 'cat' on mac and linux
      // use 'type' on windows

      if (Platform.isWindows) {
        await _runCheck(check, 'type', ['pubspec.yaml'],
            workingDirectory: projectTop, runInShell: true);
      } else {
        await _runCheck(check, 'cat', ['pubspec.yaml'],
            workingDirectory: projectTop);
      }
    });

    test('space in binary', () async {
      var path = '.dart_tool/process_run/test/space in binary';
      await createEchoExecutable(path);
      var env = Map<String, String>.from(platformEnvironment);
      env[envPathKey] = '${dirname(path)}${envPathSeparator}${env[envPathKey]}';
      print(env[envPathKey]);
      var result = await run(
          'space in binary$basicScriptExecutableExtension', [],
          environment: env);
      expect(result.stdout.toString().trim(), 'Hello');

      expect(
          (await Shell(environment: env, verbose: false)
                  .run('${shellArgument('space in binary')}'))
              .first
              .stdout
              .toString()
              .trim(),
          'Hello');
    });
    test('space in path', () async {
      var path = '.dart_tool/process_run/test/space in path/binary';
      await createEchoExecutable(path);
      var env = Map<String, String>.from(platformEnvironment);
      env[envPathKey] = '${dirname(path)}${envPathSeparator}${env[envPathKey]}';
      print(env[envPathKey]);
      var result = await run('binary$basicScriptExecutableExtension', [],
          environment: env);
      expect(result.stdout.toString().trim(), 'Hello');

      expect(
          (await Shell(environment: env, verbose: false).run('binary'))
              .first
              .stdout
              .toString()
              .trim(),
          'Hello');
    });
    test('windows_system_command', () async {
      if (Platform.isWindows) {
        if (Platform.isWindows) {
          ProcessResult result;

          result = await run('cmd', ['/c', 'echo', 'hi']);
          expect(result.stdout, 'hi\r\n');
          expect(result.stderr, '');
          expect(result.pid, isNotNull);
          expect(result.exitCode, 0);

          await run('echo', ['hi'], runInShell: true);
          expect(result.stdout, 'hi\r\n');
          expect(result.stderr, '');
          expect(result.pid, isNotNull);
          expect(result.exitCode, 0);

          // not using runInShell crashes
          try {
            await run('echo', ['hi']);
          } on ProcessException catch (_) {
            // ProcessException: not fount
          }
        }
      }
    });
  });
}
