import 'package:flutter_test/flutter_test.dart';
import 'package:rubicsolver/scan/minimum_cost_assignment.dart';

void main() {
  test('finds the minimum-cost unique column assignment', () {
    expect(
      minimumCostAssignment(const [
        [4, 1, 3],
        [2, 0, 5],
        [3, 2, 2],
      ]),
      [1, 0, 2],
    );
  });

  test('rejects empty, non-square, and non-finite matrices', () {
    expect(() => minimumCostAssignment(const []), throwsArgumentError);
    expect(
      () => minimumCostAssignment(const [
        [1, 2],
      ]),
      throwsArgumentError,
    );
    expect(
      () => minimumCostAssignment(const [
        [1, double.nan],
        [2, 3],
      ]),
      throwsArgumentError,
    );
  });
}
