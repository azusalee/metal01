//
//  RouteShader.metal
//  metal01
//
//  Created by lizihong on 2019/10/18.
//  Copyright © 2019 AL. All rights reserved.
//

#include <metal_stdlib>
#import "ALShaderTypes.h"

using namespace metal;

typedef struct
{
    float4 position [[position]];
} RouteInOut;

vertex RouteInOut routeVertexShader(uint vertexID [[vertex_id]],
             constant ALRouteVertex *vertices [[buffer(0)]],
             constant ALMatrix &matrix [[ buffer(1) ]])
{
    RouteInOut out;

    // Initialize our output clip space position
    out.position = vector_float4(0.0, 0.0, 0.0, 1.0);

    float3 pixelSpacePosition = vertices[vertexID].position.xyz;

    out.position.xyz = pixelSpacePosition;
    out.position = matrix.projectionMatrix * matrix.viewMatrix * matrix.modelMatrix * out.position;
    
    return out;
}

fragment half4 routeFragmentShader(RouteInOut        in             [[ stage_in ]],
                                    constant float &runTime [[ buffer(1) ]])
{   
    int time_int = runTime;
    half r = sin(time_int/360.0f*3.1415926)*0.5+0.5;
    half g = sin(time_int/240.0f*3.1415926)*0.5+0.5;
    half b = sin(time_int/120.0f*3.1415926)*0.5+0.5;
    half4 color = half4{r, g, b, 1.0};
    return half4(color);
}
