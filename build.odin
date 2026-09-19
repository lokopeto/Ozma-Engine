package main

import "core:terminal/ansi"
import "core:fmt"
import "core:os"
import "core:math"
import "core:strings"

when ODIN_OS == .Windows {
	EXE :: ".exe"
} else {
	EXE :: ""
}
S :: os.Path_Separator_String

main :: proc() {
	command := [dynamic; 10]string{
		"odin",
		"build",
		"builder",
		"-out:."+S+"Ozma_Engine"+EXE,
		"-collection:shared=."+S+"shared",
		"-show-timings",
	}

	when !#defined("FAST", false) {
		append(&command,"-o:speed")
	}

	fmt.println(command)
	odin, stdout, stderr, err := os.process_exec({
		command = command
	}, context.allocator
	)
	
	if len(stdout) > 0 {
		fmt.println(string(stdout))
	}
	if len(stderr) > 0 {
		fmt.println(string(stderr))
	}
}
