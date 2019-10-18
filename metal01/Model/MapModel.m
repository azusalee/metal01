//
//  MapModel.m
//  metal01
//
//  Created by yangming on 2019/2/1.
//  Copyright © 2019年 AL. All rights reserved.
//

#import "MapModel.h"


@interface MapModel()

@property (nonatomic, assign) vector_float3 mapSize;

@property (nonatomic, assign) BOOL is3D;

//保证有一条路径能连接上起点和终点
@property (nonatomic, strong) NSArray *safeRouteArray;
//箱子数组
@property (nonatomic, strong) NSArray *boxArray;

//开始位置
@property (nonatomic, assign) vector_float3 startPosition;
//结束位置
@property (nonatomic, assign) vector_float3 endPosition;

@end

@implementation MapModel

- (instancetype)initWith2DSize:(vector_float2)size{
    if (self = [super init]) {
        _mapSize = (vector_float3){size.x, 1, size.y};
        [self setup2DMap];
    }
    return self;
}

- (instancetype)initWith3DSize:(vector_float3)size{
    if (self = [super init]) {
        _mapSize = size;
        [self setup3DMap];
    }
    return self;
}

- (void)setup2DMap{
    self.is3D = NO;
    CFTimeInterval startTime = CACurrentMediaTime();
    NSInteger maxLengthX = self.mapSize.x;
    //NSInteger maxLengthY = self.mapSize.y;
    NSInteger maxLengthZ = self.mapSize.z;

    NSInteger startX = (NSInteger)(arc4random()%(maxLengthX))+1;
    //NSInteger startY = (NSInteger)(arc4random()%(maxLengthY+1));
    NSInteger startZ = (NSInteger)(arc4random()%(maxLengthZ))+1;

    NSInteger endX = (NSInteger)(arc4random()%(maxLengthX))+1;
    //NSInteger endY = (NSInteger)(arc4random()%(maxLengthY+1));
    NSInteger endZ = (NSInteger)(arc4random()%(maxLengthZ))+1;

    NSInteger outX = 0;
    //NSInteger outY = 0;
    NSInteger outZ = 0;

    NSInteger centerX = 0;
    //NSInteger centerY = 0;
    NSInteger centerZ = 0;

    if (endZ > endX) {
        centerZ = endZ;
        centerX = maxLengthX-endX;

        outX = endX;
        if (endZ < maxLengthZ/2) {
            endZ = 1;
            outZ = 0;
        }else{
            endZ = maxLengthZ;
            outZ = maxLengthZ+1;
        }
    }else{
        centerX = endX;
        centerZ = maxLengthZ - endZ;

        outZ = endZ;
        if (endX < maxLengthX/2) {
            endX = 1;
            outX = 0;
        }else{
            endX = maxLengthX;
            outX = maxLengthX+1;
        }
    }

    NSInteger routeX = startX;
    NSInteger routeZ = startZ;

    NSMutableArray *routeArray = [[NSMutableArray alloc] init];
    //限制路径的长度，以保证复杂度
    routeX = startX;
    routeZ = startZ;

    NSInteger centerID = centerZ*100+centerX;

    while (labs(routeX - endX) + labs(routeZ - endZ) > 1) {

        if (![routeArray containsObject:@(centerID)]) {
            long offsetX = routeX-centerX;
            long offsetZ = routeZ-centerZ;
            int type = arc4random()%2;
            if (offsetX == 0) {
                type = 1;
            }else if (offsetZ == 0){
                type = 0;
            }
            if (type == 0) {
                if (offsetX > 0) {
                    routeX -= 1;
                }else{
                    routeX += 1;
                }
            }else{
                if (offsetZ > 0) {
                    routeZ -= 1;
                }else{
                    routeZ += 1;
                }
            }
        }else{
            long offsetX = routeX-endX;
            long offsetZ = routeZ-endZ;
            int type = arc4random()%2;
            if (offsetX == 0) {
                type = 1;
            }else if (offsetZ == 0){
                type = 0;
            }
            if (type == 0) {
                if (offsetX > 0) {
                    routeX -= 1;
                }else{
                    routeX += 1;
                }
            }else{
                if (offsetZ > 0) {
                    routeZ -= 1;
                }else{
                    routeZ += 1;
                }
            }
        }

        //生成id，例如x最大长度为10，z最大长度为10时，id2010, 表示坐标是x=10, z=20
        NSInteger routeID = routeZ*100+routeX;
        if (![routeArray containsObject:@(routeID)]) {
            [routeArray addObject:@(routeID)];
        }
    }

    self.safeRouteArray = routeArray.copy;

    NSMutableArray *boxArray = [[NSMutableArray alloc] init];
    for (NSInteger x = 0; x <= maxLengthX+1; ++x) {
        for (NSInteger z = 0; z <= maxLengthZ+1; ++z) {
            //不在起点和终点生成箱子
            if (x == startX && z == startZ) {
                continue;
            }
            if (x == endX && z == endZ) {
                continue;
            }
            if (x == outX && z == outZ) {
                continue;
            }
            if (x == 0 || x == maxLengthX+1 || z == 0 || z == maxLengthZ+1) {
                //在边缘位置生成箱子
                BoxModel *box = [[BoxModel alloc] init];
                box.position = (vector_float3){x, 0, z};

                [boxArray addObject:box];
            }else{
                NSInteger routeID = z*100+x;
                if ([self.safeRouteArray containsObject:@(routeID)]) {
                    //不在安全路径处生成箱子
                    continue;
                }

                int ranVal = arc4random()%100;
                //70%概率生成箱子
                if (ranVal < 70) {
                    BoxModel *box = [[BoxModel alloc] init];
                    box.position = (vector_float3){x, 0, z};

                    [boxArray addObject:box];
                }

            }
        }
    }

    self.boxArray = boxArray.copy;

    self.startPosition = (vector_float3){startX, 0, startZ};
    self.endPosition = (vector_float3){outX, 0, outZ};

    CFTimeInterval userTime = CACurrentMediaTime()-startTime;
    NSLog(@"耗时:%0.2f", userTime);
}

- (void)setup3DMap{
    self.is3D = YES;
    CFTimeInterval startTime = CACurrentMediaTime();
    NSInteger maxLengthX = self.mapSize.x;
    NSInteger maxLengthY = self.mapSize.y;
    NSInteger maxLengthZ = self.mapSize.z;

    NSInteger startX = (NSInteger)(arc4random()%(maxLengthX))+1;
    NSInteger startY = (NSInteger)(arc4random()%(maxLengthY))+1;
    NSInteger startZ = (NSInteger)(arc4random()%(maxLengthZ))+1;

    NSInteger endX = (NSInteger)(arc4random()%(maxLengthX))+1;
    NSInteger endY = (NSInteger)(arc4random()%(maxLengthY))+1;
    NSInteger endZ = (NSInteger)(arc4random()%(maxLengthZ))+1;

    int outType = arc4random()%3;

    NSInteger centerX = maxLengthX - endX;
    NSInteger centerZ = maxLengthZ - endZ;
    NSInteger centerY = maxLengthY - endY;

    NSInteger outX = endX;
    NSInteger outZ = endZ;
    NSInteger outY = endY;
    if (outType == 0) {
        //出口在X軸方向
        if (endX < maxLengthX/2) {
            endX = 1;
            outX = 0;
        }else{
            endX = maxLengthX;
            outX = maxLengthX+1;
        }
    }else if (outType == 1) {
        //出口在Y軸方向
        if (endY < maxLengthY/2) {
            endY = 1;
            outY = 0;
        }else{
            endY = maxLengthY;
            outY = maxLengthY+1;
        }
    }else{
        //出口在Z軸方向
        if (endZ < maxLengthZ/2) {
            endZ = 1;
            outZ = 0;
        }else{
            endZ = maxLengthZ;
            outZ = maxLengthZ+1;
        }
    }

    NSInteger routeX = startX;
    NSInteger routeY = startY;
    NSInteger routeZ = startZ;

    NSMutableArray *routeArray = [[NSMutableArray alloc] init];

    NSInteger centerID = centerZ*10000+centerY*100+centerX;

    while (labs(routeX - endX) + (labs(routeY-endY)) + labs(routeZ - endZ) > 1) {
        long offsetX = 0;
        long offsetY = 0;
        long offsetZ = 0;

        if (![routeArray containsObject:@(centerID)]) {
            offsetX = routeX-centerX;
            offsetY = routeY-centerY;
            offsetZ = routeZ-centerZ;
        }else{
            offsetX = routeX-endX;
            offsetY = routeY-endY;
            offsetZ = routeZ-endZ;
        }

        int type = 0;
        if (offsetX == 0) {
            if (offsetY == 0) {
                type = 2;
            }else if (offsetZ == 0){
                type = 1;
            }else{
                type = arc4random()%2+1;
            }
        }else if (offsetY == 0){
            if (offsetZ == 0) {
                type = 0;
            }else{
                type = arc4random()%2;
                if (type == 1) {
                    type = 2;
                }
            }
        }else if (offsetZ == 0){
            type = arc4random()%2;
        }else{
            type = arc4random()%3;
        }

        if (type == 0) {
            if (offsetX > 0) {
                routeX -= 1;
            }else{
                routeX += 1;
            }
        }else if (type == 1){
            if (offsetY > 0) {
                routeY -= 1;
            }else{
                routeY += 1;
            }
        }else{
            if (offsetZ > 0) {
                routeZ -= 1;
            }else{
                routeZ += 1;
            }
        }

        //生成id，例如x最大长度为10，z最大长度为10时，id2010, 表示坐标是x=10, z=20
        NSInteger routeID = routeZ*10000+routeY*100+routeX;
        if (![routeArray containsObject:@(routeID)]) {
            [routeArray addObject:@(routeID)];
        }
    }

    self.safeRouteArray = routeArray.copy;

    NSMutableArray *boxArray = [[NSMutableArray alloc] init];
    for (NSInteger x = 0; x <= maxLengthX+1; ++x) {
        for (NSInteger y = 0; y <= maxLengthY+1; ++y) {
            for (NSInteger z = 0; z <= maxLengthZ+1; ++z) {
                //不在起点和终点生成箱子
                if (x == startX && y == startY && z == startZ) {
                    continue;
                }
                if (x == endX && y == endY && z == endZ) {
                    continue;
                }
                if (x == outX && y == outY && z == outZ) {
                    continue;
                }
                if (x == 0 || x == maxLengthX+1 || y == 0 || y == maxLengthY+1 || z == 0 || z == maxLengthZ+1) {
                    //在边缘位置生成箱子
                    BoxModel *box = [[BoxModel alloc] init];
                    box.position = (vector_float3){x, y, z};
                    [boxArray addObject:box];
                }else{
                    NSInteger routeID = z*10000+y*100+x;
                    if ([self.safeRouteArray containsObject:@(routeID)]) {
                        //不在安全路径处生成箱子
                        continue;
                    }

                    int ranVal = arc4random()%100;
                    //70%概率生成箱子
                    if (ranVal < 70) {
                        BoxModel *box = [[BoxModel alloc] init];
                        box.position = (vector_float3){x, y, z};
                        [boxArray addObject:box];
                    }
                }
            }
        }
    }

    self.boxArray = boxArray.copy;

    self.startPosition = (vector_float3){startX, startY, startZ};
    self.endPosition = (vector_float3){outX, outY, outZ};

    CFTimeInterval userTime = CACurrentMediaTime()-startTime;
    NSLog(@"耗时:%0.2f", userTime);
}

- (NSArray*)nearBoxArrayWithPosition:(vector_float3)position andFront:(vector_float3)front{
    NSMutableArray *nearBoxArray = [[NSMutableArray alloc] init];
    for (int i = 0; i < _boxArray.count; ++i) {
        BoxModel *box = _boxArray[i];
        vector_float3 boxPos = box.position;
        vector_float3 vec = (boxPos-position)*front;

        if (vec.x >= -0.8 && vec.y >= -0.8 && vec.z >= -0.8 ) {
            //獲取當前面向方向的box
            float distacne = vec.x*vec.x+vec.y*vec.y+vec.z*vec.z;
            if (distacne < 64) {
                //把距離自己小于一定值的box加入數組
                [nearBoxArray addObject:box];
            }
        }
    }

    return nearBoxArray.copy;
}

- (NSArray *)boxArray{
    return _boxArray;
}

- (vector_float3)startPosition{
    return _startPosition;
}

- (vector_float3)endPosition{
    return _endPosition;
}

@end
