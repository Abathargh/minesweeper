import std/assertions
import std/strformat
import std/random
import raylib


const
  box  = 30.int32
  fps  = 60
  rows = 20
  cols = 20
  off  = 2

  width  = box * cols + off
  height = box * rows + off

  color_neutral = get_color(0xb8f9ea)
  color_pressed = get_color(0x50bfa5)
  color_bomb    = get_color(0x000000)
  color_set     = get_color(0x61877d)


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

  Field* = object
    state: FieldState
    neighbouring_bombs: int
    bomb*: bool

  Board* = object
    fields*: seq[seq[Field]]
    pressed_fields: int
    num_bombs: int

  CollisionBoard = seq[seq[Rectangle]]

  Direction* = enum
    North
    NorthEast
    East
    SouthEast
    South
    SouthWest
    West
    NorthWest


proc init*(board: var Board, rows, cols: int) =
  board.fields = @[]
  board.num_bombs = 0
  board.pressed_fields = 0
  for i in 0..<rows:
    board.fields.add newSeq[Field](cols)
    for j in 0..<cols:
      board.fields[i][j] = Field(state: FieldState.Neutral, bomb: false)


proc clear(board: var Board) =
  board.num_bombs = 0
  board.pressed_fields = 0
  for idx, row in board.fields.pairs:
    for jdx, field in row.pairs:
      board.fields[idx][jdx].state = FieldState.Neutral
      board.fields[idx][jdx].neighbouring_bombs = 0
      board.fields[idx][jdx].bomb = false


proc len(board: Board): int =
  board.fields.len * board.fields[0].len


proc print(board: Board) =
  let
    pressed = board.pressed_fields
    bombs   = board.num_bombs

  stdout.write &"{pressed} - {bombs}\n"
  stdout.write "[ "
  for idx, row in board.fields.pairs:
    for jdx, field in row.pairs:
      if idx != 0 and jdx == 0: stdout.write "  "
      let
        state  = if field.state == FieldState.Neutral: "●" else: "○"
        bomb   = if field.bomb: "▣" else: "□"
        nbombs = field.neighbouring_bombs
      stdout.write fmt"({state}, {bomb}, {nbombs}) "
    stdout.write if idx == board.fields.len - 1: "]\n" else: "\n"


proc winning_state(board: Board): bool =
  board.len - board.pressed_fields == board.num_bombs


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


iterator neighbours*(board: Board; x, y: int): (int, int, Field) =
  let
    x_start = if x == 0: 0 else: x - 1
    y_start = if y == 0: 0 else: y - 1
    x_end   = if x == board.fields.len - 1:    x else: x + 1
    y_end   = if y == board.fields[0].len - 1: y else: y + 1

  for ix in x_start..x_end:
    for iy in y_start..y_end:
      if x == ix and y == iy: continue
      yield (ix, iy, board.fields[ix][iy])


iterator direction_neighbours(board: Board; x, y: int, dir: Direction): (int, int, Field) =
  let
    x_start = if x == 0: 0 else: x - 1
    y_start = if y == 0: 0 else: y - 1
    x_end   = if x == board.fields.len - 1:    x else: x + 1
    y_end   = if y == board.fields[0].len - 1: y else: y + 1

  for ix in x_start..x_end:
    for iy in y_start..y_end:
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


proc generate_board(board: var Board; x, y: int) =
  # Generate a board with a random mapping for bombs.
  # Make it so that the first point (x, y), is never a bomb.
  const max_ratio = 0.2

  # first pass: bombs generation algorithm
  for idx, row in board.fields.mpairs:
    for jdx, field in row.mpairs:
      let
        (num, bombs) = board.neighbours_bomb_count(idx, jdx)
        ratio        = bombs.float / num.float

      if not (idx == x and jdx == y) and ratio < max_ratio and rand(0..1) == 1:
        field.bomb = true
        inc board.num_bombs

  # second pass: set the neighbouring bombs count for each field
  for idx, row in board.fields.mpairs:
    for jdx, field in row.mpairs:
      let (_, bombs) = board.neighbours_bomb_count(idx, jdx)
      field.neighbouring_bombs = bombs


proc update_in_direction(board: var Board; x, y: int, dir: Direction) =
  # This is only ever called if (x, y) is neutral and not a bomb
  let field = addr board.fields[x][y]

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
  let field = addr board.fields[x][y]

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

  if board.winning_state():
    return GameState.Done

  GameState.Playing


proc init(cboard: var CollisionBoard; rows, cols: int) =
  cboard = @[]
  for i in 0..<rows:
    cboard.add newSeq[Rectangle](cols)
    for j in 0..<cols:
      cboard[i][j] = Rectangle(
        x: (j * box + off).float,
        y: (i * box + off).float,
        width: (box - off).float,
        height: (box - off).float
      )


proc draw_endgame_state(state: GameState) =
  assert state != GameState.Playing

  const
    msg_box_width = 300
    msg_box_height = 200

    msg_box_x = (width - msg_box_width) div 2
    msg_box_y = (height - msg_box_height) div 2

    msg_font_size = 20

  let
    msg = if state == GameState.Explosion: "You lost... (S to restart)" else: "You won!"
    msg_width = measure_text(msg, msg_font_size)

    msg_x = msg_box_x + (msg_box_width - msg_width) div 2
    msg_y = msg_box_y + (msg_box_height - msg_font_size) div 2

  draw_rectangle(msg_box_x, msg_box_y, msg_box_width , msg_box_height, LightGray)
  draw_text(msg, msg_x, msg_y, msg_font_size, DarkGray)


proc main =
  var
    started = false
    game_state = GameState.Playing
    board = Board()
    collision_board = default(CollisionBoard)

  randomize()

  init_window(width, height, "Cambo Minato")
  set_target_fps(fps)

  board.init(rows, cols)
  collision_board.init(rows, cols)
  board.print()

  while not window_should_close():
    if is_key_pressed(KeyboardKey.S):
      board.clear()
      started = false
      game_state = GameState.Playing

    let pos = get_mouse_position()

    # write an algorithm that extracts the i, j coordinates from the mouse position, instead of looping
    if game_state == GameState.Playing:
      for i, row in collision_board.pairs:
        for j, box in row.pairs:
          let field = addr board.fields[i][j]
          if is_mouse_button_pressed(MouseButton.Right):
            if check_collision_point_rec(pos, box):
              case field.state
              of FieldState.Neutral: field.state = FieldState.Set
              of FieldState.Set:     field.state = FieldState.Neutral
              else: discard
              continue

          if is_mouse_button_pressed(MouseButton.Left) and field.state == FieldState.Neutral:
            if check_collision_point_rec(pos, box):
              if not started:
                board.generate_board(i, j)
                started = true
              game_state  = board.update(i, j)

    drawing:
      clearBackground(LightGray)
      for i in 0.int32..<rows:
        for j in 0.int32..<cols:
          let field = board.fields[i][j]
          let color = case field.state
            of FieldState.Neutral: color_neutral
            of FieldState.Pressed: color_pressed
            of FieldState.Bomb:    color_bomb
            of FieldState.Set:     color_set

          # draw the box for this field, with the appropriate color
          draw_rectangle(j * box + off, i * box + off, box - off, box - off, color)

          # write the number of mines close to this box
          if field.state == FieldState.Pressed:
            let text = if field.neighbouring_bombs == 0: "" else: fmt"{field.neighbouring_bombs}"
            draw_text(text, j * box + off, i * box + off, box, DarkGray)

      if game_state != GameState.Playing:
        draw_endgame_state(game_state)


when isMainModule:
  main()
