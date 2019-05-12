import 'dart:async';

import 'package:mockito/mockito.dart';
import 'package:test/test.dart';

import 'package:graphql/client.dart';
import 'package:graphql/internal.dart';
import 'package:graphql/src/link/dedup/link_dedup.dart';

class MockLink extends Mock implements Link {}

void main() {
  group('DedupLink', () {
    test('does not affect different queries', () async {
      const document = '''
        query withVar(\$i: Int) {
          take(i: \$i)
        }
      ''';

      final op1 = Operation(
        document: document,
        variables: <String, dynamic>{'i': 12},
      );

      final op2 = Operation(
        document: document,
        variables: <String, dynamic>{'i': 42},
      );

      final result1 = FetchResult(
        data: 1,
      );

      final result2 = FetchResult(
        data: 2,
      );

      final mockLink = MockLink();

      when(mockLink.request(op1))
          .thenAnswer((_) => Stream.fromIterable([result1]));

      when(mockLink.request(op2))
          .thenAnswer((_) => Stream.fromIterable([result2]));

      final link = Link.from([
        DedupLink(),
        mockLink,
      ]);

      final stream1 = link.request(op1);
      final stream2 = link.request(op2);

      verify(mockLink.request(op1)).called(1);
      verify(mockLink.request(op2)).called(1);
      expect(await stream1.first, result1);
      expect(await stream2.first, result2);
    });

    test('dedupes identical queries', () async {
      const document = '''
        query withVar(\$i: Int) {
          take(i: \$i)
        }
      ''';

      final op1 = Operation(
        document: document,
        variables: <String, dynamic>{'i': 12},
      );

      final op2 = Operation(
        document: document,
        variables: <String, dynamic>{'i': 12},
      );

      final result1 = FetchResult(
        data: 1,
      );

      final result2 = FetchResult(
        data: 2,
      );

      final mockLink = MockLink();

      when(mockLink.request(op1))
          .thenAnswer((_) => Stream.fromIterable([result1]));

      when(mockLink.request(op2))
          .thenAnswer((_) => Stream.fromIterable([result2]));

      final link = Link.from([
        DedupLink(),
        mockLink,
      ]);

      final stream1 = link.request(op1);
      final stream2 = link.request(op2);

      var return1 = stream1.first;
      var return2 = stream2.first;

      verify(mockLink.request(op1)).called(1);
      verifyNever(mockLink.request(op2));
      expect(await return1, result1);
      expect(await return2, result1);
    });

    test('does not dedup consequtive queries', () async {
      const document = '''
        query withVar(\$i: Int) {
          take(i: \$i)
        }
      ''';

      final op1 = Operation(
        document: document,
        variables: <String, dynamic>{'i': 12},
      );

      final result1 = FetchResult(
        data: 1,
      );

      final mockLink = MockLink();

      when(mockLink.request(op1))
          .thenAnswer((_) => Stream.fromIterable([result1]));

      final link = Link.from([
        DedupLink(),
        mockLink,
      ]);

      expect(
        await link.request(op1).first,
        result1,
      );
      expect(
        await link.request(op1).first,
        result1,
      );
      verify(mockLink.request(op1)).called(2);
    });

    test('does not dedup a query after an error query', () async {
      const document = '''
        query withVar(\$i: Int) {
          take(i: \$i)
        }
      ''';

      final op1 = Operation(
        document: document,
        variables: <String, dynamic>{'i': 12},
      );

      final result1 = FetchResult(
        data: 1,
      );

      final mockLink = MockLink();

      final link = Link.from([
        DedupLink(),
        mockLink,
      ]);

      final controller1 = StreamController<FetchResult>();
      when(mockLink.request(op1)).thenAnswer((_) => controller1.stream);
      controller1.addError('Error');
      controller1.close();

      try {
        await link.request(op1).first;
      } catch (e) {
        expect(e, 'Error');
      }

      final controller2 = StreamController<FetchResult>();
      when(mockLink.request(op1)).thenAnswer((_) => controller2.stream);
      controller2.add(result1);
      controller2.close();

      expect(
        await link.request(op1).first,
        result1,
      );

      verify(mockLink.request(op1)).called(2);
    });
  });
}
