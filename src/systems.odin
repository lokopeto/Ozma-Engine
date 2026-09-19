package koto

import hm "core:container/handle_map"

// $D == data of the system, assignment is used as a default
System :: struct($S, $I: typeid) {
	// enable running system on network entities
	shared: bool,

	init:          proc(f: ^FrameData, data: ^S, index: ^I),
	process:       proc(f: ^FrameData, data: ^S, index: ^I),
	process_fixed: proc(f: ^FrameData, data: ^S, index: ^I),
	process_late:  proc(f: ^FrameData, data: ^S, index: ^I),
	end:           proc(f: ^FrameData, data: ^S, index: ^I),
}

System_Data :: struct($S, $I, $D: typeid) {
	using s: System(S, I),
	data : proc(f: ^FrameData, systems: ^S, e: ^Entity) -> D,
	_data : D
}

SystemBox :: struct($T: typeid){
	handle: Handle,
	_entity: ^Entity,
	using _data : T
}

HMIndex :: struct($T, $Handle_Type: typeid) {
	val: ^T,
	h: Handle_Type,
	ok: bool
}

DrawCMD :: proc(frame: FrameData, f_index: u32)
DrawCMDS :: []DrawCMD

FrameData :: struct {
	render : RenderFrame,
	worlds : WorldFrame
}

load_world: proc(vulkan: ^Vulkan, frame: ^FrameData, world: string)

entity_spawn :: proc() {}
entity_despawn :: proc() {}

entity_delete :: proc(t: ^Terrain, e: ^Entity) {
	delete(e.models[:])
	hm.remove(&t.entities, e.handle)
}

entity_create :: proc(t: ^Terrain) -> ^Entity {
	handle := hm.add(&t.entities, Entity{})
	return hm.get(&t.entities, handle)
}

entity_obj_add :: proc(e: ^Entity, o: Obj) {
	append(&e.models, o)
}

entity_obj_remove :: proc(e: ^Entity, name: string) -> bool {
	for o, o_i in e.models {
		if o.name == name {
			ordered_remove(&e.models, o_i)
			return true
		}
	}
	return false
}

entity_obj_remove_indexed :: proc(e: ^Entity, i: int) -> bool {
	i := i >= 0 ? i : len(e.models) - -i
	if i <= len(e.models) {
		ordered_remove(&e.models, i)
		return true
	}
	return false
}
