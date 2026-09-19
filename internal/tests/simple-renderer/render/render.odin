package render

import hm "core:container/handle_map"
import "core:mem"
import "core:os"
import "core:strings"
import "core:fmt"
import kt "KT:."

import vk "vendor:vulkan"
import "core:math"
import vmath "core:math/linalg"
import "core:time"
import "shared:vma"

@(private) print := fmt.println

state := kt.RenderState {
	camera = {
		rotation = vmath.Quaternionf32(1),
		position = {0,0,10},
		scale = {1,1,1},
		// position = {0,40,0},
		fov = 400,
		near = 0.1,
		far = 1.1,
		orthographic = false,
	},
	input = {
		keyMap = #partial{
			.A = "left",
			.D = "right",
			.W = "up",
			.S = "down",
			.SPACE = "upward",
			.M_LEFT_SHIFT = "downward",
			.M_LEFT_CONTROL = "speed",
			.F_TAB = "switch"
		}
	},
	window_info = {
		decorated = true,
		resizable = true
	},
	texture = {
		sampler = {
			addressModeU = .REPEAT,
			addressModeV = .REPEAT,
			addressModeW = .REPEAT,
			maxAnisotropy = 1,
			
			mipmapMode = .NEAREST
		}
	}
}
drawCMDS := kt.DrawCMDS{
	rStart, rDrawScene, rEnd
}


rStart :: proc(F: kt.FrameData, f_index: u32) {
	imgbarrier1 := vk.ImageMemoryBarrier2 {
		sType = .IMAGE_MEMORY_BARRIER_2,
		image = F.render.swapchain.images[f_index],
		subresourceRange = {aspectMask = {.COLOR}, layerCount = 1, levelCount = 1},
		oldLayout = .UNDEFINED,
		newLayout = .COLOR_ATTACHMENT_OPTIMAL,
		srcStageMask = {.ALL_COMMANDS},
		dstStageMask = {.COLOR_ATTACHMENT_OUTPUT},
		srcAccessMask = {.MEMORY_READ},
		dstAccessMask = {.COLOR_ATTACHMENT_WRITE},
	}
	barrier1_info := vk.DependencyInfo {
		imageMemoryBarrierCount = 1,
		pImageMemoryBarriers    = &imgbarrier1,
		sType                   = .DEPENDENCY_INFO,
	}

	vk.CmdPipelineBarrier2(F.render.cmd.buffer, &barrier1_info)

	barrier2 := vk.MemoryBarrier2 {
		sType = .MEMORY_BARRIER_2,
		srcStageMask = {.COMPUTE_SHADER},
		dstStageMask = {.ALL_GRAPHICS},
		srcAccessMask = {.SHADER_WRITE},
		dstAccessMask = {.SHADER_READ},
	}
	barrier_info2 := vk.DependencyInfo {
		sType = .DEPENDENCY_INFO,
		pMemoryBarriers = &barrier2,
		memoryBarrierCount = 1,
	}
	vk.CmdPipelineBarrier2(F.render.cmd.buffer, &barrier_info2)

	color := vk.RenderingAttachmentInfo {
		clearValue = {color = {float32 = {1.0, 0.5, 0.0, 1.0}}},
		imageLayout = .ATTACHMENT_OPTIMAL,
		loadOp = .CLEAR,
		storeOp = .STORE,
		imageView = F.render.swapchain.views[f_index],
		sType = .RENDERING_ATTACHMENT_INFO,
	}
	depth := vk.RenderingAttachmentInfo {
		clearValue = { depthStencil = { depth = 0 , stencil = 0}},
		imageLayout = .DEPTH_STENCIL_ATTACHMENT_OPTIMAL,
		
		loadOp = .CLEAR,
		storeOp = .STORE,
		imageView = F.render.swapchain.views_depth[f_index],
		sType = .RENDERING_ATTACHMENT_INFO,
	}
	// stencil := vk.RenderingAttachmentInfo {
	// 	clearValue = {color = {float32 = {1.0, 1.0, 1.0, 1.0}}},
	// 	imageLayout = .ATTACHMENT_OPTIMAL,
	// 	loadOp = .CLEAR,
	// 	storeOp = .STORE,
	// 	imageView = F.render.swapchain.views[f_index],
	// 	sType = .RENDERING_ATTACHMENT_INFO,
	// }
	rBegin_info := vk.RenderingInfo {
		renderArea = {extent = F.render.swapchain.extent},
		layerCount = 1,
		colorAttachmentCount = 1,
		pColorAttachments = &color,
		pDepthAttachment = &depth,
		
		
		sType = .RENDERING_INFO,
	}
	vk.CmdBeginRendering(F.render.cmd.buffer, &rBegin_info)

	viewport := vk.Viewport{
		height = f32(F.render.swapchain.extent.height),
		width = f32(F.render.swapchain.extent.width),
		minDepth = 1.0,
		maxDepth = 0.0
	}
	scissors := vk.Rect2D{
		extent = F.render.swapchain.extent
	}
	//
	vk.CmdSetViewportWithCount(F.render.cmd.buffer, 1, &viewport)
	vk.CmdSetScissorWithCount(F.render.cmd.buffer, 1, &scissors)

	vk.CmdSetCullMode(F.render.cmd.buffer, {.FRONT})
	vk.CmdSetFrontFace(F.render.cmd.buffer, .CLOCKWISE)
	vk.CmdSetPrimitiveTopology(F.render.cmd.buffer, .TRIANGLE_LIST)
	//vk.CmdSetLineWidth(F.render.cmd.buffer, 10)
	vk.CmdSetPolygonModeEXT(F.render.cmd.buffer, .FILL)
	vk.CmdSetVertexInputEXT(F.render.cmd.buffer, 0, nil, 0, nil)

	vk.CmdSetDepthCompareOp(F.render.cmd.buffer, .GREATER_OR_EQUAL)
	vk.CmdSetDepthTestEnable(F.render.cmd.buffer, true)
	vk.CmdSetDepthWriteEnable(F.render.cmd.buffer, true)
	
	vk.CmdSetDepthClipEnableEXT(F.render.cmd.buffer, false)
	vk.CmdSetDepthBiasEnable(F.render.cmd.buffer, false)
	
	//vk.CmdSetStencilOp(F.render.cmd.buffer, .FRONT, .REPLACE, .REPLACE, ..)
	vk.CmdSetStencilTestEnable(F.render.cmd.buffer, false)
	
	vk.CmdSetPrimitiveRestartEnable(F.render.cmd.buffer, false)
	vk.CmdSetRasterizerDiscardEnable(F.render.cmd.buffer, false)
	vk.CmdSetRasterizationSamplesEXT(F.render.cmd.buffer,{._1})

	sample_mask := vk.SampleMask(1)
	vk.CmdSetSampleMaskEXT(F.render.cmd.buffer,{._1},&sample_mask)
	vk.CmdSetAlphaToCoverageEnableEXT(F.render.cmd.buffer, true)
	color_blend_toggle := b32(false)
	vk.CmdSetColorBlendEnableEXT(F.render.cmd.buffer, 0, 1, &color_blend_toggle)
	vk.CmdSetColorWriteMaskEXT(F.render.cmd.buffer, 0, 1, &vk.ColorComponentFlags{.R,.G,.B,.A})


	descBind_info := vk.DescriptorBufferBindingInfoEXT{
		sType = .DESCRIPTOR_BUFFER_BINDING_INFO_EXT,
		usage = {.SAMPLER_DESCRIPTOR_BUFFER_EXT, .RESOURCE_DESCRIPTOR_BUFFER_EXT},
		address = F.worlds.models.texture_address,
	}
	vk.CmdBindDescriptorBuffersEXT(F.render.cmd.buffer,1,&descBind_info)

	// kt.cmdload_shaders(F.render.cmd.buffer,F.render.shaderBox,"shader.comp")
	kt.cmdload_shaders(F.render.cmd.buffer,F.render.shaderBox,"shader.frag")
	kt.cmdload_shaders(F.render.cmd.buffer,F.render.shaderBox,"shader.vert")

	descBuff_i := []u32{0}
	descBuff_off := []vk.DeviceSize{0}
	vk.CmdSetDescriptorBufferOffsetsEXT(F.render.cmd.buffer, .GRAPHICS,F.render.pipeline, 0, 1, raw_data(descBuff_i), raw_data(descBuff_off))
}

switch_uv: bool
rDrawScene ::	proc(F: kt.FrameData, f_index: u32) {
	if kt.inputs["switch"].status == .PRESSED {
		if switch_uv {
			switch_uv = false
		}	else {
			switch_uv = true
		}
	}

	v := kt.view(
		F.render.camera.position,
		F.render.camera.rotation,
		F.render.camera.scale,
	)

	// tp := t/100
	// print(tp)

	// print(
	// 	F.render.camera.position,
	// 	F.render.camera.rotation,
	// 	F.render.camera.scale,

	// 	F.render.camera.fov,
	// 	f32(F.render.window[0].resolution.x) / f32(F.render.window[0].resolution.y),
	// 	F.render.camera.near,
	// 	F.render.camera.far,
	// 	F.render.camera.orthographic
	// )
	p := kt.proj(
		F.render.camera.fov,
		f32(F.render.window[0].resolution.x) / f32(F.render.window[0].resolution.y),
		F.render.camera.near,
		F.render.camera.far,
		F.render.camera.orthographic
	)

	modelBox := F.worlds.models
	models_len := len(modelBox.models)

	it := hm.iterator_make(&F.worlds.terrains[0].entities)
	for e, h in hm.iterate(&it) {
		// print(e)
		for &m,m_i in e.models {
			// fmt.print(m.model, "-")
			if int(m.model) >= models_len { // verify if valid
				continue
			}
			model := modelBox.models[m.model]
			// print(F.worlds.current_world.models.models[m.].offsets)
			if len(model.vertex) > 0 { // the "ok" function 
				m := kt.transform(
					m.transform.position,
					m.transform.rotation,
					m.transform.scale
				)
				const := struct #align(4) {
					mvp: vmath.Matrix4f32,
					time: f32,
					texture_offset: i32,
					vextex_address: vk.DeviceAddress,
					switch_uv: bool,
				}{
					p * v * m, f32(F.render.dt.value),
					model.offsets.texture,
					modelBox.vextex_address + model.offsets.vertex,
					switch_uv,
				}
	
				// print(h, const.vextex_address)
				// print("")
				// print("Projection")
				// kt.print_column(p)
				// print("View")
				// kt.print_column(v)
				// print("Transform")
				// kt.print_column(m)

				vk.CmdPushConstants(
					F.render.cmd.buffer,
					F.render.pipeline,
					{.COMPUTE, .VERTEX, .FRAGMENT},
					0, size_of(const), &const
				)
				vk.CmdDraw(F.render.cmd.buffer, u32(len(model.vertex)), 1, 0, 0)
				/*
				*/
			}
		}
	}
	// print("")
}

rEnd ::	proc(F: kt.FrameData, f_index: u32) {
	vk.CmdEndRendering(F.render.cmd.buffer)

	imgbarrier2 := vk.ImageMemoryBarrier2 {
		image = F.render.swapchain.images[f_index],
		subresourceRange = {aspectMask = {.COLOR}, layerCount = 1, levelCount = 1},
		sType = .IMAGE_MEMORY_BARRIER_2,
		oldLayout = .COLOR_ATTACHMENT_OPTIMAL,
		newLayout = .PRESENT_SRC_KHR,
		srcStageMask = {.COLOR_ATTACHMENT_OUTPUT},
		srcAccessMask = {.COLOR_ATTACHMENT_WRITE},
		dstStageMask = {},
		dstAccessMask = {},
	}

	barrier2_info := vk.DependencyInfo {
		pImageMemoryBarriers    = &imgbarrier2,
		imageMemoryBarrierCount = 1,
		sType                   = .DEPENDENCY_INFO,
	}

	vk.CmdPipelineBarrier2(F.render.cmd.buffer, &barrier2_info)
}
