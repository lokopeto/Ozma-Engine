struct PushConstants {
  float32_t4x4 mvp;
  float4 color;
  float4 line_start;
  float4 line_end;
}

// Get from the host
[vk_push_constant]
PushConstants const;


// Send to the fragment shader
struct VSOutput {
  float4 pos : SV_Position;
  [vk_binding(0)] float4 color : COLOR0;
};

[shader("vertex")] // Type of the shader
VSOutput main(uint i: SV_VertexID) {
  VSOutput output;

  if (i == 0) {
    output.pos.xyz = const.line_start.xyz;
  }
  if (i >= 1) {
    output.pos.xyz = const.line_end.xyz;
  }
  output.pos.w = 1;
  output.pos = mul(const.mvp, output.pos);

  output.color.xyz = const.color.xyz;
  output.color.w = 1;
  return output;
}
