import std/strformat
import std/random

import raylib


type
  State = enum
    Neutral
    Pressed
    Bomb
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

# Make it so that when egnerating this, the first hit is always fine
proc generate_board(board: var Board) =
  const max_ratio = 0.8
  for idx, row in board.fields.mpairs:
    for jdx, field in row.mpairs:
      let
        (num, bombs) = neighbours(board, idx, jdx)
        ratio        = bombs.float / num.float

      if ratio < max_ratio and rand(0..1) == 1:
        field.bomb = true



const
  box    = 20.int32
  fps    = 60

  rows = 40
  cols = 50

  off = 2

  width  = box * cols + off
  height = box * rows + off

  color_neutral = get_color(0xb8f9ea)
  color_pressed = get_color(0x50bfa5)
  color_bomb    = get_color(0x000000)
  color_set     = get_color(0x61877d)


proc main =
  randomize()
  var board = Board()
  board.init(rows, cols)
  board.generate_board()

  var actual_board: seq[seq[Rectangle]] = @[]
  for i in 0..<rows:
      actual_board.add newSeq[Rectangle](cols)
      for j in 0..<cols:
        actual_board[i][j] = Rectangle(
          x: (j * box + off).float,
          y: (i * box + off).float,
          width: (box - off).float,
          height: (box - off).float
        )

  init_window(width, height, "Cambo Minato")
  set_target_fps(fps)

  while not window_should_close():
    let pos = get_mouse_position()

    # write an algorithm that extracts the i, j coordinates from the mouse position, instead of looping
    for i, row in actual_board.pairs:
      for j, box in row.pairs:
        if is_mouse_button_pressed(MouseButton.Left):
          if check_collision_point_rec(pos, box):
            var field = addr board.fields[i][j]
            field.state = if field.bomb: State.Bomb else: State.Pressed
        elif is_mouse_button_pressed(MouseButton.Right):
          if check_collision_point_rec(pos, box):
            board.fields[i][j].state = State.Set


    drawing:
      clearBackground(LightGray)
      for i in 0.int32..<rows:
        for j in 0.int32..<cols:
          let color = case board.fields[i][j].state
            of State.Neutral: color_neutral
            of State.Pressed: color_pressed
            of State.Bomb:    color_bomb
            of State.Set:     color_set

          draw_rectangle(j * box + off, i * box + off, box - off, box - off, color)

main()
