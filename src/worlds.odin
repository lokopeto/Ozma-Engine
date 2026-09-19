package koto

import hm "core:container/handle_map"
import vk "vendor:vulkan"
import "core:fmt"
import "core:os"

Universe :: struct {
	worldsIndex: WorldIndex,
	assets: []Asset,
	current_world: LoadedWorld
}
WorldIndex :: map[string][]int

LoadedWorld :: struct {
	using _world: World,
	models: ModelBox,
}
