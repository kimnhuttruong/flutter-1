import 'dart:async';

/// Flattens the items emitted by the given streams into a single Observable
/// sequence.
///
/// [Interactive marble diagram](http://rxmarbles.com/#merge)
///
/// ### Example
///
///     new MergeStream([
///       new TimerStream(1, new Duration(days: 10)),
///       new Stream.fromIterable([2])
///     ])
///     .listen(print); // prints 2, 1
class MergeStream<T> extends Stream<T> {
  final StreamController<T> _controller;

  /// Constructs a [Stream] which flattens all events in [streams] and emits
  /// them in a single sequence.
  MergeStream(Iterable<Stream<T>> streams)
      : _controller = _buildController(streams);

  @override
  StreamSubscription<T> listen(void onData(T event),
          {Function onError, void onDone(), bool cancelOnError}) =>
      _controller.stream.listen(onData,
          onError: onError, onDone: onDone, cancelOnError: cancelOnError);

  static StreamController<T> _buildController<T>(Iterable<Stream<T>> streams) {
    if (streams == null) {
      throw ArgumentError('streams cannot be null');
    } else if (streams.isEmpty) {
      throw ArgumentError('at least 1 stream needs to be provided');
    } else if (streams.any((Stream<T> stream) => stream == null)) {
      throw ArgumentError('One of the provided streams is null');
    }

    final len = streams.length;
    final subscriptions = List<StreamSubscription<T>>(len);
    StreamController<T> controller;

    controller = StreamController<T>(
        sync: true,
        onListen: () {
          var completed = 0;

          final onDone = () {
            completed++;

            if (completed == len) controller.close();
          };

          for (var i = 0; i < len; i++) {
            var stream = streams.elementAt(i);

            subscriptions[i] = stream.listen(controller.add,
                onError: controller.addError, onDone: onDone);
          }
        },
        onPause: ([Future<dynamic> resumeSignal]) => subscriptions
            .forEach((subscription) => subscription.pause(resumeSignal)),
        onResume: () =>
            subscriptions.forEach((subscription) => subscription.resume()),
        onCancel: () => Future.wait<dynamic>(subscriptions
            .map((subscription) => subscription.cancel())
            .where((cancelFuture) => cancelFuture != null)));

    return controller;
  }
}
