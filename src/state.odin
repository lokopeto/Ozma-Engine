package koto
import vmath "core:math/linalg"
import hm "core:container/handle_map"
import "core:encoding/uuid"
import "core:time"

import "base:runtime"

import vk "vendor:vulkan"

KeyMapInput :: #sparse[Keys]string
Camera :: struct{
	rotation : vmath.Quaternionf32,
	position : [3]f32,
  scale : [3]f32,
	fov: f32,
	near: f32,
	far: f32,
	orthographic: bool,
}

RenderState :: struct {
	input: struct{
		keyMap: KeyMapInput
	},
	camera: Camera,
	window_info: WindowInfo,
	texture : struct {
		sampler : Sampler
	},
}

ShaderState :: struct {
	shaders : []Create_Shader_info,
	config : Create_Shader_config
}



uni: Universe

WorldFrame :: struct {
	using _ : LoadedWorld,
	using _state : WorldState,
}

WorldState :: struct {
	initial_world : string
}

Asset :: struct{
 path: string,
 worlds: []string,
 type: enum {
 	Model,
  Texture,
  Sound
 },
 flags: bit_set[enum{}],
}

Handle :: hm.Handle64

Entity :: struct {
	handle: Handle,
	systems: SystemsToggler,
	
	_internal: struct {
		systems_index: SystemsIndex,
		id_local: uuid.Identifier,
		id_public: uuid.Identifier,
	},
	models: [dynamic]Obj,
}

Terrain :: struct {
	update_freq: u32,
	entities: hm.Dynamic_Handle_Map(Entity, Handle),
}

WorldsSound :: struct {

}
WorldsModel :: struct {

}
WorldsTexture :: struct {

}


World :: struct{
	terrains: []Terrain,
	systems : uintptr,
	assets: struct{
		sounds: map[string]WorldsSound,
		models: map[string]WorldsModel,
		textures: map[string]WorldsTexture,
	}
}

// model selector interface(?)
Obj :: struct{
	name: string,
	transform: struct{
		position: [3]f32,
		rotation: vmath.Quaternionf32,
		scale: [3]f32,
	},
	// shaders: struct{
	// 	vertex:
	// 	fragment:
	// }
	model: AssetsModels,
	texture: []struct{
		from: enum{MODELS, USER},
		texture: [3]u32
	},
}
