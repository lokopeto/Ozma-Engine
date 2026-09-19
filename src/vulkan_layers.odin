package koto
import vk "vendor:vulkan"
import "core:mem"

EXTENSIONS :: []cstring{
	vk.KHR_SWAPCHAIN_EXTENSION_NAME,
	vk.EXT_SHADER_OBJECT_EXTENSION_NAME, 
	vk.KHR_BUFFER_DEVICE_ADDRESS_EXTENSION_NAME,

	vk.EXT_EXTENDED_DYNAMIC_STATE_3_EXTENSION_NAME,
	vk.EXT_EXTENDED_DYNAMIC_STATE_2_EXTENSION_NAME,
	vk.EXT_EXTENDED_DYNAMIC_STATE_EXTENSION_NAME,
	
	vk.EXT_DEPTH_CLIP_ENABLE_EXTENSION_NAME,
	vk.EXT_DEPTH_CLIP_CONTROL_EXTENSION_NAME,

	// vk.KHR_PUSH_DESCRIPTOR_EXTENSION_NAME,
	vk.KHR_DYNAMIC_RENDERING_LOCAL_READ_EXTENSION_NAME,
	vk.EXT_DESCRIPTOR_BUFFER_EXTENSION_NAME,
	vk.KHR_WORKGROUP_MEMORY_EXPLICIT_LAYOUT_EXTENSION_NAME,
	vk.EXT_MEMORY_BUDGET_EXTENSION_NAME,
	vk.EXT_MEMORY_PRIORITY_EXTENSION_NAME,
	// vk.KHR_SWAPCHAIN_MUTABLE_FORMAT_EXTENSION_NAME,
	// vk.KHR_IMAGE_FORMAT_LIST_EXTENSION_NAME,
}

vkGet_Features :: proc() -> (next: rawptr) {
	new_feature :: proc(feature: $T) -> rawptr {
		f := new(T, context.temp_allocator)
		f^ = feature
		return f
	}
	// next = &vk.PhysicalDeviceVulkan14Features {
	// 	sType = .PHYSICAL_DEVICE_VULKAN_1_4_FEATURES,
	// 	pNext = next,
	// 	maintenance5 = true,
	// 	// maintenance6 = true

	// 	dynamicRenderingLocalRead = true,
	// }
	next = new_feature(vk.PhysicalDeviceVulkan13Features {
		sType = .PHYSICAL_DEVICE_VULKAN_1_3_FEATURES,
		pNext = next,
		dynamicRendering = true,
		synchronization2 = true,
		maintenance4 = true,
	})
	next = new_feature(vk.PhysicalDeviceMemoryPriorityFeaturesEXT {
		sType = .PHYSICAL_DEVICE_MEMORY_PRIORITY_FEATURES_EXT,
		pNext = next,
		memoryPriority = true
	})
	next = new_feature(vk.PhysicalDeviceVulkan12Features {
		sType = .PHYSICAL_DEVICE_VULKAN_1_2_FEATURES,
		pNext = next,
		timelineSemaphore = true,
		bufferDeviceAddress = true,

		descriptorIndexing =  															 true,
		shaderInputAttachmentArrayDynamicIndexing =          true,
		shaderUniformTexelBufferArrayDynamicIndexing =       true,
		shaderStorageTexelBufferArrayDynamicIndexing =       true,
		shaderUniformBufferArrayNonUniformIndexing =         true,
		shaderSampledImageArrayNonUniformIndexing =          true,
		shaderStorageBufferArrayNonUniformIndexing =         true,
		shaderStorageImageArrayNonUniformIndexing =          true,
		shaderInputAttachmentArrayNonUniformIndexing =       true,
		shaderUniformTexelBufferArrayNonUniformIndexing =    true,
		shaderStorageTexelBufferArrayNonUniformIndexing =    true,
		descriptorBindingUniformBufferUpdateAfterBind =      true,
		descriptorBindingSampledImageUpdateAfterBind =       true,
		descriptorBindingStorageImageUpdateAfterBind =       true,
		descriptorBindingStorageBufferUpdateAfterBind =      true,
		descriptorBindingUniformTexelBufferUpdateAfterBind = true,
		descriptorBindingStorageTexelBufferUpdateAfterBind = true,
		descriptorBindingUpdateUnusedWhilePending =          true,
		descriptorBindingPartiallyBound =                    true,
		descriptorBindingVariableDescriptorCount =           true,
		runtimeDescriptorArray =                             true,
		scalarBlockLayout = 																 false,
		shaderInt8 = 																				 true,
		storagePushConstant8 = true,
	})
	next = new_feature(vk.PhysicalDeviceVulkan11Features {
		sType = .PHYSICAL_DEVICE_VULKAN_1_1_FEATURES,
		pNext = next,
		shaderDrawParameters = true,	
	})

	next = new_feature(vk.PhysicalDeviceShaderObjectFeaturesEXT {
    sType = .PHYSICAL_DEVICE_SHADER_OBJECT_FEATURES_EXT,
    pNext = next,
    shaderObject = true,
	})
	next = new_feature(vk.PhysicalDeviceDepthClipEnableFeaturesEXT {
    sType = .PHYSICAL_DEVICE_DEPTH_CLIP_ENABLE_FEATURES_EXT,
    pNext = next,
    depthClipEnable = true,
  })
	next = new_feature(vk.PhysicalDeviceExtendedDynamicStateFeaturesEXT {
    sType = .PHYSICAL_DEVICE_EXTENDED_DYNAMIC_STATE_FEATURES_EXT,
    pNext = next,
    extendedDynamicState = true
	})
	next = new_feature(vk.PhysicalDeviceExtendedDynamicState2FeaturesEXT {
    sType = .PHYSICAL_DEVICE_EXTENDED_DYNAMIC_STATE_2_FEATURES_EXT,
    pNext = next,
    extendedDynamicState2 = true,
    extendedDynamicState2LogicOp = true,
    extendedDynamicState2PatchControlPoints = true
	})
	next = new_feature(vk.PhysicalDeviceDescriptorBufferFeaturesEXT {
    sType = .PHYSICAL_DEVICE_DESCRIPTOR_BUFFER_FEATURES_EXT,
    pNext = next,
    descriptorBuffer = true,
    descriptorBufferCaptureReplay = true,
	})
	next = new_feature(vk.PhysicalDeviceExtendedDynamicState3FeaturesEXT {
    sType = .PHYSICAL_DEVICE_EXTENDED_DYNAMIC_STATE_3_FEATURES_EXT,
    pNext = next,
    extendedDynamicState3AlphaToCoverageEnable = true,
    extendedDynamicState3AlphaToOneEnable = true,

    extendedDynamicState3ColorBlendEnable = true,
    extendedDynamicState3ColorBlendEquation = true,
    extendedDynamicState3ColorWriteMask = true,

    extendedDynamicState3DepthClampEnable = true,
    extendedDynamicState3DepthClipEnable = true,
    extendedDynamicState3DepthClipNegativeOneToOne = true,

    extendedDynamicState3LineRasterizationMode = true,
    extendedDynamicState3LineStippleEnable = true,
    extendedDynamicState3LogicOpEnable = true,
    extendedDynamicState3PolygonMode = true,
    extendedDynamicState3ProvokingVertexMode = true,
    extendedDynamicState3RasterizationSamples = true,
    extendedDynamicState3SampleLocationsEnable = true,
    extendedDynamicState3SampleMask = true,
    extendedDynamicState3TessellationDomainOrigin = true,    
	})
	next = new_feature(vk.PhysicalDeviceFeatures2 {
		sType = .PHYSICAL_DEVICE_FEATURES_2,
		pNext = next,
		// features = g.vk.physical.features,
		features = {
			sparseBinding = true,
			samplerAnisotropy = true,
			wideLines = true,
			fillModeNonSolid = true
		}
	})
	next = new_feature(vk.PhysicalDeviceWorkgroupMemoryExplicitLayoutFeaturesKHR {
		sType = .PHYSICAL_DEVICE_WORKGROUP_MEMORY_EXPLICIT_LAYOUT_FEATURES_KHR,
		pNext = next,
		workgroupMemoryExplicitLayout =                  true,
		workgroupMemoryExplicitLayoutScalarBlockLayout = true,
		workgroupMemoryExplicitLayout8BitAccess =        true,
		workgroupMemoryExplicitLayout16BitAccess =       true,
	})
	return
}
