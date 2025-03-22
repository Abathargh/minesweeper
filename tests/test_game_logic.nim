import ../minesweeper
import std/sugar
import unittest

suite "logic":
  test "direction":
    # let's say we have a 3x3 matrix
    type
      Point = object
        x, y: int

      TestCase = object
        p1, p2:   Point
        expected: Direction

    let test_cases = [
      TestCase(
        p1: Point(x: 1, y: 1),
        p2: Point(x: 0, y: 1),
        expected: North
      ),
      TestCase(
        p1: Point(x: 1, y: 1),
        p2: Point(x: 0, y: 0),
        expected: NorthWest
      ),
      TestCase(
        p1: Point(x: 1, y: 1),
        p2: Point(x: 1, y: 0),
        expected: West
      ),
      TestCase(
        p1: Point(x: 1, y: 1),
        p2: Point(x: 2, y: 0),
        expected: SouthWest
      ),
      TestCase(
        p1: Point(x: 1, y: 1),
        p2: Point(x: 2, y: 1),
        expected: South
      ),
      TestCase(
        p1: Point(x: 1, y: 1),
        p2: Point(x: 2, y: 2),
        expected: SouthEast
      ),
      TestCase(
        p1: Point(x: 1, y: 1),
        p2: Point(x: 1, y: 2),
        expected: East
      ),
      TestCase(
        p1: Point(x: 1, y: 1),
        p2: Point(x: 0, y: 2),
        expected: NorthEast
      )
    ]

    for test_case in test_cases:
      let p1  = test_case.p1
      let p2  = test_case.p2
      let exp = test_case.expected
      check minesweeper.direction(p1.x, p1.y, p2.x, p2.y) == exp

  test "basic neighbours algorithm":
    type TestCase = object
      x, y: int
      exp:  seq[(int, int, bool)]

    var board = Board()
    board.init(3, 3)
    board.fields[0][0].bomb = true
    board.fields[0][1].bomb = true
    board.fields[1][2].bomb = true
    board.fields[2][2].bomb = true

    let test_cases = [
      TestCase(
        x: 1,
        y: 1,
        exp: @[
          (0, 0, true),
          (0, 1, true),
          (0, 2, false),
          (1, 0, false),
          (1, 2, true),
          (2, 0, false),
          (2, 1, false),
          (2, 2, true),
        ])
    ]

    for test_case in test_cases:
      let
        x =   test_case.x
        y =   test_case.y
        exp = test_case.exp

      let neigh = collect:
        for nx, ny, field in board.neighbours(x, y):
          (nx, ny, field.bomb)

      check exp.len == neigh.len

      for idx, exp_neighbour in exp.pairs:
        check exp_neighbour[0] == neigh[idx][0]
        check exp_neighbour[1] == neigh[idx][1]
        check exp_neighbour[2] == neigh[idx][2]
