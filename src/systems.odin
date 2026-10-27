package oz

import hm "core:container/handle_map"
import phos "shared:Phos"

// $D == data of the system, assignment is used as a default
System :: struct($S, $I: typeid) {
	// enable running system on network entities
	shared: bool,

	init:            proc(f: ^FrameData, data: ^S, index: ^I),
	process:         proc(f: ^FrameData, data: ^S, index: ^I),
	process_fixed:   proc(f: ^FrameData, data: ^S, index: ^I),
	process_late:    proc(f: ^FrameData, data: ^S, index: ^I),
	end:             proc(f: ^FrameData, data: ^S, index: ^I),

	init_world:      proc(f: ^FrameData, data: ^S, index: ^I),
	end_world:       proc(f: ^FrameData, data: ^S, index: ^I),
	oneshot: struct {
		init:          proc(f: ^FrameData),
		process:       proc(f: ^FrameData),
		process_fixed: proc(f: ^FrameData),
		process_late:  proc(f: ^FrameData),
		end:           proc(f: ^FrameData),
	
		init_world:    proc(f: ^FrameData),
		end_world:     proc(f: ^FrameData),
	},
	oneshotThread: struct {
		init:          proc(f: ^FrameData, data: ^S),
		process:       proc(f: ^FrameData, data: ^S),
		process_fixed: proc(f: ^FrameData, data: ^S),
		process_late:  proc(f: ^FrameData, data: ^S),
		end:           proc(f: ^FrameData, data: ^S),
	
		init_world:    proc(f: ^FrameData, data: ^S),
		end_world:     proc(f: ^FrameData, data: ^S),
	}

}

System_Data :: struct($S, $I, $D: typeid) {
	using s: System(S, I),
	data_init : proc(f: ^FrameData, systems: ^S, e: ^Entity) -> D,
	data_end  : proc(f: ^FrameData, systems: ^S, e: ^Entity, d: ^D),
	_data : D
}

SystemBox :: struct($T: typeid){
	_entity: ^Entity,
	using _data : T
}

HMIndex :: struct($T: typeid) {
	val: ^T,
	h: phos.Handle,
	ok: bool
}

DrawCMD :: proc(frame: FrameData, f_index: u32)
DrawCMDS :: []DrawCMD

FrameData :: struct {
	render : RenderFrame,
	worlds : WorldFrame,
	graphic : GraphicContext,
}

// load_world: proc(vulkan: ^Vulkan, frame: ^FrameData, world: string)

entity_spawn :: proc() {}
entity_despawn :: proc() {}

entity_delete :: proc(t: ^phos.HandleBox(Entity), e: phos.Handle) {
	phos.remove(t, e)
}

EntityPtr :: struct{
	handle: phos.Handle,
	using entity: ^Entity
}

entity_create :: proc(t: ^phos.HandleBox(Entity)) -> (e: EntityPtr) {
	h,d := phos.add(t)
	e = { h,d }
	e.entity._internal.systems_index = systemsInit()
	return
}

entity_obj_add :: proc(m: ^phos.HandleBox(Obj),e: ^Entity, o: Obj) {
	h,d := phos.add(m)
	d^ = o
	append(&e.models, h)
}

entity_obj_remove :: proc{
	entity_obj_remove_name,
	entity_obj_remove_index
}

entity_obj_remove_name :: proc(m: ^phos.HandleBox(Obj), e: ^Entity, name: string) -> bool {
	for o, o_i in e.models {
		d, _ := phos.get_data(m, o)
		if d.name == name {
			ordered_remove(&e.models, o_i)
			return true
		}
	}
	return false
}
entity_obj_remove_index :: proc(m: ^phos.HandleBox(Obj), e: ^Entity, index: uint) -> bool {
	if phos.is_valid(m, e.models[min(index, uint(len(e.models)-1))]) {
		ordered_remove(&e.models, index)
		return true
	}
	return false
}
