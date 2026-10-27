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
entity_system_add_movementSystem :: proc(f: ^oz.FrameData, s: ^_SYSTEMS, e: ^oz.Entity) -> (sys: ^oz.SystemBox(MovementData)) {
	handle := e._internal.systems_index.movementSystem
	if phos.is_valid(&s.movementSystem, handle) {
		phos.remove(&s.movementSystem, handle)
	}
	handle, sys = phos.add(&s.movementSystem)
	sys._entity = e
	if systems.movementSystem.data_init != nil do sys._data = systems.movementSystem.data_init(f,s,e)
	e._internal.systems_index.movementSystem = handle
	e.systems.movementSystem = true
	return
}
get_data_movementSystem :: proc(f: ^oz.WorldFrame, e: ^oz.Entity) -> (^oz.SystemBox(MovementData),bool) {
	return phos.get_data(&(cast(^_SYSTEMS)(f.systems)).movementSystem,e._internal.systems_index.movementSystem)
}
entity_system_add_testSystem3 :: proc(f: ^oz.FrameData, s: ^_SYSTEMS, e: ^oz.Entity) -> (sys: ^oz.SystemBox(TestData)) {
	handle := e._internal.systems_index.testSystem3
	if phos.is_valid(&s.testSystem3, handle) {
		phos.remove(&s.testSystem3, handle)
	}
	handle, sys = phos.add(&s.testSystem3)
	sys._entity = e
	if systems.testSystem3.data_init != nil do sys._data = systems.testSystem3.data_init(f,s,e)
	e._internal.systems_index.testSystem3 = handle
	e.systems.testSystem3 = true
	return
}
get_data_testSystem3 :: proc(f: ^oz.WorldFrame, e: ^oz.Entity) -> (^oz.SystemBox(TestData),bool) {
	return phos.get_data(&(cast(^_SYSTEMS)(f.systems)).testSystem3,e._internal.systems_index.testSystem3)
}
entity_system_remove :: proc(f: ^oz.FrameData, s: ^_SYSTEMS, e: ^oz.Entity, d: _SYS_ENUM) {
	switch d {
		case .movementSystem:
			if !phos.is_valid(&s.movementSystem,e._internal.systems_index.movementSystem) {return}
			sys,_ := phos.get_data(&s.movementSystem,e._internal.systems_index.movementSystem)
			if systems.movementSystem.data_end != nil do systems.movementSystem.data_end(f,s,e,sys)
			if phos.remove(&s.movementSystem, e._internal.systems_index.movementSystem) {
				e._internal.systems_index.movementSystem = {phos.NULL_IDX, phos.NULL_IDX}
			}
		case .testSystem3:
			if !phos.is_valid(&s.testSystem3,e._internal.systems_index.testSystem3) {return}
			sys,_ := phos.get_data(&s.testSystem3,e._internal.systems_index.testSystem3)
			if systems.testSystem3.data_end != nil do systems.testSystem3.data_end(f,s,e,sys)
			if phos.remove(&s.testSystem3, e._internal.systems_index.testSystem3) {
				e._internal.systems_index.testSystem3 = {phos.NULL_IDX, phos.NULL_IDX}
			}
	}
}
