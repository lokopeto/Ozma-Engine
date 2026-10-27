package oz

import hm "core:container/handle_map"
import vk "vendor:vulkan"
import "core:fmt"
import "core:os"

UniAssets :: []Asset
WorldIndex :: [WorldsNames][]int

LoadedWorld :: struct {
	using _world: World,
	models: ModelBox,
}
