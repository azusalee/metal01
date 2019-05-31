//
//  AZLCameraControl.h
//  metal01
//
//  Created by yangming on 2019/1/16.
//  Copyright © 2019年 AL. All rights reserved.
//

#import <Foundation/Foundation.h>
@import MetalKit;

NS_ASSUME_NONNULL_BEGIN

@interface AZLCamera : NSObject

//位置
@property (nonatomic, assign) vector_float3 position;

//投影角
@property (nonatomic, assign) float fovyAngle;
@property (nonatomic, assign) vector_uint2 viewportSize;

//前向量
@property (nonatomic, assign) vector_float3 front;
//右向量
@property (nonatomic, assign) vector_float3 right;
//上向量
@property (nonatomic, assign) vector_float3 up;

//投影矩阵
@property (nonatomic, assign) matrix_float4x4 projection_matrix;

//觀察矩阵
@property (nonatomic, assign) matrix_float4x4 view_matrix;

//能不能再y轴上移动
@property (nonatomic, assign) BOOL canMoveY;



//更新观察矩阵，front，right，up也会更新
- (matrix_float4x4)updateViewMatrixWithVelocity:(vector_float2)velocity;
//更新投影矩阵
- (void)updateProjectionMatrixWithAngle:(float)angle viewPort:(vector_uint2)viewportSize;
//移动位置
- (void)moveWithVelocity:(vector_float2)velocity;


@end

NS_ASSUME_NONNULL_END
