//
//  PlaneShader.metal
//  metal01
//
//  Created by yangming on 2019/2/1.
//  Copyright © 2019年 AL. All rights reserved.
//

#include <metal_stdlib>
#import "ALShaderTypes.h"
using namespace metal;

// Include header shared between this Metal shader code and C code executing Metal API commands


// Per-vertex inputs fed by vertex buffer laid out with MTLVertexDescriptor in Metal API


typedef struct
{
    float4 position [[position]];
    float2 texcoord;
} PlaneInOut;

vertex PlaneInOut plane_vertex(uint vertexID [[vertex_id]],
                               constant float3 *vertices [[buffer(AAPLVertexAttributePosition)]],
                               constant float2 *coordinates [[buffer(AAPLVertexAttributeTexcoord)]],
                                 constant ALMatrix *matrix [[ buffer(2) ]])
{
    PlaneInOut out;

    // Add vertex pos to fairy position and project to clip-space
    out.position = matrix->projectionMatrix * matrix->viewMatrix * matrix->modelMatrix * float4(vertices[vertexID], 1.0f);

    // Pass position through as texcoord
    out.texcoord = coordinates[vertexID];

    return out;
}

fragment half4 plane_fragment(PlaneInOut        in             [[ stage_in ]],
                               texture2d<half> plane_texture [[ texture(AAPLTextureIndexBaseColor) ]])
{
    constexpr sampler textureSampler (mag_filter::linear,
                                      min_filter::linear); // sampler是采样器
    half4 color = plane_texture.sample(textureSampler, in.texcoord);

    return half4(color);
}
