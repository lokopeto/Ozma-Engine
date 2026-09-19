package systems

import "core:fmt"
import "core:os"
import "core:math"
import "core:strings"
import kt "KT:."

Systems :: struct {
	movementSystem : kt.System_Data(_SYSTEMS, _HANDLES, MovementData),
	testSystem3 : kt.System_Data(_SYSTEMS, _HANDLES, TestData)
}
systems :: Systems {
	movementSystem = movementSystem
}
