export type Point = readonly [number, number];

function solveLinear(matrix: number[][], vector: number[]) {
  const size = vector.length;
  const rows = matrix.map((row, index) => [...row, vector[index]]);
  for (let column = 0; column < size; column += 1) {
    let pivot = column;
    for (let row = column + 1; row < size; row += 1) {
      if (Math.abs(rows[row][column]) > Math.abs(rows[pivot][column])) pivot = row;
    }
    [rows[column], rows[pivot]] = [rows[pivot], rows[column]];
    for (let row = 0; row < size; row += 1) {
      if (row === column) continue;
      const factor = rows[row][column] / rows[column][column];
      for (let k = column; k <= size; k += 1) rows[row][k] -= factor * rows[column][k];
    }
  }
  return rows.map((row, index) => row[size] / row[index]);
}

export function rectToQuadTransform(width: number, height: number, quad: readonly Point[]) {
  const corners: Point[] = [
    [0, 0],
    [width, 0],
    [width, height],
    [0, height],
  ];
  const matrix: number[][] = [];
  const vector: number[] = [];
  corners.forEach(([x, y], index) => {
    const [u, v] = quad[index];
    matrix.push([x, y, 1, 0, 0, 0, -u * x, -u * y]);
    vector.push(u);
    matrix.push([0, 0, 0, x, y, 1, -v * x, -v * y]);
    vector.push(v);
  });
  const [a, b, c, d, e, f, g, h] = solveLinear(matrix, vector);
  return `matrix3d(${[a, d, 0, g, b, e, 0, h, 0, 0, 1, 0, c, f, 0, 1].join(",")})`;
}
