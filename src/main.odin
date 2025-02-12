package main

import "core:fmt"
import "core:math/linalg"
import "core:math"
import rl "vendor:raylib"

WINDOW_WIDTH :: 1280
WINDOW_HEIGHT :: 720

RESX :: 320
RESY :: 180

GRAVITY :: 3000.0
SPREAD_FACTOR :: 5

SIM_TICKS :: 120
SIM_TICK_TIME :: (1.0 / SIM_TICKS)

COLOR_BG :: rl.Color{0x18, 0x18, 0x18, 0xFF}

ParticleType :: enum(u8) {
    NONE,
    SAND,
    WATER,
    SMOKE,
}

Particle :: struct {
    type: ParticleType,
    free_particle: bool,
    velocity: rl.Vector2,
    life_time: f32,
}

EngineState :: struct {
    window_width: i32,
    window_height: i32,
    last_tick: f64,
}

particle_colors := [ParticleType]rl.Color {
    .NONE = COLOR_BG,
    .SAND = rl.YELLOW,
    .WATER = rl.BLUE,
    .SMOKE = rl.GRAY,
}

// global state
state: EngineState
particles: [RESY][RESX]Particle
simulation_image: rl.Image = rl.GenImageColor(RESX, RESY, COLOR_BG)

in_bounds :: proc(row, col: i32) -> bool {
    if !(row >= 0 && row < RESY) do return false
    if !(col >= 0 && col < RESX) do return false
    return true
}

can_move_to_cell :: proc(row, col: i32, t: ParticleType) -> bool {
    if !in_bounds(row, col) do return false
    switch t {
    case .NONE: return true
    case .WATER: {
        if particles[row][col].type == .NONE do return true
    }
    case .SAND: {
        if particles[row][col].type == .NONE do return true
        if particles[row][col].type == .WATER do return true
    }
    case .SMOKE:
    }

    return false
}

set_particle :: proc(row, col: i32, t: ParticleType) {
    particles[row][col].type = t
    rl.ImageDrawPixel(&simulation_image, col, row, particle_colors[t])
}

// move the given particle
move_particle :: proc(p: Particle, row, col: i32) {
    particles[row][col] = p
    rl.ImageDrawPixel(&simulation_image, i32(col), i32(row), particle_colors[p.type])
} 

update_sand :: proc(p: Particle, row, col: i32) {
    p := p
    if can_move_to_cell(row + 1, col, p.type) {
        p.velocity.y += GRAVITY * SIM_TICK_TIME
        dest_row := row + i32(p.velocity.y * SIM_TICK_TIME)
        dest_row = dest_row == row ? dest_row + 1 : dest_row
        for r in row+2..=dest_row {
            if !can_move_to_cell(r, col, p.type) {
                dest_row = r - 1
                break
            }
        }
        move_particle(p, dest_row, col)
        set_particle(row, col, .NONE)
        return
    } else if can_move_to_cell(row + 1, col + 1, p.type) {
        move_particle(p, row + 1, col + 1)
    } else if can_move_to_cell(row + 1, col - 1, p.type) {
        move_particle(p, row + 1, col - 1)
    } else {
        p.velocity = rl.Vector2(0)
        return
    }

    set_particle(row, col, .NONE)
}

update_liquid :: proc(p: Particle, row, col: i32) {
    p := p
    if can_move_to_cell(row + 1, col, p.type) {
        p.velocity.y += GRAVITY * SIM_TICK_TIME
        dest_row := row + i32(p.velocity.y * SIM_TICK_TIME)
        dest_row = dest_row == row ? dest_row + 1 : dest_row
        for r in row+2..=dest_row {
            if !can_move_to_cell(r, col, p.type) {
                dest_row = r - 1
                break
            }
        }
        move_particle(p, dest_row, col)
    } else if can_move_to_cell(row + 1, col + 1, p.type) {
        move_particle(p, row + 1, col + 1)
    } else if can_move_to_cell(row + 1, col - 1, p.type) {
        move_particle(p, row + 1, col - 1)
    } else if can_move_to_cell(row, col + 1, p.type) {
        dest_col := col + SPREAD_FACTOR
        for c in col+1..=dest_col {
            if !can_move_to_cell(row, c, p.type) {
                dest_col = c - 1
                break
            }
        }
        move_particle(p, row, dest_col)
    } else if can_move_to_cell(row, col - 1, p.type) {
        dest_col := col - SPREAD_FACTOR
        for c := col; c >= dest_col; c -= 1 {
            if !can_move_to_cell(row, c, p.type) {
                dest_col = c - 1
                break
            }
        }
        move_particle(p, row, dest_col)
    } else do return

    set_particle(row, col, .NONE)

}

update_particles :: proc() {
    for row := RESY - 1; row >= 0; row -= 1 {
        for col in 0..<RESX {
            p := &particles[row][col]
            switch p.type {
                case .NONE: continue
                case .SAND: update_sand(p^, i32(row), i32(col))
                case .WATER: update_liquid(p^, i32(row), i32(col))
                case .SMOKE: continue
            }
        }
    }

}

// handle interactions with the particle simulation
handle_particle_interaction :: proc(selected_type: ParticleType) {
    mouse_pos := rl.GetMousePosition() * (f32(RESX)/f32(state.window_width))
    mouse_x, mouse_y := int(mouse_pos.x), int(mouse_pos.y)
    // clamp truncated mouse coords
    mouse_x = min(RESX - 1, max(0, mouse_x))
    mouse_y = min(RESY - 1, max(0, mouse_y))

    // add particles
    DRAW_RADIUS :: 2
    if rl.IsMouseButtonDown(.LEFT) {
        for y := 0; y < 2*DRAW_RADIUS; y += 1 {
            py := mouse_y - DRAW_RADIUS + y
            if !(py >= 0 && py < RESY) do continue
            for x := 0; x < 2*DRAW_RADIUS; x += 1 {
                px := mouse_x - DRAW_RADIUS + x
                if !(px >= 0 && px < RESX) {
                    continue
                }
                dist := [2]f32{f32(px - mouse_x), f32(py - mouse_y)}
                if linalg.vector_length(dist) > DRAW_RADIUS {
                    continue
                }

                if particles[py][px].type == .NONE {
                    set_particle(i32(py), i32(px), selected_type)
                }

            }

        }
    }

    ERASE_RADIUS :: 5
    if rl.IsMouseButtonDown(.RIGHT) {
        // erase a circle
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

                if particles[py][px].type == .SAND {
                    set_particle(i32(py), i32(px), .NONE)
                }

            }

        }
    }
}

main :: proc() {
    fmt.println("Hello, World")
    rl.InitWindow(WINDOW_WIDTH, WINDOW_HEIGHT, "Sand Worm")
    rl.SetTargetFPS(144)
    defer rl.CloseWindow()
    state.window_width = rl.GetScreenWidth()
    state.window_height = rl.GetScreenHeight()

    target := rl.LoadRenderTexture(RESX, RESY)
    simulation_tex := rl.LoadTextureFromImage(simulation_image)

    selected_type: ParticleType = .SAND
    for !rl.WindowShouldClose() {
        dt := rl.GetFrameTime()
        time := rl.GetTime()

        if rl.IsKeyPressed(.ONE) do selected_type = .SAND
        if rl.IsKeyPressed(.TWO) do selected_type = .WATER
        handle_particle_interaction(selected_type)

        // run the simulation at set update rate
        if time - state.last_tick >= SIM_TICK_TIME {
            update_particles()
            state.last_tick = time
        }

        // Draw to Render Target
        rl.BeginTextureMode(target)
        rl.ClearBackground(COLOR_BG)
        rl.UpdateTexture(simulation_tex, simulation_image.data)
        rl.DrawTexture(simulation_tex, 0, 0, rl.WHITE)
        rl.EndTextureMode()

        // scale to window
        rl.BeginDrawing()
        src := rl.Rectangle{0, 0, f32(target.texture.width), -f32(target.texture.height)}
        dst := rl.Rectangle{0, 0, f32(state.window_width), f32(state.window_height)}
        rl.DrawTexturePro(target.texture, src, dst, rl.Vector2(0), 0, rl.WHITE)

        rl.DrawFPS(10, 10)
        rl.EndDrawing()
    }
}
