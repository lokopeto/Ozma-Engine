package koto

import "core:slice"
import "core:container/queue"
import "core:c"
import "core:math/bits"
import "core:reflect"
import "core:fmt"
import "core:image"
import "core:mem"
import "core:os"
import "core:math"
import "core:strings"
import "core:time"

import "base:runtime"

import "vendor:glfw"
import vk "vendor:vulkan"

import "shared:vma"

@(private) print := fmt.println

// ================ INDIVIDUAL STRUCTS ================
RenderFrame :: struct {
	using state:       RenderState,
	using cmd:         Command,
	using shaderBox: 	 ShaderBox,
	swapchain:         Swapchain,
	window:            []Window,
	format_info:       FormatInfo,
	info:    				   PhysicalDeviceInfo,
	dt:                DeltaTime64,
	dt32:              DeltaTime32,
	dt16:              DeltaTime16,
	userPointer:       any,
}

DeltaTime :: struct(T: typeid) {
	fixed : T,
	fixed_overtime : T,
	value : T,
	overtime : T,
}

DeltaTime64 :: DeltaTime(f64)
DeltaTime32 :: DeltaTime(f32)
DeltaTime16 :: DeltaTime(f16)
Window :: struct {
	resolution: [2]u32,
	resized: bool,
	handle: glfw.WindowHandle
}

Buffer :: struct {
	allocation: vma.Allocation,
	allocator: 	vma.Allocator,
  buffer:     vk.Buffer,
  info:       vma.Allocation_Info,
}
Image :: struct {
	image: 		  vk.Image,
	view:    		vk.ImageView,
	format:  		vk.Format,
	allocation: vma.Allocation
}

Vulkan :: struct {
	vma: 			 vma.Allocator,
	instance:  vk.Instance,
	device:    vk.Device,
	queue: 		 vk.Queue,
	immCmd: 	 Command,
}
PhysicalDeviceInfo :: struct {
	features:     		vk.PhysicalDeviceFeatures,
	memory:       		struct{
		using memory : vk.PhysicalDeviceMemoryProperties,
		budget : vk.PhysicalDeviceMemoryBudgetPropertiesEXT,
	},
	properties:   		struct{
		using _ : vk.PhysicalDeviceProperties,
		maxPushDescriptors: u32,
	},
	descriptorBuffer: vk.PhysicalDeviceDescriptorBufferPropertiesEXT,
}
//Basically a struct of pointers
Command :: struct {
	fence: vk.Fence,
	semaphore: vk.Semaphore,
	buffer: vk.CommandBuffer,
	pool: vk.CommandPool
}

// ================ GLOBAL GRAPHICS CONTEXT ================
GraphicContext :: struct {
	vulkan: Vulkan,
	physical: vk.PhysicalDevice,
	info: PhysicalDeviceInfo,
	formats: FormatInfo,
	surface: vk.SurfaceKHR,
	swapchain: Swapchain,	
}

// ================ API SPECIFIC ================
create_renderer :: proc(windowHandle: glfw.WindowHandle) -> (g: GraphicContext) {
	g.vulkan, g.physical, g.info = vulkan_init()
	g.surface = glfwCreate_surface(&g.vulkan, g.physical, windowHandle)

	g.formats = vkGet_Formats(g.physical, g.surface)
	w,h := glfw.GetWindowSize(windowHandle)
	g.swapchain = vkSwapchain_Create(&g.vulkan, g.surface,
		{ 
			{u32(w), u32(h)},
			g.formats.capabilities.currentTransform,
			g.formats.capabilities.minImageCount,
		}
	)
	return 
}

WINPOSITION_IDENTITY :: [2]int{ bits.INT_MAX, bits.INT_MAX }

WindowInfo :: struct {
	resizable: bool,
	focused: bool,
	maximized: bool,
	floating: bool,
	decorated: bool,
	auto_iconify: bool,
	center_cursor: bool,
	transparent_framebuffer: bool,
	focus_on_show: bool,
	scale_to_monitor: bool,
	scale_framebuffer: bool,
	mouse_passthrough: bool,
	position: [2]int,
}
WINDOW_DEFAULT :: WindowInfo {
	resizable = true,
	focused = true,
	maximized = true,
	floating = true,
	decorated = true,
	auto_iconify = false,
	center_cursor = false,
	transparent_framebuffer = false,
	focus_on_show = false,
	scale_to_monitor = false,
	scale_framebuffer = false,
	mouse_passthrough = false,
	position = WINPOSITION_IDENTITY
}

@(require_results)
create_window :: proc(
	width: u32, height: u32, 
	info: WindowInfo = WINDOW_DEFAULT,
	name := "Ozma Engine"
	) -> (handle: glfw.WindowHandle) {
	@(static) is_init := false
	if is_init == false {
		assert(cast(bool)glfw.Init() != false, "Glfw Failed")
		is_init = true
	}

	glfw.WindowHint(glfw.RESIZABLE, b32(info.resizable))
	glfw.WindowHint(glfw.FOCUSED, b32(info.focused))
	glfw.WindowHint(glfw.MAXIMIZED, b32(info.maximized))
	glfw.WindowHint(glfw.FLOATING, b32(info.floating))
	glfw.WindowHint(glfw.DECORATED, b32(info.decorated))
	glfw.WindowHint(glfw.AUTO_ICONIFY, b32(info.auto_iconify))
	glfw.WindowHint(glfw.CENTER_CURSOR, b32(info.center_cursor))
	glfw.WindowHint(glfw.TRANSPARENT_FRAMEBUFFER, b32(info.transparent_framebuffer))
	glfw.WindowHint(glfw.FOCUS_ON_SHOW, b32(info.focus_on_show))
	glfw.WindowHint(glfw.SCALE_TO_MONITOR, b32(info.scale_to_monitor))
	glfw.WindowHint(glfw.SCALE_FRAMEBUFFER, b32(info.scale_framebuffer))
	glfw.WindowHint(glfw.MOUSE_PASSTHROUGH, b32(info.mouse_passthrough))
	glfw.WindowHint(glfw.POSITION_X, c.int(info.position.x))
	glfw.WindowHint(glfw.POSITION_Y, c.int(info.position.y))



	glfw.WindowHint(glfw.CLIENT_API, glfw.NO_API)

	name_c := strings.clone_to_cstring(name)
	handle = glfw.CreateWindow(i32(width), i32(height), name_c, nil, nil)

	if handle == nil {
		print("Unable to start Window")
		return
	}

	// glfw.SetWindowUserPointer(handle, &g)
	glfw.SetFramebufferSizeCallback(handle, glfwResize_callback);
	glfw.SetKeyCallback(handle, glfwInput_callback)

	glfw.SetMouseButtonCallback(handle, glfwMouseButton_callback)
	glfw.SetCursorPosCallback(handle, glfwMousePos_callback)
	glfw.SetScrollCallback(handle, glfwMouseScroll_callback)
	glfw.SetCursorEnterCallback(handle, glfwMouseEnter_callback)
	//glfw.SetCharCallback
	//glfw.SetCharModsCallback
	//glfw.SetJoystickCallback
	return
}
destroy_window :: proc(handle: glfw.WindowHandle) {
	glfw.DestroyWindow(handle)
	glfw.Terminate()
}

@(private) winResize_callback: [dynamic]Window
windowShouldClose :: proc(vulkan: ^Vulkan, physical: vk.PhysicalDevice, frame: ^RenderFrame) -> b32 {
	@(static) swapchainOld_Queue: [dynamic]vk.SwapchainKHR
  resized := false

	frame.info.memory.budget.pNext = nil
  prop := &vk.PhysicalDeviceMemoryProperties2 {
		sType = .PHYSICAL_DEVICE_MEMORY_PROPERTIES_2,
		pNext = &frame.info.memory.budget
	}

	vk.GetPhysicalDeviceMemoryProperties2(physical, prop)

	glfw.PollEvents()
	vk.DeviceWaitIdle(vulkan.device)

	
	for &winf, winf_i in frame.window {
		winf.resized = false
		for win, win_i in winResize_callback {
			if win.handle == winf.handle {
				if win.resized == true {
					w,h := glfw.GetWindowSize(win.handle)
					winf.resolution = { u32(w), u32(h) }
					winf.resized = true
					resized = true
				}
			}
		}
	}	
	if resized {
		if len(swapchainOld_Queue) > 0 {
			for sc, sc_i in swapchainOld_Queue {
				vk.DestroySwapchainKHR(vulkan.device,sc,nil)
			}
			clear_dynamic_array(&swapchainOld_Queue)
		}
		append(&swapchainOld_Queue, frame.swapchain.handle)
		capabilities : vk.SurfaceCapabilitiesKHR
		vk.GetPhysicalDeviceSurfaceCapabilitiesKHR(
			physical,
			frame.swapchain.surface,
			&capabilities
		)
		
		frame.swapchain = vkSwapchain_Create(
			vulkan, 
			frame.swapchain.surface, 
			{
				minImageCount = capabilities.minImageCount,
				resolution = frame.window[0].resolution,
				preTransform = capabilities.currentTransform
			}, frame.swapchain.handle
		)
	}

	clear_dynamic_array(&winResize_callback)


	@(static) mouse_scroll_reset: bool
	if mouse_scroll_reset == true {
		mouse.scroll.x = 0
		mouse.scroll.y = 0
		
		mouse_scroll_reset = false
	}
	if mouse.scroll.x != 0 || mouse.scroll.y != 0 {
		mouse_scroll_reset = true
	}


	for name in input_callbackList_old {
		input := &inputs[name]
		if input.value > 0 && input.status == .PRESSED {
			input.status = .HOLDING
		}
	}
	input_callbackList_old = make([]string, len(input_callbackList))
	copy(input_callbackList_old, input_callbackList[:])
	clear(&input_callbackList)

	@(static) mouse_click_past: [MouseButtons]InputStatus
	for &mb, mb_i in mouse.buttons {
		if mb == .PRESSED && mouse_click_past[mb_i] == .PRESSED {
			mb = .HOLDING
		}
	}
	mouse_click_past = mouse.buttons

	return glfw.WindowShouldClose(frame.window[0].handle)
}

keyMap: #sparse[Keys]string

cursor_visibility :: proc(win: Window,v: enum{NORMAL,HIDDEN,LOCKED}) {
	switch v {
		case .NORMAL:
			glfw.SetInputMode(win.handle, glfw.CURSOR, glfw.CURSOR_NORMAL)
		case .HIDDEN:
			glfw.SetInputMode(win.handle, glfw.CURSOR, glfw.CURSOR_HIDDEN)
		case .LOCKED:
			glfw.SetInputMode(win.handle, glfw.CURSOR, glfw.CURSOR_DISABLED)
	}
}
cursor_position_set :: proc(win: Window,x,y: f64) {
	mouse.pos.xy = 0
	glfw.SetCursorPos(win.handle,x,y)
}


// ================ API SPECIFIC ================

// ================ VULKAN ================
vulkan_init :: proc() -> (
	vulkan: Vulkan, 
	physical: vk.PhysicalDevice, 
	info: PhysicalDeviceInfo
) {
	// -- Vulkan Instance
	vk.load_proc_addresses(rawptr(glfw.GetInstanceProcAddress))

	layers: [dynamic]cstring

	if #config(GPU_DUMP, false) {
		append(&layers, "VK_LAYER_LUNARG_api_dump")
	}
	when ODIN_DEBUG {
		append(&layers, "VK_LAYER_KHRONOS_validation")
	}
	vulkan.instance, _ = vkInstanceInit(layers[:])

	// -- Vulkan Device
	physical, _ = vkGetDevice_Podium(&vulkan)
	
	info = vkGet_Info(physical)
	//Vulkan Queue
	vulkan.queue, _ = vkDeviceQueueInit(
		&vulkan,
		physical,
		EXTENSIONS
	)
	// VMA Initialization
	vma_vulkan_functions := vma.create_vulkan_functions()

	vmaalloc := vma.Allocator_Create_Info {
		vulkan_api_version = 1003000, // e.g. 1 == 100, 3000 == .3 -> 1.3
		flags = {.Buffer_Device_Address, .Khr_Bind_Memory2},
		device = vulkan.device,
		instance = vulkan.instance,
		physical_device = physical,
		vulkan_functions = &vma_vulkan_functions
	}
	vma.create_allocator(vmaalloc, &vulkan.vma)

	// Vulkan Immediate Commands
	vulkan.immCmd = vkImmCMD_Create(vulkan.device)
	return
// vulkan_init will run all of the func bellow
}
vkInstanceInit :: proc(
	layers: []cstring = {},
	user_extensions: []cstring = {},
) ->  (instance: vk.Instance, err: vk.Result) {
	application_info := vk.ApplicationInfo {
		apiVersion = vk.API_VERSION_1_3, //vulkan version
		pEngineName = "Ozma Engine",
		engineVersion = 0,
		pApplicationName = strings.clone_to_cstring(PROJECT_NAME, context.temp_allocator),
		applicationVersion = PROJECT_VERSION,
		sType = .APPLICATION_INFO,
	}
	defer free(&application_info.pApplicationName)

	glfw_ext := glfw.GetRequiredInstanceExtensions()
	extensions: [dynamic]cstring

	append(&extensions, ..glfw_ext)
	append(&extensions, ..user_extensions)

	create_info := vk.InstanceCreateInfo {
		pApplicationInfo = &application_info,

		ppEnabledLayerNames = raw_data(layers[:]),
		enabledLayerCount = u32(len(layers[:])),

		ppEnabledExtensionNames = raw_data(extensions[:]),
		enabledExtensionCount = u32(len(extensions)),
		
		sType = .INSTANCE_CREATE_INFO
	}

	if err = vk.CreateInstance(
		/* info - alloc - instance */
		&create_info, nil, &instance
	); err == .SUCCESS {
		vk.load_proc_addresses(instance)
		print(
			"Vulkan Instance Created with",
			extensions[:],
			"extensions and",
			layers[:],
			"layers.",
		)
	} else {
		print(
			"Failed to create Vulkan Instance with",
			extensions[:],
			"extensions and",
			layers[:],
			"layers.",
		)
	}
	return 
}
vkGetDevice_Podium :: proc(vulkan: ^Vulkan) -> (handle: vk.PhysicalDevice, err: vk.Result) {
	// get the amount of devices
	device_count: u32
	if err = vk.EnumeratePhysicalDevices(vulkan.instance, &device_count, nil); err != .SUCCESS {
		print("No Vulkan Compatible GPU")
		return
	}

	// get all devices handles and select
	physical_devices := make([]vk.PhysicalDevice, device_count) //list of devices
	if err = vk.EnumeratePhysicalDevices(
		vulkan.instance,
		&device_count,
		raw_data(physical_devices),
	); err == .SUCCESS {

		sum :: proc(T: typeid, s: ^$I) -> (res: u32) {
			for v in reflect.struct_fields_zipped(T) {
				if (cast(^bool)(uintptr(s) + v.offset))^ == true {
					res += 1
				}
			}
			return  
		}

		Entry :: struct{
			index: u32,
			score: u32
		}
		podium: Entry

		properties_pNext : rawptr
		vk11 := vk.PhysicalDeviceVulkan11Properties {
			pNext = properties_pNext,
			sType = .PHYSICAL_DEVICE_VULKAN_1_1_PROPERTIES,
		}
		properties_pNext = &vk11


		features := vk.PhysicalDeviceFeatures2 {
			sType = .PHYSICAL_DEVICE_FEATURES_2
		}
		memory := vk.PhysicalDeviceMemoryProperties2 {
			sType = .PHYSICAL_DEVICE_MEMORY_PROPERTIES_2
		}
		properties := vk.PhysicalDeviceProperties2 {
			pNext = properties_pNext,
			sType = .PHYSICAL_DEVICE_PROPERTIES_2
		}
		for phy,phy_i in physical_devices {
			score : u32
			
			vk.GetPhysicalDeviceFeatures2(phy, &features)
			vk.GetPhysicalDeviceMemoryProperties2(phy, &memory)
			vk.GetPhysicalDeviceProperties2(phy, &properties)
			
			// print(entry.features)
			// score += sum(vk.PhysicalDeviceFeatures, &features.features)

			if properties.properties.deviceType != .CPU {
				for m, m_i in memory.memoryProperties.memoryHeaps {
					score += u32(m.size / 10000000)
				}
				score += memory.memoryProperties.memoryHeapCount * 1000
				score += properties.properties.limits.maxMemoryAllocationCount / 100000000
			}
			if properties.properties.deviceType == .DISCRETE_GPU {
				score += 1000000000
			}
			if properties.properties.deviceID == 0  {
				score = score / 10000000
			}
			score += u32(card(vk11.subgroupSupportedStages))
			
			score += .MESH_EXT in vk11.subgroupSupportedStages ? 10000 : 0
			score += .RAYGEN_KHR in vk11.subgroupSupportedStages ? 100000 : 0
			score += vk11.subgroupSize * 20

			print(string(properties.properties.deviceName[:]), properties.properties.deviceType, "=", score)
			if score > podium.score {
				podium = {
					index = u32(phy_i),
					score = score
				}
			}
		}

		handle = physical_devices[podium.index]
		print(device_count, "physical device's found!")
	} else {
		print("no physical device found! buy a GPU!!", err)
	}
	return
}
vkDeviceQueueInit :: proc(vulkan: ^Vulkan, physical: vk.PhysicalDevice, extensions: []cstring) -> ( queue: vk.Queue ,err: vk.Result) {

	features := vkGet_Features()

	priority: f32 = 1.0
	queue_create_info := vk.DeviceQueueCreateInfo {
		pQueuePriorities = &priority,
		queueFamilyIndex = 0,
		queueCount       = 1,
		sType            = .DEVICE_QUEUE_CREATE_INFO,
	}

	create_info := vk.DeviceCreateInfo {
		queueCreateInfoCount    = 1,
		pQueueCreateInfos       = &queue_create_info,
		enabledExtensionCount   = u32(len(extensions)),
		ppEnabledExtensionNames = raw_data(extensions),
		sType                   = .DEVICE_CREATE_INFO,
		pNext                   = features,
	}

	if err := vk.CreateDevice(physical, &create_info, nil, &vulkan.device);
	   err == .SUCCESS {
		vk.GetDeviceQueue(vulkan.device, 0, 0, &queue)
		print("Device created! with extensions:", extensions)
	} else {
		print("Device failed to create:", err)
	}
	return
} // Use that for loading Extensions


//Create Immediate CMD Buffers
vkImmCMD_Create :: proc(device: vk.Device) -> (cmd: Command) {
	pool_info := vk.CommandPoolCreateInfo {
		queueFamilyIndex = 0,
		flags = {.TRANSIENT, .RESET_COMMAND_BUFFER},
		sType = .COMMAND_POOL_CREATE_INFO,
	}
	vk.CreateCommandPool(device,&pool_info,nil,&cmd.pool)

	buff_info := vk.CommandBufferAllocateInfo {
		commandBufferCount = 1,
		commandPool = cmd.pool,
		level = .PRIMARY,
		sType = .COMMAND_BUFFER_ALLOCATE_INFO,
	}
	vk.AllocateCommandBuffers(device, &buff_info, &cmd.buffer)

	semaphore_info := semaphore_info()
	vk.CreateSemaphore(device, &semaphore_info, nil, &cmd.semaphore)
	fence_info := fence_info(true)
	vk.CreateFence(device, &fence_info, nil, &cmd.fence)
	return
}
vkImmCMD_Destroy :: proc(device: vk.Device, cmd: ^Command) {
	vk.DestroyCommandPool(device, cmd.pool, nil)
	vk.DestroyFence(device, cmd.fence, nil)
	vk.DestroySemaphore(device, cmd.semaphore, nil)
	free(cmd)
}

// end of vulkan_init functions

//saves info for later use
vkGet_Info :: proc(physical: vk.PhysicalDevice) -> (info: PhysicalDeviceInfo) {
	features := new(vk.PhysicalDeviceFeatures2)
	features.sType = .PHYSICAL_DEVICE_FEATURES_2
	vk.GetPhysicalDeviceFeatures2(physical, features)

	pushDesc_next := new(vk.PhysicalDevicePushDescriptorPropertiesKHR)
	pushDesc_next.sType = .PHYSICAL_DEVICE_PUSH_DESCRIPTOR_PROPERTIES

	descBuff_next := new(vk.PhysicalDeviceDescriptorBufferPropertiesEXT)
	descBuff_next.sType = .PHYSICAL_DEVICE_DESCRIPTOR_BUFFER_PROPERTIES_EXT
	descBuff_next.pNext = pushDesc_next


	prop := new(vk.PhysicalDeviceProperties2)
	prop.sType = .PHYSICAL_DEVICE_PROPERTIES_2
	prop.pNext = descBuff_next
	vk.GetPhysicalDeviceProperties2(physical, prop)

	memBudget_next := new(vk.PhysicalDeviceMemoryBudgetPropertiesEXT)
	memBudget_next.sType = .PHYSICAL_DEVICE_MEMORY_BUDGET_PROPERTIES_EXT

	memprop := new(vk.PhysicalDeviceMemoryProperties2)
	memprop.sType = .PHYSICAL_DEVICE_MEMORY_PROPERTIES_2
	memprop.pNext = memBudget_next
	vk.GetPhysicalDeviceMemoryProperties2(physical, memprop)

	info = {
		features = features.features,
		properties = {
			prop.properties,
			pushDesc_next.maxPushDescriptors,
		},
		descriptorBuffer = descBuff_next^,
		memory = {memprop.memoryProperties, memBudget_next^},
	}
	// free(descBuff_next)
	// free(memBudget_next)

	print(
		"\n",
		string(info.properties.deviceName[:]),
		"\n  apiVersion:",
		fmt.tprintf(
			"%v.%v%v",
			vk.API_VERSION_MAJOR(prop.properties.apiVersion), 
			vk.API_VERSION_MINOR(prop.properties.apiVersion), 
			vk.API_VERSION_PATCH(prop.properties.apiVersion)
		),
		"\n  driverVersion:",
		info.properties.driverVersion,
		"\n  vendorID:",
		info.properties.vendorID,
		"\n  deviceID:",
		info.properties.deviceID,
		"\n  deviceType:",
		info.properties.deviceType,
		"\n  pipelineCacheUUID:",
		string(info.properties.pipelineCacheUUID[:]),
		"\n",
	)

	print("Memory Heap:", info.memory.memoryHeapCount, "Heaps and", info.memory.memoryTypeCount, "Types")
	
	for i: u32 = 0; i < max(info.memory.memoryHeapCount, info.memory.memoryTypeCount); i += 1 {
		heap_str: string
		type_str: string

		if info.memory.memoryHeaps[i].size > 0 {
			heap_str = fmt.aprint("	Heap Size: ",info.memory.memoryHeaps[i].size,"\n	Flags:",info.memory.memoryHeaps[i].flags)
		}
		if info.memory.memoryTypes[i].propertyFlags != {} {
			type_str = fmt.aprint("\n	Type: ",info.memory.memoryTypes[i].propertyFlags, "\n	Index:", info.memory.memoryTypes[i].heapIndex)
		}
		fmt.printfln("Heap %i = %s%s",i,heap_str,type_str)
	}
	return
}
FormatInfo :: struct {
	capabilities: vk.SurfaceCapabilitiesKHR,
	formats: []vk.SurfaceFormatKHR,
	formats_map: map[vk.Format]^vk.SurfaceFormatKHR,
}
vkGet_Formats :: proc(
	physical: vk.PhysicalDevice, 
	surface: vk.SurfaceKHR
) -> (info: FormatInfo) {
	format_count: u32
	vk.GetPhysicalDeviceSurfaceFormatsKHR(
		physical,
		surface,
		&format_count,
		nil,
	)
	info.formats = make([]vk.SurfaceFormatKHR, format_count)
	vk.GetPhysicalDeviceSurfaceFormatsKHR(
		physical,
		surface,
		&format_count,
		raw_data(info.formats),
	)

	vk.GetPhysicalDeviceSurfaceCapabilitiesKHR(
		physical,
		surface,
		&info.capabilities,
	)

	for &i in info.formats {
		info.formats_map[i.format] = &i
	}
	return
}

Swapchain :: struct {
	handle: vk.SwapchainKHR,
	
	// using render : struct{

	// }
	extent:       vk.Extent2D,
	imageCount:   u32,
	allocation:   vma.Allocation,
	images:       []vk.Image,
	views:        []vk.ImageView,
	images_depth: []vk.Image,
	views_depth:  []vk.ImageView,
	semaphores:   []vk.Semaphore,
	surface: 			vk.SurfaceKHR
}
SwapchainInfo :: struct {
	resolution : [2]u32,
	preTransform : vk.SurfaceTransformFlagsKHR,
	minImageCount : u32,
	// format : FormatInfo
}

vkSwapchain_Create :: proc(
	vulkan: ^Vulkan, 
	surface: vk.SurfaceKHR, 
	info: SwapchainInfo,
	oldSwapchain: vk.SwapchainKHR = 0,
) -> (swapchain: Swapchain) {

	// print((g.vk.physical.formats))
	
	// viewFormats := []vk.Format{ .R8G8B8A8_SRGB, .D24_UNORM_S8_UINT }
	// next := &vk.ImageFormatListCreateInfoKHR{
	// 	pViewFormats = raw_data(viewFormats),
	// 	viewFormatCount = u32(len(viewFormats)),
	// 	sType = .IMAGE_FORMAT_LIST_CREATE_INFO
	// }

	//format = "B8G8R8A8_SRGB", colorSpace = "SRGB_NONLINEAR"
	resolution := [2]u32{max(1,info.resolution.x), max(1,info.resolution.y)}

	swap_info := vk.SwapchainCreateInfoKHR {
		minImageCount    = max(RENDER_SWAPCHAIN_IMAGES, info.minImageCount),
		surface          = surface,
		imageColorSpace  = .SRGB_NONLINEAR,
		imageFormat      = .B8G8R8A8_SRGB,
		imageUsage       = {.COLOR_ATTACHMENT},
		imageExtent      = {
			resolution.x,
			resolution.y,
		},
		// pNext 					 = next,

		imageArrayLayers = 1,
		imageSharingMode = .EXCLUSIVE,
		preTransform     = info.preTransform,
		compositeAlpha   = {.OPAQUE},
		presentMode      = .IMMEDIATE,
		clipped          = true,
		oldSwapchain 		 = oldSwapchain,
		sType            = .SWAPCHAIN_CREATE_INFO_KHR,
	}


	if err := vk.CreateSwapchainKHR(
		vulkan.device,
		&swap_info,
		nil,
		&swapchain.handle,
	); err == .SUCCESS {
		swapchain.extent = {
			resolution.x,
			resolution.y
		}
	} else {
		print("SwapChain Error:", err)
	}

	if err := vk.GetSwapchainImagesKHR(
		vulkan.device,
		swapchain.handle,
		&swapchain.imageCount,
		nil,
	); err == .SUCCESS {
		// for i, k in g.vk.swapchain.images {
		// 	vk.DestroyImageView(vulkan.device, g.vk.swapchain.views[k], nil)
		// 	vk.DestroySemaphore(vulkan.device, g.vk.swapchain.semaphores[k], nil)
		// }
		// delete(g.vk.swapchain.images[:])
		
		swapchain.images =       make([]vk.Image, swapchain.imageCount)
		swapchain.views =        make([]vk.ImageView, swapchain.imageCount)
		swapchain.images_depth = make([]vk.Image, swapchain.imageCount)
		swapchain.views_depth =  make([]vk.ImageView, swapchain.imageCount)
		vk.GetSwapchainImagesKHR(
			vulkan.device,
			swapchain.handle,
			&swapchain.imageCount,
			raw_data(swapchain.images),
		)
		//print(swapchain.imageCount, "images in SwapChain")
	} else {
		print("Error geting Swapchain Images:", err)
	}

	// Create Depth Buffer
	// for i in g.vk.render.images {
	// 	vma.destroy_image(
	// 		g.vk.vma,
	// 		i.image,
	// 		i.allocation,
	// 	)
	// 	vk.DestroyImageView(vulkan.device, i.view, nil)
	// 	delete(g.vk.render.images[:])
	// }
	// g.vk.render.images = make([]Image, 1)

	// my minimum is 4.. :>
	imageDepth_info := vk.ImageCreateInfo {
		extent = {info.resolution.x, info.resolution.y, 1},	
		format = .D32_SFLOAT,
		imageType = .D2,
		initialLayout = .UNDEFINED,
		samples = {._1},
		sharingMode = .EXCLUSIVE,
		usage = {.DEPTH_STENCIL_ATTACHMENT},
		mipLevels = 1,
		arrayLayers = 1,
		sType = .IMAGE_CREATE_INFO,
	}
	allocDepth_info := vma.Allocation_Create_Info {
		usage = .Gpu_Only
	}
	for i in 0..<swapchain.imageCount {
		// Depth 
		vma.create_image(
			vulkan.vma,
			imageDepth_info,
			allocDepth_info,
			&swapchain.images_depth[i],
			&swapchain.allocation,
			nil
		)
		viewDepth_info := vk.ImageViewCreateInfo {
			format = .D32_SFLOAT,
			viewType = .D2,
			image = swapchain.images_depth[i],
			components = {.IDENTITY,.IDENTITY,.IDENTITY,.IDENTITY},
			subresourceRange = {
				layerCount = 1,
				levelCount = 1,
				aspectMask = {.DEPTH}
			},
			sType = .IMAGE_VIEW_CREATE_INFO
		}
		// vk.DestroyImageView(vulkan.device,swapchain.views_depth[i], nil)
	
		vk.CreateImageView(vulkan.device, &viewDepth_info, nil, &swapchain.views_depth[i])
	
		vkRecord_command(vulkan, &vulkan.immCmd)
		imgBarrier_Prepare(
			vulkan.immCmd.buffer,
			swapchain.images_depth[i],
			viewDepth_info.subresourceRange, 
			.UNDEFINED, 
			.DEPTH_STENCIL_ATTACHMENT_OPTIMAL
		)
		vkRun_command(vulkan, &vulkan.immCmd)
	
		// Screen
		view_info := vk.ImageViewCreateInfo {	
			image = swapchain.images[i],
			flags = {},
			format = .B8G8R8A8_SRGB,
	
			viewType = .D2,
			components = {.IDENTITY, .IDENTITY, .IDENTITY, .IDENTITY}, //rgba
			subresourceRange = {
				aspectMask     = {.COLOR},
				layerCount     = 1,
				levelCount     = 1,
				baseMipLevel   = 0,
				baseArrayLayer = 0,
			},
			sType = .IMAGE_VIEW_CREATE_INFO
		}
		if err := vk.CreateImageView(vulkan.device, &view_info, nil, &swapchain.views[i]);
		   err == .SUCCESS {
			//fmt.print("View", i, "- ")
		} else {
			print("Error in View", i, "- ")
		}
	}

	// prepare for sync issues
	swapchain.semaphores = make([]vk.Semaphore, swapchain.imageCount)
	sm_info := semaphore_info()
	for &s in swapchain.semaphores {
		vk.CreateSemaphore(vulkan.device, &sm_info, nil, &s)
	}
	swapchain.surface = surface
	return
}
vkSwapchain_Destroy :: proc(
	vulkan: ^Vulkan, 
	swapchain: Swapchain
) -> () {
	vk.DestroySwapchainKHR(vulkan.device, swapchain.handle, nil)
	for i in 0..<swapchain.imageCount {
		vk.DestroyImage(vulkan.device,swapchain.images[i],nil)
		vma.destroy_image(vulkan.vma,swapchain.images_depth[i],swapchain.allocation)

		vk.DestroyImageView(vulkan.device,swapchain.views[i],nil)
		vk.DestroyImageView(vulkan.device,swapchain.views_depth[i],nil)
		vk.DestroySemaphore(vulkan.device,swapchain.semaphores[i],nil)
	}
	return
}

// draw is separated in 2 func for prepass and inline cmd Buffer
vkRenderCommand_Create :: proc(vulkan: ^Vulkan, flight_frames := RENDER_FRAME_IN_FLIGHT) -> (frames: []Command) {
	// Semaphore == wait for the GPU
	// Fences		 == wait for the CPU
	// Timeline Semaphore == GOAT

	//create FLIGHT_FRAMES
	frames = make([]Command, flight_frames)
	cmd_info := vk.CommandPoolCreateInfo{
		queueFamilyIndex = 0,
		flags = {.TRANSIENT},
		sType = .COMMAND_POOL_CREATE_INFO,
	}
	for &f, f_i in frames {
		vk.CreateCommandPool(vulkan.device, &cmd_info, nil, &f.pool)

		//TODO: Allocate more command buffer!
		cmdBuff_info := vk.CommandBufferAllocateInfo{
			commandBufferCount = 1,
			level = .PRIMARY,
			commandPool = f.pool,
			sType = .COMMAND_BUFFER_ALLOCATE_INFO,
		}

		vk.AllocateCommandBuffers(vulkan.device, &cmdBuff_info, &f.buffer)

		semaphore_info := semaphore_info()
		vk.CreateSemaphore(vulkan.device, &semaphore_info, nil, &f.semaphore)
		fence_info := fence_info(true)
		vk.CreateFence(vulkan.device, &fence_info, nil, &f.fence)

		print("Creating frames in Flight:", f_i)
	}
	return
}

vkDraw_prepare :: proc(vulkan: ^Vulkan, frame: ^RenderFrame) -> (imgIndex: u32) {
	//===============================
	//print("WaitForFences")
	vk.WaitForFences(vulkan.device, 1, &frame.fence, true, max(u64))
	//print("WaitForFences", "OK")
	// waits for the fences to sync the gpu with cpu
	vk.AcquireNextImage2KHR(
		vulkan.device,
		&vk.AcquireNextImageInfoKHR {
			deviceMask = 1,
			timeout = max(u64),
			swapchain = frame.swapchain.handle,
			semaphore = frame.semaphore,
			sType = .ACQUIRE_NEXT_IMAGE_INFO_KHR
		}, &imgIndex
	)
	//print("AcquireNextImage2KHR", "OK", "-", g.vk.swapchain.imageIndices)

	// gets the finished frame
	//print("ResetFences")
	vk.ResetFences(vulkan.device, 1, &frame.fence)
	//print("ResetFences", "OK")

	//THE ULTRA MASTER BLASTER COMMAND BUFFERSSS!!!!!!!
	vk.ResetCommandPool(vulkan.device, frame.cmd.pool, {})

	vk.BeginCommandBuffer(frame.cmd.buffer, &vk.CommandBufferBeginInfo {
		flags = {.ONE_TIME_SUBMIT},
		sType = .COMMAND_BUFFER_BEGIN_INFO
	})

	return imgIndex
}
vkDraw_present :: proc(vulkan: ^Vulkan, frame: ^RenderFrame, imgIndex: ^u32) {
	vk.EndCommandBuffer(frame.cmd.buffer)

	present_info := vk.PresentInfoKHR {
		sType              = .PRESENT_INFO_KHR,
		waitSemaphoreCount = 1,
		pWaitSemaphores    = &frame.swapchain.semaphores[imgIndex^],
		swapchainCount     = 1,
		pSwapchains        = &frame.swapchain.handle,
		pImageIndices      = imgIndex,
	}

	queueSubmit := vk.SubmitInfo{
		sType = .SUBMIT_INFO,
		pWaitDstStageMask = &vk.PipelineStageFlags{.ALL_COMMANDS},
		pSignalSemaphores = &frame.swapchain.semaphores[imgIndex^],
		pWaitSemaphores = &frame.semaphore,
		waitSemaphoreCount = 1,
		signalSemaphoreCount = 1,

		pCommandBuffers = &frame.cmd.buffer,
		commandBufferCount = 1,
	}
	//print("QueueSubmit")
	vk.QueueSubmit(vulkan.queue, 1, &queueSubmit, frame.cmd.fence)
	//print("QueueSubmit", "OK")
	//print("QueuePresent")
	vk.QueuePresentKHR(vulkan.queue, &present_info)
	//print("QueuePresent", "OK")
	// submit the frame and displays it
}

vkRecord_command :: proc(vulkan: ^Vulkan, cmd: ^Command) {
	vk.ResetFences(vulkan.device, 1, &cmd.fence)
	vk.ResetCommandBuffer(cmd.buffer, {})
	
	begin_info := vk.CommandBufferBeginInfo{
		flags = {.ONE_TIME_SUBMIT},
		sType = .COMMAND_BUFFER_BEGIN_INFO
	}
	vk.BeginCommandBuffer(cmd.buffer, &begin_info)
	return
}
vkRun_command :: proc(vulkan: ^Vulkan, cmd: ^Command) {
	vk.EndCommandBuffer(cmd.buffer)
	
	submit_info := vk.SubmitInfo {
		commandBufferCount = 1,
		pCommandBuffers = &cmd.buffer,
		sType = .SUBMIT_INFO
	}
	vk.QueueSubmit(vulkan.queue, 1, &submit_info, cmd.fence)
	
	vk.WaitForFences(vulkan.device, 1, &cmd.fence, true, max(u64))
}


ShadersInChain :: struct{
	vertex: ShaderGPU,
	fragment: ShaderGPU,
	shaders: map[string]ShaderGPU,
}

ShaderBox :: struct {
	shaders: map[string]ShadersInChain,
	descriptor_layout: vk.DescriptorSetLayout,
	pipeline: vk.PipelineLayout
}
ShaderGPU :: struct {
	ptr: vk.ShaderEXT, 
	stage: vk.ShaderStageFlags,
}
Create_Push_Constant :: struct {
	stageFlags: vk.ShaderStageFlags,
	size:       enum{Max_32, Max_64, Max_128, Max_256},
}
Create_Descriptors :: struct {
	stageFlags : vk.ShaderStageFlags,
	descriptorType : vk.DescriptorType,
	limit : u32,
}

Shader_Code :: struct{
	data: []byte,
	os_error: os.Error,
	from: enum{PATH, DATA, FILE},
	file: ^os.File,
	path: string,
}

Shader_Main :: struct {
	code: Shader_Code,
	flags: vk.ShaderCreateFlagsEXT,
	codeType: vk.ShaderCodeTypeEXT,
	specialization: vk.SpecializationInfo,
	pushConstant: []Create_Push_Constant,
}

Shader_Chain :: struct {
	code:           Shader_Code,
	flags:          vk.ShaderCreateFlagsEXT,
	stage:          vk.ShaderStageFlags,
	nextStage:      vk.ShaderStageFlags,
	codeType:       vk.ShaderCodeTypeEXT,
	specialization: vk.SpecializationInfo,
	pushConstant:	  []Create_Push_Constant,
	pNext:          rawptr // Because.. why not? O_O
}

Create_Shader_info :: struct{
	name: string,
	vertex:		Shader_Main,
	fragment:	Shader_Main,

	shaders: []Shader_Chain
}
// 
Create_Shader_config :: struct{
	// global type on shaders inside the chain 
	codeType : enum{ Custom, Binary, Spirv },
	
	// global constants on shaders inside the chain
	constant: struct {
		behavior: enum{
			Substitute, // the name says everything
			Fill_Empty // if the const is empty, he will fill with the default
		},
		data: []Create_Push_Constant, // only works if length > 0
	},
	descriptor_push: Create_Push_Constant,
	descriptors: []Create_Descriptors,
}

// "Code from path/file" will skip the path if failed and insert a error in that struc
VkCreateShaderError :: enum{NONE, FILE, SHADER}
@(require_results)
vkCreate_shaders :: proc(
	device: vk.Device, 
	info: ^[]Create_Shader_info, 
	config: Create_Shader_config,
	allocator := context.allocator
	) -> (
		shaderBox: ShaderBox, 
		err: VkCreateShaderError
	) 
{
	context.allocator = allocator
	@(static) is_link_frag_created: bool
	@(static) is_link_vert_created: bool
	
	convert_pushConst_individual :: proc(
		push: Create_Push_Constant,
	) -> (out: vk.PushConstantRange) {
		out.stageFlags = push.stageFlags
		switch push.size {
			case .Max_32:
				out.size = 32
			case .Max_64:
				out.size = 64
			case .Max_128:
				out.size = 128
			case .Max_256:
				out.size = 256
		}
		return
	}
	convert_pushConst_list :: proc(
		push: []Create_Push_Constant, 
		allocator := context.allocator
	) -> (out: []vk.PushConstantRange) {
		out = make([]vk.PushConstantRange, len(push), allocator)
		for &o, i in out {
			o = convert_pushConst_individual(push[i])
		}
		return
	}
	load_code :: proc(code: ^Shader_Code, allocator := context.allocator ) -> bool {
		switch code.from {
			case .PATH:
				when !ODIN_DEBUG {
					if os.base(code.path)[0] == '_' {
						return false
					}
				}
				code.data, 
				code.os_error = os.read_entire_file_from_path(code.path, allocator)
				return true
			case .FILE:
				code.data, 
				code.os_error = 
				os.read_entire_file_from_file(code.file, allocator)
				return true
			case .DATA:
				return true
		}
		return false
	}
	set_globals :: proc(info: ^vk.ShaderCreateInfoEXT, config: Create_Shader_config, push: []Create_Push_Constant) {
		defaultConst_len := u32(len(config.constant.data))
		if defaultConst_len > 0 {
			switch config.constant.behavior {
				case .Substitute:
					info.pPushConstantRanges = raw_data(convert_pushConst_list(config.constant.data))
					info.pushConstantRangeCount = defaultConst_len
				case .Fill_Empty:
					if len(push) == 0 {
						info.pPushConstantRanges = raw_data(convert_pushConst_list(config.constant.data))
						info.pushConstantRangeCount = defaultConst_len
					}
			}
		} else {
			pushConst := convert_pushConst_list(push)
			info.pPushConstantRanges = raw_data(pushConst)
			info.pushConstantRangeCount = u32(len(pushConst))
		}

		if config.codeType != .Custom {
			info.codeType = vk.ShaderCodeTypeEXT(u8(config.codeType) - 1)
		}
	}

	const := convert_pushConst_individual(config.descriptor_push)
	bindCount : u32 = u32(len(config.descriptors))
	descBind := make([]vk.DescriptorSetLayoutBinding, bindCount)
	for cfg, cfg_i in config.descriptors {
		//TODO: Make imm sampler creation
		descBind[cfg_i] = {
			stageFlags = cfg.stageFlags,
			binding = u32(cfg_i),
			descriptorCount = cfg.limit,
			descriptorType = cfg.descriptorType,
			// pImmutableSamplers -> Expose that to the developer or make another one?
		}
	}

	setLayout_flags := vk.DescriptorSetLayoutBindingFlagsCreateInfo {
		bindingCount = bindCount,
		pBindingFlags	= &vk.DescriptorBindingFlags{.PARTIALLY_BOUND},
		sType = .DESCRIPTOR_SET_LAYOUT_BINDING_FLAGS_CREATE_INFO
	}
	descSetLayout_info := vk.DescriptorSetLayoutCreateInfo {
		bindingCount = bindCount,
		pBindings = raw_data(descBind),
		pNext = &setLayout_flags,
		flags = {.DESCRIPTOR_BUFFER_EXT},
		
		sType = .DESCRIPTOR_SET_LAYOUT_CREATE_INFO,
	}
	vk.CreateDescriptorSetLayout(device, &descSetLayout_info, nil, &shaderBox.descriptor_layout)

	layout_info := vk.PipelineLayoutCreateInfo {
		sType = .PIPELINE_LAYOUT_CREATE_INFO,
		pushConstantRangeCount = 1,
		pPushConstantRanges = &const,
		setLayoutCount = 1,
		pSetLayouts = &shaderBox.descriptor_layout
	}
	vk.CreatePipelineLayout(device, &layout_info, nil, &shaderBox.pipeline)
	
	for &input, ip_i in info {
		when ODIN_DEBUG {
			assert(input.name != "", "Name cannot be empty")
		}
		defaultConst_len := u32(len(config.constant.data))

		main_compile : bool
		shaders_main := make([]vk.ShaderEXT, 2)
		shaders_main_info := make([]vk.ShaderCreateInfoEXT, 2)
		for i in 0..=1 {
			type_switcher := i == 0
			s := type_switcher ? &input.vertex : &input.fragment
			info : struct{
				stage: vk.ShaderStageFlags,
				nextStage: vk.ShaderStageFlags
			} = type_switcher ? {
				stage = {.VERTEX},
				nextStage = {.FRAGMENT}
			} : {
				stage = {.FRAGMENT}
			}
			if !load_code(&s.code) { continue }

			if s.code.os_error != os.General_Error.None {
				err = .FILE; continue
			}


			shaders_main_info[i] = {
				flags =                  s.flags + {.LINK_STAGE},
				stage =                  info.stage,
				nextStage =              info.nextStage,
				codeType =               s.codeType,
				pSpecializationInfo =    &s.specialization,
	
				//TEMPORARY
				pSetLayouts =            &shaderBox.descriptor_layout,
				setLayoutCount = 				 1,
	
				// pPushConstantRanges = 	 raw_data(s.pushConstant),
				// pushConstantRangeCount = u32(len(s.pushConstant)),
	
				pCode = 								 raw_data(s.code.data),
				codeSize = 							 len(s.code.data),
				pName = 								 "main",
	
				sType = .SHADER_CREATE_INFO_EXT,
			}

			set_globals(&shaders_main_info[i], config, s.pushConstant)
			// print(i,shaders_main_info[i], "\n")
			main_compile = true
		}
		if main_compile {	
			shaders_err := vk.CreateShadersEXT(device, 2, raw_data(shaders_main_info), nil, raw_data(shaders_main))
			assert(shaders_err == .SUCCESS, fmt.tprint("Error Compiling Main Shaders:", shaders_err))
			shader_mainBox := map_insert(&shaderBox.shaders, input.name, 
				ShadersInChain {
					vertex = {shaders_main[0], {.VERTEX}},
					fragment = {shaders_main[1], {.FRAGMENT}},
				}
			)

			len_info := u32(len(input.shaders[:]))
			shaders : []vk.ShaderEXT
			shader_compile : bool
			if len_info > 0 {		
				shaders_len : u32
				for &s, i in input.shaders {
					// when ODIN_DEBUG {
					// 	assert(input.name != "", "Name cannot be empty")
					// }
					if !load_code(&s.code) { continue }

					if s.code.os_error != os.General_Error.None {
						err = .FILE; continue
					}
					shader_compile = true
					// print(i,shaders_info[i], "\n")
				}
				if shader_compile {
					shaders := make([]vk.ShaderEXT, shaders_len)
					shaders_info := make([]vk.ShaderCreateInfoEXT, shaders_len)
					index : u32
					for &s, _ in input.shaders {
						if len(s.code.data) == 0 { continue }
						defer index += 1

						shaders_info[index] = {
							flags =                  s.flags - {.LINK_STAGE},
							stage =                  s.stage,
							nextStage =              s.nextStage,
							codeType =               s.codeType,
							pSpecializationInfo =    &s.specialization,
				
							//TEMPORARY
							pSetLayouts =            &shaderBox.descriptor_layout,
							setLayoutCount = 				 1,
				
							// pPushConstantRanges = 	 raw_data(s.pushConstant),
							// pushConstantRangeCount = u32(len(s.pushConstant)),
				
							pCode = 								 raw_data(s.code.data),
							codeSize = 							 len(s.code.data),
							pName = 								 "main",
				
							sType = .SHADER_CREATE_INFO_EXT,
						}
						
						set_globals(&shaders_info[index], config, s.pushConstant)
					}

					shaders_err := vk.CreateShadersEXT(device, len_info, raw_data(shaders_info), nil, raw_data(shaders))
					assert(shaders_err == .SUCCESS, fmt.tprint("Error Compiling Shaders:", shaders_err))
	
					for inf, inf_i in input.shaders {
						print(inf_i)
						if inf_i <= 1 { continue }
						field := os.stem(
							strings.trim_prefix(
								inf.code.path,
								fmt.tprint("shaders" + os.Path_Separator_String),
							)
						)
			
						shader_mainBox.shaders[field] = {
							ptr = shaders[inf_i],
							stage = inf.stage
						}
					}
				}
			}
		}
	}

	return
}

//Load and bind shader from relative path
cmdload_shaders :: proc {
	cmdload_shaders_main,
	cmdload_shaders_entry,
}
cmdload_shaders_entry :: proc(cmd: vk.CommandBuffer, shaders: ShaderBox, main_entry, entry: string) {
	shader := shaders.shaders[main_entry].shaders[entry]
	when ODIN_DEBUG {
    assert(shader.ptr != 0, "Shader does not exist!")
  }
	vk.CmdBindShadersEXT(cmd, 1, &shader.stage, &shader.ptr)
}
ShaderMainEntry :: enum{Vertex, Fragment}
cmdload_shaders_main :: proc(cmd: vk.CommandBuffer, shaders: ShaderBox, main_entry: string, stage: ShaderMainEntry) {
	shader : ShaderGPU
	switch stage {
		case .Vertex: 
			shader = shaders.shaders[main_entry].vertex
		case .Fragment: 
			shader = shaders.shaders[main_entry].fragment
	}
	when ODIN_DEBUG {
    assert(shader.ptr != 0, "Shader does not exist!")
  }
	vk.CmdBindShadersEXT(cmd, 1, &shader.stage, &shader.ptr)
}




@(require_results)
vkCreate_buffer :: proc(
	vulkan: ^Vulkan,
	size: vk.DeviceSize, 
	buffer_usage: vk.BufferUsageFlags,
	alloc_info: vma.Memory_Usage,
) -> (buff: Buffer, err: vk.Result) {
	buff.allocator = vulkan.vma

	buff_info := vk.BufferCreateInfo {
		sType = .BUFFER_CREATE_INFO,
		usage = buffer_usage,
		size = size,
	}
	alloc_info := vma.Allocation_Create_Info {
		usage = alloc_info,
		flags = {.Mapped}
	}

	if err := vma.create_buffer(buff.allocator,buff_info, alloc_info, &buff.buffer, &buff.allocation, &buff.info); err != .SUCCESS {
		return buff, err
	}
	return
}

TexGPU :: struct{
	image: vk.Image,
	view: vk.ImageView,
	sampler: vk.Sampler,
	mips: []vk.ImageView, 
	allocation: vma.Allocation
}
ModelGPU :: struct {
	using model: Model,
	
	tex_raw: []TexGPU,
	offsets: struct{
		vertex: vk.DeviceAddress,
		texture: i32
	},
}
ModelBox :: struct{
	models: []ModelGPU,

	vextex_buffer: Buffer,
	texture_buffer: Buffer,

	vextex_address: vk.DeviceAddress,
	texture_address: vk.DeviceAddress,
}


TextureDefaultConfig := struct{
	image: vk.DescriptorImageInfo,
	view: vk.ImageViewCreateInfo,
	sampler: vk.SamplerCreateInfo,
}{
	
}

TexFilter :: enum c.int {
	NEAREST   = 0,
	LINEAR    = 1,
}
TexSamplerAddressMode :: enum c.int {
	REPEAT                   = 0,
	MIRRORED_REPEAT          = 1,
	CLAMP_TO_EDGE            = 2,
	CLAMP_TO_BORDER          = 3,
	MIRROR_CLAMP_TO_EDGE     = 4,
}
Sampler :: struct{
	magFilter:               TexFilter,
	minFilter:               TexFilter,
	mipmapMode:              TexFilter,
	addressModeU:            TexSamplerAddressMode,
	addressModeV:            TexSamplerAddressMode,
	addressModeW:            TexSamplerAddressMode,
	mipLodBias:              f32,
	maxAnisotropy:           uint,
	compareOp:               vk.CompareOp,
	minLod:                  f32,
	maxLod:                  f32,
	borderColor:             vk.BorderColor,
	unnormalizedCoordinates: bool,
}

UploadMeshListInfo :: struct {
	// get from PhysicalDeviceInfo.descriptorBuffer.combinedImageSamplerDescriptorSize
	textureStride: u64,
	// get from PhysicalDeviceInfo.descriptorBuffer.descriptorBufferOffsetAlignment
	descriptor_offset: vk.DeviceSize,
	// get from PhysicalDeviceInfo.descriptorBuffer.combinedImageSamplerDescriptorSingleArray
	is_singleArray: bool,
	descriptor_layout: vk.DescriptorSetLayout,

	sampler : Sampler
}
@(require_results)
vkUpload_meshList :: proc(
	vulkan: ^Vulkan,
	path: []string,
	info: UploadMeshListInfo,
	allocator := context.allocator,
) -> (box: ModelBox) {
	if len(path) <= 0 {return}
	vkRecord_command(vulkan, &vulkan.immCmd)
	box.models = make([]ModelGPU, len(path), allocator)
	models := box.models[:]
	vexSize_sum: int
	texSize_sum: int
	print(path)

	for p,i in path {
		// models[i].model = modelfile_parse(p, allocator)
		models[i].model = load_hxa(p, allocator)
		vexSize_temp, texSize_temp: int
		vexSize_temp += len(models[i].vertex) * size_of(models[i].vertex[0])

		for tex, tex_i in models[i].textures {
			texSize_temp += len(tex.data) * size_of(tex.data[0])

			// models
			texSize_sum += texSize_temp
		}
		vexSize_sum += vexSize_temp

		if len(models[i].vertex) > 0 {
			models[i].offsets.vertex = vk.DeviceAddress(vexSize_sum - vexSize_temp)
		}
	}

	// Vextex Buffer Preparation
	buffsrc, _ := vkCreate_buffer(
		vulkan,
		vk.DeviceSize(vexSize_sum),
		{.TRANSFER_SRC},
		.Cpu_To_Gpu
	)
	box.vextex_buffer, _ = vkCreate_buffer(
		vulkan,
		vk.DeviceSize(vexSize_sum),
		{.TRANSFER_DST, .SHADER_DEVICE_ADDRESS, .STORAGE_BUFFER},
		.Gpu_Only
	)
	buff_slice := mem.byte_slice(buffsrc.info.mapped_data, vexSize_sum)
	//

	//Texture Buffer Preparation
	// The byte distance between bytes
	stride := info.textureStride
	// The offset from the start of the buffer
	bindingOffset: vk.DeviceSize 
	vk.GetDescriptorSetLayoutBindingOffsetEXT(
		vulkan.device,
		info.descriptor_layout,
		0,
		&bindingOffset
	)

	// Get the aligned size of the descriptor buffer
	descBuffer_size: vk.DeviceSize
	vk.GetDescriptorSetLayoutSizeEXT(
		vulkan.device, 
		info.descriptor_layout,
		&descBuffer_size
	)
	descBuffer_size = getAlignedSize(descBuffer_size, info.descriptor_offset)

	box.texture_buffer, _ = vkCreate_buffer(
		vulkan,
		descBuffer_size,
		{
			.SHADER_DEVICE_ADDRESS, 
			.SAMPLER_DESCRIPTOR_BUFFER_EXT, 
			.RESOURCE_DESCRIPTOR_BUFFER_EXT
		},
		.Cpu_To_Gpu
	)
	//
	
	tex_count: u64
	for &m, i in models {
		// VERTEX
		mem.copy(raw_data(buff_slice[m.offsets.vertex:]), raw_data(m.vertex), len(m.vertex) * size_of(m.vertex[0]))
		
		// TEXTURE
		tex_len := u32(len(m.textures))
		m.tex_raw = make([]TexGPU, tex_len)
		m.offsets.texture = i32(tex_count)

		for &tex, tex_i in m.tex_raw {
			// Create Image
			image_info := vk.ImageCreateInfo {
				extent = m.model.textures[tex_i].size,
				format = .R8G8B8A8_SRGB,
				imageType = m.model.textures[tex_i].data[0].type,
				arrayLayers = 1,
				
				initialLayout = .UNDEFINED,
				sharingMode = .EXCLUSIVE,
				tiling = .OPTIMAL,
				usage = {.SAMPLED, .TRANSFER_DST},
				samples = {._1},
				
				sType = .IMAGE_CREATE_INFO,
			}
			image_info.mipLevels = calcMip(image_info.extent.width, image_info.extent.height)
			
			alloc_info : vma.Allocation_Info
			vma.create_image(
				vulkan.vma,
				image_info,
				{
					required_flags = {.DEVICE_LOCAL},
					usage = .Gpu_Only,
				},
				&tex.image, 
				&tex.allocation, 
				&alloc_info
			)
			
			// Create View
			imageView_info := vk.ImageViewCreateInfo {
				image = tex.image,
				components = {.IDENTITY, .IDENTITY, .IDENTITY, .IDENTITY},
				format = .R8G8B8A8_SRGB,
				viewType = .D2,
				
				subresourceRange = {
					baseMipLevel   = 0,
					levelCount     = 1,
					
					baseArrayLayer = 0,
					layerCount     = 1,

					aspectMask     = {.COLOR},
				},
				sType = .IMAGE_VIEW_CREATE_INFO
			}
			vk.CreateImageView(vulkan.device,&imageView_info, nil, &tex.view)
			//

			// Send raw data to img buffer
			cmdImg_Upload(vulkan.immCmd.buffer, m.textures[tex_i].data[0].data, {
				allocator = vulkan.vma,
				image = tex.image,
				extent = image_info.extent,
				subresourceRange = imageView_info.subresourceRange,
				subresourceLayers = {
					mipLevel = 0,
					baseArrayLayer = 0,
					layerCount = 1,
					aspectMask = {.COLOR},
				}
			})
			
			// Create Sampler
			sampler_info := vk.SamplerCreateInfo {
				anisotropyEnable = info.sampler.maxAnisotropy > 0 ? true : false ,
				maxAnisotropy = f32(info.sampler.maxAnisotropy),
				
				addressModeU = vk.SamplerAddressMode(info.sampler.addressModeU),
				addressModeV = vk.SamplerAddressMode(info.sampler.addressModeV),
				addressModeW = vk.SamplerAddressMode(info.sampler.addressModeW),
				
				mipmapMode = vk.SamplerMipmapMode(info.sampler.mipmapMode),
				
				magFilter = vk.Filter(info.sampler.magFilter),
				minFilter = vk.Filter(info.sampler.minFilter),
				
				mipLodBias = info.sampler.mipLodBias,
				maxLod = info.sampler.maxLod,
				minLod = info.sampler.minLod,
				
				compareEnable = info.sampler.compareOp != .NEVER ? true : false,
				compareOp = vk.CompareOp(info.sampler.compareOp),
				
				unnormalizedCoordinates = b32(info.sampler.unnormalizedCoordinates),
				borderColor = info.sampler.borderColor,
				sType = .SAMPLER_CREATE_INFO
			}
			vk.CreateSampler(vulkan.device,&sampler_info,nil,&tex.sampler)
			//

			//Prepare for deploy
			if info.is_singleArray {
				vk.GetDescriptorEXT(vulkan.device,&vk.DescriptorGetInfoEXT{
					data = {
							pCombinedImageSampler = &vk.DescriptorImageInfo {
								imageLayout = .SHADER_READ_ONLY_OPTIMAL,
								imageView = tex.view,
								sampler = tex.sampler,
							}
						},
						type = .COMBINED_IMAGE_SAMPLER,
						sType = .DESCRIPTOR_GET_INFO_EXT
					},
					int(info.textureStride),
					rawptr(uintptr(box.texture_buffer.info.mapped_data) + uintptr(bindingOffset) + uintptr(tex_count * stride))
				)
			} else {
				print("Device is not Single Array, if you see this message, contact the developer.")
				os.exit(0)
				//TODO: i need to test this to be able to do ;-;
			}

			tex_count += 1
		} // for &tex, tex_i in m.tex_raw
		
	} // for &m, i in models


	vk.CmdCopyBuffer(vulkan.immCmd.buffer, buffsrc.buffer, box.vextex_buffer.buffer, 1, &vk.BufferCopy{
			size = vk.DeviceSize(vexSize_sum)
		}
	)
	vkRun_command(vulkan,&vulkan.immCmd)
	
	box.vextex_address = vk.GetBufferDeviceAddress(
		vulkan.device, 
		&vk.BufferDeviceAddressInfo{
			sType = .BUFFER_DEVICE_ADDRESS_INFO,
			buffer = box.vextex_buffer.buffer
		}
	)	
	box.texture_address = vk.GetBufferDeviceAddress(
		vulkan.device, 
		&vk.BufferDeviceAddressInfo{
			sType = .BUFFER_DEVICE_ADDRESS_INFO,
			buffer = box.texture_buffer.buffer
		}
	)
	return	
}
// ================ VULKAN ================


// ================ GLFW ================
InputStatus :: enum {
	RELEASED,
	PRESSED,
	HOLDING,
}
Input :: struct{
	value: f32,
	status: InputStatus,
	repeating: bool
}
inputs: map[string]Input
inputs_old: map[string]Input
input_callbackList := [dynamic]string{}
input_callbackList_old := []string{}
glfwInput_callback :: proc "c" (window: glfw.WindowHandle, key, scancode, action, mods: i32) {
	context = runtime.default_context()

	name := keyMap[Keys(key)]
	if name != "" {
		inputs_old[name] = inputs[name]
		input := Input{
			value = f32(min(1,action)),
			status = inputs[name].status
		}

		if input.repeating == false {
			if action < 1 {
				input.status = .RELEASED
			}
			if action > 0 && input.status != .HOLDING {
				input.status = .PRESSED
			}
		}
		
		if action > 1 {
			input.repeating = true
		} else {
			input.repeating = false
		}
		
		inputs[name] = input

		append(&input_callbackList, name)
		// print(name,key, scancode, inputs[name].status, inputs[name].value, inputs[name].repeating)
	}
}


MouseButtons :: enum u8{
	/* Adapted from GLFW */

	/* Mouse buttons */
	BUTTON_1 = 0,
	BUTTON_2 = 1,
	BUTTON_3 = 2,
	BUTTON_4 = 3,
	BUTTON_5 = 4,
	BUTTON_6 = 5,
	BUTTON_7 = 6,
	BUTTON_8 = 7,
	
	/* Mousebutton aliases */
	BUTTON_LEFT   	= BUTTON_1,
	BUTTON_RIGHT 	 	= BUTTON_2,
	BUTTON_MIDDLE   = BUTTON_3,
	BUTTON_BACKWARD = BUTTON_4,
	BUTTON_FOWARD  	= BUTTON_5,
	BUTTON_LAST     = BUTTON_8,
}
Mouse :: struct{
	using pos: [2]f64,
	buttons: [MouseButtons]InputStatus,
	scroll: [2]f64,
	in_window: bool,
}

mouse: Mouse
glfwMouseButton_callback :: proc "c" (window: glfw.WindowHandle, button, action, mods: i32) {
	context = runtime.default_context()
	mouse.buttons[MouseButtons(button)] = InputStatus(action)
}
glfwMousePos_callback :: proc "c" (window: glfw.WindowHandle, x,  y: f64) {
	context = runtime.default_context()
	mouse.x = x
	mouse.y = y
}
glfwMouseScroll_callback :: proc "c" (window: glfw.WindowHandle, x, y: f64) {
	context = runtime.default_context()
	mouse.scroll.x = x
	mouse.scroll.y = y
}
glfwMouseEnter_callback :: proc "c" (window: glfw.WindowHandle, entered: i32) {
	context = runtime.default_context()
	mouse.in_window = bool(entered)
}
glfwResize_callback :: proc "c" (window: glfw.WindowHandle, w: i32, h: i32) {
	context = runtime.default_context()
	append_elem(&winResize_callback, Window{
		resized = true,
		resolution = { u32(w), u32(h) },
		handle = window
	})
}


glfwCreate_surface :: proc(vulkan: ^Vulkan, physical: vk.PhysicalDevice, handle: glfw.WindowHandle) -> (surface: vk.SurfaceKHR) {
	if glfw.GetPhysicalDevicePresentationSupport(vulkan.instance, physical, 0) {
		print("GLFW has presentation")
	} else {
		print("GLFW dont have Presentation")
	}
	if err := glfw.CreateWindowSurface(vulkan.instance, handle, nil, &surface);
	   err == .SUCCESS {
		print("GLFW window surface is created")
	} else {
		print("GLFW window surface was unable to create:", err)
	}
	return
}
/*** Procedure type declarations ***/
// SetWindowIconifyCallback	-> proc "c" (window: WindowHandle, iconified: c.int)
// SetWindowRefreshCallback	-> proc "c" (window: WindowHandle)
// SetWindowFocusCallback	-> proc "c" (window: WindowHandle, focused: c.int)
// SetWindowCloseCallback	-> proc "c" (window: WindowHandle)
// SetWindowSizeCallback	-> proc "c" (window: WindowHandle, width, height: c.int)
// SetWindowPosCallback	-> proc "c" (window: WindowHandle, xpos, ypos: c.int)
// SetFramebufferSizeCallback	-> proc "c" (window: WindowHandle, width, height: c.int)
// SetDropCallback	-> proc "c" (window: WindowHandle, count: c.int, paths: [^]cstring)
// SetWindowMaximizeCallback	-> proc "c" (window: WindowHandle, iconified: c.int) 
// SetWindowContentScaleCallback	-> proc "c" (window: WindowHandle, xscale, yscale: f32)

// SetKeyCallback	-> proc "c" (window: WindowHandle, key, scancode, action, mods: c.int)
// SetMouseButtonCallback	-> proc "c" (window: WindowHandle, button, action, mods: c.int)
// SetCursorPosCallback	-> proc "c" (window: WindowHandle, xpos,  ypos: f64)
// SetScrollCallback	-> proc "c" (window: WindowHandle, xoffset, yoffset: f64)
// SetCharCallback	-> proc "c" (window: WindowHandle, codepoint: rune)
// SetCharModsCallback	-> proc "c" (window: WindowHandle, codepoint: rune, mods: c.int)
// SetCursorEnterCallback	-> proc "c" (window: WindowHandle, entered: c.int)

// SetMonitorCallback	-> proc "c" (monitor: MonitorHandle, event: c.int)
// SetJoystickCallback	-> proc "c" (joy, event: c.int)

// SetErrorCallback	-> proc "c" (error: c.int, description: cstring)

// ================ GLFW ================
