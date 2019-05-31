//
//  ALShaderTypes.h
//  metal01
//
//  Created by yangming on 2018/12/26.
//  Copyright © 2018年 AL. All rights reserved.
//

#ifndef ALShaderTypes_h
#define ALShaderTypes_h

#import <simd/simd.h>

typedef enum AAPLBufferIndices
{
    AAPLBufferIndexMeshPositions     = 0,
    AAPLBufferIndexMeshGenerics      = 1,
    AAPLBufferIndexUniforms          = 2,
    AAPLBufferIndexLightsData        = 3,
    AAPLBufferIndexLightsPosition    = 4,

#if SUPPORT_BUFFER_EXAMINATION_MODE
    AAPLBufferIndexFlatColor         = 0,
    AAPLBufferIndexDepthRange        = 0,
#endif

} AAPLBufferIndices;

typedef enum AAPLRenderTargetIndices
{
    AAPLRenderTargetLighting  = 0,
    AAPLRenderTargetAlbedo    = 1,
    AAPLRenderTargetNormal    = 2,
    AAPLRenderTargetDepth     = 3
} AAPLRenderTargetIndices;

typedef enum AAPLTextureIndices
{
    AAPLTextureIndexBaseColor = 0,
    AAPLTextureIndexSpecular  = 1,
    AAPLTextureIndexNormal    = 2,
    AAPLTextureIndexShadow    = 3,
    AAPLTextureIndexAlpha     = 4,

    AAPLNumMeshTextures = AAPLTextureIndexNormal + 1

} AAPLTextureIndices;

typedef enum AAPLVertexAttributes
{
    AAPLVertexAttributePosition  = 0,
    AAPLVertexAttributeTexcoord  = 1,
    AAPLVertexAttributeNormal    = 2,
    AAPLVertexAttributeTangent   = 3,
    AAPLVertexAttributeBitangent = 4
} AAPLVertexAttributes;

typedef struct
{
    vector_float3 position;
    vector_float4 color;
    vector_float2 textureCoordinate;
    vector_float3 normal;
} ALVertex;

typedef struct
{
    matrix_float4x4 projectionMatrix; // 投影变换
    matrix_float4x4 modelMatrix; // 模型变换
    matrix_float4x4 viewMatrix;
} ALMatrix;

typedef struct
{
    vector_float3 direction; // 光的方向
    vector_float3 ambient; // 环境光
    vector_float3 diffuse; // 漫反射光
    vector_float3 specular; // 镜面光
} ALDirectLight;//平行光

typedef struct
{
    vector_float3 position; // 聚光位置
    vector_float3 direction; // 聚光方向
    float cutOff; // 内圆
    float outerCutOff; // 外圆

    float constan;
    float linear;
    float quadratic;

    vector_float3 diffuse;
    vector_float3 ambient;
    vector_float3 specular;

} ALSpotLight;//聚光

typedef enum ALVertexInputIndex
{
    ALVertexInputIndexVertices     = 0,
    ALVertexInputIndexMatrix       = 1,
    ALVertexInputIndexTransposInverse       = 2,

} ALVertexInputIndex;

typedef enum ALFragmentTextureIndex
{
    
    ALFragmentInputIndexDirectLight       = 2,
    ALFragmentInputIndexViewpos       = 3,
    ALFragmentInputIndexSpotLight       = 4,
    ALFragmentInputIndexTime      = 5,
    
} ALFragmentTextureIndex;


typedef enum ALComputeTextureIndex
{
    ALComputeTextureIndexTextureSource     = 0,
    ALComputeTextureIndexTextureDest       = 1,
    ALComputeTextureIndexTime       = 2,
} ALComputeTextureIndex;




#endif /* ALShaderTypes_h */
