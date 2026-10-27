#+feature dynamic-literals
package _global

import "core:fmt"
import "core:os"
import "core:math"
import vmath "core:math/linalg"
import hm "core:container/handle_map"
import "core:strings"
import oz "ozma:."
import sys "game:systems"

player : ^oz.Entity
init :: proc(frame: ^oz.FrameData, vulkan: ^oz.Vulkan){
	oz.cursor_visibility(frame.render.window[0],.LOCKED)

	player = oz.entity_create(&frame.worlds.terrains[0])
	oz.entity_obj_add(player, 
		{
			model = .MODELS_ALYRA_alyra,
			transform = {
				position = {0,10,0},
				rotation = vmath.QUATERNIONF32_IDENTITY,
				scale = {1,1,1}
			},
		}
	)
	player2 := oz.entity_create(&frame.worlds.terrains[0])
	oz.entity_obj_add(player2, 
		{
			model = .MODELS_ALYRA_alyra,
			transform = {
				position = {0,10,2},
				rotation = vmath.QUATERNIONF32_IDENTITY,
				scale = {1,1,1}
			},
		}
	)

	sys.entity_system_add(cast(^sys._SYSTEMS)frame.worlds.systems, player, sys.MovementData{
	})
}
update :: proc(frame: ^oz.FrameData, vulkan: ^oz.Vulkan){
	// fmt.println(hm.get(&frame.worlds.terrains[0].entities, oz.Handle{1,1}))

	// it := hm.iterator_make(&frame.worlds.terrains[0].entities)
	// for e,h in hm.iterate(&it) {
	// 	fmt.println(e.models)
	// }

	// os.exit(0)
	// fmt.println(
	// 	// frame.render.camera,
	// 	frame.render.dt
	// )
	fmt.println(player.models[0].transform)
	if oz.mouse.buttons[.BUTTON_LEFT] == .PRESSED {
		// fmt.println(oz.mouse.buttons[.BUTTON_LEFT])
		en := oz.entity_create(&frame.worlds.terrains[0])
		oz.entity_obj_add(en, {
			model = .MODELS_522195_stadiumc,
			transform = player.models[0].transform
		})
	}
	if oz.mouse.buttons[.BUTTON_RIGHT] == .PRESSED {
		// fmt.println(oz.mouse.buttons[.BUTTON_LEFT])
		en := oz.entity_create(&frame.worlds.terrains[0])
		oz.entity_obj_add(en, {
			model = .MODELS_ALYRA_alyra,
			transform = player.models[0].transform
		})
	}
}
update_fixed :: proc(frame: ^oz.FrameData, vulkan: ^oz.Vulkan) {
	// fmt.println(player.models[0].transform.position)
	
 	/*
	horizontal := -oz.inputs["right"].value + oz.inputs["left"].value
	vertical :=  -oz.inputs["up"].value + oz.inputs["down"].value
	

	frame.render.camera.rotation = vmath.quaternion_slerp_f32(
		frame.render.camera.rotation,
		rotX * rotY,
		f32(frame.render.dt.fixed)
	)


	fly_vec = vmath.lerp(fly_vec, (pos_vecZ + pos_vecX), 0.1 * f32(frame.render.dt.fixed))
	frame.render.camera.position += fly_vec

	up = vmath.lerp(
		up, 
		oz.inputs["upward"].value + -oz.inputs["downard"].value, 
		0.05 * f32(frame.render.dt.fixed)
	)
	frame.render.camera.position.y += up * f32(frame.render.dt.fixed) * pos_scalar

	zoom_scroll  := f32(-oz.mouse.scroll.y)
	speed_scroll := f32( oz.mouse.scroll.y)
	if oz.inputs["speed"].value > 0 {
		zoom_scroll = 0
	} else {
		speed_scroll = 0
	}

	zoom = math.lerp(zoom, zoom_scroll, 0.03 * f32(frame.render.dt.fixed))
	frame.render.camera.fov += 0.1 * zoom

	pos_scalar = max(
		math.lerp(
			pos_scalar,
			pos_scalar + ((speed_scroll * 0.1) * f32(frame.render.dt.fixed)),
			f32(frame.render.dt.fixed)
		), 0
	)
  */
}
update_late :: proc(frame: ^oz.FrameData, vulkan: ^oz.Vulkan){

}
end :: proc(frame: ^oz.FrameData, vulkan: ^oz.Vulkan){

}
