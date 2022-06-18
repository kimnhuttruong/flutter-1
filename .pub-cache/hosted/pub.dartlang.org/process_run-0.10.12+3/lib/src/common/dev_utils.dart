/// Development helpers to generate warning in code

void _devPrint(Object object) {
  if (_devPrintEnabled) {
    print(object);
  }
}

bool _devPrintEnabled = true;

@deprecated
set devPrintEnabled(bool enabled) => _devPrintEnabled = enabled;

@deprecated
void devPrint(Object object) {
  if (_devPrintEnabled) {
    print(object);
  }
}

@deprecated
T devWarning<T>([T t]) => t;

void _devError([Object msg]) {
  // one day remove the print however sometimes the error thrown is hidden
  try {
    throw UnsupportedError('$msg');
  } catch (e, st) {
    if (_devPrintEnabled) {
      print('# ERROR $msg');
      print(st);
    }
    rethrow;
  }
}

@deprecated
void devError([String msg]) => _devError(msg);

// exported for testing
void debugDevPrint(Object object) => _devPrint(object);
void debugDevError(Object object) => _devError(object);
set debugDevPrintEnabled(bool enabled) => _devPrintEnabled = enabled;
