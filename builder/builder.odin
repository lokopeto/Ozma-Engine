package main

import "core:crypto/_subtle"
import "core:mem"
import "core:slice"
import "core:terminal/ansi"
import "base:runtime"
import "core:strconv"
import "core:time"
import "core:encoding/hxa"
import "core:fmt"
import "core:os"
import "core:math"
import "core:strings"
import "../shared/joy"
import hh "../shared/Holographic-HxA"
import oz "../src/"
import slang "../shared/odin-slang/slang"
import "core:odin/ast"
import "core:odin/parser"
import "core:odin/tokenizer"



Build_ProcData :: struct{
	name: string,
	pre: 	proc(data: []Build_ProcData, data_index: int, allocator: runtime.Allocator),
	pos: 	proc(data: []Build_ProcData, data_index: int, allocator: runtime.Allocator),
	reportIn: []string,
	reportOut: [dynamic]string,
	data: union {
		[]oz.Asset,
		bpShaders_data,
		joy.Map
	},
}
build_ProcList := []Build_ProcData{
	{
		name = "Config",
		pre  = bpConfig,
		pos  = nil,
	},
	{
		name = "Meta",
		pre  = bpMeta,
		pos  = nil,
	},
	{
		name = "Shaders",
		pre  = bpShaders,
		pos  = bpShaders_after,
	},
	{
		name = "Render",
		pre  = bpRender,
		pos	 = nil,
	},
	{
		name = "Systems",
		pre	 = bpSystems,
		pos	 = nil,
	},
	{
		name = "Assets",
		pre	 = bpAssets,
		pos	 = bpAssets_After,
	},
	{
		name = "Worlds",
		pre	 = bpWorlds,
		pos	 = nil,
	},
	{
		name = "Engine",
		pre	 = bpEngine,
		pos	 = nil,
	},
}

// ================================================
// BUILDER METAPROGRAMING
// ================================================
bpMeta :: proc(data: []Build_ProcData, data_index: int, allocator: runtime.Allocator) {
	path_lib, _ := os.join_path({global.exec_path, "src"}, context.temp_allocator)
	walker := os.walker_create_path(path_lib)
	for f in os.walker_walk(&walker) {
		path_rel, _ := os.get_relative_path(path_lib,f.fullpath, context.temp_allocator)
		path_lib, _ := os.join_path({global.build.game_folder, ".build", "ozma", path_rel}, context.temp_allocator)

		if f.type == .Directory {
			os.make_directory_all(path_lib)
		} else if len(f.name) > 0 && f.name[0] != '!' {
			os.change_mode(path_lib, os.Permissions_Default)
			if os.exists(path_lib) {
				// TODO: Versioning
				data, read_err := os.read_entire_file(f.fullpath, context.temp_allocator)
				if read_err != os.General_Error.None {
					print_error(read_err)
				}
				write_err := os.write_entire_file(path_lib, data)
				if write_err != os.General_Error.None {
					print_error(write_err)
				}
			} else {
				os.copy_file(path_lib, f.fullpath)
			}
			os.change_mode(path_lib, {.Read_Other, .Read_Group, .Read_User})
		}
	}

	// if true {os.exit(0)}
}


// ================================================
// BUILDER ASSETS
// ================================================
DeltaReport :: map[string]time.Time
bpAssets :: proc(data: []Build_ProcData, data_index: int, allocator: runtime.Allocator) {
	context.allocator = context.temp_allocator
	assetMap, err, allocErr, line := joy.load_from_path("worlds/assets.joy", allocator)
	// defer joy.delete_map(assetMap)

	files := make([dynamic]oz.Asset, allocator)

	fileDelta := read_lazyDelta(data[data_index].reportIn[:], allocator)

	if global.build.args.clean {
		path, _ := os.join_path({".build", "assets"}, allocator)
		os.remove_all(path)
	}

	codegen : strings.Builder
	strings.builder_init(&codegen)
	strings.write_string(&codegen, fmt.tprintln(
			"package oz",
			"AssetsModels :: enum {",
			sep="\n"
		)
	)
	
	index : u32
	for m_pathRaw, m_v in assetMap {
		m_path, _ := os.replace_path_separators(m_pathRaw, os.Path_Separator, allocator)
		src, _ := os.join_path({"assets", m_path}, allocator)

		if !os.exists(src) { print("Invalid Asset:",src); continue }
		// print(m_v)

		if m_v["type"].(string) == "Model" {
			codegen_dirStem := strings.to_upper_snake_case(os.dir(m_path))
			codegen_dirStem, _ = os.replace_path_separators(codegen_dirStem, '_', allocator)
			strings.write_string(&codegen, 
				fmt.tprintln(
					codegen_dirStem,
					"_",
					os.stem(m_path),
					" = ", index,
					",",
					sep=""
				)
			)
			// strings.write_string(&codegen, ",\n")

			mReport := fileDelta[m_path]
			ext := os.ext(m_path)
			dstName, _ := strings.join({src[:len(src)-len(ext)], ".hxa"}, "")
	
			filesrc_info, _ := os.lstat(src, allocator)
			dst, _ := os.join_path({".build", dstName}, allocator)
	
			// print(dst)
			conv_trigger: bool
			append_trigger: bool
			if global.build.args.clean {
				conv_trigger = true
				append_trigger = true
			} else {
				if os.exists(dst) {
					if time.diff(mReport, filesrc_info.modification_time) > 1 {
						conv_trigger = true
					}
					append_trigger = true
				} else {
					conv_trigger = true
					append_trigger = true
				}
			}

	
			if conv_trigger {
				print("Converting", m_path)
				model, convErr := hh.converter(src, {uv_flip=true,verbose=false}, allocator)
				if convErr != .None {
					print("Error Converting Model:", convErr)
					continue
				}
				mkdirErr := os.make_directory_all(os.dir(dst))
				if mkdirErr != os.General_Error.None && mkdirErr != os.General_Error.Exist {
					print("Error Making Folder:", mkdirErr)
					continue
				}
				file_size := hxa.required_write_size(model)
				file_bytes := make([]byte, file_size)
				file_finalSize, hxaErr := hxa.write(file_bytes[:], model)
				if hxaErr != .None {
					print("Error Saving Model:", hxaErr)
					continue
				}
				fileError := os.write_entire_file(dst, file_bytes)
				if fileError != os.General_Error.None {
					print("Error Saving Model File:", fileError)
					continue
				}
			}
	
			if append_trigger {
				append(&files, oz.Asset{
					path = dstName,
					type = .Model,
					worlds = m_v["worlds"].([]string)
				})
			}

			append(&data[data_index].reportOut, save_delta(m_pathRaw, filesrc_info.modification_time, context.temp_allocator))
		}
		// print(src, dst)
		// print(os.exists(path))
		index += 1
	}
	strings.write_string(&codegen, "}\n")

	out_path,_ := os.join_path({".build", "ozma"}, context.temp_allocator)
	os.make_directory_all(out_path)
	file_err := os.write_entire_file(
		fmt.tprint(out_path, "!assets.odin", sep=os.Path_Separator_String), 
		codegen.buf[:]
	)


	data[data_index].data = files[:]
	// print(assetMap, err, allocErr, line)
	return
}

bpAssets_After :: proc(data: []Build_ProcData, data_index: int, allocator: runtime.Allocator) {
	assets_outFolder := fmt.tprint(global.build.output_folder, "assets", sep=os.Path_Separator_String)
	os.make_directory_all(assets_outFolder)
	os.copy_directory_all(assets_outFolder, fmt.tprint(".build","assets",sep=os.Path_Separator_String))
	return
}

read_lazyDelta :: proc (str: []string, allocator := context.allocator) -> (report: DeltaReport) {
	for v,k in str {
		entries := strings.split(v, " ", allocator)
		
		path, delta := read_delta(entries[0], entries[1], allocator)
		report[path] = delta
	}
	return
}
read_delta :: proc(path, sec: string, allocator := context.allocator) -> (string, time.Time) {
	path, _, _ := strconv.unquote_string(path, allocator)
	nsec, _ := strconv.parse_i64(sec)
	return path, { _nsec = nsec}
}
save_delta :: proc(path: string, sec: time.Time, allocator := context.allocator) -> string {	
	return strings.join(
		{
			fmt.tprint("\"",path,"\"", sep=""),
			fmt.tprint(time.to_unix_nanoseconds(sec)),
			"\n"
		}, " ", allocator
	)
}

// ================================================
// BUILDER RENDER
// ================================================
bpRender :: proc(data: []Build_ProcData, data_index: int, allocator: runtime.Allocator) {
	// os.make_directory(".build/render")
	
	// walk := os.walker_create("render")
	// for w in os.walker_walk(&walk) {
		
	// }
	// os.walker_destroy(&walk)
	// file, _ := os.create("./build/render/render.odin")	
	return
}

// ================================================
// BUILDER SHADERS
// ================================================
slBlob_String :: proc(blob: ^slang.IBlob) -> string {
	return blob != nil ? string(cast(cstring)blob.getBufferPointer(blob)) : ""
}
slModule_from_data :: proc(session: ^slang.ISession, module_name, file_name: string, data: []u8) -> (module: ^slang.IModule, diagnostics: string) {
	diag_blob: ^slang.IBlob
	return session.loadModuleFromSourceString(session,
		strings.clone_to_cstring(module_name),
		strings.clone_to_cstring(file_name),
		cstring(raw_data(data)),
		&diag_blob
	), slBlob_String(diag_blob)
}

bpShaders_data :: struct{
	shaders_path: []string
}

bpShaders :: proc(data: []Build_ProcData, data_index: int, allocator: runtime.Allocator) {
	if global.build.args.clean {
		os.remove_all(fmt.tprint(".build", "shaders", sep=os.Path_Separator_String))
	}

	// report_info: strings.Builder
	// strings.write_string()

	sessionGlobal: ^slang.IGlobalSession
	session: ^slang.ISession

	shader_folder :: "shaders"
	shader_folder_out :: ".build/shaders/"
	
	wd, _ := os.getwd(context.allocator)

	fileDelta := read_lazyDelta(data[data_index].reportIn[:])

	session_exists : bool
	paths := make([dynamic]string)
	index : int
	s_walker := os.walker_create(shader_folder)
	for entry in os.walker_walk(&s_walker) {
		if os.ext(entry.name) == ".slang" && entry.name[0] != '!' && entry.size > 0 {
			if entry.name[0] == '_' && !global.build.args.debug {
				continue
			}
			rel_path,_ := os.get_relative_path(wd,entry.fullpath, context.temp_allocator)
			append(&data[data_index].reportOut, save_delta(rel_path, entry.modification_time))

			if !global.build.args.clean {
				if rel_path in fileDelta {
					if time.diff(fileDelta[rel_path], entry.modification_time) <= 1 {
						continue
					}
				}				
			}

			if !session_exists {
				slang.createGlobalSession(slang.API_VERSION, &sessionGlobal)
				
				config : [dynamic]slang.CompilerOptionEntry
				append(
					&config,
					..[]slang.CompilerOptionEntry{
						// {	
						// name = .ForceCLayout,
						// value = {
						// 	intValue0 = 1,
						// 	kind = .Int,
						// }
						// },
						{
							name = .EmitSpirvDirectly,
							value = {
								intValue0 = 1,
								kind = .Int,
							}
						},
					}
				)
				if global.build.args.debug {
					append(
					&config,
					slang.CompilerOptionEntry{
						name = .DebugInformation,
						value = {
							intValue0 = 3,
							kind = .Int,
						}
					}
					)
				}

				if !global.build.args.quick {
					append(
					&config,
					slang.CompilerOptionEntry{
						name = .Optimization,
						value = {
							intValue0 = 3,
							kind = .Int,
						}
					}
					)
				}
			
				targets := []slang.TargetDesc{
					{
						structureSize = size_of(slang.TargetDesc),
						profile = sessionGlobal->findProfile("spirv_1_6"),
						floatingPointMode = .DEFAULT,
						format = .SPIRV,
						compilerOptionEntries = raw_data(config[:]),
						compilerOptionEntryCount = u32(len(config))
					}
				}
				searchPaths := []cstring{
					"shaders"
				}


				sessionGlobal->createSession(slang.SessionDesc{
					structureSize = size_of(slang.SessionDesc),
					
					targets = raw_data(targets),
					targetCount = len(targets),
					
					searchPaths = raw_data(searchPaths),
					searchPathCount = len(searchPaths),

					
					// defaultMatrixLayoutMode = .COLUMN_MAJOR
				}, &session)

				session_exists = true
			}

			print(ansiColor(ansi.FG_MAGENTA),"[Compiling] \"",entry.name,"\"",ansiColor(ansi.RESET),sep="")

			module_name := strings.trim_suffix(entry.name, os.ext(entry.name))
			shader_src, _ := os.read_entire_file(entry.fullpath, context.temp_allocator)
			module, module_diagnostics := slModule_from_data(
				session,
				module_name,
				entry.name,
				shader_src,
			)
			if module_diagnostics != "" { fmt.println(module_diagnostics) }
		
			base_out := strings.join(
				{
					shader_folder_out,
					strings.trim_prefix(
						os.dir(rel_path), 
						shader_folder
					)
				}, ""
			)
			
			if !os.exists(base_out) {
				os.make_directory(base_out)
			}

			file_out_name := strings.join({
					strings.trim_suffix(entry.name, "slang"),
					"spv"
				}, "", context.allocator
			)
			
			out_path,_ := os.join_path({
					base_out, file_out_name
				}, context.allocator
			)

			entry : ^slang.IEntryPoint
			if module->findEntryPointByName("main", &entry) == 0 {
				diagnostics : ^slang.IBlob
				components := []^slang.IComponentType{
					module,
					entry,
				}

				composed: ^slang.IComponentType
				session->createCompositeComponentType(
					raw_data(components), len(components), &composed, &diagnostics
				)
				if diagnostics != nil do print(
					cast(string)mem.byte_slice(
						diagnostics->getBufferPointer(), 
						diagnostics->getBufferSize()
					)
				)
				
				linked : ^slang.IComponentType
				composed->link(&linked, &diagnostics)


				if diagnostics != nil do print(
					cast(string)mem.byte_slice(
						diagnostics->getBufferPointer(), 
						diagnostics->getBufferSize()
					)
				)

				code : ^slang.IBlob
				linked->getTargetCode(0, &code, &diagnostics)
				os.make_directory_all(os.dir(out_path))
				if save_err := os.write_entire_file(
					out_path,
					mem.byte_slice(
						code->getBufferPointer(), 
						code->getBufferSize())
					); save_err != os.General_Error.None {
					print_error("Cannot save shader file, ", save_err)
				}
			}
			append(&paths, out_path)
		}
	}	
	build_data := new(bpShaders_data)
	build_data.shaders_path = paths[:]
	data[data_index].data = build_data^
	slang.shutdown()
	return
}

bpShaders_after :: proc(data: []Build_ProcData, data_index: int, allocator: runtime.Allocator){
	assets_outFolder := fmt.tprint(global.build.output_folder, "shaders", sep=os.Path_Separator_String)
	os.make_directory_all(assets_outFolder)
	os.copy_directory_all(assets_outFolder, fmt.tprint(".build", "shaders", sep=os.Path_Separator_String))
	// fmt.println(data[data_index].data)
	return
}


// ================================================
// BUILDER SYSTEMS
// ================================================
bpSystems :: proc(data: []Build_ProcData, data_index: int, allocator: runtime.Allocator) {

	// READ FILES /////////////////
	tk : tokenizer.Tokenizer

	path_rel := fmt.tprint(
		"systems", "!systems.odin",
		sep = os.Path_Separator_String
	)
	path_abs, _ := os.get_absolute_path(path_rel, context.temp_allocator)
	data, _ := os.read_entire_file_from_path(path_rel, context.temp_allocator)

	tokenizer.init(&tk, string(data), path_abs)

	detect_struct :: proc(tk: string, kind: tokenizer.Token_Kind) -> (strings.Builder, bool) {
		@(static) builder: strings.Builder
		@(static) builder_is_init: bool
		@(static) count: u32

		if !builder_is_init {
			strings.builder_init(&builder)
			count = 0
			builder_is_init = true
		}

		if builder_is_init {
			if kind == .Ident && tk == "Systems" && count == 0 {
				strings.write_string(&builder, tk)
				count += 1
				return builder, false
			}
			if kind == .Colon && count == 1 {
				strings.write_string(&builder, tk)	
				count += 1
				return builder, false
			}
			if kind == .Colon && count == 2 {
				strings.write_string(&builder, tk)	
				count += 1
				return builder, false
			}
			if kind == .Struct && count == 3 {
				strings.write_string(&builder, tk)	
				count += 1
				return builder, false
			}
			if kind == .Open_Brace && count == 4 {
				strings.write_string(&builder, tk)
				count += 1
				return builder, true
			}
			
			builder_is_init = false
			count = 0
		}

		return builder, false
	}

	finder : strings.Builder
	fd_ok : bool
	for {
		token := tokenizer.scan(&tk)
		finder, fd_ok = detect_struct(token.text, token.kind)
		if fd_ok {
			break
		}

		// print(ansiColor(ansi.FG_BRIGHT_BLACK),token.text,token.kind,ansiColor(ansi.RESET))
		if token.kind == .EOF {
			break
		}
	}

	Entry :: struct {
		name: string,
		value: string,
		data: string,
	}
	assignments: [dynamic]Entry
	if fd_ok {
		for {
			entry: Entry
			token := tokenizer.scan(&tk)
			if token.kind == .Comment {
				continue
			}
			
			if token.kind == .Ident {
				entry.name = token.text
				tokenizer.scan(&tk)
			} else if token.kind == .Close_Brace {
				break
			}

			paren : bool
			name_builder: strings.Builder
			count : u32
			for {
				token = tokenizer.scan(&tk)

				if token.kind == .Open_Paren {
					count = 0
					paren = true
				}
				if token.kind == .Close_Paren {
					paren = false
					// print(paren)
				}

				if paren && count == 5 && token.kind == .Ident {
					entry.data = token.text
				}

				if
					!paren &&
					(token.kind == .Comma || 
					token.kind == .Close_Brace)
				{
					break
				}
				count += 1
				strings.write_string(&name_builder, token.text)
			}
			entry.value = string(name_builder.buf[:])
			append(&assignments, entry)
			if token.kind == .Close_Brace {
				break
			}
 		}
	}
	assign_len := len(assignments[:])

	// GENERATE FILES /////////////////
	builder_init :: proc(sep : string, args: ..any) -> (s: strings.Builder) {
		strings.write_string(&s,
			fmt.tprintln(..args,
				sep=sep
		))
		return
	}
	builder_finalize :: proc(out: ^strings.Builder, b: ^strings.Builder, str: string) {
		strings.write_string(b, str)
		strings.write_bytes(out, b.buf[:])
	}
	builder_write :: proc(b: ^strings.Builder, sep : string, args: ..any) {
		strings.write_string(b, fmt.tprintln(..args, sep=sep))
	}

	// CODEGEN INLINE
	codegenInFiles := builder_init("\n", 
		"package systems",
		"import oz \"ozma:.\"",
		"import phos \"shared:Phos\"",
		"SYS_PROC_IDENTITY :: proc(f: ^oz.FrameData, data: ^_SYSTEMS, h: ^_HANDLES) {}",
	)
	codegenin_struct := builder_init("",
		"_SYSTEMS :: struct {\n"
	)

	codegenin_struct_assign: strings.Builder
	codegenin_handles_enum := builder_init("\n",
		"_SYS_ENUM :: enum {",
	)
	codegenin_handles := builder_init("\n",
		"_HANDLES :: struct {",
	)

	/*
	entity_system_add :: proc(s: ^_SYSTEMS, e: ^oz.Entity, d: TestData) -> (sys: ^TestData) {
		if e._internal.systems_index.testSystem > 0 {
			sys := cast(^oz.SystemBox(TestData))e._internal.systems_index.testSystem
			hm.dynamic_remove(&s.testSystem, sys.handle)
		}
		handle :=	hm.dynamic_add(&s.testSystem, oz.SystemBox(TestData){ 
			_data = d,
			_entity = e
	 	})
		sys = hm.dynamic_get(&s.testSystem, handle)
		e._internal.systems_index.testSystem = uintptr(sys)
		e.systems.testSystem = true
		return
	}

	entity_system_remove :: proc(s: ^_SYSTEMS, e: ^oz.Entity, d: _SYS_ENUM) {
		switch d {
			case .testSystem:
				if e._internal.systems_index.testSystem < 0 {return}
				sys := cast(^oz.SystemBox(TestData))e._internal.systems_index.testSystem
				if hm.dynamic_is_valid(&s.testSystem, sys.handle) {
					hm.dynamic_remove(&s.testSystem, sys.handle)
				}
			case .testSystem3:
				if e._internal.systems_index.testSystem3 < 0 {return}
				sys := cast(^oz.SystemBox(TestData3))e._internal.systems_index.testSystem3
				if hm.dynamic_is_valid(&s.testSystem3, sys.handle) {
					hm.dynamic_remove(&s.testSystem3, sys.handle)
				}
		}
	}
	*/

	codegenin_sysadd_procs : strings.Builder
	// codegenin_sysadd_morph := builder_init("\n",
	// 	"entity_system_add :: proc {",
	// )
	codegenin_sysrem := builder_init("\n",
		"entity_system_remove :: proc(f: ^oz.FrameData, s: ^_SYSTEMS, e: ^oz.Entity, d: _SYS_ENUM) {",
		"	switch d {"
	)

	//BUILD
	out := builder_init("\n", 
		"package oz",
		"import phos \"shared:Phos\" ",
	)
	out_systoggle := builder_init("\n", 
		"SystemsToggler :: struct {",
	)
	out_sysIndex := builder_init("\n", 
		"SystemsIndex :: struct {",
	)
	out_sysInit := builder_init("\n", 
		"systemsInit :: proc() -> SystemsIndex {",
		"return {",
	)

	// CODEGEN
	codegen := builder_init("\n",
		"package codegen",
		"import oz \"../ozma\"",
		"import gs \"game:systems\"",
		// "import hm \"core:container/handle_map\"",
		"import phos \"shared:Phos\"",
		"import \"core:mem/virtual\"",
		// "import \"core:fmt\"",
	)

	codegen_process := builder_init("",
		"sysProcess :: proc(f: ^oz.FrameData, d: ^gs._SYSTEMS, i: ^gs._HANDLES) {"
	)
	codegen_process_fixed := builder_init("",
		"sysProcessFixed :: proc(f: ^oz.FrameData, d: ^gs._SYSTEMS, i: ^gs._HANDLES) {"
	)
	codegen_process_late := builder_init("", 
		"sysProcess_late :: proc(f: ^oz.FrameData, d: ^gs._SYSTEMS, i: ^gs._HANDLES) {"
	)
	codegen_initProcess := builder_init("",
		"sysInitProcess :: proc(f: ^oz.FrameData, d: ^gs._SYSTEMS, i: ^gs._HANDLES) {",
	)
	codegen_endProcess := builder_init("",
		"sysEndProcess :: proc(f: ^oz.FrameData, d: ^gs._SYSTEMS, i: ^gs._HANDLES) {",
	)
	codegen_initProcess_world := builder_init("",
		"sysInitProcess_world :: proc(f: ^oz.FrameData, d: ^gs._SYSTEMS, i: ^gs._HANDLES) {",
	)
	codegen_endProcess_world := builder_init("",
		"sysEndProcess_world :: proc(f: ^oz.FrameData, d: ^gs._SYSTEMS, i: ^gs._HANDLES) {",
	)
	
	codegen_one_process := builder_init("",
		"sysProcess_one :: proc(f: ^oz.FrameData) {"
	)
	codegen_one_process_fixed := builder_init("",
		"sysProcessFixed_one :: proc(f: ^oz.FrameData) {"
	)
	codegen_one_process_late := builder_init("", 
		"sysProcess_late_one :: proc(f: ^oz.FrameData) {"
	)
	codegen_one_initProcess := builder_init("",
		"sysInitProcess_one :: proc(f: ^oz.FrameData) {",
	)
	codegen_one_endProcess := builder_init("",
		"sysEndProcess_one :: proc(f: ^oz.FrameData) {",
	)
	codegen_one_initProcess_world := builder_init("",
		"sysInitProcess_world_one :: proc(f: ^oz.FrameData) {",
	)
	codegen_one_endProcess_world := builder_init("",
		"sysEndProcess_world_one :: proc(f: ^oz.FrameData) {",
	)

	codegen_oneThread_process := builder_init("",
		"sysProcess_oneThread :: proc(f: ^oz.FrameData, d: ^gs._SYSTEMS) {"
	)
	codegen_oneThread_process_fixed := builder_init("",
		"sysProcessFixed_oneThread :: proc(f: ^oz.FrameData, d: ^gs._SYSTEMS) {"
	)
	codegen_oneThread_process_late := builder_init("", 
		"sysProcess_late_oneThread :: proc(f: ^oz.FrameData, d: ^gs._SYSTEMS) {"
	)
	codegen_oneThread_initProcess := builder_init("",
		"sysInitProcess_oneThread :: proc(f: ^oz.FrameData, d: ^gs._SYSTEMS) {",
	)
	codegen_oneThread_endProcess := builder_init("",
		"sysEndProcess_oneThread :: proc(f: ^oz.FrameData, d: ^gs._SYSTEMS) {",
	)
	codegen_oneThread_initProcess_world := builder_init("",
		"sysInitProcess_world_oneThread :: proc(f: ^oz.FrameData, d: ^gs._SYSTEMS) {",
	)
	codegen_oneThread_endProcess_world := builder_init("",
		"sysEndProcess_world_oneThread :: proc(f: ^oz.FrameData, d: ^gs._SYSTEMS) {",
	)

	
	codegen_get_len := builder_init("",
		"sysGet_len :: proc(d: ^gs._SYSTEMS) -> (v: int) {",
	)
	codegen_init := builder_init("",
		"sysInit :: proc(d: ^gs._SYSTEMS, size: int) {\n",
		"err: virtual.Allocator_Error"
	)
	codegen_del := builder_init("",
		"sysDel :: proc(d: ^gs._SYSTEMS) {\n",
	)
	// codegen_get_iterators := builder_init("\n",
	// 	"sysGet_iterators :: proc(d: ^gs._SYSTEMS) -> (it: hmIter) {",
	// 	"return {",
	// )
	codegen_iterate := builder_init("\n",
		"sysIterate :: proc(s: ^gs._SYSTEMS, i: int) -> (h: gs._HANDLES) {",
		// "return {",
	) 
	// codegen_iterator_struct := builder_init("\n",
	// 	"hmIter :: struct {",
	// )

	for i in 0..<assign_len {
		a := assignments[i]

		rev_len := max(0,(assign_len - 1) - i)
		
		{ // PROCESS		
			builder_write(&codegen_initProcess,"", 
				"if gs.",a.name, ".s.init != nil do gs.",a.name, ".s.init(f,d,i)"
			)
			builder_write(&codegen_endProcess,"", 
				"if gs.",a.name, ".s.end != nil do gs.",a.name, ".s.end(f,d,i)"
			)
			builder_write(&codegen_initProcess_world,"", 
				"if gs.",a.name, ".s.init_world != nil do gs.",a.name, ".s.init_world(f,d,i)"
			)
			builder_write(&codegen_endProcess_world,"", 
				"if gs.",a.name, ".s.end_world != nil do gs.",a.name, ".s.end_world(f,d,i)"
			)		
			builder_write(&codegen_process,"", 
				"if gs.",a.name, ".s.process != nil do gs.",a.name, ".s.process(f,d,i)"
			)
			builder_write(&codegen_process_fixed,"", 
				"if gs.",a.name, ".s.process_fixed != nil do gs.",a.name, ".s.process_fixed(f,d,i)"
			)
			builder_write(&codegen_process_late,"",
				"if gs.",assignments[rev_len].name, ".s.process_late != nil do gs.",assignments[rev_len].name, ".s.process_late(f,d,i)"
			)
		}
	
		{ // ONESHOT PROCESS
			builder_write(&codegen_one_initProcess,"", 
				"if gs.",a.name, ".s.oneshot.init != nil do gs.",a.name, ".s.oneshot.init(f)"
			)
			builder_write(&codegen_one_endProcess,"", 
				"if gs.",a.name, ".s.oneshot.end != nil do gs.",a.name, ".s.oneshot.end(f)"
			)
			builder_write(&codegen_one_initProcess_world,"", 
				"if gs.",a.name, ".s.oneshot.init_world != nil do gs.",a.name, ".s.oneshot.init_world(f)"
			)
			builder_write(&codegen_one_endProcess_world,"", 
				"if gs.",a.name, ".s.oneshot.end_world != nil do gs.",a.name, ".s.oneshot.end_world(f)"
			)		
			builder_write(&codegen_one_process,"", 
				"if gs.",a.name, ".s.oneshot.process != nil do gs.",a.name, ".s.oneshot.process(f)"
			)
			builder_write(&codegen_one_process_fixed,"", 
				"if gs.",a.name, ".s.oneshot.process_fixed != nil do gs.",a.name, ".s.oneshot.process_fixed(f)"
			)
			builder_write(&codegen_one_process_late,"",
				"if gs.",assignments[rev_len].name, ".s.oneshot.process_late != nil do gs.",assignments[rev_len].name, ".s.oneshot.process_late(f)"
			)
		}

		{ // ONESHOT THREAD PROCESS
			builder_write(&codegen_oneThread_initProcess,"", 
				"if gs.",a.name, ".s.oneshotThread.init != nil do gs.",a.name, ".s.oneshotThread.init(f,d)"
			)
			builder_write(&codegen_oneThread_endProcess,"", 
				"if gs.",a.name, ".s.oneshotThread.end != nil do gs.",a.name, ".s.oneshotThread.end(f,d)"
			)
			builder_write(&codegen_oneThread_initProcess_world,"", 
				"if gs.",a.name, ".s.oneshotThread.init_world != nil do gs.",a.name, ".s.oneshotThread.init_world(f,d)"
			)
			builder_write(&codegen_oneThread_endProcess_world,"", 
				"if gs.",a.name, ".s.oneshotThread.end_world != nil do gs.",a.name, ".s.oneshotThread.end_world(f,d)"
			)
			builder_write(&codegen_oneThread_process,"", 
				"if gs.",a.name, ".s.oneshotThread.process != nil do gs.",a.name, ".s.oneshotThread.process(f,d)"
			)
			builder_write(&codegen_oneThread_process_fixed,"", 
				"if gs.",a.name, ".s.oneshotThread.process_fixed != nil do gs.",a.name, ".s.oneshotThread.process_fixed(f,d)"
			)
			builder_write(&codegen_oneThread_process_late,"",
				"if gs.",assignments[rev_len].name, ".s.oneshotThread.process_late != nil do gs.",assignments[rev_len].name, ".s.oneshotThread.process_late(f,d)"
			)
		}

		if a.data != "" {
			// CODEGEN
			builder_write(&out_systoggle, "",
				a.name, ": bool,",
			)
			builder_write(&out_sysIndex, "",
				a.name, ": phos.Handle,",
			)
			builder_write(&out_sysInit, "",
				"{phos.NULL_IDX, phos.NULL_IDX},",
			)

			// CODEGEN INLINE
			builder_write(&codegenin_struct_assign, "",
				"_",a.name," :: phos.HandleBox(oz.SystemBox(",a.data,"))",
			)
			builder_write(&codegenin_struct, "",
				a.name, ": _", a.name,",",
			)
			builder_write(&codegenin_handles, "",
				a.name, ": oz.HMIndex(oz.SystemBox(",a.data,")),",
			)
			builder_write(&codegenin_handles_enum, "",
				a.name, ",",
			)

			// builder_write(&codegenin_sysadd_morph, "", 
			// 	"	entity_system_add_",a.name,","
			// )

			builder_write(&codegenin_sysadd_procs, "",
				"entity_system_add_",a.name," :: ",
				"proc(f: ^oz.FrameData, s: ^_SYSTEMS, e: ^oz.Entity) -> (sys: ^oz.SystemBox(",a.data,")) {\n",
				"	handle := e._internal.systems_index.",a.name,"\n",

				"	if phos.is_valid(&s.",a.name,", handle) {\n",
				"		phos.remove(&s.",a.name,", handle)\n",
				"	}\n",
				
				"	handle, sys = phos.add(&s.",a.name,")\n",
				"	sys._entity = e\n",
				"	if systems.",a.name,".data_init != nil do sys._data = systems.",a.name,".data_init(f,s,e)\n",
				"	e._internal.systems_index.",a.name," = handle\n",

				"	e.systems.",a.name," = true\n",
				"	return\n",
				"}"
			)
			builder_write(&codegenin_sysadd_procs, "",
				"get_data_",a.name," :: ",
				"proc(f: ^oz.WorldFrame, e: ^oz.Entity) -> (^oz.SystemBox(",a.data,"),bool) {\n",
				"	return phos.get_data(&(cast(^_SYSTEMS)(f.systems)).",a.name,",e._internal.systems_index.",a.name,")\n",
				"}"
			)
			builder_write(&codegenin_sysrem, "", 
				"		case .",a.name,":\n",
				"			if !phos.is_valid(&s.",a.name,",e._internal.systems_index.",a.name,") {return}\n",
				"			sys,_ := phos.get_data(&s.",a.name,",e._internal.systems_index.",a.name,")\n",
				"			if systems.",a.name,".data_end != nil do systems.",a.name,".data_end(f,s,e,sys)\n",
				"			if phos.remove(&s.",a.name,", e._internal.systems_index.",a.name,") {\n",
				"				e._internal.systems_index.",a.name," = {phos.NULL_IDX, phos.NULL_IDX}\n",
				"			}",
			)
			// BUILD
			builder_write(&codegen_get_len, "",
				"v = max(v,phos.len(&d.",a.name,"))",
				// "fmt.println(phos.len(&d.",a.name,"))",
			)
			builder_write(&codegen_init, "",
				"err = phos.create(&d.",a.name,", size)",
			)
			builder_write(&codegen_del, "",
				"phos.delete(&d.",a.name,")",
			)
			// builder_write(&codegen_get_iterators, "",
			// 	a.name," = {&d.",a.name, ", 1},",
			// )
			builder_write(&codegen_iterate, "",
				"if s.",a.name,".list[i].idx != phos.NULL_IDX {\n",
				"	h.",a.name," = {\n",
				"		&s.",a.name,".list[i].data,\n",
				"		s.",a.name,".list[i].handle,\n",
				"		true\n",
				"	}\n",
				"}"
			)
			// builder_write(&codegen_iterate, "",
			// 	"if ",
			// 	a.name,"_val,",
			// 	a.name,"_h,",
			// 	a.name,"_ok",
			// 	" := hm.dynamic_iterate(&it.",a.name, "); ",
			// 	a.name,"_ok {\n",

			// 	"h.",a.name, ".val = ", a.name,"_val\n",
			// 	"h.",a.name, ".h = ",   a.name,"_h\n",
			// 	"h.",a.name, ".ok = ",  a.name,"_ok",
			// 	"\n}",
			// )
			// builder_write(&codegen_iterator_struct, "",
			// 	a.name,": hm.Dynamic_Handle_Map_Iterator(gs._",a.name,"),",
			// )
		}
	}

	// CODEGEN INLINE
	builder_finalize(&codegenInFiles,&codegenin_struct, "}\n")
	strings.write_bytes(&codegenInFiles, codegenin_struct_assign.buf[:])
	builder_finalize(&codegenInFiles,&codegenin_handles, "}\n")
	builder_finalize(&codegenInFiles,&codegenin_handles_enum, "}\n")
	// builder_finalize(&codegenInFiles,&codegenin_sysadd_morph, "}\n")
	strings.write_bytes(&codegenInFiles,codegenin_sysadd_procs.buf[:])
	builder_finalize(&codegenInFiles,&codegenin_sysrem, "	}\n}\n")

	// BUILD
	builder_finalize(&out,&out_sysIndex, "}\n")
	builder_finalize(&out,&out_systoggle, "}\n")
	builder_finalize(&out,&out_sysInit, "}\n}\n")

	//// CODEGEN ////

	// PROCESS \\
	builder_finalize(&codegen,&codegen_process, "}\n")
	builder_finalize(&codegen,&codegen_process_late, "}\n")
	builder_finalize(&codegen,&codegen_process_fixed, "}\n")
	builder_finalize(&codegen,&codegen_get_len, "return\n}\n")
	builder_finalize(&codegen,&codegen_init, "}\n")
	builder_finalize(&codegen,&codegen_del, "}\n")
	builder_finalize(&codegen,&codegen_initProcess, "}\n")
	builder_finalize(&codegen,&codegen_endProcess, "}\n")
	builder_finalize(&codegen,&codegen_initProcess_world, "}\n")
	builder_finalize(&codegen,&codegen_endProcess_world, "}\n")
	
	// PROCESS ONE \\
	builder_finalize(&codegen,&codegen_one_process, "}\n")
	builder_finalize(&codegen,&codegen_one_process_late, "}\n")
	builder_finalize(&codegen,&codegen_one_process_fixed, "}\n")
	builder_finalize(&codegen,&codegen_one_initProcess, "}\n")
	builder_finalize(&codegen,&codegen_one_endProcess, "}\n")
	builder_finalize(&codegen,&codegen_one_initProcess_world, "}\n")
	builder_finalize(&codegen,&codegen_one_endProcess_world, "}\n")

	// PROCESS THREAD ONE \\
	builder_finalize(&codegen,&codegen_oneThread_process, "}\n")
	builder_finalize(&codegen,&codegen_oneThread_process_late, "}\n")
	builder_finalize(&codegen,&codegen_oneThread_process_fixed, "}\n")
	builder_finalize(&codegen,&codegen_oneThread_initProcess, "}\n")
	builder_finalize(&codegen,&codegen_oneThread_endProcess, "}\n")
	builder_finalize(&codegen,&codegen_oneThread_initProcess_world, "}\n")
	builder_finalize(&codegen,&codegen_oneThread_endProcess_world, "}\n")
	
	// builder_finalize(&codegen,&codegen_get_iterators, "}\n}\n")
	// builder_finalize(&codegen,&codegen_iterator_struct, "}\n")
	builder_finalize(&codegen,&codegen_iterate, "return\n}\n")

	fileErr := os.write_entire_file(
		fmt.tprint("systems", "!codegen.odin", sep=os.Path_Separator_String),
		codegenInFiles.buf[:]
	)

	codegen_path,_ := os.join_path({".build", "codegen"}, context.temp_allocator)
	os.make_directory_all(codegen_path)
	fileErr = os.write_entire_file(
		fmt.tprint(codegen_path, "systems.odin", sep=os.Path_Separator_String),
		codegen.buf[:]
	)

	out_path,_ := os.join_path({".build", "ozma"}, context.temp_allocator)
	os.make_directory_all(out_path)
	fileErr = os.write_entire_file(
		fmt.tprint(out_path, "!systems.odin", sep=os.Path_Separator_String),
		out.buf[:]
	)
}

// ================================================
// BUILDER WORLDS
// ================================================
bpWorlds :: proc(data: []Build_ProcData, data_index: int, allocator: runtime.Allocator) {
	context.allocator = context.temp_allocator
	worlds_files, worldsPathErr := os.read_all_directory_by_path("worlds", allocator)
	
	worldsImport : strings.Builder

	worldsInline : strings.Builder
	strings.write_string(&worldsInline, 
		fmt.tprint(
			"package oz",
			"WorldsNames :: enum {\n",
			sep="\n"
		)
	)
	worldsNames_withGlobal : strings.Builder
	strings.write_string(&worldsNames_withGlobal, 
		fmt.tprint(
			"WorldsNames_All :: enum {\n",
			sep="\n"
		)
	)
	out : strings.Builder
	strings.write_string(&out,
		fmt.tprintln(
			"#+feature dynamic-literals",
			"package codegen",
			"import oz \"../ozma\"",
			"WorldProc :: proc(f: ^oz.FrameData)",
			// "import \"internal:build\"",
			sep="\n"
		)
	)
	procedures : strings.Builder
	strings.write_string(&procedures, 
		fmt.tprintln(
			"procedures := [oz.WorldsNames][]WorldProc {",
			sep="\n"
		)
	)

	strings.write_string(&out,"assets := oz.UniAssets{\n")
		worlds_assetsIndex: map[string][dynamic]int
		// worlds
		for w in worlds_files {
			if w.type == .Directory {
				if w.name != "_global" {
					worlds_assetsIndex[w.name] = make([dynamic]int, allocator)
				}
				strings.write_string(&worldsImport, 
					fmt.tprintln("import g",w.name," \"game:worlds/",w.name,"\"", sep="")
				)

				strings.write_string(&worldsNames_withGlobal,
					fmt.tprintln(w.name,",",sep="")
				)
			}
		}
	
		// assets
		for &asset, asset_i in data[data_index - 1].data.([]oz.Asset) {
			for w, w_i in asset.worlds {
				append(&worlds_assetsIndex[w], asset_i)
			}
	
			when ODIN_OS == .Windows {
				is_alloc: bool
				asset.path, is_alloc = strings.replace_all(asset.path, "\\", "\\\\", context.temp_allocator)					
			}
			worlds_str := fmt.tprint(asset.worlds)
			strings.write_string(&out, fmt.tprintln(
				"	{ ",
				"path = \"", asset.path, "\"",
				", worlds = {", worlds_str[1:len(worlds_str)-1], "}",
				", type = .", asset.type,
				// ", flags = ", asset.flags,
				" },", sep="")
			)
		}
	strings.write_string(&out, "}\n") // assets
	
	strings.write_string(&out, "worldsIndex := oz.WorldIndex{\n")
		for w, w_v in worlds_assetsIndex {
			wv_str := fmt.tprint(w_v,sep="")
			strings.write_string(&out,
				fmt.tprintln("	.",w," = {", wv_str[1:len(wv_str)-1],"},", sep="")
			)
			strings.write_string(&worldsInline, 
				fmt.tprint(
					w, ",\n",
					sep="",
				)
			)
			strings.write_string(&procedures,
				fmt.tprintln(".",w," = {",
					"g",w,".init,",
					"g",w,".update,",
					"g",w,".update_fixed,",
					"g",w,".update_late,",
					"g",w,".end,",
				"},",sep="")
			)
		}
	strings.write_string(&out, "}\n") // WorldsIndex

	strings.write_string(&worldsInline, "}\n")

	strings.write_string(&worldsNames_withGlobal, "}\n")
	strings.write_bytes(&worldsInline, worldsNames_withGlobal.buf[:])

	strings.write_string(&procedures, "}\n")
	// procedures_global : strings.Builder
	strings.write_string(&procedures, 
		fmt.tprintln(
			"procedures_global := []WorldProc {",
			"	g_global.init,g_global.update,g_global.update_fixed,g_global.update_late,g_global.end",
			"}",
			sep="\n"
		)
	)


	strings.write_bytes(&out, worldsImport.buf[:])
	strings.write_bytes(&out, procedures.buf[:])

	// dir, _ := os.join_path({".build","codegen"}, context.temp_allocator)
	os.make_directory_all(".build")
	file_err := os.write_entire_file(
		fmt.tprint(".build", "codegen", "worlds.odin", sep=os.Path_Separator_String), out.buf[:]
	)
	file_err  = os.write_entire_file(
		fmt.tprint(".build", "ozma", "!worlds.odin", sep=os.Path_Separator_String), worldsInline.buf[:]
	)
	return
}

// ================================================
// BUILDER ENGINE
// ================================================
bpEngine :: proc(data: []Build_ProcData, data_index: int, allocator: runtime.Allocator) {
	return
}

// ================================================
// BUILDER CONFIG
// ================================================
bpConfig :: proc(data: []Build_ProcData, data_index: int, allocator: runtime.Allocator) {
	// TODO: Error Handling 	
	config_map , _, _, _ := joy.load_from_path("game.joy")
	// print(config_map)
	file : strings.Builder
	strings.builder_init(&file)
	strings.write_string(&file, "package oz\n")

	project_map := config_map["project"]

	strings.write_string(&file, "PROJECT_NAME :: ")
	strings.write_quoted_string(&file, project_map["name"].(string))
	strings.write_string(&file, "\n")

	strings.write_string(&file, fmt.tprintln(
			"PROJECT_VERSION :: ",
			project_map["version"].(int),
			sep=""
		)
	)
	
	render_map := config_map["render"]
	strings.write_string(&file, fmt.tprintln(
			"RENDER_FRAME_IN_FLIGHT :: ",
			render_map["frame_in_flight"].(int),
			sep=""
		)
	)
	strings.write_string(&file, fmt.tprintln(
			"RENDER_FIXED_UPDATE_FREQUENCY :: ",
			render_map["fixed_update_frequency"].(int),
			sep=""
		)
	)
	// strings.write_string(&file, fmt.tprintln(
	// 		"RENDER_FIXED_UPDATE_LIMIT :: ",
	// 		render_map["fixed_update_limit"].(int),
	// 		sep=""
	// 	)
	// )
	strings.write_string(&file, fmt.tprintln(
			"RENDER_SWAPCHAIN_IMAGES :: ",
			render_map["swapchain_images"].(int),
			sep=""
		)
	)

	worlds_map := config_map["worlds"]
	strings.write_string(&file, fmt.tprintln(
			"WORLDS_TERRAIN_LIMIT :: ",
			worlds_map["terrain_limit"].(int),
			sep=""
		)
	)
	strings.write_string(&file, fmt.tprintln(
			"WORLDS_ENTITIES_LIMIT :: ",
			worlds_map["entities_limit"].(int),
			sep=""
		)
	)

	out_path, _ := os.join_path({".build", "ozma"}, context.temp_allocator)
	os.make_directory_all(out_path)
	outFileErr := os.write_entire_file(
		fmt.tprint(out_path, "!config.odin",sep=os.Path_Separator_String), 
		file.buf[:]
	)
	data[data_index].data = config_map
	return
}
