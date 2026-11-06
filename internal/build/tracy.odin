package main

import tracy "shared:tracy"
import "core:c"
TRACY_ENABLE :: #config(TRACY_ENABLE, false)

when TRACY_ENABLE {
SourceLocationData :: tracy.SourceLocationData
ZoneCtx            :: tracy.ZoneCtx
LockCtx            :: tracy.LockCtx
SharedLockCtx      :: tracy.SharedLockCtx

// Zone markup

// NOTE: These automatically calls ZoneEnd() at end of scope.
Zone   :: tracy.Zone
ZoneN  :: tracy.ZoneN
ZoneC  :: tracy.ZoneC
ZoneNC :: tracy.ZoneNC

ZoneText  :: tracy.ZoneText
ZoneName  :: tracy.ZoneName
ZoneColor :: tracy.ZoneColor
ZoneValue :: tracy.ZoneValue

// NOTE: scoped Zone*() procs also exists, no need of calling this directly.
ZoneBegin :: tracy.ZoneBegin
// NOTE: scoped Zone*() procs also exists, no need of calling this directly.
ZoneEnd :: tracy.ZoneEnd

// Memory profiling
// (See allocator.odin for an implementation of an Odin custom allocator using memory profiling.)
Alloc        :: tracy.Alloc
Free         :: tracy.Free
MemoryDiscard:: tracy.MemoryDiscard
AllocN       :: tracy.AllocN
FreeN        :: tracy.FreeN

// Frame markup
FrameMark      :: tracy.FrameMark
FrameMarkStart :: tracy.FrameMarkStart
FrameMarkEnd   :: tracy.FrameMarkEnd
FrameImage     :: tracy.FrameImage

// Plots
Plot       :: tracy.Plot
PlotF      :: tracy.PlotF
PlotI      :: tracy.PlotI
PlotConfig :: tracy.PlotConfig
AppInfo    :: tracy.AppInfo

// Messages
MessageS   :: tracy.MessageS
MessageCS  :: tracy.MessageCS

SetThreadName :: tracy.SetThreadName

// Connection status
IsConnected :: tracy.IsConnected

// Fibers
when tracy.TRACY_FIBERS {
	FiberEnter :: tracy.FiberEnter
	FiberLeave :: tracy.FiberLeave
}
} else {
SourceLocationData :: struct{}
ZoneCtx            :: struct{}
LockCtx            :: struct{}
SharedLockCtx      :: struct{}

// Zone markup

// NOTE: These automatically calls ZoneEnd() at end of scope.
Zone   :: #force_inline proc(active := true, depth: i32 = tracy.TRACY_CALLSTACK, loc := #caller_location) -> (ctx: ZoneCtx)                           {return{}}
ZoneN  :: #force_inline proc(name: string, active := true, depth: i32 = tracy.TRACY_CALLSTACK, loc := #caller_location) -> (ctx: ZoneCtx)             {return{}}
ZoneC  :: #force_inline proc(color: u32, active := true, depth: i32 = tracy.TRACY_CALLSTACK, loc := #caller_location) -> (ctx: ZoneCtx)               {return{}}
ZoneNC :: #force_inline proc(name: string, color: u32, active := true, depth: i32 = tracy.TRACY_CALLSTACK, loc := #caller_location) -> (ctx: ZoneCtx) {return{}}

ZoneText  :: #force_inline proc(ctx: ZoneCtx, text: string) {}
ZoneName  :: #force_inline proc(ctx: ZoneCtx, name: string) {}
ZoneColor :: #force_inline proc(ctx: ZoneCtx, color: u32)   {}
ZoneValue :: #force_inline proc(ctx: ZoneCtx, value: u64)   {}

// NOTE: scoped Zone*() procs also exists, no need of calling this directly.
ZoneBegin :: proc(active: bool, depth: i32, name: string = "", color: u32 = 0, loc := #caller_location) -> (ctx: ZoneCtx) { return {} }

// NOTE: scoped Zone*() procs also exists, no need of calling this directly.
ZoneEnd :: #force_inline proc(ctx: ZoneCtx) {}

// Memory profiling
// (See allocator.odin for an implementation of an Odin custom allocator using memory profiling.)
Alloc        :: #force_inline proc(ptr: rawptr, size: c.size_t, depth: i32 = tracy.TRACY_CALLSTACK)                {}
Free         :: #force_inline proc(ptr: rawptr, depth: i32 = tracy.TRACY_CALLSTACK)                                {}
MemoryDiscard:: #force_inline proc(name: cstring)                                                                  {}
AllocN       :: #force_inline proc(ptr: rawptr, size: c.size_t, name: cstring, depth: i32 = tracy.TRACY_CALLSTACK) {}
FreeN        :: #force_inline proc(ptr: rawptr, name: cstring, depth: i32 = tracy.TRACY_CALLSTACK)                 {}

// Frame markup
FrameMark      :: #force_inline proc(name: cstring = nil)                             {}
FrameMarkStart :: #force_inline proc(name: cstring)                                   {}
FrameMarkEnd   :: #force_inline proc(name: cstring)                                   {}
FrameImage     :: #force_inline proc(image: rawptr, w, h: u16, offset: u8, flip: b32) {}

// Plots
Plot       :: #force_inline proc(name: cstring, value: f64) {}
PlotF      :: #force_inline proc(name: cstring, value: f32) {}
PlotI      :: #force_inline proc(name: cstring, value: i64) {}
PlotConfig :: #force_inline proc(name: cstring, type:  tracy.TracyPlotFormatEnum, step, fill: b32, color: u32) {}
AppInfo    :: #force_inline proc(name: string)              {}

// Messages
MessageS   :: #force_inline proc( txt: string, depth: i32 = tracy.TRACY_CALLSTACK )                 {}
MessageCS  :: #force_inline proc( txt: string, color: u32 = 0, depth: i32 = tracy.TRACY_CALLSTACK ) {}

SetThreadName :: #force_inline proc(name: cstring) {}

// Connection status
IsConnected :: #force_inline proc() -> bool { return false }

// Fibers
when tracy.TRACY_FIBERS {
	FiberEnter :: #force_inline proc(name: cstring) {}
	FiberLeave :: #force_inline proc()              {}
}
}
