#+feature dynamic-literals
package main

import "base:builtin"
import "shared:tracy"
import "vendor:glfw"
import "core:sync"
import "core:strings"
import "base:runtime"
import "core:reflect"
import "core:os"

import th "core:thread"
import "core:mem"
import "core:fmt"
import "core:time"

import "core:math"
import vmath "core:math/linalg"

import render "game:render"
import gworld "game:worlds"
import shader "game:shaders"
import systems "game:systems"

import phos "shared:Phos"

import cg "codegen:."

import oz "ozma:."

// 
// RenderInfo :: struct {
// 	model:    oz.AssetsModels,
// 	position: [3]f32,
// 	rotation: vmath.Quaternionf32,
// 	scale:    [3]f32,
// }
// ModelCMD   :: struct {
// 	vertexCount:   u32,
// 	instanceCount: u32,
// 	firstVertex:   u32,
// 	firstInstance: u32,
// }
TRACY_CALLSTACK :: #config(TRACY_CALLSTACK, 0)

TC_UPDATE :: 0x0044FF
TC_UPDATE_FIXED :: 0x0099FF

// cmd_buffer  : [3]RenderCMDBuffer
model_buffer  : phos.HandleBox(oz.Obj)

//\\ SYSTEMS SYNC //\\
is_loading := true
loading_mutex : sync.Mutex
world_loaded  : oz.WorldsNames
systems_sync  : []bool
systems_count : []u64
systems_time  : []f64
barrier_system  : sync.Barrier
groupWait_system : sync.Wait_Group
semaphore_system : sync.Sema
sysThread_count : int

//\\ RENDER //\\
RENDERCMD_MAX_BUFFER :: 1*mem.Megabyte
cmd_frames : []oz.Command
fixed_dt      : f64 : 1000.0 / (oz.RENDER_FIXED_UPDATE_FREQUENCY)
fixed_dt_over : f64 : 1000.0 / (oz.RENDER_FIXED_UPDATE_FREQUENCY+2)
fixed_dt_2x   : f64 : 1000.0 / (oz.RENDER_FIXED_UPDATE_FREQUENCY*2)
fixed_dt_4x   : f64 : 1000.0 / (oz.RENDER_FIXED_UPDATE_FREQUENCY*4)
fixed_dt_8x   : f64 : 1000.0 / (oz.RENDER_FIXED_UPDATE_FREQUENCY*8)
//////////////////

main :: proc() {
	///////////////////////////
	// INIT
	///////////////////////////
	// Frame should be easy to reassemble
	frame : oz.FrameData
	frame.render._state = render.state
	frame.worlds._state = gworld.state

	oz.keyMap = render.state.input_default.keyMap
	sync.mutex_lock(&loading_mutex)
	AppInfo("Ozma Engine Application")
	///////////////////////////

	///////////////////////////
	// ARENAS
	///////////////////////////
	render_arena := create_arena(100*mem.Kilobyte)
	shader_arena := create_arena(100*mem.Kilobyte)
	cmd_arena    := create_arena(100*mem.Kilobyte)
	///////////////////////////

	///////////////////////////
	// RENDERER
	///////////////////////////
	// One Window per frame!
	win_name := render.state.window_info.name == "" ? "Ozma Engine" : render.state.window_info.name
	frame.render.window.handle = oz.create_window(
		render.state.window_info.resolution.x,
		render.state.window_info.resolution.y,
		render.state.window_info.info,
		win_name
	); render.state.window_info.name = win_name
	// force update on the render for evading NaN
	frame.render.window.resolution = render.state.window_info.resolution

	frame.graphic = oz.create_renderer(frame.render.window.handle, render_arena)
	cmd_frames = oz.vkRenderCommand_Create(&frame.graphic.vulkan, cmd_arena)

	{
		shader_err : oz.VkCreateShaderError
		info := shader.state.shaders
		frame.render.shaderBox, shader_err = oz.vkCreate_shaders(
			frame.graphic.device,
			&info,
			shader.state.config,
			shader_arena
		)
		fmt.println(shader_err)
	}
	///////////////////////////

	///////////////////////////
	// HANDLE MAPS
	///////////////////////////
	phos.create(&model_buffer, RENDERCMD_MAX_BUFFER)
	frame.render.models = model_buffer
	_entity  : oz.EntityBox
	///////////////////////////


	///////////////////////////
	// FRAMETIME
	///////////////////////////
  frame_i   :  int
  time_now  := time.tick_now()
  time_past := time_now
  frametime :  f64
	///////////////////////////

	///////////////////////////
	// THREADS
	///////////////////////////
	render_th  := th.create(render_proc, .High, "Render")
	render_th.user_args[0] = &frame
	th.start(render_th); defer th.destroy(render_th)
	network_th := th.create(network_proc, .Low, "Network")
	network_th.user_args[0] = &frame
	th.start(network_th); defer th.destroy(network_th)

	// Sys threads per Physical minus render + network
	// dynamic scalabe?
	sysThread_count = max(os.get_processor_core_count() - 3, 1)
	systems_ths := make([]^th.Thread, sysThread_count)
	// sync //
	systems_sync = make([]bool, sysThread_count)
	systems_loop_count := make([]i64, sysThread_count)
	systems_count = make([]u64, sysThread_count)
	systems_time = make([]f64, sysThread_count)
	//////////
	_systems := make([]systems._SYSTEMS, sysThread_count)
	sysSplit := int(math.ceil(f32(oz.WORLDS_ENTITIES_LIMIT) / f32(sysThread_count)))
	sync.barrier_init(&barrier_system, sysThread_count)

	{
		for &t,t_i in systems_ths {
			name := strings.join({"System ",fmt.tprint(t_i)}, "", context.allocator)
			t = th.create(systems_proc, .High, name)
			t.user_args[0] = &frame
			t.data = &T_SystemsData{
				system = &_systems[t_i],
				sync   = &systems_sync[t_i],
				loops  = &systems_loop_count[t_i]
			}
			t.user_index = t_i
			th.start(t)
		};
	}
	defer for &t,t_i in systems_ths { th.destroy(t) }
	///////////////////////////

	{
		cg.sysInitProcess_one(&frame)
		for &s,s_i in _systems {
			cg.sysInitProcess_oneThread(&frame,&s)
			sysLen := cg.sysGet_len(&s)
			for i in 0..<sysLen {
				handle := cg.sysIterate(&s, i)
				cg.sysInitProcess(&frame,&s,&handle)
			}
		}
	}
	sync.mutex_unlock(&loading_mutex)

	mouse_reset: oz._mouse_handler_reset
	//////////////////////////////////////////////////
	// UPDATE LOOP                                  //
	//////////////////////////////////////////////////
	for !oz.windowShouldClose(&frame) {
		free_all(context.temp_allocator)

		// WORLD SWITCHER //
		if world_loaded != frame.worlds._state.initial_world || is_loading {
			// LOAD WORLD AND UNLOADS PAST
			// TODO: Do a proper semaphore or load as a stream and survive the memory overhead hell..
			is_loading = true
			sync.mutex_lock(&loading_mutex); defer sync.mutex_unlock(&loading_mutex)
			for {
				time.sleep(time.Millisecond)
				count : int
				for v in systems_sync { if v { count += 1 } }
				if count >= sysThread_count { break }
				fmt.println(sysThread_count, count)
				fmt.println(systems_sync)
				fmt.println(systems_loop_count)
			}
			ZoneN("World Loading")

			{
				cg.sysEndProcess_world_one(&frame)
				for &s,s_i in _systems {
					cg.sysEndProcess_oneThread(&frame, &s)
					sysLen := cg.sysGet_len(&s)
					for i in 0..<sysLen {
						handle := cg.sysIterate(&s, i)
						cg.sysEndProcess_world(&frame,&s,&handle)
					}
				}
			}

			cg.procedures_global[4](&frame)
			cg.procedures[world_loaded][4](&frame)

			//////////
			// TODO: Handle the mesh upload better
			// TODO: do textures & sounds 
			models_path: [dynamic]string
			// textures:
			// sounds:
			for wi, wi_i in cg.worldsIndex[world_loaded] {
		    append(&models_path, cg.assets[wi].path)
			}
			
			// fmt.print(state.current_world.models)
			frame.worlds.models = oz.vkUpload_meshList(
				&frame.graphic.vulkan, models_path[:], 
				{
					u64(frame.graphic.info.descriptorBuffer.combinedImageSamplerDescriptorSize),
					frame.graphic.info.descriptorBuffer.descriptorBufferOffsetAlignment,
					bool(frame.graphic.info.descriptorBuffer.combinedImageSamplerDescriptorSingleArray),
					frame.render.descriptor_layout,
					frame.render.texture.sampler,
				}, context.allocator
			)

			phos.delete(&_entity)
			phos.create(&_entity, oz.WORLDS_ENTITIES_LIMIT)
			frame.worlds.entities = _entity
			
			split_sum : int
			for &s,s_i in _systems {
				cg.sysDel(&s)

				split_sum += sysSplit
				split := sysSplit
				split += split_sum >= oz.WORLDS_ENTITIES_LIMIT ? oz.WORLDS_ENTITIES_LIMIT - split_sum : 0

				cg.sysInit(&s, split)
			}
			frame.worlds.systems = &_systems
			//////////
			

			cg.procedures_global[0](&frame)
			cg.procedures[world_loaded][0](&frame)
			{
				cg.sysInitProcess_world_one(&frame)
				for &s,s_i in _systems {
					cg.sysInitProcess_oneThread(&frame, &s)
					sysLen := cg.sysGet_len(&s)
					for i in 0..<sysLen {
						handle := cg.sysIterate(&s, i)
						cg.sysInitProcess_world(&frame,&s,&handle)
					}
				}
			}

			is_loading = false; world_loaded = frame.worlds._state.initial_world
		}
		////////////////////
		defer FrameMark("Update")	
		ZoneN("Main Loop")
		{
			ZoneN("Init")

	    time_past = time_now
	    time_now = time.tick_now()
	    frame.render.dt.value = time.duration_milliseconds(time.tick_diff(time_past,time_now))
	    frametime += frame.render.dt.value
	    frame.render.dt.overtime += frame.render.dt.value
	    frame.render.dt.fixed_overtime += fixed_dt
	    frame.render.dt.fixed = fixed_dt
	
	    frame.render.dt32 = {
	    	cast(f32)frame.render.dt.fixed,
	    	cast(f32)frame.render.dt.fixed_overtime,
	    	cast(f32)frame.render.dt.value,
	    	cast(f32)frame.render.dt.overtime,
	    }
	    frame.render.dt16 = {
	    	cast(f16)frame.render.dt.fixed,
	    	cast(f16)frame.render.dt.fixed_overtime,
	    	cast(f16)frame.render.dt.value,
	    	cast(f16)frame.render.dt.overtime,
	    }
		}
    
		oz.pollEvents()
		oz._input_handler(
			&oz._input_callbackList_old,
			&oz._input_callbackList,
			&oz.inputs
		)
		oz._mouse_handler(&oz.mouse,&mouse_reset)

    // frame_i = (frame_i + 1) % oz.RENDER_FRAME_IN_FLIGHT
    // frame.render.cmd = cmd_frames[frame_i]

    // systems_data := cast(^gs._SYSTEMS)state.frame.worlds.systems
    {
    	ZoneNC("Update", TC_UPDATE)
			cg.procedures_global[1](&frame)
			cg.procedures[world_loaded][1](&frame)
    }
    
    {
			for {
				if frametime > 0 {
    			ZoneNC("Update Fixed", TC_UPDATE_FIXED)
					oz._input_handler(
						&oz._input_callbackList_fixed_old,
						&oz._input_callbackList_fixed,
						&oz.inputs_fixed_old,
					)
					
					frametime -= fixed_dt
	
					// fmt.print(frametime)
					cg.procedures_global[2](&frame)
					cg.procedures[world_loaded][2](&frame)
				} else { break }
			}
    }

    {
    	ZoneNC("Update Late", TC_UPDATE)
			cg.procedures_global[3](&frame)
			cg.procedures[world_loaded][3](&frame)
    }
		// time.sleep(500*time.Millisecond)
	}

	{
		cg.sysEndProcess_one(&frame)
		for &s,s_i in _systems {
			cg.sysEndProcess_oneThread(&frame, &s)
			sysLen := cg.sysGet_len(&s)
			for i in 0..<sysLen {
				handle := cg.sysIterate(&s, i)
				cg.sysEndProcess(&frame,&s,&handle)
			}
		}
	}
	
	
	// global_state := build.GameState{
	// 	render = {render.state, render.drawCMDS},
	// 	world = {gworld.state, uni, procedures},
	// 	shader = shader.state
	// }
	// build.run_state(
	// 	&global_state
	// )
}





T_RenderData :: struct{
	cmd : []oz.Command
}; render_proc  :: proc(t: ^th.Thread) {
	///////////////////////////
	// INIT
	///////////////////////////
	sync.mutex_lock(&loading_mutex)
	F_REF := cast(^oz.FrameData)t.user_args[0]
	F : oz.FrameData
	mem.copy(&F, F_REF, size_of(oz.FrameData))
	///////////////////////////

	///////////////////////////
	// ARENAS
	///////////////////////////
	swapchain_arena : [3]^MemArena
	for &m in swapchain_arena {
		m = create_arena(10*mem.Kilobyte)
	}; swapchain_index : int
	///////////////////////////

	///////////////////////////
	// RENDERER
	///////////////////////////
	sz := oz.getResolution(F_REF.render.window)
	F_REF.graphic.swapchain = oz.vkSwapchain_Create(
		&F_REF.graphic.vulkan, F_REF.graphic.surface, 
		{ 
			sz,
			F_REF.graphic.formats.capabilities.currentTransform,
			F_REF.graphic.formats.capabilities.minImageCount,
		}, swapchain_arena[0]
	)
	swapchainOld: oz.Swapchain
	///////////////////////////

	///////////////////////////
	// FRAMETIME
	///////////////////////////
	dt:   oz.DeltaTime64
	dt32: oz.DeltaTime32
	dt16: oz.DeltaTime16
	
  frame_i   :  int
  time_now  := time.tick_now()
  time_past := time_now
	///////////////////////////
	
	for {
		// HEADER //////////////////
		if is_loading {
			sync.mutex_lock(&loading_mutex)
		}; defer sync.mutex_unlock(&loading_mutex)
		if oz._swapchainRecriation(F_REF, &swapchainOld, swapchain_arena[swapchain_index]) {
			swapchain_index = (swapchain_index + 1) % (len(swapchain_arena))
			idx := (len(swapchain_arena) - (swapchain_index+1))

			free_all(swapchain_arena[idx])
			mem.arena_free_all(&swapchain_arena[idx].arena)
		}

		///////////////////////////
		free_all(context.temp_allocator)
		defer FrameMark()
		ZoneN("Render Loop")
		mem.copy(&F, F_REF, size_of(oz.FrameData))

		///////////////////////////
		// DELTA TIME
		///////////////////////////
    time_past = time_now
    time_now = time.tick_now()
    dt.value = time.duration_milliseconds(time.tick_diff(time_past,time_now))
    dt.overtime += dt.value
    dt.fixed_overtime += fixed_dt
    dt.fixed = fixed_dt
    
    dt32 = {
    	cast(f32)dt.fixed,
    	cast(f32)dt.fixed_overtime,
    	cast(f32)dt.value,
    	cast(f32)dt.overtime,
    }
    dt16 = {
    	cast(f16)dt.fixed,
    	cast(f16)dt.fixed_overtime,
    	cast(f16)dt.value,
    	cast(f16)dt.overtime,
    }

    F.render.dt = dt
    F.render.dt32 = dt32
    F.render.dt16 = dt16
		///////////////////////////

    F.render.dt = dt
    F.render.dt32 = dt32
    F.render.dt16 = dt16

    frame_i = (frame_i + 1) % oz.RENDER_FRAME_IN_FLIGHT
    F.render.cmd = cmd_frames[frame_i]


    img_idx := oz.vkDraw_prepare(&F)
    for f in render.drawCMDS { f(F, img_idx) }
    oz.vkDraw_present(&F, &img_idx)

    // TEMPORARY RENDER FPS LIMITER
    // TODO: Expoxe this
    frame_limiter(time_now, fixed_dt_2x)
   	// time.sleep(cast(time.Duration)(((fixed_dt_over - time.duration_milliseconds(time.tick_since(time_now))))*f64(time.Millisecond)))

    // fmt.println(dt.value)
	} // for
} // render_proc

network_proc  :: proc(t: ^th.Thread) {
	frame := cast(^oz.FrameData)t.user_args[0]
	
	for {
		free_all(context.temp_allocator)

		time.sleep(500*time.Millisecond)
	}
}
T_SystemsData :: struct{
	system : ^systems._SYSTEMS,
	sync   : ^bool,
	loops  : ^i64
}; systems_proc :: proc(t: ^th.Thread) {
	///////////////////////////
	// INIT
	///////////////////////////
	F_REF := cast(^oz.FrameData)t.user_args[0]
	F : oz.FrameData
	mem.copy(&F, F_REF, size_of(oz.FrameData))
	data  := cast(^T_SystemsData)t.data
	///////////////////////////
	
	///////////////////////////
	// FRAMETIME
	///////////////////////////
	dt:   oz.DeltaTime64
	dt32: oz.DeltaTime32
	dt16: oz.DeltaTime16
	
  frame_i   :  int
  time_now  := time.tick_now()
  time_past := time_now
  frametime :  f64
	///////////////////////////

	fixed_loop_count : u64
	sync.wait_group_add(&groupWait_system, 1)
	for {
		// HEADER //////////////////
		data.loops^ += 1
		for {
			data.sync^ = true

			if is_loading { time.sleep(time.Millisecond) } else { break }
		}
		data.sync^ = false

		///////////////////////////
		free_all(context.temp_allocator)
		{
			ZoneN("Init")
			mem.copy(&F, F_REF, size_of(oz.FrameData))

	
			///////////////////////////
			// DELTA TIME
			///////////////////////////
	    time_past = time_now
	    time_now = time.tick_now()
	    dt.value = time.duration_milliseconds(time.tick_diff(time_past,time_now))
	    frametime += dt.value
	    dt.overtime += dt.value
	    dt.fixed_overtime += fixed_dt
	    dt.fixed = fixed_dt
	
	    dt32 = {
	    	cast(f32)dt.fixed,
	    	cast(f32)dt.fixed_overtime,
	    	cast(f32)dt.value,
	    	cast(f32)dt.overtime,
	    }
	    dt16 = {
	    	cast(f16)dt.fixed,
	    	cast(f16)dt.fixed_overtime,
	    	cast(f16)dt.value,
	    	cast(f16)dt.overtime,
	    }
	
	    F.render.dt = dt
	    F.render.dt32 = dt32
	    F.render.dt16 = dt16
		}
		ZoneN("System Loop")
		///////////////////////////
		// fmt.println(
  //   	F.render.dt.value,
		// )
		// {
		// 	if sync.barrier_wait(&barrier_update) { 
		// 		// fmt.println(t.name.(string))
		// 	}
		// }

		{
			ZoneNC("Update", TC_UPDATE)
			cg.sysProcess_one(&F,data.system)
			sysLen := cg.sysGet_len(data.system)
			for i in 0..<sysLen {
				handle := cg.sysIterate(data.system, i)
				cg.sysProcess(&F,data.system,&handle)
			}
		}
		
		{
			for {
				if frametime > 0 {
					fixed_loop_count += 1
					@(static) global_fixed_loop_count : u64
					systems_count[t.user_index] = fixed_loop_count
					defer frametime -= fixed_dt_over
					fixed_Z := ZoneNC("Update Fixed", TC_UPDATE_FIXED)
					fixez_Z_color : u32 = 0xFFAA00
					defer ZoneColor(fixed_Z,fixez_Z_color)
					{
						// {
						// 	barrier: for {
						// 		equals: int
						// 		for sc,sc_i in systems_count {
						// 			if sc <= global_fixed_loop_count { break barrier }
						// 			if sc == global_fixed_loop_count { equals += 1   }
						// 		}
						// 		fmt.println(systems_count, global_fixed_loop_count, sysThread_count)
						// 		if equals == sysThread_count { break }
						// 		time.sleep(time.Millisecond)
						// 	}
						// }
						// 
						sysFixed_dt       := time.tick_now()
						sysFixed_dt_after :  time.Tick
						cg.sysProcessFixed_one(&F,data.system)
						sysLen := cg.sysGet_len(data.system)
						for i in 0..<sysLen {
							handle := cg.sysIterate(data.system, i)
							cg.sysProcessFixed(&F,data.system,&handle)
						}
						sysFixed_dt_after = time.tick_now()
						diff_ms := time.duration_milliseconds(
							time.tick_diff(
								sysFixed_dt,
								sysFixed_dt_after,
							)
						)
						
						fixed_Z := ZoneNC("Semaphore", 0x999999)
						systems_time[t.user_index] = diff_ms
						sync.barrier_wait(&barrier_system)

						status : oz.OneshotThreadStatus
						status.num = t.user_index
						
						dt_worst : f64
						th_worst : int
						dt_best : f64 = max(f64)
						th_best : int
						for ti,ti_i in systems_time {
							if ti >= dt_worst {
								dt_worst = ti
								th_worst = ti_i
							}
							if ti <= dt_best {
								dt_best = ti
								th_best = ti_i
							}
						}

						if th_best == t.user_index {
							fixez_Z_color = 0x47AA00
							status.is_first = true
						}
						if th_worst == t.user_index {
							global_fixed_loop_count += 1
							fixez_Z_color = 0x9955F9
							status.is_last = true
							// fmt.println(t.user_index, th_worst)
							// count_cleanup : [dynamic; 10]u64
							// for sc,sc_i in systems_count {
							// 	if len(count_cleanup) == 0 { append(&count_cleanup, sc) }
							// 	for c in count_cleanup { 
							// 		if c != sc { append(&count_cleanup, sc) } else {
							// 			break
							// 		}
							// 	}
							// }
							// fmt.println(global_fixed_loop_count, count_cleanup)
						}
						{
							fixed_Z := ZoneNC("One Thread", 0x990099)
							cg.sysProcessFixed_oneThread(&F, data.system, status)
						}
						/*
						_, th_worst_check := sync.atomic_compare_exchange_strong(&th_worst, t.id, th_worst)
						*/

						// fmt.println(sysFixed_thread_worst, dt_worst)
						
						/*
						{
							fixed_Z := ZoneN("Update Fixed Barrier")
							@(static) fixed_barrier_loop_count : u64
							@(static) threads_list : int
							threads_list += 1
							cur_count := fixed_barrier_loop_count

							for (cur_count == fixed_barrier_loop_count) {
								fmt.println(sysThread_count, threads_list)
								time.sleep(time.Nanosecond)
								if sysThread_count == threads_list { threads_list = 0; break }
							}
							if fixed_loop_count >= fixed_barrier_loop_count {
								// sync.barrier_wait(&barrier_system)
							}
						}
						*/
					}
				} else { break }
			}
		}
		// {
		// 	if frametime > 0 {
		// 			// fmt.println(t.name.(string))
		// 		}
		// 	}
		// }

		{
			ZoneNC("Update Late", TC_UPDATE)
			cg.sysProcess_late_one(&F,data.system)
			sysLen := cg.sysGet_len(data.system)
			for i in 0..<sysLen {
				handle := cg.sysIterate(data.system, i)
				cg.sysProcess_late(&F,data.system,&handle)
			}
		}
  	frame_limiter(time_now, fixed_dt_8x)
	} // for
} // system_proc


///////////////////////////
// UTILS
///////////////////////////
MemArena :: struct {using alloc: runtime.Allocator, arena: mem.Arena}
create_arena :: proc(size: int) -> (^MemArena) {
	size := max(size, 0)
	a := new(MemArena)
	buff := make([]byte, size)
	
	mem.arena_init(&a.arena, buff)
	a.alloc = mem.arena_allocator(&a.arena)
	return a
}

frame_limiter :: proc(start: time.Tick, value: f64) {
  time.sleep(cast(time.Duration)(((value - time.duration_milliseconds(time.tick_since(start))))*f64(time.Millisecond)))
}
///////////////////////////
