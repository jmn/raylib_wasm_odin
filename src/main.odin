package main

import "base:runtime"
import "core:fmt"
import "core:math/rand"
import "core:mem"
import rl "raylib"

foreign import "odin_env"

ctx: runtime.Context

tempAllocatorData: [mem.Megabyte * 4]byte
tempAllocatorArena: mem.Arena

mainMemoryData: [mem.Megabyte * 16]byte
mainMemoryArena: mem.Arena

timer: f32
cubePos: [32]rl.Vector3
cubeColors: [32]rl.Color

GAME_TITLE :: "A SPACE GAME"
SCREEN_SIZE :: 800
PROJECTILE_SPEED :: 1.2
PLAYER_SIZE :: 50
SHOT_SIZE :: 15
SCORE_INCREMENT :: 10

score: i32 = 0
colliding := false
shots: [dynamic]Shot = make([dynamic]Shot, 0, 64)
target_is_alive := true
player_has_moved := false
player_position: rl.Vector2
target_position: rl.Vector2
first_run := true

Shot :: struct {
	position:   rl.Vector2,
	direction:  rl.Vector2,
	time_fired: f64,
}

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

@(export, link_name = "step")
step :: proc "contextless" () {
	context = ctx
	update()
}

update :: proc() {
	dt := rl.GetFrameTime() // Get actual delta time for each frame
	initial_player_position := rl.Vector2 {
		f32(rl.GetScreenWidth() / 2),
		f32(rl.GetScreenHeight() / 2),
	}
	initial_target_position := rl.Vector2{f32(rl.GetScreenWidth() / 2), 100}

	camera_zoom := f32(rl.GetScreenHeight() / SCREEN_SIZE)
	if (first_run) {
		target_position = initial_target_position
		first_run = false
	}

	if (!player_has_moved) {
		player_position = initial_player_position
	}

	// Clear the background at the start of drawing
	rl.BeginDrawing()
	rl.ClearBackground(rl.BLUE)

	// Camera settings
	camera := rl.Camera2D {
		// target = rl.Vector2{player_position[0], player_position[1]}, // Camera target follows the player
		// offset = rl.Vector2{f32(rl.GetScreenWidth()) / 2, f32(rl.GetScreenHeight()) / 2}, // Center the camera on the player
		zoom = camera_zoom,
	}
	//rl.BeginMode2D(camera)

	// Handle player movement
	if rl.IsKeyDown(.LEFT) || rl.IsKeyDown(.A) {
		player_position[0] = player_position[0] - f32(300) * dt
		player_has_moved = true
	}

	if rl.IsKeyDown(.RIGHT) || rl.IsKeyDown(.D) {
		player_position[0] += f32(300) * dt
		player_has_moved = true
	}

	rl.DrawCircleV(player_position, PLAYER_SIZE, rl.RED)

	// Draw the score text
	rl.DrawText(rl.TextFormat("Score: %d", score), 20, 20, 40, rl.WHITE)
	// Draw player as a red circle

	// Draw target rectangle
	if (target_is_alive) {
		rl.DrawRectangleV(target_position, rl.Vector2{300, 30}, rl.YELLOW)
	}

	// Fire projectiles when SPACE is pressed
	if rl.IsKeyDown(.SPACE) || rl.IsKeyDown(.W) {
		// Calculate direction relative to the player position
		dir := rl.Vector2 {
			rl.GetMousePosition()[0] - player_position[0],
			rl.GetMousePosition()[1] - player_position[1],
		}

		// Normalize the direction vector
		//dir = rl.Vector2Normalize(dir)

		// Make a copy of the player position to use for the projectile's starting position
		start_pos := rl.Vector2{player_position[0], player_position[1]}

		// Add a new projectile to the shots array if the last shot is older than 0.4 seconds
		if len(shots) == 0 || rl.GetTime() - shots[len(shots) - 1].time_fired > 0.4 {
			append(&shots, Shot{position = start_pos, direction = dir, time_fired = rl.GetTime()})
		}
	}

	// Update and draw each projectile
	for &shot in shots {
		// Update projectile position based on direction, speed, and delta time
		shot.position = rl.Vector2 {
			shot.position[0] + shot.direction[0] * PROJECTILE_SPEED * dt,
			shot.position[1] + shot.direction[1] * PROJECTILE_SPEED * dt,
		}
		// check if shot is colliding with target if target is alive

		if (target_is_alive) {
			colliding = rl.CheckCollisionCircleRec(
				shot.position,
				SHOT_SIZE,
				rl.Rectangle{target_position[0], target_position[1], 300, 30},
			)
		} else {
			colliding = false
		}
		// remove the shot if it is colliding with the target, destroy the target
		if colliding {
			score += SCORE_INCREMENT
			target_is_alive = false
		}

		rl.DrawCircleV(shot.position, SHOT_SIZE, rl.GREEN)
	}

	//target reappears after .5 seconds
	if !target_is_alive && rl.GetTime() - shots[len(shots) - 1].time_fired > 0.5 {
		target_is_alive = true
		target_position = rl.Vector2 {
			f32(rand.int31() % SCREEN_SIZE),
			f32(rand.int31() % SCREEN_SIZE),
		}
	}

	rl.EndMode2D()
	rl.EndDrawing()
}
