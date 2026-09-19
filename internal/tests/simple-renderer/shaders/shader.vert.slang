import builtins;

// Get from the host
[vk_push_constant]
PushConstants const;


// Send to the fragment shader
struct VSOutput {
  float4 pos : SV_Position;
  [vk_location(0)] float4 pos_frag;
  [vk_location(1)] float32_t time;
  [vk_location(2)] float32_t mvp;
  [vk_location(3)] int32_t tex_i;
  [vk_location(4)] bool switch;
  [vk_location(5)] Vertex vert;
};

[shader("vertex")] // Type of the shader
VSOutput main(uint i: SV_VertexID) {
  VSOutput output;

  output.pos = mul(
    float4(const.vert[i].position.xyz, 1), 
    const.mvp,
  );
  output.pos_frag = output.pos;
  output.time = const.time;
  output.vert = const.vert[i];
  output.tex_i = const.tex_i;
  output.switch = const.switch;

  return output;
}
