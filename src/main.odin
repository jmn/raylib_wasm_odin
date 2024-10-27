package click3

import "base:runtime"
import "core:mem"
import "core:fmt"
import "core:math/rand"
import rl "raylib"
foreign import "odin_env"

GAME_TITLE :: "ALL GREEN"
SCREEN_SIZE :: 600

INITIAL_WIDTH :: 600
INITIAL_HEIGHT :: 600
FPS :: 144

BOX_GAP_SIZE :: 20
COLOR_TOLERANCE :: 30

GREEN_COLOR :: rl.Color{0, 255, 0, 255} // Green color for the win condition
KEYS :: []rl.KeyboardKey {
	rl.KeyboardKey.ZERO,
	rl.KeyboardKey.ONE,
	rl.KeyboardKey.TWO,
	rl.KeyboardKey.THREE,
	rl.KeyboardKey.FOUR,
	rl.KeyboardKey.FIVE,
	rl.KeyboardKey.SIX,
	rl.KeyboardKey.SEVEN,
	rl.KeyboardKey.EIGHT,
	rl.KeyboardKey.NINE,
}

Square :: struct {
	x:     int,
	y:     int,
	color: rl.Color,
}


ctx: runtime.Context

tempAllocatorData: [mem.Megabyte * 4]byte
tempAllocatorArena: mem.Arena

mainMemoryData: [mem.Megabyte * 16]byte
mainMemoryArena: mem.Arena

@(export, link_name = "_main")
_main :: proc "c" () {
	ctx = runtime.default_context()
	context = ctx

	mem.arena_init(&mainMemoryArena, mainMemoryData[:])
	mem.arena_init(&tempAllocatorArena, tempAllocatorData[:])

	ctx.allocator = mem.arena_allocator(&mainMemoryArena)
	ctx.temp_allocator = mem.arena_allocator(&tempAllocatorArena)

	rl.InitWindow(SCREEN_SIZE, SCREEN_SIZE, GAME_TITLE)
	rl.SetTargetFPS(60)

}

update :: proc() {
	// Initialize grid dimensions
	columns, rows: int = 2, 2
	// Initialize grid of squares
	grid := initialize_grid(columns, rows)
	game_won := false
	keys := KEYS
	for !rl.WindowShouldClose() {
		winWidth := f32(rl.GetRenderWidth())
		winHeight := f32(rl.GetRenderHeight())
		if rl.IsWindowResized() {
			winWidth = f32(rl.GetRenderWidth())
			winHeight = f32(rl.GetRenderHeight())
		}

		// Check for numeric key presses to change grid size
		for i in 0 ..< 10 {
			if rl.IsKeyPressed(keys[i]) {
				columns = i + 1 // Update columns (1-10)
				rows = i + 1 // Update rows (1-10)
				grid = initialize_grid(columns, rows) // Reinitialize grid
				game_won = false // Reset win condition
			}
		}

		// Check for mouse actions
		if rl.IsMouseButtonPressed(rl.MouseButton.LEFT) {
			mouse_pos := rl.GetMousePosition()
			shift_square_color_at_hover(&grid, columns, rows, mouse_pos, winWidth, winHeight)
			game_won = check_if_all_green(grid, columns, rows)
		}

		if rl.IsMouseButtonPressed(rl.MouseButton.RIGHT) {
			shuffle_grid_colors(&grid, columns, rows)
			game_won = check_if_all_green(grid, columns, rows)
		}

		rl.BeginDrawing()
		rl.ClearBackground(rl.WHITE)
		draw(winWidth, winHeight, grid, columns, rows, game_won)

		rl.EndDrawing()
	}
}
// Initializes the grid with random colors based on columns and rows
initialize_grid :: proc(columns, rows: int) -> []Square {
	grid := make([]Square, columns * rows) // Create a slice to hold all squares

	for i in 0 ..< columns {
		for j in 0 ..< rows {
			index := i * rows + j // Calculate index in the linear slice
			// 25% chance to be green, otherwise random color
			if rand.int31_max(100) < 25 {
				grid[index] = Square {
					x     = i,
					y     = j,
					color = GREEN_COLOR,
				}
			} else {
				grid[index] = Square {
					x     = i,
					y     = j,
					color = random_color(),
				}
			}
		}
	}

	return grid
}

random_color :: proc() -> rl.Color {
	return rl.Color {
		u8(rand.int31_max(255)),
		u8(rand.int31_max(255)),
		u8(rand.int31_max(255)),
		255, // Full opacity
	}
}

shift_square_color_at_hover :: proc(
	grid: ^[]Square,
	columns, rows: int,
	mouse_pos: rl.Vector2,
	winWidth, winHeight: f32,
) {
	total_gap_width := f32(columns + 1) * f32(BOX_GAP_SIZE)
	total_gap_height := f32(rows + 1) * f32(BOX_GAP_SIZE)
	col_size := f32(winWidth - f32(total_gap_width)) / f32(columns)
	row_size := f32(winHeight - f32(total_gap_height)) / f32(rows)
	box_size := min(col_size, row_size)

	for i in 0 ..< columns {
		for j in 0 ..< rows {
			pos_x := f32(i) * (box_size + BOX_GAP_SIZE) + BOX_GAP_SIZE
			pos_y := f32(j) * (box_size + BOX_GAP_SIZE) + BOX_GAP_SIZE

			// Check if mouse position is within this square
			if mouse_pos.x >= pos_x &&
			   mouse_pos.x <= pos_x + box_size &&
			   mouse_pos.y >= pos_y &&
			   mouse_pos.y <= pos_y + box_size {
				// 25% chance to turn green when clicked, otherwise shift color
				if rand.int31_max(100) < 25 {
					grid[i * rows + j].color = GREEN_COLOR
				} else {
					shift_color(&grid[i * rows + j].color)
				}
				return
			}
		}
	}
}

shift_color :: proc(color: ^rl.Color) {
	// Set color to a completely random color
	color.r = u8(rand.int31_max(255))
	color.g = u8(rand.int31_max(255))
	color.b = u8(rand.int31_max(255))
}

shuffle_grid_colors :: proc(grid: ^[]Square, columns, rows: int) {
	for i in 0 ..< columns {
		for j in 0 ..< rows {
			index := i * rows + j // Calculate index in the linear slice
			// 5% chance to become green, otherwise random color
			if rand.int31_max(100) < 5 {
				grid[index].color = GREEN_COLOR
			} else {
				grid[index].color = random_color()
			}
		}
	}
}

// Helper function to check if two colors are equal
color_equals :: proc(a, b: rl.Color) -> bool {
    return a.r == b.r && a.g == b.g && a.b == b.b && a.a == b.a
}

// Helper function to check if a color is close enough to green
color_is_close_to_green :: proc(color: rl.Color) -> bool {
    return abs(int(color.r) - int(GREEN_COLOR.r)) <= COLOR_TOLERANCE &&
           abs(int(color.g) - int(GREEN_COLOR.g)) <= COLOR_TOLERANCE &&
           abs(int(color.b) - int(GREEN_COLOR.b)) <= COLOR_TOLERANCE &&
           color.a == GREEN_COLOR.a
}

// Updated check_if_all_green function to use direct color comparison
check_if_all_green :: proc(grid: []Square, columns, rows: int) -> bool {
    for i in 0 ..< columns {
        for j in 0 ..< rows {
            if !color_equals(grid[i * rows + j].color, GREEN_COLOR) {
                return false
            }
        }
    }
    return true
}

display_win_message :: proc(winWidth, winHeight: f32) {
	win_message: cstring = "You Win!"
	difficulty_message: cstring = "Press numeric keys to change difficulty"

	win_font_size: i32 = 80
	difficulty_font_size: i32 = 26 // Smaller font size for difficulty message

	// Calculate position for the win message
	win_text_width := rl.MeasureText(win_message, win_font_size)
	win_text_position := rl.Vector2 {
		(winWidth - f32(win_text_width)) / 2,
		(winHeight - f32(win_font_size)) / 2,
	}

	// Calculate position for the difficulty message
	difficulty_text_width := rl.MeasureText(difficulty_message, difficulty_font_size)
	difficulty_text_position := rl.Vector2 {
		(winWidth - f32(difficulty_text_width)) / 2,
		(winHeight - f32(win_font_size) - f32(difficulty_font_size) - 10), // Position below the win message
	}

	// Draw the win message
	rl.DrawText(
		win_message,
		i32(win_text_position.x),
		i32(win_text_position.y),
		win_font_size,
		rl.DARKGREEN,
	)

	// Draw the difficulty message
	rl.DrawText(
		difficulty_message,
		i32(difficulty_text_position.x),
		i32(difficulty_text_position.y),
		difficulty_font_size,
		rl.DARKGRAY,
	) // Use a different color for contrast
}


draw :: proc(winWidth, winHeight: f32, grid: []Square, columns, rows: int, game_won: bool) {
	total_gap_width := f32(columns + 1) * f32(BOX_GAP_SIZE)
	total_gap_height := f32(rows + 1) * f32(BOX_GAP_SIZE)
	col_size := f32(winWidth - f32(total_gap_width)) / f32(columns)
	row_size := f32(winHeight - f32(total_gap_height)) / f32(rows)
	box_size := min(col_size, row_size)

	for i in 0 ..< columns {
		for j in 0 ..< rows {
			pos: rl.Vector2
			pos.x = f32(f32(i) * (box_size + BOX_GAP_SIZE) + BOX_GAP_SIZE)
			pos.y = f32(f32(j) * (box_size + BOX_GAP_SIZE) + BOX_GAP_SIZE)

			rl.DrawRectangleV(pos, {box_size, box_size}, grid[i * rows + j].color)
		}
	}

	// Display win message if the game is won
	if game_won {
		display_win_message(winWidth, winHeight)
	}
}

@(export, link_name = "step")
step :: proc "contextless" () {
	context = ctx
	update()
}