extends Node2D

@onready var header_text: Label = $header_text

@onready var tic_box_0: Node2D = $Board/ButtonGrid/TicBox0
@onready var tic_box_1: Node2D = $Board/ButtonGrid/TicBox1
@onready var tic_box_2: Node2D = $Board/ButtonGrid/TicBox2
@onready var tic_box_3: Node2D = $Board/ButtonGrid/TicBox3
@onready var tic_box_4: Node2D = $Board/ButtonGrid/TicBox4
@onready var tic_box_5: Node2D = $Board/ButtonGrid/TicBox5
@onready var tic_box_6: Node2D = $Board/ButtonGrid/TicBox6
@onready var tic_box_7: Node2D = $Board/ButtonGrid/TicBox7
@onready var tic_box_8: Node2D = $Board/ButtonGrid/TicBox8

# either 1 or 2
var current_player = 1

# true = playing, false = game over
var game_state = true

var game_grid = [
	[0, 0, 0],
	[0, 0, 0],
	[0, 0, 0],
]
const GRID_SIZE = 3    # convenience

# This is populated in _ready()
var grid_button_mapping := []

# Coordinates mapping for a 3x3 grid
const cell_mapping = {
	0: [0, 0],
	1: [0, 1],
	2: [0, 2],
	3: [1, 0],
	4: [1, 1],
	5: [1, 2],
	6: [2, 0],
	7: [2, 1],
	8: [2, 2],
}

# Use thread for running the AI thinking so that it doesn't
# block the main loop
var _thread: Thread = Thread.new()

# These are all for the minimax function
const MAX_DEPTH = 9
const ART_DELAY = 0.6   # artificial delay
var _best_move = -1
var minimax_counter = 0
var pruning_counter = 0
var depth_limit_counter = 0

# ==================
# 	Helper Functions
# ==================

func _calculate_winner(board: Array) -> int:
	# Return codes:
	# 1 = player1 wins
	# 2 = computer wins
	# 0 = tie game
	# -1 = game ongoing
	
	var rows: Array = board
	var columns: Array = []
	var main_diag: Array = []
	var anti_diag: Array = []

	for col in range(GRID_SIZE):
		var column: Array = []
		for row in board:
			column.append(row[col])
		columns.append(column)

	for i in range(GRID_SIZE):
		main_diag.append(board[i][i])
		anti_diag.append(board[i][GRID_SIZE - i - 1])

	var lines: Array = rows + columns + [main_diag] + [anti_diag]

	for player in [1, 2]:
		for line in lines:
			if line.all(func(cell): return cell == player):
				return 1 if player == 1 else 2
	
	# The usage of Array.all() here is just like in Javascript.
	# Also Array.any(), Array.map(), Array.filter()

	var board_full: bool = (
		board.all(func(row): return row.all(func(cell): return cell != 0))
	)
	if board_full:
		return 0    # tie game
	else:
		return -1   # game ongoing

func _game_over(result: int):
	await get_tree().process_frame
	if result == 1:
		header_text.text = "You win"
	elif result == 2:
		header_text.text = "Computer wins"
	else:
		assert(result == 0)
		header_text.text = "Draw"
	game_state = false

func _reset_grid():
	game_grid = [
		[0, 0, 0],
		[0, 0, 0],
		[0, 0, 0],
	]

func _update_visual_grid():
	# then update visual state
	for i in range(game_grid.size()):
		var row = game_grid[i]
		for j in range(row.size()):
			var col = row[j]
			assert(col is int)
			var button = grid_button_mapping[i][j]
			assert(button is Node2D)
			button.set_player(col)

# ==================
# 	Game Buttons
# ==================

func _on_quit_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/menu.tscn")
	
func _on_restart_button_pressed() -> void:
	_reset_grid()
	_update_visual_grid()
	game_state = true
	header_text.text = "Your turn"
	

func apply_move(player: int, x: int, y: int):
	# first update the bit grid
	game_grid[x][y] = player
	_update_visual_grid()

# =======+++===========
# 	Game Loop Functions
# =====================

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	
	grid_button_mapping = [
		[tic_box_0, tic_box_1, tic_box_2],
		[tic_box_3, tic_box_4, tic_box_5],
		[tic_box_6, tic_box_7, tic_box_8],
	]
	header_text.text = "Your move"
	
	# Register all the button signals
	for row in grid_button_mapping:
		for box in row:
			box.pressed_action.connect(_handle_button)
	
func _handle_button(cell_num: int):
	print("Game state is %s" % game_state)
	if not game_state:
		print("Game is over broa")
		return
		
	print("You pressed button %s" % cell_num)
	var coordinates = cell_mapping[cell_num]
	var x = coordinates[0]
	var y = coordinates[1]
	player_turn(x, y)

func player_turn(x: int, y: int):
	apply_move(1, x, y)
	var result = _calculate_winner(game_grid)
	
	# -1 means game ongoing, anything else means game over
	if result == -1:
		header_text.text = "Computer is thinking..."
		# This line waits for the frame to finish drawing:
		await RenderingServer.frame_post_draw
		var board_state = game_grid.duplicate(true)
		_thread.start(_run_ai.bind(board_state))

		# This would run without using threading. Interesting to see the
		# difference in gameplay. It will freeze the UI while thinking.
		# For a game like this, that is often not a significant issue, because
		# it does not take long to think.
		#_run_ai(board_state)
	else:
		_game_over(result)


# This gets run in a thread. This is the expensive computation work.
func _run_ai(board_state: Array) -> void:
	
	var move = _minimax(
		board_state,
		0,      # starting depth
		true,   # starts maximizing
		-INF,   # alpha
		INF     # beta
	)
	var coordinates = move[1]
	
	# This will schedule a function to run on the main thread
	call_deferred("_ai_finished_thinking", coordinates)

func _ai_finished_thinking(coordinates: Array) -> void:
	# We're back on the main thread here, safe to touch nodes again
	var x = coordinates[0]
	var y = coordinates[1]
	_thread.wait_to_finish()
	print("Computer finished thinking")
	print("Minimax counter: %s" % minimax_counter)
	print("Pruning counter: %s" % pruning_counter)
	
	# Artificial delay for computer thinking:
	await get_tree().create_timer(ART_DELAY).timeout
	apply_move(2, x, y)
	
	var result = _calculate_winner(game_grid)
	
	# -1 means game ongoing, anything else means game over
	if result == -1:
		header_text.text = "Your move"
	else:
		_game_over(result)

func _minimax(
	board: Array,
	depth: int,
	is_maximizing: bool,
	alpha: float,
	beta: float,
) -> Array:

	# First, check if there's a winner on the board.
	var winner_check = _calculate_winner(board)
	
	minimax_counter += 1   # counters are just for debugging
	
	# Base cases: game over scenarios
	if winner_check == 2:       # AI is maximizer
		return [10 - depth, null]
	elif winner_check == 1:     # Human is minimizer
		return [-10 + depth, null]
	elif winner_check == 0:       # Draw
		return [0, null]
	
	## This is the max depth
	# We dont need it for tic tac toe. But here for reference.
	#if depth == MAX_DEPTH:
		#depth_limit_counter += 1
		#return [0, null]

	var best_move = [null, null]
	var best_score = -INF if is_maximizing else INF
	var player = 2 if is_maximizing else 1
	
	# Try all possible moves
	for row in range(GRID_SIZE):
		for col in range(GRID_SIZE):
			if board[row][col] == 0:   # only try empty cells

				board[row][col] = player
				var result = self._minimax(board, depth + 1, not is_maximizing, alpha, beta)
				var score = result[0]
				board[row][col] = 0         # Undo move
				# NOTE on the move undoing: It's computationally faster
				# to do it this way instead of copying the board each time.

				if is_maximizing and score > best_score:
						best_score = score
						alpha = max(score, alpha)
						best_move = [row, col]
				elif not is_maximizing and score < best_score:
						best_score = score
						beta = min(score, beta)
						best_move = [row, col]

				if beta <= alpha:
					self.pruning_counter += 1   # for debugging
					break

	return [best_score, best_move]
