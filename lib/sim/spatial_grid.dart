/// Uniform bucket grid for "what is near this point" queries. Rebuilt every
/// tick, which is cheaper than keeping it in sync as things move.
class SpatialGrid<T> {
  SpatialGrid({required double width, required double height, this.cellSize = 40})
    : columns = (width / cellSize).ceil().clamp(1, 1 << 16).toInt(),
      rows = (height / cellSize).ceil().clamp(1, 1 << 16).toInt() {
    _cells = List.generate(columns * rows, (_) => <_Entry<T>>[]);
  }

  final double cellSize;
  final int columns;
  final int rows;
  late final List<List<_Entry<T>>> _cells;

  void clear() {
    for (final cell in _cells) {
      cell.clear();
    }
  }

  void add(T item, double x, double y) {
    _cells[_index(_column(x), _row(y))].add(_Entry(item, x, y));
  }

  /// Calls [visit] for every item within [radius] of ([x], [y]), with the
  /// squared distance so callers can compare without a square root.
  void forEachWithin(double x, double y, double radius, void Function(T item, double distanceSquared) visit) {
    final radiusSquared = radius * radius;
    final c0 = _column(x - radius), c1 = _column(x + radius);
    final r0 = _row(y - radius), r1 = _row(y + radius);
    for (var row = r0; row <= r1; row++) {
      for (var column = c0; column <= c1; column++) {
        for (final entry in _cells[_index(column, row)]) {
          final dx = entry.x - x, dy = entry.y - y;
          final d2 = dx * dx + dy * dy;
          if (d2 <= radiusSquared) visit(entry.item, d2);
        }
      }
    }
  }

  int _column(double x) => (x / cellSize).floor().clamp(0, columns - 1).toInt();
  int _row(double y) => (y / cellSize).floor().clamp(0, rows - 1).toInt();
  int _index(int column, int row) => row * columns + column;
}

class _Entry<T> {
  const _Entry(this.item, this.x, this.y);

  final T item;
  final double x;
  final double y;
}
