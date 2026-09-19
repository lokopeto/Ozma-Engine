// Recive from the vertex shader
import builtins;

struct VSInput {
  [vk_location(0)] float4 pos_frag;
  [vk_location(1)] float32_t time;
  [vk_location(2)] float32_t mvp;
  [vk_location(3)] int32_t tex_i;
  [vk_location(4)] bool switch;
  [vk_location(5)] Vertex vert;
};

// Print to the screen
struct FSOutput {
  [vk_location(0)]
  float4 frag_color : COLOR0;
};

[vk_binding(0,0)]
Sampler2D tex[] : register(t0);


[shader("fragment")]
FSOutput main(VSInput input) {
  FSOutput output;

  // float3 color = frac(input.vert.position.xyz / 0.8);
  // output.frag_color = float4(color.y, color.y, color.y + 0.3, 1);
 
  int idx = int(input.vert.tex) + input.tex_i;
  float4 tex_color = tex[NonUniformResourceIndex(idx)].Sample(float2(input.vert.uv.xy));

  if (input.switch) {
    output.frag_color.xy = input.vert.uv;
    output.frag_color.w = 1;
  } else {
    output.frag_color = tex_color;
  }
  return output;
}
