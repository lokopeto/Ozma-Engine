## Physical devices
A GPU no mundo fisico, é dali que tu entende oque é suportado e oque não é

## Instance
É como se fosse o "nucleo" do vulkan, tudo será em volta dessa instancia, ela é "abstrato", ou seja, você pode ter varias instancias, vulkan cria ela pra você.

## Device
Um dispositivo imaginario criado pelo Host(CPU) para um uso especifico

## Queue Family
Como se fosse um nucleo de um CPU
## Queue
Como se fosse os threads de um CPU
## Dynamic Layout Commands

| Rasterization | RasterizerDiscardEnable, CullMode, FrontFace, PolygonModeEXT, RasterizationSamplesEXT, SampleMaskEXT, AlphaToCoverageEnableEXT, DepthClampEnableEXT, LineWidth, LineStippleEnableEXT |
| ------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Depth/Stencil | DepthTestEnable, DepthWriteEnable, DepthCompareOp, DepthBoundsTestEnable, DepthBiasEnable, StencilTestEnable, StencilOp, StencilCompareMask, StencilWriteMask, StencilReference      |
| Blending      | ColorBlendEnableEXT, ColorBlendEquationEXT, ColorWriteMaskEXT, BlendConstants, LogicOpEnableEXT, LogicOpEXT                                                                          |
| Vertex Input  | VertexInputEXT, PrimitiveRestartEnable                                                                                                                                               |
| Viewport      | ViewportWithCount, ScissorWithCount                                                                                                                                                  |
| Topology      | PrimitiveTopology                                                                                                                                                                    |
| Tessellation  | PatchControlPointsEXT, TessellationDomainOriginEXT                                                                                                                                   |

### Comandos

#### Comandos "Set"
```C
CmdSetAttachmentFeedbackLoopEnableEXT
CmdSetAlphaToCoverageEnableEXT
CmdSetAlphaToOneEnableEXT

CmdSetBlendConstants
CmdSetColorBlendAdvancedEXT
CmdSetColorBlendEnableEXT
CmdSetColorBlendEquationEXT
CmdSetColorWriteMaskEXT
CmdSetConservativeRasterizationModeEXT

CmdSetCullMode
CmdSetDepthBias
CmdSetDepthBias2EXT
CmdSetDepthBiasEnable
CmdSetDepthBiasEnableEXT
CmdSetDepthBounds
CmdSetDepthBoundsTestEnable
CmdSetDepthBoundsTestEnableEXT
CmdSetDepthClampEnableEXT
CmdSetDepthClampRangeEXT
CmdSetDepthClipEnableEXT
CmdSetDepthClipNegativeOneToOneEXT
CmdSetDepthCompareOp
CmdSetDepthCompareOpEXT
CmdSetDepthTestEnable
CmdSetDepthTestEnableEXT
CmdSetDepthWriteEnable
CmdSetDepthWriteEnableEXT

CmdSetDeviceMask
CmdSetDescriptorBufferOffsetsEXT
CmdSetDescriptorBufferOffsets2EXT
//CmdSetDeviceMaskKHR
CmdSetDiscardRectangleEXT
CmdSetDiscardRectangleEnableEXT
CmdSetDiscardRectangleModeEXT
CmdSetEvent
CmdSetEvent2
//CmdSetEvent2KHR
CmdSetExtraPrimitiveOverestimationSizeEXT
CmdSetFragmentShadingRateKHR
CmdSetFrontFace
//CmdSetFrontFaceEXT
CmdSetLineRasterizationModeEXT
CmdSetLineStipple
//CmdSetLineStippleEXT
//CmdSetLineStippleKHR
CmdSetLineStippleEnableEXT
CmdSetLineWidth
CmdSetLogicOpEXT
CmdSetLogicOpEnableEXT
CmdSetPatchControlPointsEXT
CmdSetPolygonModeEXT
CmdSetPrimitiveRestartEnable
//CmdSetPrimitiveRestartEnableEXT
CmdSetPrimitiveTopology
//CmdSetPrimitiveTopologyEXT
CmdSetProvokingVertexModeEXT
CmdSetRasterizationSamplesEXT
CmdSetRasterizationStreamEXT
CmdSetRasterizerDiscardEnable
//CmdSetRasterizerDiscardEnableEXT
CmdSetRenderingAttachmentLocations
//CmdSetRenderingAttachmentLocationsKHR
CmdSetRenderingInputAttachmentIndices
//CmdSetRenderingInputAttachmentIndicesKHR
CmdSetSampleLocationsEXT
CmdSetSampleLocationsEnableEXT
CmdSetSampleMaskEXT

CmdSetStencilCompareMask
CmdSetStencilOp
//CmdSetStencilOpEXT
CmdSetStencilReference
CmdSetStencilTestEnable
//CmdSetStencilTestEnableEXT
CmdSetStencilWriteMask

CmdSetTessellationDomainOriginEXT
CmdSetVertexInputEXT

CmdSetViewport
CmdSetViewportWithCount
//CmdSetViewportWithCountEXT
CmdSetScissor
CmdSetScissorWithCount
//CmdSetScissorWithCountEXT

CmdSetRayTracingPipelineStackSizeKHR

// Nvidia
CmdSetRepresentativeFragmentTestEnableNV
CmdSetCoarseSampleOrderNV
CmdSetCheckpointNV
CmdSetCoverageModulationModeNV
CmdSetCoverageModulationTableEnableNV
CmdSetCoverageModulationTableNV
CmdSetCoverageReductionModeNV
CmdSetCoverageToColorEnableNV
CmdSetCoverageToColorLocationNV
CmdSetViewportShadingRatePaletteNV
CmdSetViewportSwizzleNV
CmdSetViewportWScalingEnableNV
CmdSetViewportWScalingNV
CmdSetShadingRateImageEnableNV
CmdSetExclusiveScissorNV
CmdSetFragmentShadingRateEnumNV
CmdSetExclusiveScissorEnableNV
//

// Intel
CmdSetPerformanceMarkerINTEL
CmdSetPerformanceOverrideINTEL
CmdSetPerformanceStreamMarkerINTEL
//

```

#### Comandos Obrigatórios
```C
CmdSetViewportWithCount        (1, &vp);
CmdSetScissorWithCount         (1, &sc);
CmdSetRasterizerDiscardEnable  (false)
CmdSetCullMode                 ({})               // NONE
CmdSetFrontFace                (.COUNTER_CLOCKWISE)
CmdSetPrimitiveTopology        (.TRIANGLE_LIST)
CmdSetPrimitiveRestartEnable   (false)
CmdSetPolygonModeEXT           (.FILL)
CmdSetDepthTestEnable          (false)
CmdSetDepthWriteEnable         (false)
CmdSetDepthCompareOp           (.LESS_OR_EQUAL)
CmdSetDepthBoundsTestEnable    (false)
CmdSetDepthBiasEnable          (false)
CmdSetStencilTestEnable        (false)
CmdSetStencilOp                ({.FRONT,.BACK}, .KEEP, .KEEP, .KEEP, .ALWAYS)
CmdSetRasterizationSamplesEXT  (._1_BIT)          // match attachment sample count
CmdSetSampleMaskEXT            (1, &~0u)
CmdSetAlphaToCoverageEnableEXT (false)
CmdSetColorBlendEnableEXT      (0, 1, &false)
CmdSetColorBlendEquationEXT    (0, 1, &eq)        // ONE, ZERO, ADD
CmdSetColorWriteMaskEXT        (0, 1, &{.R,.G,.B,.A})
CmdSetVertexInputEXT           (0, nil, 0, nil)   // empty = vertex pulling
```

### Necessarios
- VkInstance
- VkPhysicalDevice
- VkDevice
- VkQueue
- VkCommandBuffer


# Lembrar
```C
AoS = position[i].x //Array of Struct
SoA = x[i] // Struct of Arrays
AoSoA = block[i/8].x[i%8] // melhor metodo, SIMD friendly
```


# Links


