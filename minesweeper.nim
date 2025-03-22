import std/assertions
import std/strformat
import std/random

import raylib


type
  GameState = enum
    Playing
    Done
    Explosion

  FieldState = enum
    Neutral
    Pressed
    Bomb
    Set

  Field = ref object
    state: FieldState
    bomb: bool

  Board = object
    fields: seq[seq[Field]]
    pressed_fields: int
    num_bombs: int

  Direction* = enum
    North
    NorthEast
    East
    SouthEast
    South
    SouthWest
    West
    NorthWest


proc init(board: var Board, rows, cols: int) =
  board.fields = @[]
  board.num_bombs = 0
  board.pressed_fields = 0
  for i in 0..<rows:
    board.fields.add newSeq[Field](cols)
    for j in 0..<cols:
      board.fields[i][j] = Field(state: FieldState.Neutral, bomb: false)


proc len(board: Board): int =
  return board.fields.len * board.fields[0].len


proc print(board: Board) =
  stdout.write "[ "
  for idx, row in board.fields.pairs:
    for jdx, field in row.pairs:
      if idx != 0 and jdx == 0: stdout.write "  "
      stdout.write fmt"({field.state}, {field.bomb}) "
    stdout.write if idx == board.fields.len - 1: "]\n" else: "\n"


proc direction*(x, y, nx, ny: int): Direction =
  ## Checks the direction of the Point(nx, ny) with reference to Point(x, y)
  let
    xdiff = x - nx
    ydiff = y - ny

  assert x != nx or y != ny

  if xdiff == 0:
    return if ydiff > 0: West else: return East

  if ydiff == 0:
    return if xdiff > 0: North else: South

  if xdiff > 0:
    return if ydiff > 0: NorthWest else: return NorthEast

  return if ydiff > 0: SouthWest else: SouthEast


iterator neighbours(board: Board; x, y: int): (int, int, Field) =
  let
    x_start = if x == 0: 0 else: x - 1
    x_end   = if x == board.fields.len - 1: board.fields.len - 1 else: x + 1
    y_start = if y == 0: 0 else: y - 1
    y_end   = if x == board.fields.len - 1: board.fields.len - 1 else: y + 1

  for ix in x_start..<x_end:
    for iy in y_start..<y_end:
      if x == ix and y == iy: continue
      yield (ix, iy, board.fields[ix][iy])


iterator direction_neighbours(board: Board; x, y: int, dir: Direction): (int, int, Field) =
  let
    x_start = if x == 0: 0 else: x - 1
    x_end   = if x == board.fields.len - 1: board.fields.len - 1 else: x + 1
    y_start = if y == 0: 0 else: y - 1
    y_end   = if x == board.fields.len - 1: board.fields.len - 1 else: y + 1

  for ix in x_start..<x_end:
    for iy in y_start..<y_end:
      if x == ix and y == iy: continue
      if direction(x, y, ix, iy) == dir:
        yield (ix, iy, board.fields[ix][iy])


proc neighbours_bomb_count(board: Board; x, y: int): (int, int) =
  var
    bombs = 0
    num   = 0

  for nx, ny, elem in board.neighbours(x, y):
    if elem.bomb:
      inc bombs
    inc num

  (num, bombs)


# Make it so that when egnerating this, the first hit is always fine
proc generate_board(board: var Board) =
  const max_ratio = 0.5
  for idx, row in board.fields.mpairs:
    for jdx, field in row.mpairs:
      let
        (num, bombs) = neighbours_bomb_count(board, idx, jdx)
        ratio        = bombs.float / num.float

      if ratio < max_ratio and rand(0..1) == 1:
        field.bomb = true
        inc board.num_bombs


proc update_in_direction(board: var Board; x, y: int, dir: Direction) =
  # This is only ever called if (x, y) is neutral and not a bomb
  let field = board.fields[x][y]

  field.state = FieldState.Pressed
  inc board.pressed_fields

  for nx, ny, dir_elem in board.direction_neighbours(x, y, dir):
    if dir_elem.state != FieldState.Neutral or dir_elem.bomb:
      continue
    board.update_in_direction(nx, ny, dir)


proc update(board: var Board; x, y: int): GameState =
  # check if (x, y) is a bomb or not; things to be noted:
  # - if it is a bomb:
  #   - switch state to bomb so the ui can update
  #   - return GameState.Bomb
  # - if it is not a bomb:
  #   - update the board, the algorithm may be:
  #     - if neighbours don't have a bomb in the direction from which the selection came, then expand again
  #     - if the neighbour is set or pressed stop expanding
  #     - if there is a bomb in that direction, stop expanding
  #   -  in case every element is cleared, return GameState.Done, otherwise GameState.Playing

  let field = board.fields[x][y]

  if field.bomb:
    field.state = FieldState.Bomb
    return GameState.Explosion

  if field.state == FieldState.Set or field.state == FieldState.Pressed:
    return GameState.Playing

  # (x, y) is neutral and it has no bomb => let's mark it as pressed
  field.state = FieldState.Pressed
  inc board.pressed_fields

  for nx, ny, elem in board.neighbours(x, y):
    # don't expand when encountering set/pressed blocks
    if elem.state != FieldState.Neutral or elem.bomb:
      continue

    # check the cardinal direction of this neighbour with reference to the current element under analysis
    # and try updating in that direction until a nested neighbour with a non-neutral field is encountered
    let dir = direction(x, y, nx, ny)
    board.update_in_direction(nx, ny, dir)

  if board.pressed_fields == board.len - board.num_bombs:
    return GameState.Done

  GameState.Playing


const
  box  = 20.int32
  fps  = 60
  rows = 40
  cols = 50
  off  = 2

  width  = box * cols + off
  height = box * rows + off

  color_neutral = get_color(0xb8f9ea)
  color_pressed = get_color(0x50bfa5)
  color_bomb    = get_color(0x000000)
  color_set     = get_color(0x61877d)


proc draw_endgame_state(state: GameState) =
  assert state != GameState.Playing

  const
    msg_box_width = 300
    msg_box_height = 200

    msg_box_x = (width - msg_box_width) div 2
    msg_box_y = (height - msg_box_height) div 2

    msg_font_size = 20

  let
    msg = if state == GameState.Explosion: "You lost..." else: "You won!"
    msg_width = measure_text(msg, msg_font_size)

    msg_x = msg_box_x + (msg_box_width - msg_width) div 2
    msg_y = msg_box_y + (msg_box_height - msg_font_size) div 2

  draw_rectangle(msg_box_x, msg_box_y, msg_box_width , msg_box_height, LightGray)
  draw_text(msg, msg_x, msg_y, msg_font_size, DarkGray)


proc main =
  randomize()
  var game_state = GameState.Playing

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
    if game_state == GameState.Playing:
      for i, row in actual_board.pairs:
        for j, box in row.pairs:
          let field = board.fields[i][j]
          if is_mouse_button_pressed(MouseButton.Right):
            if check_collision_point_rec(pos, box):
              case field.state
              of FieldState.Neutral:
                field.state = FieldState.Set
              of FieldState.Set:
                field.state = FieldState.Neutral
              else:
                discard
              continue

          if is_mouse_button_pressed(MouseButton.Left):
            if check_collision_point_rec(pos, box):
              game_state  = board.update(i, j)

    drawing:
      clearBackground(LightGray)
      for i in 0.int32..<rows:
        for j in 0.int32..<cols:
          let color = case board.fields[i][j].state
            of FieldState.Neutral: color_neutral
            of FieldState.Pressed: color_pressed
            of FieldState.Bomb:    color_bomb
            of FieldState.Set:     color_set

          draw_rectangle(j * box + off, i * box + off, box - off, box - off, color)

      if game_state != GameState.Playing:
        draw_endgame_state(game_state)


when isMainModule:
  main()
