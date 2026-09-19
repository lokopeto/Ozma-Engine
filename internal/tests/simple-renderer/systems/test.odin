package systems

import "core:fmt"
import "core:os"
import "core:math"
import "core:strings"
import vmath "core:math/linalg"
import kt "KT:."

MovementData :: struct {
	fly_vec: [3]f32,
	zoom: f32,
	up : f32,
	pos_scalar : f32,
	rot_scalar : f32,
}
movementSystem :: kt.System_Data(_SYSTEMS, _HANDLES, MovementData) {
	shared = false,
	process = movementSystem_process,
	process_late = movementSystem_process_late,
	process_fixed = movementSystem_process_fixed,

	data = {
	 pos_scalar = 0.001,
	 rot_scalar = 0.0007,
	}
}

movementSystem_process :: proc(f: ^kt.FrameData, data: ^_SYSTEMS, h: ^_HANDLES) {

}

movementSystem_process_fixed :: proc(f: ^kt.FrameData, data: ^_SYSTEMS, h: ^_HANDLES) {
	// fmt.println(h)
	if !h.movementSystem.ok { return }
	player := h.movementSystem.val._entity

	dt_fixed := f32(f.render.dt.fixed)

	pos := 0.01 * [?]f32{
		(-kt.inputs["right"].value + kt.inputs["left"].value) * f32(f.render.dt.fixed),
		(-kt.inputs["downward"].value + kt.inputs["upward"].value) * f32(f.render.dt.fixed),
		(-kt.inputs["down"].value + kt.inputs["up"].value) * f32(f.render.dt.fixed)
	}

	old_player_pos := player.models[0].transform.position
	player.models[0].transform.position += pos

	h.movementSystem.val.fly_vec = vmath.lerp(h.movementSystem.val.fly_vec, player.models[0].transform.position, 0.01 * dt_fixed)
	f.render.camera.position = h.movementSystem.val.fly_vec + {0,10,-3}
	f.render.camera.rotation = vmath.quaternion_from_euler_angle_x_f32(1)
	
	rotY := vmath.quaternion_angle_axis_f32(f32(kt.mouse.x) * 0.001, {0,1,0})
	player.models[0].transform.rotation = rotY
}
movementSystem_process_late :: proc(f: ^kt.FrameData, data: ^_SYSTEMS, h: ^_HANDLES) {

}
