package systems
import kt "KT:."
import hm "core:container/handle_map"
SYS_PROC_IDENTITY :: proc(f: ^kt.FrameData, data: ^_SYSTEMS, h: ^_HANDLES) {}
_SYSTEMS :: struct {

movementSystem: _movementSystem,
testSystem3: _testSystem3,
}
_movementSystem :: hm.Dynamic_Handle_Map(kt.SystemBox(MovementData),hm.Handle64)
_testSystem3 :: hm.Dynamic_Handle_Map(kt.SystemBox(TestData),hm.Handle64)
_HANDLES :: struct {
movementSystem: kt.HMIndex(kt.SystemBox(MovementData),hm.Handle64),
testSystem3: kt.HMIndex(kt.SystemBox(TestData),hm.Handle64),
}
_SYS_ENUM :: enum {
movementSystem,
testSystem3,
}
entity_system_add_movementSystem :: proc(f: ^kt.FrameData, s: ^_SYSTEMS, e: ^kt.Entity) -> (sys: ^MovementData) {
	if e._internal.systems_index.movementSystem > 0 {
		sys := cast(^kt.SystemBox(MovementData))e._internal.systems_index.movementSystem
		hm.dynamic_remove(&s.movementSystem, sys.handle)
	}
 sys = new(MovementData)
	if movementSystem.data != nil { sys^ = movementSystem.data(f,s,e) }
	handle :=	hm.dynamic_add(&s.movementSystem, kt.SystemBox(MovementData){
		_data = sys^,
		_entity = e
	})
	sys = hm.dynamic_get(&s.movementSystem, handle)
	e._internal.systems_index.movementSystem = uintptr(sys)
	e.systems.movementSystem = true
	return
}

entity_system_add_testSystem3 :: proc(f: ^kt.FrameData, s: ^_SYSTEMS, e: ^kt.Entity) -> (sys: ^TestData) {
	if e._internal.systems_index.testSystem3 > 0 {
		sys := cast(^kt.SystemBox(TestData))e._internal.systems_index.testSystem3
		hm.dynamic_remove(&s.testSystem3, sys.handle)
	}
 sys = new(TestData)
	if testSystem3.data != nil { sys^ = testSystem3.data(f,s,e) }
	handle :=	hm.dynamic_add(&s.testSystem3, kt.SystemBox(TestData){
		_data = sys^,
		_entity = e
	})
	sys = hm.dynamic_get(&s.testSystem3, handle)
	e._internal.systems_index.testSystem3 = uintptr(sys)
	e.systems.testSystem3 = true
	return
}

entity_system_remove :: proc(s: ^_SYSTEMS, e: ^kt.Entity, d: _SYS_ENUM) {
	switch d {
		case .movementSystem:
			if e._internal.systems_index.movementSystem < 0 {return}
			sys := cast(^kt.SystemBox(MovementData))e._internal.systems_index.movementSystem
			if hm.dynamic_is_valid(&s.movementSystem, sys.handle) {
				hm.dynamic_remove(&s.movementSystem, sys.handle)
			}
		case .testSystem3:
			if e._internal.systems_index.testSystem3 < 0 {return}
			sys := cast(^kt.SystemBox(TestData))e._internal.systems_index.testSystem3
			if hm.dynamic_is_valid(&s.testSystem3, sys.handle) {
				hm.dynamic_remove(&s.testSystem3, sys.handle)
			}
	}
}
