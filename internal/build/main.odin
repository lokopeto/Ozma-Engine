#+feature dynamic-literals
package main

import "gamebuild:ozma"
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

model_buffer  : phos.HandleBox(oz.Obj)

SystemThread :: struct {
	thread : ^th.Thread,
	system : ^systems._SYSTEMS,
	sync  : bool,
	count : u64,
	time  : f64,
	loop : i64
}
system_threads : []SystemThread
barrier_system  : sync.Barrier
groupWait_system : sync.Wait_Group
semaphore_system : sync.Sema

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
	F  : oz.FrameData
	FL : oz.FrameDataLocal
	FL.render._deltatime.fixed_dt = fixed_dt

	F.render._state = render.state
	F.worlds._state = gworld.state

	oz.keyMap = render.state.input_default.keyMap
	sync.mutex_lock(&oz.loading_mutex)
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
	F.render.window.handle = oz.create_window(
		render.state.window_info.resolution.x,
		render.state.window_info.resolution.y,
		render.state.window_info.info,
		win_name
	); render.state.window_info.name = win_name
	// force update on the render for evading NaN
	F.render.window.resolution = render.state.window_info.resolution

	F.graphic = oz.create_renderer(F.render.window.handle, render_arena)
	cmd_frames = oz.vkRenderCommand_Create(&F.graphic.vulkan, cmd_arena)

	{
		shader_err : oz.VkCreateShaderError
		info := shader.state.shaders
		F.render.shaderBox, shader_err = oz.vkCreate_shaders(
			F.graphic.device,
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
	F.render.models = model_buffer
	_entity  : oz.EntityBox
	///////////////////////////

	///////////////////////////
	// THREADS
	///////////////////////////
	render_th  := th.create(render_proc, .High, "Render")
	render_th.user_args[0] = &F
	th.start(render_th); defer th.destroy(render_th)
	network_th := th.create(network_proc, .Low, "Network")
	network_th.user_args[0] = &F
	th.start(network_th); defer th.destroy(network_th)

	// Sys threads per Physical minus render + network
	// dynamic scalabe?
	// TODO: i'm dumb ._.
	//       just have a thread limit on a constant
	// Sys Threads //
	F.worlds.thread_count = max(os.get_processor_core_count() - 3, 1)

	fmt.println(ozma.WORLDS_THREAD_LIMIT)
	if ozma.WORLDS_THREAD_LIMIT >= 1 {
		F.worlds.thread_count = max(int(ozma.WORLDS_THREAD_LIMIT), 1)
	} else {
		F.worlds.thread_count = max(int(math.round(f32(ozma.WORLDS_THREAD_LIMIT) * f32(F.worlds.thread_count))), 1)		
	}
	system_threads = make([]SystemThread, F.worlds.thread_count)
	_systems := make([]systems._SYSTEMS, F.worlds.thread_count)
	sysSplit := int(math.ceil(f32(oz.WORLDS_ENTITIES_LIMIT) / f32(F.worlds.thread_count)))
	sync.barrier_init(&barrier_system, F.worlds.thread_count)

	{
		for &t,t_i in system_threads {
			t.system = &_systems[t_i]

			name := strings.join({"System ",fmt.tprint(t_i)}, "", context.allocator)
			t.thread = th.create(systems_proc, .High, name)
			t.thread.user_args[0] = &F
			t.thread.user_args[1] = &FL
			t.thread.data = &t
			t.thread.user_index = t_i
			th.start(t.thread)
		};
	}
	defer for t,t_i in system_threads { th.destroy(t.thread) }
	///////////////////////////

	{
		cg.sysInitProcess_one(&F,&FL)
		for &s,s_i in _systems {
			cg.sysInitProcess_oneThread(&F,&FL,&s)
			sysLen := cg.sysGet_len(&s)
			for i in 0..<sysLen {
				handle := cg.sysIterate(&s, i)
				cg.sysInitProcess(&F,&FL,&s,&handle)
			}
		}
	}
	sync.mutex_unlock(&oz.loading_mutex)

	mouse_reset: oz._mouse_handler_reset
	//////////////////////////////////////////////////
	// UPDATE LOOP                                  //
	//////////////////////////////////////////////////
	for !oz.windowShouldClose(&F) {
		free_all(context.temp_allocator)

		// WORLD SWITCHER //
		if oz.world_loaded != F.worlds._state.initial_world || oz.is_loading {
			// LOAD WORLD AND UNLOADS PAST
			// TODO: Do a proper semaphore or load as a stream and survive the memory overhead hell..
			oz.is_loading = true
			sync.mutex_lock(&oz.loading_mutex); defer sync.mutex_unlock(&oz.loading_mutex)
			for {
				time.sleep(time.Millisecond)
				count : int
				for v in system_threads { if v.sync { count += 1 } }
				if count >= F.worlds.thread_count { break }
				fmt.println(F.worlds.thread_count, count)
			}
			ZoneN("World Loading")

			{
				cg.sysEndProcess_world_one(&F,&FL)
				for &s,s_i in _systems {
					cg.sysEndProcess_oneThread(&F,&FL, &s)
					sysLen := cg.sysGet_len(&s)
					for i in 0..<sysLen {
						handle := cg.sysIterate(&s, i)
						cg.sysEndProcess_world(&F,&FL,&s,&handle)
					}
				}
			}

			cg.procedures_global[.end](&F,&FL)
			cg.procedures[oz.world_loaded][.end](&F,&FL)

			//////////
			// TODO: Handle the mesh upload better
			// TODO: do textures & sounds 
			models_path: [dynamic]string
			// textures:
			// sounds:
			for wi, wi_i in cg.worldsIndex[oz.world_loaded] {
    append(&models_path, cg.assets[wi].path)
			}
			
			// fmt.print(state.current_world.models)
			F.worlds.models = oz.vkUpload_meshList(
				&F.graphic.vulkan, models_path[:], 
				{
					u64(F.graphic.info.descriptorBuffer.combinedImageSamplerDescriptorSize),
					F.graphic.info.descriptorBuffer.descriptorBufferOffsetAlignment,
					bool(F.graphic.info.descriptorBuffer.combinedImageSamplerDescriptorSingleArray),
					F.render.descriptor_layout,
					F.render.texture.sampler,
				}, context.allocator
			)

			phos.delete(&_entity)
			phos.create(&_entity, oz.WORLDS_ENTITIES_LIMIT)
			F.worlds.entities = _entity
			
			split_sum : int
			for &s,s_i in _systems {
				cg.sysDel(&s)

				split_sum += sysSplit
				split := sysSplit
				split += split_sum >= oz.WORLDS_ENTITIES_LIMIT ? oz.WORLDS_ENTITIES_LIMIT - split_sum : 0

				cg.sysInit(&s, split)
			}
			F.worlds.systems = &_systems
			//////////

			cg.procedures_global[.init](&F,&FL)
			cg.procedures[oz.world_loaded][.init](&F,&FL)
			{
				cg.sysInitProcess_world_one(&F,&FL)
				for &s,s_i in _systems {
					cg.sysInitProcess_oneThread(&F,&FL,&s)
					sysLen := cg.sysGet_len(&s)
					for i in 0..<sysLen {
						handle := cg.sysIterate(&s, i)
						cg.sysInitProcess_world(&F,&FL,&s,&handle)
					}
				}
			}

			oz.is_loading = false; oz.world_loaded = F.worlds._state.initial_world
		}
		////////////////////
		defer FrameMark("Update")	
		ZoneN("Main Loop")
		{
			ZoneN("Init")
			deltatime_calc(
				&FL.render._deltatime,
				&FL.render.dt,
				&FL.render.dt32,
				&FL.render.dt16,
			)
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
			cg.procedures_global[.update](&F,&FL)
			cg.procedures[oz.world_loaded][.update](&F,&FL)
  }
  
  {
		for {
			if FL.render._deltatime.fixed_accum > 0 {
				defer FL.render._deltatime.fixed_accum -= fixed_dt
 			ZoneNC("Update Fixed", TC_UPDATE_FIXED)
				oz._input_handler(
					&oz._input_callbackList_fixed_old,
					&oz._input_callbackList_fixed,
					&oz.inputs_fixed_old,
				)
				
	
				// fmt.print(frametime)
				cg.procedures_global[.update_fixed](&F,&FL)
				cg.procedures[oz.world_loaded][.update_fixed](&F,&FL)
			} else { break }
		}
  }

  {
  	ZoneNC("Update Late", TC_UPDATE)
			cg.procedures_global[.update_late](&F,&FL)
			cg.procedures[oz.world_loaded][.update_late](&F,&FL)
  }
		// time.sleep(500*time.Millisecond)
	}

	{
		cg.sysEndProcess_one(&F,&FL)
		for &s,s_i in _systems {
			cg.sysEndProcess_oneThread(&F,&FL, &s)
			sysLen := cg.sysGet_len(&s)
			for i in 0..<sysLen {
				handle := cg.sysIterate(&s, i)
				cg.sysEndProcess(&F,&FL,&s,&handle)
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
	sync.mutex_lock(&oz.loading_mutex)
	F := cast(^oz.FrameData)t.user_args[0]
	FL : oz.FrameDataLocal
	FL.render._deltatime.fixed_dt = fixed_dt
	///////////////////////////

	///////////////////////////
	// ARENAS
	///////////////////////////
	// TODO : Make coarse
	swapchain_arena : [3]^MemArena
	for &m in swapchain_arena {
		m = create_arena(10*mem.Kilobyte)
	}; swapchain_index : int
	///////////////////////////

	///////////////////////////
	// RENDERER
	///////////////////////////
	sz := oz.getResolution(F.render.window)
	F.graphic.swapchain = oz.vkSwapchain_Create(
		&F.graphic.vulkan, F.graphic.surface, 
		{ 
			sz,
			F.graphic.formats.capabilities.currentTransform,
			F.graphic.formats.capabilities.minImageCount,
		}, swapchain_arena[0]
	)
	swapchainOld: oz.Swapchain

	frame_i : int
	///////////////////////////
	
	for {
		// HEADER //////////////////
		if oz.is_loading {
			sync.mutex_lock(&oz.loading_mutex)
		}; defer sync.mutex_unlock(&oz.loading_mutex)
		if oz._swapchainRecriation(F, &swapchainOld, swapchain_arena[swapchain_index]) {
			swapchain_index = (swapchain_index + 1) % (len(swapchain_arena))
			idx := (len(swapchain_arena) - (swapchain_index+1))

			free_all(swapchain_arena[idx])
			mem.arena_free_all(&swapchain_arena[idx].arena)
		}
		///////////////////////////

		free_all(context.temp_allocator)
		defer FrameMark()
		ZoneN("Render Loop")

		///////////////////////////
		// FRAME LOCAL
		///////////////////////////
		deltatime_calc(
			&FL.render._deltatime,
			&FL.render.dt,
			&FL.render.dt32,
			&FL.render.dt16,
		)

  frame_i = (frame_i + 1) % oz.RENDER_FRAME_IN_FLIGHT
  FL.render.cmd = cmd_frames[frame_i]
  ///////////////////////////

  img_idx := oz.vkDraw_prepare(F,&FL)
  for f in render.drawCMDS { f(F,&FL, img_idx) }
  oz.vkDraw_present(F,&FL, &img_idx)

  // TEMPORARY RENDER FPS LIMITER
  // TODO: Expose this on the main lib
  frame_limiter(FL.render._deltatime.time_now, fixed_dt_2x)
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

systems_proc :: proc(t: ^th.Thread) {
	///////////////////////////
	// INIT
	///////////////////////////
	F := cast(^oz.FrameData)t.user_args[0]
	FL : oz.FrameDataLocal
	FL.render._deltatime.fixed_dt = fixed_dt
	data  := cast(^SystemThread)t.data
	///////////////////////////

	fixed_loop_count : u64
	sync.wait_group_add(&groupWait_system, 1)
	// TODO : DeltaTime is long cus is_loading is making it longer
	// 		     needs confirmation with simulation/heavy scenarios
	for {
		///////////////////////////
		// HEADER
		///////////////////////////
		data.loop += 1
		sync_runned : bool
		for {
			data.sync = true

			if oz.is_loading { 
				time.sleep(time.Millisecond)
				sync_runned = true
			} else {
				// if sync_runned do FL.render._deltatime.time_now = time.tick_now()
				///////////////////////////
				// DELTA TIME
				///////////////////////////
				deltatime_calc(
					&FL.render._deltatime,
					&FL.render.dt,
					&FL.render.dt32,
					&FL.render.dt16,
				)
				///////////////////////////
				break 
			}
		}
		data.sync = false
		///////////////////////////

		///////////////////////////
		free_all(context.temp_allocator)
		{
			ZoneN("Init")
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
			cg.sysProcess_one(F,&FL,data.system)
			sysLen := cg.sysGet_len(data.system)
			for i in 0..<sysLen {
				handle := cg.sysIterate(data.system, i)
				cg.sysProcess(F,&FL,data.system,&handle)
			}
		}
		
		{
			for {
				if FL.render._deltatime.fixed_accum > 0 {
					defer FL.render._deltatime.fixed_accum -= fixed_dt
					fixed_loop_count += 1
					@(static) global_fixed_loop_count : u64
					system_threads[t.user_index].count = fixed_loop_count
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
						cg.sysProcessFixed_one(F,&FL,data.system)
						sysLen := cg.sysGet_len(data.system)
						for i in 0..<sysLen {
							handle := cg.sysIterate(data.system, i)
							cg.sysProcessFixed(F,&FL,data.system,&handle)
						}
						sysFixed_dt_after = time.tick_now()
						diff_ms := time.duration_milliseconds(
							time.tick_diff(
								sysFixed_dt,
								sysFixed_dt_after,
							)
						)
						
						system_threads[t.user_index].time = diff_ms
						{
							fixed_Z := ZoneNC("Semaphore", 0x999999)
							sync.barrier_wait(&barrier_system)
						}

						status : oz.OneshotThreadStatus
						status.num = t.user_index
						
						dt_worst : f64
						th_worst : int
						dt_best  : f64 = max(f64)
						th_best  : int
						for st,st_i in system_threads {
							if st.time >= dt_worst {
								dt_worst = st.time
								th_worst = st_i
							}
							if st.time <= dt_best {
								dt_best = st.time
								th_best = st_i
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
							cg.sysProcessFixed_oneThread(F,&FL, data.system, status)
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
			cg.sysProcess_late_one(F,&FL,data.system)
			sysLen := cg.sysGet_len(data.system)
			for i in 0..<sysLen {
				handle := cg.sysIterate(data.system, i)
				cg.sysProcess_late(F,&FL,data.system,&handle)
			}
		}
  	frame_limiter(FL.render._deltatime.time_now, fixed_dt_8x)
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

deltatime_calc :: proc(
	data: ^oz.DeltaTimeData,
	dt:   ^oz.DeltaTime64,
	dt32: ^oz.DeltaTime32,
	dt16: ^oz.DeltaTime16
) {
	// Resolve DeltaTime 
	data.time_past = data.time_past == {} ? time.tick_now() : data.time_now
	data.time_now = time.tick_now()
	dt.value = time.duration_milliseconds(
		time.tick_diff( data.time_past, data.time_now )
 )
 data.fixed_accum += dt.value
 
 // Update DeltaTime
 dt.overtime += dt.value
 dt.fixed_overtime += data.fixed_dt
 dt.fixed = data.fixed_dt
 
 dt32^ = {
 	cast(f32)dt.fixed,
 	cast(f32)dt.fixed_overtime,
 	cast(f32)dt.value,
 	cast(f32)dt.overtime,
 }
 dt16^ = {
 	cast(f16)dt.fixed,
 	cast(f16)dt.fixed_overtime,
 	cast(f16)dt.value,
 	cast(f16)dt.overtime,
 }
}
///////////////////////////
