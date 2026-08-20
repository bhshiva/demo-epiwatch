import 'package:epiwatch/models/lab_models.dart';
import 'package:epiwatch/state/lab_dashboard.dart';
import 'package:flutter_test/flutter_test.dart';

Isolate _isolate({
  String? pathogen,
  List<AstResult> ast = const [],
}) =>
    Isolate(
      isolateId: 'i1',
      status: 'final',
      createdAt: '2026-08-01T00:00:00Z',
      pathogen: pathogen,
      astResults: ast,
    );

void main() {
  group('pathogenCounts', () {
    test('counts isolates by named pathogen, most frequent first', () {
      final isolates = [
        _isolate(pathogen: 'Escherichia coli'),
        _isolate(pathogen: 'Escherichia coli'),
        _isolate(pathogen: 'Klebsiella pneumoniae'),
      ];

      final counts = pathogenCounts(isolates);

      expect(counts, hasLength(2));
      expect(counts[0].pathogen, 'Escherichia coli');
      expect(counts[0].count, 2);
      expect(counts[1].pathogen, 'Klebsiella pneumoniae');
      expect(counts[1].count, 1);
    });

    test('ignores isolates with no pathogen identified (e.g. no growth)', () {
      final isolates = [_isolate(pathogen: null), _isolate(pathogen: '')];

      expect(pathogenCounts(isolates), isEmpty);
    });

    test('caps at the top 8 pathogens', () {
      final isolates = [
        for (var i = 0; i < 10; i++) _isolate(pathogen: 'Organism $i'),
      ];

      expect(pathogenCounts(isolates), hasLength(8));
    });
  });

  group('sirCounts', () {
    test('aggregates susceptible/intermediate/resistant/not-tested per drug', () {
      final isolates = [
        _isolate(ast: const [
          AstResult(antibiotic: 'Meropenem', astResult: 'Susceptible'),
          AstResult(antibiotic: 'Meropenem', astResult: 'Resistant'),
        ]),
        _isolate(ast: const [
          AstResult(antibiotic: 'Meropenem', astResult: 'Intermediate'),
          AstResult(antibiotic: 'Ciprofloxacin', astResult: 'Not tested'),
        ]),
      ];

      final rows = sirCounts(isolates);
      final mero = rows.firstWhere((r) => r.antibiotic == 'Meropenem');

      expect(mero.susceptible, 1);
      expect(mero.resistant, 1);
      expect(mero.intermediate, 1);
      expect(mero.total, 3);

      final cipro = rows.firstWhere((r) => r.antibiotic == 'Ciprofloxacin');
      expect(cipro.notTested, 1);
    });

    test('sorts by total tests, most-tested first, capped at 8', () {
      final isolates = [
        _isolate(ast: const [
          AstResult(antibiotic: 'A', astResult: 'Susceptible'),
        ]),
        _isolate(ast: const [
          AstResult(antibiotic: 'B', astResult: 'Susceptible'),
          AstResult(antibiotic: 'B', astResult: 'Resistant'),
        ]),
      ];

      final rows = sirCounts(isolates);

      expect(rows.first.antibiotic, 'B');
    });

    test('an isolate with no AST results contributes nothing', () {
      final isolates = [_isolate()];

      expect(sirCounts(isolates), isEmpty);
    });
  });
}
