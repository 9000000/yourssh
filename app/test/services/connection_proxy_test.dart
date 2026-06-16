import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:yourssh/services/proxy_handshake.dart';

void main() {
  test('release() emits live data; takeLeftover returns buffered tail', () async {
    final input = StreamController<Uint8List>();
    final reader = ByteReader(input.stream);

    // Simulate a handshake having read up to a point, leaving trailing bytes.
    input.add(Uint8List.fromList([1, 2, 3, 4]));
    await Future<void>.delayed(Duration.zero);
    final firstTwo = await reader.readExactly(2);
    expect(firstTwo, [1, 2]);

    final leftover = reader.takeLeftover();
    expect(leftover, [3, 4]);

    final live = <int>[];
    final done = Completer<void>();
    reader.release().listen(live.addAll, onDone: done.complete);
    input.add(Uint8List.fromList([5, 6]));
    await Future<void>.delayed(Duration.zero);
    await input.close();
    await done.future;
    expect(live, [5, 6]);
  });
}
