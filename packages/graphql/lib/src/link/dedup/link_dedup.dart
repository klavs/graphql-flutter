import 'package:graphql/src/link/fetch_result.dart';
import 'package:graphql/src/link/link.dart';
import 'package:graphql/src/link/operation.dart';

class DedupLink extends Link {
  final _inFlightStreams = <String, Stream<FetchResult>>{};

  Stream<FetchResult> _transform(
    Stream<FetchResult> forwardStream,
    String key,
  ) async* {
    try {
      await for (final result in forwardStream) {
        if (_inFlightStreams.containsKey(key)) {
          _inFlightStreams.remove(key);
        }

        yield result;
      }
    } catch (e) {
      _inFlightStreams.remove(key);

      rethrow;
    }
  }

  @override
  Stream<FetchResult> request(Operation operation, [NextLink forward]) {
    final key = operation.toKey();

    if (!_inFlightStreams.containsKey(key)) {
      _inFlightStreams[key] = _transform(
        forward(operation),
        key,
      ).asBroadcastStream();
    }

    return _inFlightStreams[key];
  }
}
