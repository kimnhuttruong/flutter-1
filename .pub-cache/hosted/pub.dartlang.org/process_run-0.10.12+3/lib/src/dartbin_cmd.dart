import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart';
import 'package:process_run/cmd_run.dart';
import 'package:process_run/src/utils.dart';

import 'package:process_run/dartbin.dart';
import 'package:process_run/process_run.dart';
import 'package:pub_semver/pub_semver.dart';
import 'common/import.dart';
import 'process_cmd.dart';

String dartBinFileName = 'dart${Platform.isWindows ? '.exe' : ''}';

@Deprecated('Use DartCmd instead')
ProcessCmd dartCmd(List<String> arguments) => DartCmd(arguments);

@Deprecated('Use DartFmtCmd instead')
ProcessCmd dartfmtCmd(List<String> args) => DartFmtCmd(args);

@Deprecated('Use DartAnalyzerCmd instead')
ProcessCmd dartanalyzerCmd(List<String> args) => DartAnalyzerCmd(args);

@Deprecated('Use Dart2JsCmd instead')
ProcessCmd dart2jsCmd(List<String> args) => Dart2JsCmd(args);

@Deprecated('Use DartDocCmd instead')
ProcessCmd dartdocCmd(List<String> args) => DartDocCmd(args);

@Deprecated('Use DartDevcCmd instead')
ProcessCmd dartdevcCmd(List<String> args) => DartDevcCmd(args);

@Deprecated('Use PubCmd instead')
ProcessCmd pubCmd(List<String> args) => PubCmd(args);

/// Call dart executable
///
/// To prevent 'Observatory server failed to start after 1 tries' when
/// running from an idea use: includeParentEnvironment = false
class DartCmd extends _DartBinCmd {
  DartCmd(List<String> arguments) : super(dartBinFileName, arguments);
}

/// dartfmt command
class DartFmtCmd extends _DartBinCmd {
  DartFmtCmd(List<String> arguments)
      : super(getShellCmdBinFileName('dartfmt'), arguments);
}

/// dartanalyzer
class DartAnalyzerCmd extends _DartBinCmd {
  DartAnalyzerCmd(List<String> arguments)
      : super(getShellCmdBinFileName('dartanalyzer'), arguments);
}

/// dart2js
class Dart2JsCmd extends _DartBinCmd {
  Dart2JsCmd(List<String> arguments)
      : super(getShellCmdBinFileName('dart2js'), arguments);
}

/// dartdoc
class DartDocCmd extends _DartBinCmd {
  DartDocCmd(List<String> arguments)
      : super(getShellCmdBinFileName('dartdoc'), arguments);
}

/// dartdevc
class DartDevcCmd extends _DartBinCmd {
  DartDevcCmd(List<String> arguments)
      : super(getShellCmdBinFileName('dartdevc'), arguments);
}

/// pub
class PubCmd extends _DartBinCmd {
  PubCmd(List<String> arguments)
      : super(getShellCmdBinFileName('pub'), arguments);
}

@deprecated
class DartDevkCmd extends _DartBinCmd {
  DartDevkCmd(List<String> arguments)
      : super(getShellCmdBinFileName('dartdevk'), arguments);
}

class _DartBinCmd extends ProcessCmd {
  final String binName;

  _DartBinCmd(this.binName, List<String> arguments)
      : super(join(dartSdkBinDirPath, binName), arguments);

  @override
  String toString() => executableArgumentsToString(binName, arguments);
}

class PubRunCmd extends PubCmd {
  final String _command;
  final List<String> _arguments;

  PubRunCmd(this._command, this._arguments)
      : super(['run', _command, ..._arguments]);

  @override
  String toString() => executableArgumentsToString(_command, _arguments);
}

class PubGlobalRunCmd extends PubCmd {
  final String _command;
  final List<String> _arguments;

  PubGlobalRunCmd(this._command, this._arguments)
      : super(['global', 'run', _command, ..._arguments]);

  @override
  String toString() => executableArgumentsToString(_command, _arguments);
}

Version parsePlatformVersion(String text) {
  return Version.parse(text.split(' ').first);
}

/// Parse the text from Platform.version
String parsePlatformChannel(String text) {
  //  // 2.8.0-dev.18.0.flutter-eea9717938 (be) (Wed Apr 1 08:55:31 2020 +0000) on "linux_x64"
  var parts = text.split(' ');
  if (parts.length > 1) {
    var channelText = parts[1];
    if (channelText.toLowerCase().contains('dev')) {
      return dartChannelDev;
    } else if (channelText.toLowerCase().contains('beta')) {
      return dartChannelBeta;
    }
  }
  return dartChannelStable;
}

/// Parse flutter version
Future<Version> getDartBinVersion() async {
  // $ dart --version
  // Linux: Dart VM version: 2.7.0 (Unknown timestamp) on "linux_x64"
  var cmd = DartCmd(['--version']);
  // Take from stderr first
  var resultOutput = (await runCmd(cmd)).stderr.toString().trim();
  if (resultOutput.isEmpty) {
    resultOutput = (await runCmd(cmd)).stdout.toString().trim();
  }
  var output = LineSplitter.split(resultOutput)
      .join(' ')
      .split(' ')
      .map((word) => word?.trim())
      .where((word) => word?.isNotEmpty ?? false);
  var foundDart = false;
  try {
    for (var word in output) {
      if (foundDart) {
        try {
          var version = Version.parse(word);
          if (version != null) {
            return version;
          }
        } catch (_) {}
      }
      if (word.toLowerCase().contains('dart')) {
        foundDart = true;
      }
    }
  } catch (_) {}
  return null;
}
