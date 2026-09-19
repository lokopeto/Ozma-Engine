package koto
import vmath "core:math/linalg"
import "core:math"
import "core:fmt"

// transform :: proc "contextless"(
transform :: proc (
	pos := [3]f32{0,0,0},
	rot_quat := vmath.QUATERNIONF32_IDENTITY,
	scale := [3]f32{1,1,1},
) -> (m : vmath.Matrix4f32) #no_bounds_check {

	//Matrix = [Coluna][Linha]
	m[3][0] = pos.x
	m[3][1] = pos.y
	m[3][2] = pos.z
	// POSITION MATRIX
	// [0, 0, 0, p.x]
	// [0, 0, 0, p.y]
	// [0, 0, 0, p.z]
	// [0, 0, 0, 1  ]
 	
	m[0][0] = scale.x
	m[1][1] = scale.y
	m[2][2] = scale.z
	m[3][3] = 1
	// SCALE MATRIX
	// [s.x,   0,   0, p.x]
	// [  0, s.y,   0, p.y]
	// [  0,   0, s.z, p.z]
	// [  0,   0,   0, 1  ]

	m = m * vmath.matrix4_from_quaternion(rot_quat)
	return
}
// view ::  proc "contextless" (
view ::  proc(
	pos := [3]f32{0,0,0},
	rot_quat := vmath.QUATERNIONF32_IDENTITY,
	scale := [3]f32{1,1,1},
) -> (m : vmath.Matrix4f32) #no_bounds_check {
	//Matrix = [Column][Line]
	//       = [Line, Column]
	m[3][0] = pos.x
	m[3][1] = -pos.y
	m[3][2] = pos.z
	// POSITION MATRIX
	// [0, 0, 0, p.x]
	// [0, 0, 0, p.y]
	// [0, 0, 0, p.z]
	// [0, 0, 0, 1  ]
 			
	m[0][0] = -scale.x
	m[1][1] = scale.y
	m[2][2] = -scale.z
	m[3][3] = -1
	// SCALE MATRIX
	// [s.x,   0,   0, p.x]
	// [  0, s.y,   0, p.y]
	// [  0,   0, s.z, p.z]
	// [  0,   0,   0, 1  ]

	m = vmath.matrix4_from_quaternion(rot_quat) * m	
	return
}

proj :: proc(fov, aspect, near, far: f32, is_orthographic := false) -> (m: vmath.Matrix4f32) #no_bounds_check {
	if is_orthographic == true {
		m = orthographic(fov, aspect, near, far)
	} else {
		m = perspective(fov, aspect, near, far)
	}
	return
}


perspective :: proc(fov_raw, aspect, near, far: f32) -> 
	(m : vmath.Matrix4f32) #no_bounds_check {
	// make more accurate
	fov := math.tan(0.002 * fov_raw)
	// adjust the aspect ratio
	m[0][0] = 1 / (aspect * fov) // without the aspect the mesh is streched
	m[1][1] = -1 / (fov) // -1 to flip it

	m[2][2] = 1 / (near - far)
	m[3][2] = -near / (near - far)
	m[2][3] = -1
	return
}
orthographic :: proc(fov, aspect, near, far: f32) -> 
	(m : vmath.Matrix4f32) #no_bounds_check {
	vertical := math.tan(0.002 * fov)
	horizontal := vertical / aspect
	// m = vmath.matrix4_inverse_f32(m)

	m[0][0] = horizontal
	m[1][1] = -vertical
	m[2][2] = 1 / (near - far)
	m[3][2] = -near / (near - far)

	m[3][3] = -1
	return
}
