## Graphics Pipeline Assembly Line

Each station lists the `PipelineStageFlag2` and what `AccessFlag2` the resource goes through at that point. Read access comes in, write access goes out.

---

### 1. TOP_OF_PIPE

The idle entrance. No work happens here.

| Access Read | Access Write |
| ----------- | ------------ |
| —           | —            |

---

### 2. INPUT ASSEMBLER

```
DRAW_INDIRECT → INDEX_INPUT → VERTEX_ATTRIBUTE_INPUT → VERTEX_INPUT
```

The GPU reads your command buffers, index buffers, and vertex buffers.

| Stage                    | What it does                                  | Reads                   | Writes |
| ------------------------ | --------------------------------------------- | ----------------------- | ------ |
| `DRAW_INDIRECT`          | Fetch indirect draw commands                  | `INDIRECT_COMMAND_READ` | —      |
| `INDEX_INPUT`            | Fetch index buffer for indexed draws          | `INDEX_READ`            | —      |
| `VERTEX_ATTRIBUTE_INPUT` | Fetch per-vertex attributes (BDA vertex pull) | `VERTEX_ATTRIBUTE_READ` | —      |
| `VERTEX_INPUT`           | Combines vertex + index data into vertices    | —                       | —      |

---

### 3. VERTEX_SHADER

Runs your vertex shader. Reads uniforms and vertex data via push constants/BDA.

| Stage           | What it does                    | Reads                                                                       | Writes                                 |
| --------------- | ------------------------------- | --------------------------------------------------------------------------- | -------------------------------------- |
| `VERTEX_SHADER` | Transform vertices, compute MVP | `SHADER_READ`, `UNIFORM_READ`, `SHADER_SAMPLED_READ`, `SHADER_STORAGE_READ` | `SHADER_WRITE`, `SHADER_STORAGE_WRITE` |

---

### 4. TESSELLATION

```
TESSELLATION_CONTROL_SHADER → TESSELLATION_EVALUATION_SHADER
```

Only active with patch primitives. You use `TRIANGLE_LIST` — these stages are skipped.

| Stage                            | What it does                                           | Reads         | Writes         |
| -------------------------------- | ------------------------------------------------------ | ------------- | -------------- |
| `TESSELLATION_CONTROL_SHADER`    | Hull shader — defines tessellation factors             | `SHADER_READ` | `SHADER_WRITE` |
| `TESSELLATION_EVALUATION_SHADER` | Domain shader — evaluates tessellated vertex positions | `SHADER_READ` | `SHADER_WRITE` |

---

### 5. GEOMETRY_SHADER

Optional per-primitive shader. You don't use one.

| Stage             | What it does            | Reads         | Writes         |
| ----------------- | ----------------------- | ------------- | -------------- |
| `GEOMETRY_SHADER` | Emit/amplify primitives | `SHADER_READ` | `SHADER_WRITE` |

---

### 6. PRE_RASTERIZATION_SHADERS

Modern alias covering VERTEX → TESSELLATION → GEOMETRY. Convenience grouping.

| Stage                       | What it does                           | Reads         | Writes         |
| --------------------------- | -------------------------------------- | ------------- | -------------- |
| `PRE_RASTERIZATION_SHADERS` | All vertex-processing shaders combined | `SHADER_READ` | `SHADER_WRITE` |

---

### 7. RASTERIZATION

Viewport transform, culling, polygon mode, scissor test, depth clip/bias. Fragment shading rate also resolved here.

| Stage                          | What it does                                                   | Reads                                   | Writes                     |
| ------------------------------ | -------------------------------------------------------------- | --------------------------------------- | -------------------------- |
| `RASTERIZATION`                | Convert triangles to fragments, apply clipping/culling/scissor | `FRAGMENT_SHADING_RATE_ATTACHMENT_READ` | —                          |
| `FRAGMENT_DENSITY_PROCESS_EXT` | Variable-rate shading density                                  | `FRAGMENT_DENSITY_MAP_READ`             | —                          |
| `TRANSFORM_FEEDBACK_EXT`       | Capture vertex data before rasterization                       | —                                       | `TRANSFORM_FEEDBACK_WRITE` |

---

### 8. EARLY_FRAGMENT_TESTS

**Depth test** runs here (before fragment shader). Tests depth/stencil against the depth image. If the test fails, the fragment shader never runs.

| Stage                    | What it does                        | Reads                           | Writes                           |
| ------------------------ | ----------------------------------- | ------------------------------- | -------------------------------- |
| `EARLY_FRAGMENT_TESTS`   | Depth test (before fragment shader) | `DEPTH_STENCIL_ATTACHMENT_READ` | `DEPTH_STENCIL_ATTACHMENT_WRITE` |
| `INVOCATION_MASK_HUAWEI` | Early fragment mask                 | `INVOCATION_MASK_READ_HUAWEI`   | —                                |

This is where your **depth image barrier** must land (`dstStageMask = {.EARLY_FRAGMENT_TESTS}`) — the depth layout transition must complete before the GPU reads depth here.

---

### 9. FRAGMENT_SHADER

Runs for every fragment that passed the early depth test. Reads push constants (color), writes color output.

| Stage | What it does | Reads | Writes |
|---|---|---|---|
| `FRAGMENT_SHADER` | Shade each fragment | `SHADER_READ`, `UNIFORM_READ`, `SHADER_SAMPLED_READ`, `SHADER_STORAGE_READ`, `INPUT_ATTACHMENT_READ` | `SHADER_WRITE`, `SHADER_STORAGE_WRITE` |

---

### 10. LATE_FRAGMENT_TESTS

**Stencil test** runs here (after fragment shader). Only fragments that survived the shader reach here. Also late depth writes for fragments that modified `gl_FragDepth`.

| Stage | What it does | Reads | Writes |
|---|---|---|---|
| `LATE_FRAGMENT_TESTS` | Stencil test, late depth write | `DEPTH_STENCIL_ATTACHMENT_READ` | `DEPTH_STENCIL_ATTACHMENT_WRITE` |

---

### 11. COLOR_ATTACHMENT_OUTPUT

Blending, color write mask. Final pixel is written to the color attachment.

| Stage | What it does | Reads | Writes |
|---|---|---|---|
| `COLOR_ATTACHMENT_OUTPUT` | Blend and write final color | `COLOR_ATTACHMENT_READ`, `COLOR_ATTACHMENT_READ_NONCOHERENT_EXT` | `COLOR_ATTACHMENT_WRITE` |

Your **post-render present barrier** must set `srcStageMask = {.COLOR_ATTACHMENT_OUTPUT}` with `srcAccessMask = {.COLOR_ATTACHMENT_WRITE}` — wait until the last pixel is written before handing the image to the presentation engine.

---

### 12. BOTTOM_OF_PIPE

End of the graphics pipeline. No further work.

| Access Read | Access Write |
|---|---|
| — | — |

---

### Side Tracks (not on the main assembly line)

These stages run on their own dedicated lanes:

#### COMPUTE_SHADER

Independent queue of work. Has its own ordering — barriers bridge data between compute and graphics.

| Stage | Reads | Writes |
|---|---|---|
| `COMPUTE_SHADER` | `SHADER_READ`, `UNIFORM_READ`, `SHADER_SAMPLED_READ`, `SHADER_STORAGE_READ` | `SHADER_WRITE`, `SHADER_STORAGE_WRITE` |

#### TRANSFER

Copy/blit/resolve/clear operations. Independent queue.

| Stage | Reads | Writes |
|---|---|---|
| `COPY` | `TRANSFER_READ` | `TRANSFER_WRITE` |
| `BLIT` | `TRANSFER_READ` | `TRANSFER_WRITE` |
| `RESOLVE` | `TRANSFER_READ` | `TRANSFER_WRITE` |
| `CLEAR` | — | `TRANSFER_WRITE` |

#### HOST

CPU reads/writes through mapped memory.

| Stage | Reads | Writes |
|---|---|---|
| `HOST` | `HOST_READ` | `HOST_WRITE` |

---

### Convenience Groupings

| Flag | Includes | Use case |
|---|---|---|
| `ALL_GRAPHICS` | Every stage from `DRAW_INDIRECT` to `COLOR_ATTACHMENT_OUTPUT` | "wait for all graphics to finish" |
| `ALL_COMMANDS` | Everything including compute and transfer | "wait for literally everything" |
| `ALL_TRANSFER` | COPY + BLIT + RESOLVE + CLEAR | "wait for all copy operations" |

---

### For your current code, the minimal correct barrier set is:

| Barrier | srcStageMask | srcAccessMask | dstStageMask | dstAccessMask |
|---|---|---|---|---|
| Pre-render color layout | `{}` (or `{.TOP_OF_PIPE}`) | `{}` | `{.COLOR_ATTACHMENT_OUTPUT}` | `{.COLOR_ATTACHMENT_WRITE}` |
| Pre-render depth layout (one-time init) | `{.TOP_OF_PIPE}` | `{}` | `{.EARLY_FRAGMENT_TESTS}` | `{.DEPTH_STENCIL_ATTACHMENT_READ, .DEPTH_STENCIL_ATTACHMENT_WRITE}` |
| Post-render color layout → present | `{.COLOR_ATTACHMENT_OUTPUT}` | `{.COLOR_ATTACHMENT_WRITE}` | `{.BOTTOM_OF_PIPE}` | `{}` |
