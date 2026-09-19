// Constant host struct
struct PushConstants {
    float4x4 mvp;    
    float32_t time;
    Vertex* vert;

};
// Get from the host
[vk_push_constant]
PushConstants const;

struct Vertex {
    float3 position;
    float32_t uv_x;
    float3 normal;
    float32_t uv_y;
    float4 color;
}

struct Coutput {
    float4 position;
}

[shader("compute")] // Type of the shader
[numthreads(64, 1, 1)]
void main(uint3 i: SV_DispatchThreadID) {
    
}


