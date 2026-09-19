struct Vertex {
  float4 position;
  float4 normal;
  float4 color;
  float2 uv;
  uint32_t tex;
  uint32_t _pad1;
}
// Constant host struct
struct PushConstants {
  float4x4 mvp;
  float32_t time;
  int32_t tex_i;
  Vertex *vert;
  bool switch;
};
