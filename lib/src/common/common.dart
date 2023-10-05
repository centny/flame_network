import 'dart:async';

class HandleableStream<T> with Stream<T> {
  Stream<T> stream;
  Function? onError;
  void Function()? onDone;
  HandleableStream({required this.stream, this.onError, this.onDone});

  @override
  StreamSubscription<T> listen(void Function(T event)? onData, {Function? onError, void Function()? onDone, bool? cancelOnError}) {
    return stream.listen(
      onData,
      onError: (e) {
        if (onError != null) {
          onError(e);
        }
        if (this.onError != null) {
          this.onError!(e);
        }
      },
      onDone: () {
        if (onDone != null) {
          onDone();
        }
        if (this.onDone != null) {
          this.onDone!();
        }
      },
      cancelOnError: cancelOnError,
    );
  }
}
