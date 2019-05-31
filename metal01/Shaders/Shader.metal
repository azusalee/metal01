//
//  Shader.metal
//  metal01
//
//  Created by yangming on 2018/12/17.
//  Copyright © 2018年 AL. All rights reserved.
//

#include <metal_stdlib>
#import "ALShaderTypes.h"

using namespace metal;

typedef struct
{
    // The [[position]] attribute of this member indicates that this value is the clip space
    // position of the vertex when this structure is returned from the vertex function
    float4 clipSpacePosition [[position]];

    // Since this member does not have a special attribute, the rasterizer interpolates
    // its value with the values of the other triangle vertices and then passes
    // the interpolated value to the fragment shader for each fragment in the triangle
    float4 color;

    float2 textureCoordinate; // 纹理坐标，会做插值处理
    float3 normal;
    float3 fragPos;

} RasterizerData;

vertex RasterizerData
vertexShader(uint vertexID [[vertex_id]],
             constant ALVertex *vertices [[buffer(ALVertexInputIndexVertices)]],
             constant ALMatrix &matrix [[ buffer(ALVertexInputIndexMatrix) ]],
             constant float3x3 &transposeInverse [[ buffer(ALVertexInputIndexTransposInverse) ]])
{
    RasterizerData out;

    // Initialize our output clip space position
    out.clipSpacePosition = vector_float4(0.0, 0.0, 0.0, 1.0);

    // Index into our array of positions to get the current vertex
    //   Our positions are specified in pixel dimensions (i.e. a value of 100 is 100 pixels from
    //   the origin)
    float3 pixelSpacePosition = vertices[vertexID].position.xyz;

    // Dereference viewportSizePointer and cast to float so we can do floating-point division
    //vector_float2 viewportSize = vector_float2(*viewportSizePointer);

    // The output position of every vertex shader is in clip-space (also known as normalized device
    //   coordinate space, or NDC).   A value of (-1.0, -1.0) in clip-space represents the
    //   lower-left corner of the viewport whereas (1.0, 1.0) represents the upper-right corner of
    //   the viewport.

    // Calculate and write x and y values to our clip-space position.  In order to convert from
    //   positions in pixel space to positions in clip-space, we divide the pixel coordinates by
    //   half the size of the viewport.
    out.clipSpacePosition.xyz = pixelSpacePosition;
    out.clipSpacePosition = matrix.projectionMatrix * matrix.viewMatrix * matrix.modelMatrix * out.clipSpacePosition;


    // Pass our input color straight to our output color.  This value will be interpolated
    //   with the other color values of the vertices that make up the triangle to produce
    //   the color value for each fragment in our fragment shader
    out.color = vertices[vertexID].color;

    out.textureCoordinate = vertices[vertexID].textureCoordinate;
    out.normal = normalize(((transposeInverse)*vertices[vertexID].normal));
    //out.normal = normalize((vertices[vertexID].normal));
    out.fragPos = (matrix.modelMatrix*float4(pixelSpacePosition, 1.0f)).xyz;

    return out;
}


//计算聚光
float3
calculateSpotLight(ALSpotLight light, float3 normal, float3 fragPos, float3 viewDir, half4 diffuseColor, float3 specColor){
    float3 lightDir = normalize(light.position - fragPos);

    float3 ambient = light.ambient * float3(diffuseColor.rgb);
    float diff = max(dot(normal, lightDir), 0.0f);
    float3 diffuse = light.diffuse * diff * float3(diffuseColor.rgb);

    float3 reflectDir = reflect(-lightDir, normal);
    float spec = pow(max(dot(viewDir, reflectDir), 0.0f), 32.0f);
    float3 specular = light.specular * spec * specColor;

    //聚光边缘衰减
    float theta     = dot(lightDir, normalize(-light.direction));
    float epsilon   = light.cutOff - light.outerCutOff;
    float intensity = clamp((theta - light.outerCutOff) / epsilon, 0.0f, 1.0f);

    diffuse  *= intensity;
    specular *= intensity;

    // attenuation 衰减计算 距离
    float distance    = length(light.position - fragPos);
    float attenuation = 1.0f / (light.constan + light.linear * distance + light.quadratic * (distance * distance));

    ambient  *= attenuation;
    diffuse   *= attenuation;
    specular *= attenuation;

    return (ambient + diffuse + specular);
}

//残影效果
half4 ghostEffect(int time, float2 textureCoordinate, sampler textureSampler, texture2d<half> colorTexture) {
    float scale = 1.2;
    float padding = 0.5 * (1.0 - 1.0 / scale);
    float2 textureCoords = float2(0.5, 0.5) + (textureCoordinate - float2(0.5, 0.5)) / scale;
    int duration = 120;//帧数/周期（目前是60帧/秒）
    int timeGap = 12;
    
    //这几个值越大，偏移的效果越明显（值设得太大会给人一种恶心头晕的感觉）
    half maxAlphaR = 0.25; // max R
    half maxAlphaG = 0.08; // max G
    half maxAlphaB = 0.08; // max B
    
    half alphaR = 1.0; // R
    half alphaG = 1.0; // G
    half alphaB = 1.0; // B
    
    half4 result = half4{0, 0, 0, 0};
    
    float timeProgress = time%duration/float(duration);
    
    for (int f = 0; f < duration; f += timeGap) {
        float tmpProgress = int(duration+time-f)%duration/float(duration);
        float2 translation = float2{sin(tmpProgress * 3.1415926*2),
            cos(f * 3.1415926*2)};
        half4 tmpMask = colorTexture.sample(textureSampler, textureCoords+padding*translation);
        half missPercent = f/(float)duration;
        half tmpAlphaR = maxAlphaR - maxAlphaR * missPercent;
        half tmpAlphaG = maxAlphaG - maxAlphaG * missPercent;
        half tmpAlphaB = maxAlphaB - maxAlphaB * missPercent;
        
        result += half4{tmpMask.r * tmpAlphaR,
                           tmpMask.g * tmpAlphaG,
                           tmpMask.b * tmpAlphaB,
            1.0};
        alphaR -= tmpAlphaR;
        alphaG -= tmpAlphaG;
        alphaB -= tmpAlphaB;
    }
    float2 translation = float2{sin(timeProgress * 3.1415926*2),
        cos(timeProgress * 3.1415926*2)};
    half4 mask = colorTexture.sample(textureSampler, textureCoords+padding*translation);
    
    result += half4{mask.r * alphaR, mask.g * alphaG, mask.b * alphaB, 1.0};
    return result;
}

//2d布丁摇动效果
float getA(float2 point1, float2 point2) {
    return point2.y - point1.y;
}

float getB(float2 point1, float2 point2) {
    return point1.x - point2.x;
}

float getC(float2 point1, float2 point2) {
    return point2.x * point1.y - point1.x * point2.y;
}

float getT1(float2 point1, float2 point2, float2 point3, float a, float b, float c) {
    float t = -(sqrt((((-point3.y) + 2.0 * point2.y - point1.y) * b + ((-point3.x) + 2.0 * point2.x -point1.x) * a) * c + (pow(point2.y, 2.0) - point1.y * point3.y) * pow(b, 2.0) + ((-point1.x * point3.y) + 2.0 * point2.x * point2.y - point3.x * point1.y) * a * b +(pow(point2.x, 2.0)-point1.x * point3.x) * pow(a, 2.0)) + (point2.y - point1.y) * b + (point2.x - point1.x) * a) / ((point3.y - 2.0 * point2.y + point1.y) * b + (point3.x - 2.0 * point2.x + point1.x) * a);
    return t;
}

float getT2(float2 point1, float2 point2, float2 point3, float a, float b, float c) {
    float t = (sqrt((((-point3.y) + 2.0 * point2.y - point1.y) * b + ((-point3.x) + 2.0 * point2.x - point1.x) * a) * c + (pow(point2.y, 2.0) - point1.y * point3.y) * pow(b, 2.0) + ((-point1.x * point3.y) + 2.0 * point2.x * point2.y - point3.x * point1.y) * a * b + (pow(point2.x, 2.0) - point1.x * point3.x) * pow(a, 2.0)) + (point1.y - point2.y) * b + (point1.x - point2.x) * a) / ((point3.y - 2.0 * point2.y + point1.y) * b + (point3.x - 2.0 * point2.x + point1.x) * a);
    return t;
}

float2 getPoint(float2 point1, float2 point2, float2 point3, float t) {
    float2 point = pow(1.0 - t, 2.0) * point1 + 2.0 * t * (1.0 - t) * point2 + pow(t, 2.0) * point3;
    return point;
}

bool isPointInside(float2 point, float2 point1, float2 point2) {
    float2 tmp1 = point - point1;
    float2 tmp2 = point - point2;
    return tmp1.x * tmp2.x <= 0.0 && tmp1.y * tmp2.y <= 0.0;
}

float getMaxDistance(float2 point, float2 point1, float2 point2, float2 point3, float2 center, float a, float b, float c) {
    float T1 = getT1(point1, point2, point3, a, b, c);
    float T2 = getT2(point1, point2, point3, a, b, c);
    
    float resultDistance = -1.0;
    if (T1 >= 0.0 && T1 <= 1.0) {
        float2 p = getPoint(point1, point2, point3, T1);
        if (isPointInside(point, p, center)) {
            resultDistance = distance(p, center);
        }
    } else if (T2 >= 0.0 && T2 <= 1.0) {
        float2 p = getPoint(point1, point2, point3, T2);
        if (isPointInside(point, p, center)) {
            resultDistance = distance(p, center);
        }
    }
    return resultDistance;
}

float getMaxCenterOffset(float2 pointLT, float2 pointRT, float2 pointRB, float2 pointLB) {
    float minX = min(min(pointLT.x, pointRT.x), min(pointRB.x, pointLB.x));
    float maxX = max(max(pointLT.x, pointRT.x), max(pointRB.x, pointLB.x));
    float minY = min(min(pointLT.y, pointRT.y), min(pointRB.y, pointLB.y));
    float maxY = max(max(pointLT.y, pointRT.y), max(pointRB.y, pointLB.y));
    
    float maxWidth = maxX - minX;
    float maxHeight = maxY - minY;
    
    return min(maxWidth, maxHeight) * 0.08;
}

float2 getOffset(float2 pointLT, float2 pointRT, float2 pointRB, float2 pointLB, float2 center, int time, float2 targetPoint, float2 direction, float amplitude) {
    int Duration = 60;
    int totalStep = 6;
    float PI = 3.1415926;
    float distanceToCenter = distance(targetPoint, center);
    float maxDistance = 0.0;
    
    int curStep = (time%(totalStep*Duration))/Duration;
    amplitude = pow(0.7, curStep);
    if (amplitude < 0.1) {
        amplitude = 0;
    }
    
    float2 centerLeft = (pointLT + pointLB) / 2.0;
    float2 centerTop = (pointLT + pointRT) / 2.0;
    float2 centerRight = (pointRT + pointRB) / 2.0;
    float2 centerBottom = (pointRB + pointLB) / 2.0;
    
    float a = getA(center, targetPoint);
    float b = getB(center, targetPoint);
    float c = getC(center, targetPoint);
    
    int times = 0;
    float resultDistance = -1.0;
    
    float maxCenterDistance = getMaxCenterOffset(pointLT, pointRT, pointRB, pointLB) * amplitude;
    
    while (resultDistance < 0.0 && times < 4) {
        float2 point1;
        float2 point2;
        float2 point3;
        if (times == 0) {
            point1 = centerLeft;
            point2 = pointLT;
            point3 = centerTop;
        } else if (times == 1) {
            point1 = centerTop;
            point2 = pointRT;
            point3 = centerRight;
        } else if (times == 2) {
            point1 = centerRight;
            point2 = pointRB;
            point3 = centerBottom;
        } else {
            point1 = centerLeft;
            point2 = pointLB;
            point3 = centerBottom;
        }
        resultDistance = getMaxDistance(targetPoint,
                                        point1, point2, point3,
                                        center,
                                        a, b, c);
        if (resultDistance >= maxDistance) {
            maxDistance = resultDistance;
        }
        times++;
    }
    
    float2 offset = float2(0, 0);
    if (maxDistance > 0.0 && distanceToCenter <= maxDistance) {
        float x = (2*time)%Duration;
        x = x > 0.5*Duration ? (Duration - x) : x;
        if (x != 0) {
            x = x / (0.5 * Duration);
            float centerOffsetAngle = acos(maxCenterDistance / maxDistance);
            float currentAngle = acos(distanceToCenter / maxDistance);
            float currentOffsetAngle = currentAngle * centerOffsetAngle / (PI / 2.0);
            float currentOffset = maxDistance * (cos(currentOffsetAngle) - cos(currentAngle));
            
            float progress = (time + 0.5 * Duration) / abs(time + 0.5 * Duration) * (2.0 * x - pow(x, 2.0));
            
            offset = float2(currentOffset * direction.x, currentOffset * direction.y) * progress;
        }
    }
    
    return offset;
}
//------

fragment float4 fragmentShader(RasterizerData in [[stage_in]],
                               texture2d<half> colorTexture [[ texture(0) ]],
                               texture2d<half> specTexture [[ texture(1) ]],
                               constant ALDirectLight &directLight [[ buffer(ALFragmentInputIndexDirectLight) ]],
                               constant float3 &viewPos [[ buffer(ALFragmentInputIndexViewpos) ]],
                               constant ALSpotLight &spotLight [[ buffer(ALFragmentInputIndexSpotLight) ]],
                               constant float &runTime [[ buffer(ALFragmentInputIndexTime) ]])
{
    constexpr sampler textureSampler (mag_filter::linear,
                                      min_filter::linear); // sampler是采样器
    int time_int = runTime;
    //  毛刺效果（通過偏移紋理的x坐標），注意：观察矩阵改变后，效果会出问题
//    float maxJitter = 0.06;
//    float duration = 30;//多少帧一个循环
//    float amplitude = max(sin(time_int%int(duration)/duration * 3.1415926), 0.0);
//    float jitter = sin(in.textureCoordinate.y*43758.5453123); //fract(sin(in.textureCoordinate.y) * 43758.5453123)*2-1;
//    bool needOffset = abs(jitter) < maxJitter * amplitude;
//    float textureX = in.textureCoordinate.x + (needOffset ? jitter : (jitter * amplitude * 0.006));
//    float2 textureCoords = float2(textureX, in.textureCoordinate.y);
//    half4 colorSample = colorTexture.sample(textureSampler, textureCoords); // 得到纹理对应位置的颜色
 
//    //偏色效果（对R和B的顏色分別偏移采样，也就是RGB的3个采样位置都不一样）
//    float colorROffset = 0.01;
//    float colorBOffset = -0.025;
//    half4 colorSampleR = colorTexture.sample(textureSampler, textureCoords + float2(colorROffset * amplitude, 0.0));
//    half4 colorSampleB = colorTexture.sample(textureSampler, textureCoords + float2(colorBOffset * amplitude, 0.0));
//    colorSample.r = colorSampleR.r;
//    colorSample.b = colorSampleB.b;
    
    //残影效果
    //half4 colorSample = ghostEffect(time_int, in.textureCoordinate, textureSampler, colorTexture);
    
    //布丁效果
    float2 offset = getOffset(float2(0.2, 0.8), float2(0.8, 0.8), float2(0.8, 0.25), float2(0.2, 0.25), float2(0.5, 0.5), time_int, in.textureCoordinate, float2(0.3, 1.59), 1.0);
    half4 colorSample = colorTexture.sample(textureSampler, in.textureCoordinate+offset);

    // 正常显示
    //half4 colorSample = colorTexture.sample(textureSampler, in.textureCoordinate);
    
    half4 specSample = specTexture.sample(textureSampler, in.textureCoordinate);

    float3 viewDir = normalize(viewPos.xyz - in.fragPos);
    float3 normal = in.normal;
    float3 result = float3(0.0f, 0.0f, 0.0f);
    
    //平行光计算
    float3 lightDir = normalize(-directLight.direction);
    float diff = max(dot(normal, lightDir), 0.0);

    float3 reflectDir = reflect(-lightDir, normal);
    float spec = pow(max(dot(viewDir, reflectDir), 0.0), 32);
    float3 ambient  = directLight.ambient  * float3(colorSample.rgb);
    float3 diffuse  = directLight.diffuse  * diff * float3(colorSample.rgb);
    float3 specular = directLight.specular * spec * (float3)(specSample.rgb);
    result += ambient+diffuse+specular;

    //聚光计算
    result += calculateSpotLight(spotLight, normal, in.fragPos, viewDir, colorSample, (float3)(specSample.rgb));
    //return vector_float4(colorSample.r*in.color.r, colorSample.g*in.color.g, colorSample.b*in.color.b, colorSample.a);
    return float4(result, 1.0f);
    //return float4(colorSample)*in.color;// + vector_float4((in.color).xyz, 0);
    //return in.color;
}

kernel void
originalKernel(texture2d<half, access::read>  sourceTexture  [[texture(ALComputeTextureIndexTextureSource)]],
           texture2d<half, access::write> destTexture [[texture(ALComputeTextureIndexTextureDest)]],
           uint2                          grid         [[thread_position_in_grid]])
{
    half4 color  = sourceTexture.read(grid); // 初始颜色
    //原色输出
    destTexture.write(color, grid);
}

constant half3 kRec709Luma = half3(0.2126, 0.7152, 0.0722); // 把rgba转成亮度值

kernel void
grayKernel(texture2d<half, access::read>  sourceTexture  [[texture(ALComputeTextureIndexTextureSource)]],
           texture2d<half, access::write> destTexture [[texture(ALComputeTextureIndexTextureDest)]],
           constant float &runTime [[ buffer(ALComputeTextureIndexTime) ]],
           uint2                          grid         [[thread_position_in_grid]])
{

//    //毛刺效果（通過偏移紋理的x坐標）
//    float width = destTexture.get_width();
//    float height = destTexture.get_height();
//    float2 textureCoordinate = float2{grid.x/width, grid.y/height};
//    float maxJitter = 0.06;
//    float duration = 30;//多少帧一个循环
//    float colorROffset = 0.01;
//    float colorBOffset = -0.025;
//    int time_int = runTime;
//    float amplitude = max(sin(time_int%int(duration)/duration * 3.1415926), 0.0);
//    float jitter = fract(sin(textureCoordinate.y) * 43758.5453123)*2-1;
//    bool needOffset = abs(jitter) < maxJitter * amplitude;
//    float textureX = textureCoordinate.x + (needOffset ? jitter : (jitter * amplitude * 0.006));
//    float2 textureCoords = float2(textureX, textureCoordinate.y);
//    uint2 desGrid = uint2{uint(textureCoords.x*width), uint(textureCoords.y*height)};
//    half4 color = sourceTexture.read(desGrid);
    
    //偏色效果（对R和B的顏色分別偏移采样，也就是RGB的3个采样位置都不一样）
//    half4 colorSampleR = colorTexture.sample(textureSampler, textureCoords + float2(colorROffset * amplitude, 0.0));
//    half4 colorSampleB = colorTexture.sample(textureSampler, textureCoords + float2(colorBOffset * amplitude, 0.0));
//    colorSample.r = colorSampleR.r;
//    colorSample.b = colorSampleB.b;

    // 边界保护
//    if(grid.x <= destTexture.get_width() && grid.y <= destTexture.get_height())
//    {
    //图像180度旋转
    //uint2 desGrid = uint2{destTexture.get_width()-grid.x, destTexture.get_height()-grid.y};
        half4 color  = sourceTexture.read(grid); // 初始颜色
    //原色输出
    //destTexture.write(color, grid);
    //灰度处理后输出
        half  gray     = dot(color.rgb, kRec709Luma); // 转换成亮度
        destTexture.write(half4(gray, gray, gray, 1.0), grid); // 写回对应纹理
    //}
}

constant half sobelStep = 2.0;

kernel void
sobelKernel(texture2d<half, access::read>  sourceTexture  [[texture(ALComputeTextureIndexTextureSource)]],
           texture2d<half, access::write> destTexture [[texture(ALComputeTextureIndexTextureDest)]],
                uint2                          grid         [[thread_position_in_grid]])
{
    /*
     
     行数     9个像素          位置
     上     | * * * |      | 左 中 右 |
     中     | * * * |      | 左 中 右 |
     下     | * * * |      | 左 中 右 |
     
     */
    half4 topLeft = sourceTexture.read(uint2(grid.x - sobelStep, grid.y - sobelStep)); // 左上
    half4 top = sourceTexture.read(uint2(grid.x, grid.y - sobelStep)); // 上
    half4 topRight = sourceTexture.read(uint2(grid.x + sobelStep, grid.y - sobelStep)); // 右上
    half4 centerLeft = sourceTexture.read(uint2(grid.x - sobelStep, grid.y)); // 中左
    half4 centerRight = sourceTexture.read(uint2(grid.x + sobelStep, grid.y)); // 中右
    half4 bottomLeft = sourceTexture.read(uint2(grid.x - sobelStep, grid.y + sobelStep)); // 下左
    half4 bottom = sourceTexture.read(uint2(grid.x, grid.y + sobelStep)); // 下中
    half4 bottomRight = sourceTexture.read(uint2(grid.x + sobelStep, grid.y + sobelStep)); // 下右
    
    half4 h = -topLeft - 2.0 * top - topRight + bottomLeft + 2.0 * bottom + bottomRight; // 横方向差别
    half4 v = -bottom - 2.0 * centerLeft - topLeft + bottomRight + 2.0 * centerRight + topRight; // 竖方向差别
    
    half  grayH  = dot(h.rgb, kRec709Luma); // 转换成亮度
    half  grayV  = dot(v.rgb, kRec709Luma); // 转换成亮度
    
    // sqrt(h^2 + v^2)，相当于求点到(h, v)的距离，所以可以用length
    half color = length(half2(grayH, grayV));
    
    destTexture.write(half4(color, color, color, 1.0), grid); // 写回对应纹理
}


kernel void
bgrKernel(texture2d<half, access::read>  sourceTexture  [[texture(ALComputeTextureIndexTextureSource)]],
           texture2d<half, access::write> destTexture [[texture(ALComputeTextureIndexTextureDest)]],
                uint2                          grid         [[thread_position_in_grid]])
{
    half4 color  = sourceTexture.read(grid);
    
    destTexture.write(half4(color.b, color.g, color.r, 1.0), grid); // 写回对应纹理
}

kernel void
mosaicKernel(texture2d<half, access::read>  sourceTexture  [[texture(ALComputeTextureIndexTextureSource)]],
           texture2d<half, access::write> destTexture [[texture(ALComputeTextureIndexTextureDest)]],
                uint2                          grid         [[thread_position_in_grid]])
{
    uint mosiclevel = 8;
    uint gridx = grid.x/mosiclevel*mosiclevel;
    uint gridy = grid.y/mosiclevel*mosiclevel;
    half4 color = half4(0, 0, 0, 0);
    for (uint i = 0; i < mosiclevel; ++i) {
        for (uint j = 0; j < mosiclevel; ++j) {
            half4 tmpcolor  = sourceTexture.read(uint2(gridx+i, gridy+j));
            color += tmpcolor;
        }
    }

    color = color/(mosiclevel*mosiclevel);
    
    destTexture.write(color, grid); // 写回对应纹理
}

kernel void
waveKernel(texture2d<half, access::read>  sourceTexture  [[texture(ALComputeTextureIndexTextureSource)]],
           texture2d<half, access::write> destTexture [[texture(ALComputeTextureIndexTextureDest)]],
           constant float &runTime [[ buffer(ALComputeTextureIndexTime) ]],
           uint2                          grid         [[thread_position_in_grid]])
{

    half4 color  = sourceTexture.read(uint2(grid.x, grid.y+15*sin(grid.x/100.0f+runTime/60*3.1415926))); 
    destTexture.write(color, grid);
}

kernel void
embossingKernel(texture2d<half, access::read>  sourceTexture  [[texture(ALComputeTextureIndexTextureSource)]],
           texture2d<half, access::write> destTexture [[texture(ALComputeTextureIndexTextureDest)]],
                uint2                          grid         [[thread_position_in_grid]])
{
    /*
     
     行数     9个像素          位置
     上     | -1 -1  0 |      | 左 中 右 |
     中     | -1  0  1 |      | 左 中 右 |
     下     |  0  1  1 |      | 左 中 右 |
     
     */
    half4 topLeft = sourceTexture.read(uint2(grid.x - 1, grid.y - 1)); // 左上
    half4 top = sourceTexture.read(uint2(grid.x, grid.y - 1)); // 上
    //half4 topRight = sourceTexture.read(uint2(grid.x + 1, grid.y - 1)); // 右上
    half4 centerLeft = sourceTexture.read(uint2(grid.x - 1, grid.y)); // 中左
    half4 centerRight = sourceTexture.read(uint2(grid.x + 1, grid.y)); // 中右
    //half4 bottomLeft = sourceTexture.read(uint2(grid.x - 1, grid.y + 1)); // 下左
    half4 bottom = sourceTexture.read(uint2(grid.x, grid.y + 1)); // 下中
    half4 bottomRight = sourceTexture.read(uint2(grid.x + 1, grid.y + 1)); // 下右
    
    half4 color = -topLeft -top -centerLeft + bottom + bottomRight + centerRight; // 横方向差别
    
    destTexture.write(half4(color.r+0.5, color.g+0.5, color.b+0.5, 1.0), grid); // 写回对应纹理
}

kernel void
motionBlurKernel(texture2d<half, access::read>  sourceTexture  [[texture(ALComputeTextureIndexTextureSource)]],
           texture2d<half, access::write> destTexture [[texture(ALComputeTextureIndexTextureDest)]],
           constant float &runTime [[ buffer(ALComputeTextureIndexTime) ]],
                uint2                          grid         [[thread_position_in_grid]])
{
    /*
     
     行数     9个像素          位置
     上     | 1 0 0 |      | 左 中 右 |
     中     | 0 1 0 |      | 左 中 右 |
     下     | 0 0 1 |      | 左 中 右 |
     
     */
    uint motionLevel = (int)runTime%60;
    
    uint texWidth = destTexture.get_width();
    uint texHeight = destTexture.get_height();
     
    half4 color = sourceTexture.read(uint2(grid.x, grid.y));
    for (uint i = 1; i <= motionLevel; ++i) {
        if (grid.x < i || grid.x+i > texWidth || grid.y < i || grid.y+i > texHeight) {
            motionLevel = i-1;
            break;
        }
        color += sourceTexture.read(uint2(grid.x-i, grid.y-i));
        color += sourceTexture.read(uint2(grid.x+i, grid.y+i));
    }
    color = color/(2*motionLevel+1);
    
    destTexture.write(color, grid); // 写回对应纹理
}

