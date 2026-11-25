package oz

import hm "core:container/handle_map"
import vk "vendor:vulkan"
import "core:fmt"
import "core:os"

///////////////////////////
// STATE
///////////////////////////
WorldState :: struct {
	initial_world : WorldsNames
}
///////////////////////////

///////////////////////////
// FRAME
///////////////////////////
WorldProc :: proc(frame: ^FrameData, frameLocal: ^FrameDataLocal)
WorldFrame :: struct {
	using _ : LoadedWorld,
	using _state : WorldState,
	thread_count : int
}

LoadedWorld :: struct {
	using _world: World,
	models: ModelBox,
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
WorldsSound :: struct {

}
WorldsModel :: struct {

}
WorldsTexture :: struct {

}
///////////////////////////




///////////////////////////
// CODEGEN
///////////////////////////
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

UniAssets :: []Asset
WorldIndex :: [WorldsNames][]int
///////////////////////////
