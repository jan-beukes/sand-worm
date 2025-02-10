package main

import "core:fmt"
import "core:math/linalg"
import rl "vendor:raylib"

WINDOW_WIDTH :: 1280
WINDOW_HEIGHT :: 720

RESX :: 160
RESY :: 90

COLOR_BG :: rl.Color{0x18, 0x18, 0x18, 0xFF}

ParticleType :: enum(u32) {
    NONE,
    SAND,
}

Particle :: struct {
    type: ParticleType,
    life_time: f32,
    was_updated: bool
}

EngineState :: struct {
    window_width: i32,
    window_height: i32,
}

ParticleColors :: [ParticleType]rl.Color {
    .NONE = COLOR_BG,
    .SAND = rl.YELLOW,
}

// global state
state: EngineState
particles: [RESY][RESX]Particle
particle_image: rl.Image

move_to_cell :: proc(p: Particle, row, col: i32) -> bool {
    if !(row >= 0 && row < RESY) do return false
    if !(col >= 0 && col < RESX) do return false
    if particles[row][col].type != .NONE do return false

    particles[row][col] = p
    particles[row][col].was_updated = true
    return true
}

update_sand :: proc(p: Particle, row, col: i32) {
    if move_to_cell(p, row + 1, col) {
        rl.DrawPixel(col, row + 1, ParticleColors[.SAND])
    } else if move_to_cell(p, row + 1, col + 1) {
        rl.DrawPixel(col + 1, row + 1, ParticleColors[.SAND])
    } else if move_to_cell(p, row + 1, col - 1) {
        rl.DrawPixel(col - 1, row + 1, ParticleColors[.SAND])
    } else {
        rl.DrawPixel(col, row, ParticleColors[.SAND])
        return
    }
    particles[row][col].type = .NONE
    rl.DrawPixel(col, row, ParticleColors[.NONE])
}

update_particles :: proc() {
    for row in 0..<RESY {
        for col in 0..<RESX {
            p := &particles[row][col]
            if p.was_updated do continue
            switch p.type {
                case .NONE: continue
                case .SAND: update_sand(p^, i32(row), i32(col))
            }
        }
    }

    // reset particles updated state for this frame
    for &row in particles {
        for &p in row do p.was_updated = false
    }

}

handle_particle_interaction :: proc() {
    mouse_pos := rl.GetMousePosition() * (f32(RESX)/f32(state.window_width))
    mouse_x, mouse_y := int(mouse_pos.x), int(mouse_pos.y)
    // clamp truncated mouse coords
    mouse_x = min(RESX - 1, max(0, mouse_x))
    mouse_y = min(RESY - 1, max(0, mouse_y))

    // add particles
    if rl.IsMouseButtonDown(.LEFT) {
        selected_cell := &particles[mouse_y][mouse_x]
        if selected_cell.type == .NONE {
            selected_cell.type = .SAND
        }
    }

    ERASE_RADIUS :: 5
    if rl.IsMouseButtonDown(.RIGHT) {
        for y := 0; y < 2*ERASE_RADIUS; y += 1 {
            py := mouse_y - ERASE_RADIUS + y
            if !(py >= 0 && py < RESY) do continue
            for x := 0; x < 2*ERASE_RADIUS; x += 1 {
                px := mouse_x - ERASE_RADIUS + x
                if !(px >= 0 && px < RESX) {
                    continue
                }
                dist := [2]f32{f32(px - mouse_x), f32(py - mouse_y)}
                if linalg.vector_length(dist) > ERASE_RADIUS {
                    continue
                }

                if particles[py][px].type != .NONE {
                    particles[py][px].type = .NONE
                }

            }

        }
    }
}

main :: proc() {
    fmt.println("Hello, World")
    rl.InitWindow(WINDOW_WIDTH, WINDOW_HEIGHT, "Sand Worm")
    defer rl.CloseWindow()
    rl.SetTargetFPS(120)
    state.window_width = rl.GetScreenWidth()
    state.window_height = rl.GetScreenHeight()

    target := rl.LoadRenderTexture(RESX, RESY)

    for !rl.WindowShouldClose() {
        dt := rl.GetFrameTime()

        handle_particle_interaction()

        rl.BeginTextureMode(target)
        rl.ClearBackground(COLOR_BG)
        update_particles()
        rl.EndTextureMode()

        rl.BeginDrawing()
        src := rl.Rectangle{0, 0, f32(target.texture.width), -f32(target.texture.height)}
        dst := rl.Rectangle{0, 0, f32(state.window_width), f32(state.window_height)}
        rl.DrawTexturePro(target.texture, src, dst, rl.Vector2(0), 0, rl.WHITE)

        rl.EndDrawing()
    }
}
