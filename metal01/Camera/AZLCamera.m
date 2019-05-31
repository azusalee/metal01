//
//  AZLCameraControl.m
//  metal01
//
//  Created by yangming on 2019/1/16.
//  Copyright © 2019年 AL. All rights reserved.
//

#import "AZLCamera.h"
#import "AAPLMathUtilities.h"


static const float MaxPitchValue = M_PI_2-0.1;

static const float NearPlaneValue = 0.05;
static const float FarPlaneValue = 50;


@interface AZLCamera()
{
    float _roll;
    float _pitch;
}

@end

@implementation AZLCamera

- (instancetype)init{
    if (self = [super init]) {
        _roll = M_PI_2;
        _pitch = 0;
        _position = (vector_float3){0,0,-2};
        _fovyAngle = 65;
    }
    return self;
}

- (void)moveWithVelocity:(vector_float2)velocity{
    vector_float3 move = self.right*velocity.x+self.front*velocity.y;
    //不在y轴上移动
    if (self.canMoveY == NO) {
        move.y = 0;
    }

    self.position = self.position+move;
}

- (matrix_float4x4)updateViewMatrixWithVelocity:(vector_float2)velocity{
    float roll = _roll+velocity.x;
    float pitch = _pitch+velocity.y;

    //限制最大值和最小值
    if (pitch > MaxPitchValue) {
        pitch = MaxPitchValue;
    }else if (pitch < -MaxPitchValue) {
        pitch = -MaxPitchValue;
    }

    _roll = roll;
    _pitch = pitch;

    vector_float3 front = {cosf(roll)*cosf(pitch),
        sinf(pitch),
        sinf(roll)*cosf(pitch)};
    front = simd_normalize(front);
    self.front = front;

    vector_float3 upVector = {0, 1, 0};
    vector_float3 right = simd_normalize(simd_cross(front, upVector));
    self.right = right;
    vector_float3 up = simd_normalize(simd_cross(right, front));
    self.up = up;

    matrix_float4x4 viewMatrix = matrix_look_at_right_hand(self.position.x, self.position.y, self.position.z, self.position.x+front.x, self.position.y+front.y, self.position.z+front.z, up.x, up.y, up.z);

    self.view_matrix = viewMatrix;

    return viewMatrix;
}

- (void)setViewportSize:(vector_uint2)viewportSize{
    [self updateProjectionMatrixWithAngle:self.fovyAngle viewPort:viewportSize];
}

- (void)setFovyAngle:(float)fovyAngle{
    [self updateProjectionMatrixWithAngle:fovyAngle viewPort:self.viewportSize];
}

- (void)updateProjectionMatrixWithAngle:(float)angle viewPort:(vector_uint2)viewportSize{
    if (angle > 89) {
        angle = 89;
    }else if(angle < 25) {
        angle = 25;
    }
    _fovyAngle = angle;
    _viewportSize = viewportSize;
    if (viewportSize.y > 0) {
        float aspect = viewportSize.x / (float)viewportSize.y;
        self.projection_matrix = matrix_perspective_right_hand(angle * (M_PI / 180.0f), aspect, NearPlaneValue, FarPlaneValue);
    }
}


@end
