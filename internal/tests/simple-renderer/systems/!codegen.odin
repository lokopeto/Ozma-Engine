package systems
import oz "ozma:."
import phos "shared:Phos"
SYS_PROC_IDENTITY :: proc(f: ^oz.FrameData, data: ^_SYSTEMS, h: ^_HANDLES) {}
_SYSTEMS :: struct {

movementSystem: _movementSystem,
testSystem3: _testSystem3,
}
_movementSystem :: phos.HandleBox(oz.SystemBox(MovementData))
_testSystem3 :: phos.HandleBox(oz.SystemBox(TestData))
_HANDLES :: struct {
movementSystem: oz.HMIndex(oz.SystemBox(MovementData)),
testSystem3: oz.HMIndex(oz.SystemBox(TestData)),
}
_SYS_ENUM :: enum {
movementSystem,
testSystem3,
}
entity_system_add_movementSystem :: proc(f: ^oz.FrameData, s: rawptr, e: ^oz.Entity) -> (sys: ^oz.SystemBox(MovementData)) {
	_h := e._internal.systems_index.movementSystem
	h := _h._h
	t := _h.thread
	s_list := cast(^[]_SYSTEMS)s
	if phos.is_valid(&s_list[t].movementSystem, h) {
		phos.remove(&s_list[t].movementSystem, h)
	}
	lowest_num 		: int = max(int)
	lowest_thread : int
	for s,s_i in s_list {
		s := s
		s_len := phos.len(&s.movementSystem)
		if s_len < lowest_num { 
			lowest_num = s_len
			lowest_thread = s_i
		}
	}
	s := &s_list[lowest_thread]
	h, sys = phos.add(&s.movementSystem)
	sys._entity = e
	if systems.movementSystem.data_init != nil do sys._data = systems.movementSystem.data_init(f,s,e)
	e._internal.systems_index.movementSystem = {h, lowest_thread}
	e.systems.movementSystem = true
	return
}
get_data_movementSystem :: proc(f: ^oz.WorldFrame, e: ^oz.Entity) -> (^oz.SystemBox(MovementData),bool) {
	return phos.get_data(&((cast(^[]_SYSTEMS)(f.systems))[e._internal.systems_index.movementSystem.thread]).movementSystem,e._internal.systems_index.movementSystem)
}
entity_system_add_testSystem3 :: proc(f: ^oz.FrameData, s: rawptr, e: ^oz.Entity) -> (sys: ^oz.SystemBox(TestData)) {
	_h := e._internal.systems_index.testSystem3
	h := _h._h
	t := _h.thread
	s_list := cast(^[]_SYSTEMS)s
	if phos.is_valid(&s_list[t].testSystem3, h) {
		phos.remove(&s_list[t].testSystem3, h)
	}
	lowest_num 		: int = max(int)
	lowest_thread : int
	for s,s_i in s_list {
		s := s
		s_len := phos.len(&s.testSystem3)
		if s_len < lowest_num { 
			lowest_num = s_len
			lowest_thread = s_i
		}
	}
	s := &s_list[lowest_thread]
	h, sys = phos.add(&s.testSystem3)
	sys._entity = e
	if systems.testSystem3.data_init != nil do sys._data = systems.testSystem3.data_init(f,s,e)
	e._internal.systems_index.testSystem3 = {h, lowest_thread}
	e.systems.testSystem3 = true
	return
}
get_data_testSystem3 :: proc(f: ^oz.WorldFrame, e: ^oz.Entity) -> (^oz.SystemBox(TestData),bool) {
	return phos.get_data(&((cast(^[]_SYSTEMS)(f.systems))[e._internal.systems_index.testSystem3.thread]).testSystem3,e._internal.systems_index.testSystem3)
}
entity_system_remove :: proc(f: ^oz.FrameData, s: ^_SYSTEMS, e: ^oz.Entity, d: _SYS_ENUM) {
	switch d {
		case .movementSystem:
			if !phos.is_valid(&s.movementSystem,e._internal.systems_index.movementSystem) {return}
			sys,_ := phos.get_data(&s.movementSystem,e._internal.systems_index.movementSystem)
			if systems.movementSystem.data_end != nil do systems.movementSystem.data_end(f,s,e,sys)
			if phos.remove(&s.movementSystem, e._internal.systems_index.movementSystem) {
				e._internal.systems_index.movementSystem = oz.NULL_SYSINDEX
			}
		case .testSystem3:
			if !phos.is_valid(&s.testSystem3,e._internal.systems_index.testSystem3) {return}
			sys,_ := phos.get_data(&s.testSystem3,e._internal.systems_index.testSystem3)
			if systems.testSystem3.data_end != nil do systems.testSystem3.data_end(f,s,e,sys)
			if phos.remove(&s.testSystem3, e._internal.systems_index.testSystem3) {
				e._internal.systems_index.testSystem3 = oz.NULL_SYSINDEX
			}
	}
}
