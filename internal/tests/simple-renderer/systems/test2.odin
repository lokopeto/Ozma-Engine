package systems

import "core:fmt"
import "core:os"
import "core:math"
import "core:strings"
import kt "KT:."

TestData :: struct {
	test : bool
}
testSystem3 :: kt.System_Data(_SYSTEMS, _HANDLES, TestData) {
	shared = false,
	process = testSystem3_process,
	process_late = testSystem3_process_late,
	process_fixed = testSystem3_process_fixed,
}

testSystem3_process :: proc(f: ^kt.FrameData, data: ^_SYSTEMS, h: ^_HANDLES) {
}
testSystem3_process_late :: proc(f: ^kt.FrameData, data: ^_SYSTEMS, h: ^_HANDLES) {
}
testSystem3_process_fixed :: proc(f: ^kt.FrameData, data: ^_SYSTEMS, h: ^_HANDLES) {
}
