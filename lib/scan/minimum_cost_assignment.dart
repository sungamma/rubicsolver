List<int> minimumCostAssignment(List<List<double>> costs) {
  final size = costs.length;
  if (size == 0) {
    throw ArgumentError.value(costs, 'costs', '代价矩阵不能为空');
  }
  for (final row in costs) {
    if (row.length != size || row.any((cost) => !cost.isFinite)) {
      throw ArgumentError.value(costs, 'costs', '代价矩阵必须为有限数值方阵');
    }
  }

  final rowPotential = List<double>.filled(size + 1, 0);
  final columnPotential = List<double>.filled(size + 1, 0);
  final matchedRowByColumn = List<int>.filled(size + 1, 0);
  final previousColumn = List<int>.filled(size + 1, 0);

  for (var row = 1; row <= size; row++) {
    matchedRowByColumn[0] = row;
    var currentColumn = 0;
    final minimumReducedCost = List<double>.filled(size + 1, double.infinity);
    final usedColumn = List<bool>.filled(size + 1, false);

    do {
      usedColumn[currentColumn] = true;
      final currentRow = matchedRowByColumn[currentColumn];
      var delta = double.infinity;
      var nextColumn = 0;
      for (var column = 1; column <= size; column++) {
        if (usedColumn[column]) {
          continue;
        }
        final reducedCost =
            costs[currentRow - 1][column - 1] -
            rowPotential[currentRow] -
            columnPotential[column];
        if (reducedCost < minimumReducedCost[column]) {
          minimumReducedCost[column] = reducedCost;
          previousColumn[column] = currentColumn;
        }
        if (minimumReducedCost[column] < delta) {
          delta = minimumReducedCost[column];
          nextColumn = column;
        }
      }

      for (var column = 0; column <= size; column++) {
        if (usedColumn[column]) {
          rowPotential[matchedRowByColumn[column]] += delta;
          columnPotential[column] -= delta;
        } else {
          minimumReducedCost[column] -= delta;
        }
      }
      currentColumn = nextColumn;
    } while (matchedRowByColumn[currentColumn] != 0);

    do {
      final nextColumn = previousColumn[currentColumn];
      matchedRowByColumn[currentColumn] = matchedRowByColumn[nextColumn];
      currentColumn = nextColumn;
    } while (currentColumn != 0);
  }

  final assignedColumnByRow = List<int>.filled(size, -1);
  for (var column = 1; column <= size; column++) {
    assignedColumnByRow[matchedRowByColumn[column] - 1] = column - 1;
  }
  return List.unmodifiable(assignedColumnByRow);
}
