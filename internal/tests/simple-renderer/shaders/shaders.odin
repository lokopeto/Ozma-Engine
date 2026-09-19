package shaders

import kt "KT:."

state := kt.ShaderState{
	shaders = {
		{
			code = {
				path = "shaders/shader.comp.spv",
			},
			stage = {.COMPUTE},
			
		},
		{
			code = {
				path = "shaders/shader.vert.spv",
			},
			stage = {.VERTEX},
			nextStage = {.FRAGMENT}
		},
		{
			code = {
				path = "shaders/shader.frag.spv",
			},
			stage = {.FRAGMENT},
		}
	},
	config = {
		linkStage = .CHAIN,
		constant = {
			behavior = .FILL_EMPTY,
			data = {
				{
					size = .Max_256,
					stageFlags = {.COMPUTE,.VERTEX,.FRAGMENT}
				},
			}
		},
		descriptor_push = {
			size = .Max_256,
			stageFlags = {.COMPUTE,.VERTEX,.FRAGMENT}
		},
		descriptors = {
			{
				descriptorType = .COMBINED_IMAGE_SAMPLER,
				limit = 200,
				stageFlags = {.COMPUTE,.VERTEX,.FRAGMENT}
			}
		},
		codeType = .SPIRV
	}
}
