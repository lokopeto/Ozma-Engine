package systems

import "core:fmt"
import "core:os"
import "core:math"
import "core:strings"
import oz "ozma:."

Systems :: struct {
	movementSystem : oz.System_Data(_SYSTEMS, _HANDLES, MovementData),
	testSystem3 : oz.System_Data(_SYSTEMS, _HANDLES, TestData)
}
systems :: Systems {
	movementSystem = movementSystem
}
