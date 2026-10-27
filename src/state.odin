package oz
import vmath "core:math/linalg"
import hm "core:container/handle_map"
import "core:encoding/uuid"
import "core:time"

import "base:runtime"

import vk "vendor:vulkan"

import phos "shared:Phos"

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
	input_default: struct{
		keyMap: KeyMapInput
	},
	camera: Camera,
	window_info: struct{
		using info: WindowInfo,
		resolution: [2]u32,
		name: string,
	},
	texture : struct {
		sampler : Sampler
	},
}

ShaderState :: struct {
	shaders : []Create_Shader_info,
	config : Create_Shader_config
}

WorldFrame :: struct {
	using _ : LoadedWorld,
	using _state : WorldState,
}
WorldState :: struct {
	initial_world : WorldsNames
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

Entity :: struct {
	systems: SystemsToggler,
	
	_internal: struct {
		systems_index: SystemsIndex,
		id_local: uuid.Identifier,
		id_public: uuid.Identifier,
	},
	models: [dynamic; 32]phos.Handle,
}

EntityBox :: phos.HandleBox(Entity)
WorldsSound :: struct {

}
WorldsModel :: struct {

}
WorldsTexture :: struct {

}


World :: struct{
	entities : EntityBox,
	systems : rawptr,
	assets: struct{
		sounds: map[string]WorldsSound,
		models: map[string]WorldsModel,
		textures: map[string]WorldsTexture,
	}
}

// model selector interface(?)
Obj :: struct{
	name: string,
	model: AssetsModels,
	transform: struct{
		position: [3]f32,
		rotation: vmath.Quaternionf32,
		scale: [3]f32,
	},
	// shaders: struct{
	// 	vertex:
	// 	fragment:
	// }
	// texture: []struct{
	// 	from: enum{MODELS, USER},
	// 	texture: [3]u32
	// },
}
