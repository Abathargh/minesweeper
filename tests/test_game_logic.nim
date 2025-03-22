import ../minesweeper
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
