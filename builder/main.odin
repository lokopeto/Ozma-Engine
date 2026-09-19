package main

import "base:sanitizer"
import "core:mem"
import "core:io"
import "core:net"
import "core:flags"
import "core:terminal/ansi"
import "core:time"
import "core:bytes"

import "base:runtime"
import "core:fmt"
import "core:os"
import "core:math"
import "core:strings"
import slang "../shared/odin-slang/slang"
import "../src/"

@(private) print := fmt.println
build_srcFiles := #load_directory("../internal/build/export")

commands :: []Command{
	{
		name = "Build",
		usage = "<project path> [arguments]",
		description = "Compile the game for shipping or debugging, the platform is relative to the host.",
		procedure = cmdBuild
	},
	{
		name = "Run",
		usage = "<project path> [arguments]",
		description = "Compile the game and run, the platform is relative to the host.",
		procedure = cmdRun
	},
}
Command :: struct{
	procedure: proc(),
	usage: string,
	description: string,
	name: string,
}

global: struct{
	build: struct {
		output_folder: string,
		game_folder: string,
		args : struct {
			more_statistics: bool `args:"name=more-statistics" usage:"Show more statistics"`,
			debug: bool `args:"name=debug" usage:"Enable Vulkan Validation Layers and Odin debug"`,
			gpu_dump: bool `args:"name=gpu-dump" usage:"Prints everything that is happening in Vulkan behind the scenes"`,
			clean: bool `args:"name=clean" usage:"Clear files before the build"`,
			quick: bool `args:"name=quick" usage:"Skips optimizations for fast compilation"`,
			profiler: bool `args:"name=profiler" usage:"Inserts Tracy profiler at compilation level"`,
			sanitizer: enum{
				_,
				Address,
				Memory,
				Thread,
			} `args:"name=sanitizer" usage:"Enable Sanitizer for catching leaks"`,
		}
	},
	args_len: int,
	exec_path: string
}

main :: proc() {
			
	/*
	Build Arg Pipeline:
		Create .build folder (if not created)
		Analyze (or make) a report file for delta comparison
		Check and - if necessary - run proc's of a list of folders
			-- Build Odin files to one lib file relative to folders
		From past info, generate Odin Code to import ffi's from libs
		Build and output to out/ folder with <platform>-<arch>_<variation>/ convention
		
		Folder output structure:
			- worlds/..
			- shaders (.compiled or something)
			- <game_name>.(exe)
			- game.cfg
			- saves/ (optional)
			- cache (probably)
			- shared/ (for weird .dll/.so needs)

		TODO: Hot Reload Pipeline
		TODO: Viewer
	*/

	cmd_exists: bool
	global.exec_path, _ = os.get_executable_directory(context.allocator)
	global.args_len = len(os.args) - 1
	if global.args_len > 0 {
		for cmd,cmd_i in commands {
			name_cmd,_ := strings.to_lower(cmd.name, context.temp_allocator)
			name_arg,_ := strings.to_lower(os.args[1], context.temp_allocator)
			if name_cmd == name_arg {
				cmd_exists = true
				cmd.procedure()
				break
			}
		}
		if cmd_exists == false {
			print_error("Command Not Found")
			return
		}
	} else {
		pre, su := entries_style(" List of Commands ")

		print(
			ansiColor(ansi.FG_BRIGHT_CYAN),"᭥ ",ansiColor(ansi.FG_BRIGHT_GREEN),"Ozma Engine",ansiColor(ansi.FG_BRIGHT_CYAN)," ᭤",ansiColor(ansi.FAINT+";"+ansi.ITALIC)," ..Hurry is enemy of perfection. ",ansiColor(ansi.RESET),"\n",
			// "]",ansiColor(ansi.FAINT)," List of Commands ",ansiColor(ansi.RESET),"[ \n",
			pre,
			sep=""
		)

		for cmd,cmd_i in commands {
			print("⎾ ",ansiColor(ansi.FG_BRIGHT_CYAN+";"+ansi.BEL+";"+ansi.ITALIC),cmd.name," ",ansiColor(ansi.FG_BRIGHT_CYAN), cmd.usage, ansiColor(ansi.RESET), 
				"\n⎿⎽⎽⎇  ", ansiColor(ansi.FG_YELLOW+";"+ansi.ITALIC), cmd.description, ansiColor(ansi.RESET), sep="")
		}
		// print("\n]",ansiColor(ansi.FAINT),"==================",ansiColor(ansi.RESET),"[", sep="")
		print("\n",su, sep="")
	}
}

/*
|=======|
| BUILD |
|=======|
*/
cmdBuild :: proc() {
	if global.args_len > 1 && os.exists(os.args[2]) {  
	} else { 
		print_error("No Path Provided/Invalid Path")
		return
	}
	
	argsOk := get_args(&global.build.args, os.args[3:], "Build")
	if !argsOk {
		return
	} 

	start_time := time.now()
	time_check := time.now()

	// verify if project path exists
	game := os.args[2]
	game_abs,_ := os.get_absolute_path(game, context.allocator)
	global.build.game_folder = game_abs
	if os.exists(os.args[2]) == false {
		print_error("Project Path Does not Exist.")
		os.exit(-1)
	}

	// verify if .build exists
	os.chdir(game)
	os.make_directory(".build")
	
	//verify if "report" file exists
	infoFile: ^os.File
	{
		err: os.Error
		if os.exists(".build/report") {
			infoFile, err = os.open(".build/report", {.Read})
			info_raw, infoErr := os.read_entire_file(infoFile, context.allocator)
			infoStr := string(info_raw)
			info := strings.split_lines(infoStr)
			index: int
			for &pd, i in build_ProcList {
				name := i + 1 <= len(build_ProcList) - 1 ? strings.trim_space(build_ProcList[i + 1].name) : ""
				if info[index] == pd.name {
					// print("pd.name", pd.name)
					reportIn := make([dynamic]string)
					for v,k in info[index + 1:] {
						if name == strings.trim_space(v) {
							break
						}
						if index >= len(info) - 1 {
							break
						}
						append(&reportIn, v)
						index += 1
					}
					pd.reportIn = reportIn[:]
					index += 1
				}
			}
		}

		infoFile, err = os.create(".build/report")
	}
	folder_name := fmt.tprint(ODIN_OS_STRING, ODIN_ARCH_STRING, sep="-")
	if global.build.args.debug {
		folder_name = fmt.tprint(folder_name, "debug", sep="-")
	}
	out_folder, _ := os.join_path({game_abs, "out", folder_name}, context.allocator)
	global.build.output_folder = out_folder
	os.make_directory_all(out_folder)

	print(ansiColor(ansi.FG_BRIGHT_CYAN),"	[ Preparation Time -> ",time.diff(time_check, time.now())," ]",sep="")
	time_check = time.now()
	// run the build first pass
	arena : mem.Dynamic_Arena
	mem.dynamic_arena_init(&arena, context.temp_allocator, context.temp_allocator)
	arena_alloc := mem.dynamic_arena_allocator(&arena)
	for pd, i in build_ProcList {
		if pd.pre != nil {
			print(
				ansiColor(ansi.FG_BRIGHT_BLACK),
					"{",pd.name, "Stage }",
				ansiColor(ansi.RESET)
			)
			time_check = time.now()
			pd.pre(build_ProcList,i, arena_alloc)
			mem.dynamic_arena_free_all(&arena)
			print(
				ansiColor(ansi.FG_BRIGHT_BLACK),
					"-->",pd.name,"Time:",
					ansiColor(ansi.FG_BLUE),
						time.diff(time_check, time.now()),
					ansiColor(ansi.FG_BRIGHT_BLACK),
					"<--",
				ansiColor(ansi.RESET)
			)
		}
	}
	
	for f in build_srcFiles {
		out, err := os.create(fmt.tprint(".build/", f.name, sep = ""))
		if err != os.General_Error.None {
			fmt.println(err, #location(out))
		}
		_, err = os.write(out, f.data)
		if err != os.General_Error.None {
			fmt.println(err, #location(out))
		}
	}

	out_path : string
	//output folder
	when ODIN_OS == .Windows {
		out_path = join_path(out_folder, "game.exe")
	} else {
		out_path = join_path(out_folder, "game")
	}
	out_path = fmt.tprint("-out:",
		out_path,
		sep=""
	)

	sep :: os.Path_Separator_String
	cmd: [dynamic]string
	append(&cmd,
		"odin", "build", //odin command
		//the .build/ of the game project
		join_path(game_abs, ".build"),
		out_path,

		"-show-timings",

		//collections 
		"-collection:internal=."+sep+"internal",
		"-collection:shared=."+sep+"shared",

		fmt.tprint("-collection:game=", game_abs, sep=""),
		fmt.tprint("-collection:gamebuild=", 
			join_path(game_abs, ".build"),
		sep=""),
		fmt.tprint("-collection:KT=",
			join_path(game_abs, ".build", "KT"),
		sep=""),
		fmt.tprint("-collection:codegen=",
			join_path(game_abs, ".build", "codegen"),
		sep=""),
	)

	
	if global.build.args.more_statistics {
		append(&cmd, 
			"-show-import-graph",
			"-show-system-calls"
		)
	}
	if global.build.args.debug {
		append(&cmd, 
			"-debug",
		)
	}
	if !global.build.args.quick {
		append(&cmd, 
			"-o:aggressive",
		)
	}
	if global.build.args.profiler {
		append(&cmd, 
			"-define:TRACY_ENABLE=true",
			"-define:TRACY_CALLSTACK=20",
		)
	}
	if int(global.build.args.sanitizer) != 0 {
			type := [?]string{
				"address",
				"memory",
				"thread",
			}

			append(&cmd, 
				fmt.tprint("-sanitizer:",type[int(global.build.args.sanitizer) - 1], sep=""),
			)
	}

	cmd_join := strings.join(cmd[:], " ")

	print(
		ansiColor(ansi.FG_BRIGHT_CYAN),
			"	====> Starting Build <====",
		ansiColor(ansi.RESET),
	)
	print(ansiColor(ansi.FG_BRIGHT_CYAN),">>> Command ->",ansiColor(ansi.FG_YELLOW), cmd_join, ansiColor(ansi.RESET))
	odin_process, odin_outRaw, odin_errRaw, err := os.process_exec(
		{
			command = cmd[:],
			working_dir = global.exec_path
		}, context.allocator
	)
	odin_err := strings.clone_from_bytes(odin_errRaw)
	odin_out := strings.clone_from_bytes(odin_outRaw)
	if err == os.General_Error.None && odin_process.success {
		fmt.println(ansiColor(ansi.FG_BRIGHT_MAGENTA),odin_out,"\n", odin_err,ansiColor(ansi.RESET), sep="")
		print(
			ansiColor(ansi.FG_BRIGHT_MAGENTA),
				"	<<< User Time:",odin_process.user_time, "| System Time:", odin_process.system_time,">>>\n",
			ansiColor(ansi.RESET),
			)
	} else {
		fmt.println(ansiColor(ansi.FG_RED),odin_out,"\n", odin_err,ansiColor(ansi.RESET), sep="")
		os.exit(-1)
	}

	// run the build second pass
	time_check = time.now()
	for pd, i in build_ProcList {
		if pd.pos != nil {
			print(
				ansiColor(ansi.FG_BRIGHT_BLACK),
					"{",pd.name, "Pos-Stage }",
				ansiColor(ansi.RESET)
			)
			pd.pos(build_ProcList,i, arena_alloc)
			mem.dynamic_arena_free_all(&arena)
			print(
				ansiColor(ansi.FG_BRIGHT_BLACK),
					"-->",pd.name,"Time:",
					ansiColor(ansi.FG_BLUE),
						time.diff(time_check, time.now()),
					ansiColor(ansi.FG_BRIGHT_BLACK),
					"<--",
				ansiColor(ansi.RESET)
			)
		}
		os.write_strings(infoFile, pd.name, "\n")
		for str in pd.reportOut {
			os.write_string(infoFile, str)
		}
	}
	mem.dynamic_arena_destroy(&arena)
	print( 
		"\n", ansiColor(ansi.FG_BRIGHT_GREEN),
			"	[ Build Complete! - Time Total:", time.diff(start_time, time.now()), "]",
		ansiColor(ansi.RESET),
	)
}

join_path :: proc(paths: ..string) -> string {
	str, _ := os.join_path(paths, context.temp_allocator)
	return str
}
adjust_path :: proc(paths: ..string) -> string {
	str, _ := os.join_path(paths, context.temp_allocator)
	return str
}


cmdRun :: proc() {
	cmdBuild()
	free_all(context.temp_allocator)

	cmd : string
	when ODIN_OS == .Windows {
		cmd = fmt.tprint(global.build.output_folder, "game.exe", sep=os.Path_Separator_String)		
	} else {
		cmd = fmt.tprint(global.build.output_folder, "game", sep=os.Path_Separator_String)
	}

	process, _ := os.process_start({
		command = {cmd},
		working_dir = global.build.output_folder,
		stderr = os.stderr,
		stdin =  os.stdin,
		stdout = os.stdout,
	})

	state, _ := os.process_wait(process)
}




state_save :: proc {
	state_save_string,
	state_save_bytes
}

state_save_string :: proc(folder: string, data: string, allocator := context.allocator) -> os.Error {
	dir, _ := os.join_path({".build",folder}, allocator)
	path, _ := os.join_path({dir, "build_state.odin"}, allocator)
	
	os.make_directory_all(dir)
	return os.write_entire_file(path, data)
}
state_save_bytes :: proc(folder: string, data: []byte, allocator := context.allocator) -> os.Error {
	dir, _ := os.join_path({".build",folder}, allocator)
	path, _ := os.join_path({dir, "build_state.odin"}, allocator)
	
	os.make_directory_all(dir)
	return os.write_entire_file(path, data)
}


ansiColor :: proc(color: string) -> string {
	return fmt.tprint(ansi.CSI, color, ansi.SGR, sep="")
}

print_error :: proc(str: ..any) {
	print(ansiColor(ansi.FG_RED),"[ERROR] ",fmt.tprint(..str, sep=""),ansiColor(ansi.RESET),sep="")
}

// print_usage
get_args :: proc(
	model: ^$T,
	args: []string,
	name: string
	) -> (ok: bool) {
	argsErr := flags.parse(model, args)

	if argsErr != nil {
		switch errType in argsErr {
			case flags.Parse_Error:
				switch err in errType.reason {
					case flags.Parse_Error_Reason:
						print_error(argsErr.(flags.Parse_Error).message)
					case runtime.Allocator_Error:
					case net.Parse_Endpoint_Error:
				}
			case flags.Open_File_Error:
			case flags.Help_Request:
				pre, su := entries_style(" ",name,": Help ")
				print(pre)

				buff: bytes.Buffer
				bytes.buffer_init(&buff, {})
				stream := bytes.buffer_to_stream(&buff)

				flags.write_usage(stream, type_of(model^))

				entries_raw := bytes.trim_prefix(buff.buf[:],{'F','l','a','g','s',':', 10, 9})
				entries_raw, _ = bytes.remove_all(entries_raw, {9})
				entries := bytes.split(entries_raw, {10})
				
				entries_len := len(entries)
				for en, en_i in entries[:entries_len-1] {
					usage := bytes.split(en, {' ',' ','|',' '})
					print(
						"⎇  ",
						string(usage[0]), " ⇆ ",
						ansiColor(ansi.FG_BRIGHT_CYAN), string(usage[1]),ansiColor(ansi.RESET), 
						sep=""
					)
				}


				print("\n",su, sep="")
			case flags.Validation_Error:
		}
		return
	} else {
		ok = true
		return
	}
}

entries_style :: proc(s: ..string) -> (res: string, suffix: string) {
	middle := strings.join(s, "")
	defer delete(middle)

	res = fmt.tprintln("]",ansiColor(ansi.FAINT),middle,ansiColor(ansi.RESET),"[", sep="")
	suffix = fmt.tprint("]",ansiColor(ansi.FAINT),string(bytes.repeat({'='},len(res) - 11)),ansiColor(ansi.RESET),"[",sep="")
	return 
}
