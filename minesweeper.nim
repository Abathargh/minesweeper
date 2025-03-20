import std/strformat
import std/random


type
  State = enum
    Neutral
    Pressed
    Set

  Field = object
    state: State
    bomb: bool

  Board = object
    fields: seq[seq[Field]]


proc init(board: var Board, rows, cols: int) =
  board.fields = @[]
  for i in 0..<rows:
    board.fields.add newSeq[Field](cols)


proc print(board: Board) =
  stdout.write "[ "
  for idx, row in board.fields.pairs:
    for jdx, field in row.pairs:
      if idx != 0 and jdx == 0: stdout.write "  "
      stdout.write fmt"({field.state}, {field.bomb}) "
    stdout.write if idx == board.fields.len - 1: "]\n" else: "\n"


proc neighbours(board: Board; x, y: int): (int, int) =
  let
    x_start = if x == 0: 0 else: x - 1
    x_end   = if x == board.fields.len - 1: board.fields.len - 1 else: x + 1
    y_start = if y == 0: 0 else: y - 1
    y_end   = if x == board.fields.len - 1: board.fields.len - 1 else: y + 1

  var
    bombs = 0
    num   = 0

  for ix in x_start..<x_end:
    for iy in y_start..<y_end:
      if x == ix and y == iy: continue
      if board.fields[ix][iy].bomb:
        inc bombs
      inc num

  (num, bombs)


proc generate_board(board: var Board) =
  const max_ratio = 0.8
  for idx, row in board.fields.mpairs:
    for jdx, field in row.mpairs:
      let
        (num, bombs) = neighbours(board, idx, jdx)
        ratio        = bombs.float / num.float

      if ratio < max_ratio and rand(0..1) == 1:
        field.bomb = true


proc main =
  randomize()
  var board = Board()
  board.init(4, 5)
  board.print()
  board.generate_board()
  board.print()





main()
