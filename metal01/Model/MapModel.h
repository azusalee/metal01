//
//  MapModel.h
//  metal01
//
//  Created by yangming on 2019/2/1.
//  Copyright © 2019年 AL. All rights reserved.
//

#import <Foundation/Foundation.h>
@import MetalKit;
#import "BoxModel.h"

NS_ASSUME_NONNULL_BEGIN

@interface MapModel : NSObject

- (instancetype)initWith2DSize:(vector_float2)size;
- (instancetype)initWith3DSize:(vector_float3)size;

- (NSArray *)boxArray;

//獲取附近的箱子對象
- (NSArray*)nearBoxArrayWithPosition:(vector_float3)position andFront:(vector_float3)front;

- (vector_float3)startPosition;

- (vector_float3)endPosition;

//获取安全路径
- (NSArray *)safeRouteArray;

//是不是3纬地图(y轴只有1层的就是2D，多层是3D)
- (BOOL)is3D;

@end

NS_ASSUME_NONNULL_END
