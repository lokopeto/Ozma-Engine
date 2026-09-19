// Recive from the vertex shader
import builtins;

// Send to the fragment shader
struct VSInput {
  [vk_binding(0)] float4 color : COLOR0;
};


// Print to the screen
struct FSOutput {
  [vk_location(0)] float4 frag_color : COLOR0;
};

[vk_binding(0,0)]
Sampler2D tex[] : register(t0);


[shader("fragment")]
FSOutput main(VSInput input) {
  FSOutput output;

  // float3 color = frac(input.vert.position / 0.8);
  // output.frag_color = float4(color.y, color.y, color.y + 0.3, 1);

  // output.frag_color.xyz = input.vert.uv;
  // output.frag_color.w = 1;
  // output.frag_color = tex.Sample(float2(input.vert.uv_x, input.vert.uv_y));

  output.frag_color = input.color;

  return output;
}
