//
//  MazeGame.m
//  metal01
//
//  Created by yangming on 2019/2/13.
//  Copyright © 2019年 AL. All rights reserved.
//

#import "MazeGame.h"
#import "SettingManager.h"


@interface MazeGame()

@property (nonatomic, readwrite, strong) MapModel *map;
@property (nonatomic, readwrite, strong) AZLCamera *camera;

@property (nonatomic, assign) MazeGameState gameState;
//使用時間(這裡記錄的是幀數，60幀/s)
@property (nonatomic, assign) NSInteger useTime;

@end

@implementation MazeGame

- (instancetype)init{
    if (self = [super init]) {
        [self setup];
    }
    return self;
}

- (void)setup{
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(receiveSettingChange:) name:kNotificationSettingDidChange object:nil];
    self.camera = [[AZLCamera alloc] init];
    [self resetGame];
    [self startGame];
}

- (void)receiveSettingChange:(NSNotification*)notification{
    [self resetGame];
    [self startGame];
}

- (void)resetGame{
    self.useTime = 0;
    if ([SettingManager sharedInstance].yLength == 1){
        self.map = [[MapModel alloc] initWith2DSize:(vector_float2){[SettingManager sharedInstance].xLength, [SettingManager sharedInstance].zLength}];
        self.camera.canMoveY = NO;
    }else{
        self.map = [[MapModel alloc] initWith3DSize:(vector_float3){[SettingManager sharedInstance].xLength,[SettingManager sharedInstance].yLength, [SettingManager sharedInstance].zLength}];
        self.camera.canMoveY = YES;
    }

    self.camera.position = [self.map startPosition];
    self.viewMoveVec = (vector_float2){0,0};
    self.positionMoveVec = (vector_float2){0,0};
    self.gameState = MazeGameStatePause;
}

- (void)startGame{
    if (self.gameState == MazeGameStatePause) {
        self.gameState = MazeGameStatePlaying;
    }
}

- (void)pauseGame{
    if (self.gameState == MazeGameStatePlaying) {
        self.gameState = MazeGameStatePause;
        self.viewMoveVec = (vector_float2){0,0};
        self.positionMoveVec = (vector_float2){0,0};
    }
}

- (BOOL)checkIsGoal{
    if (self.gameState == MazeGameStateFinish) {
        return YES;
    }
    if (self.gameState == MazeGameStatePlaying) {
        vector_float3 nowPos = self.camera.position;
        vector_float3 endPos = self.map.endPosition;

        vector_float3 vector = nowPos-endPos;
        if (vector.x > -0.5 && vector.x < 0.5 && vector.y > -0.5 && vector.y < 0.5 && vector.z > -0.5 && vector.z < 0.5) {
            self.gameState = MazeGameStateFinish;
            if (self.delegate) {
                [self.delegate mazeGameDidFinishGame:self];
            }
            return YES;
        }
    }
    return NO;
}

- (MazeGameState)gameState{
    return _gameState;
}

- (void)updateGame{
    if (self.gameState == MazeGameStatePlaying) {
        self.useTime += 1;
        [self.camera moveWithVelocity:self.positionMoveVec];
        [self.camera updateViewMatrixWithVelocity:self.viewMoveVec];
        [self checkCollision];

        [self checkIsGoal];
    }
}

//碰撞檢測
- (void)checkCollision{
    NSArray *boxArray = [self.map boxArray];
    for (int i = 0; i < boxArray.count; ++i) {
        BoxModel *boxModel = boxArray[i];
        vector_float3 position = boxModel.position;
        vector_float3 cameraPosition = self.camera.position;
        //摄像机与物体中心的相对向量
        vector_float3 direct = cameraPosition-position;
        //阈值
        float threshold = 0.70;
        if (fabs(direct.x) <= threshold && fabs(direct.y) <= threshold && fabs(direct.z) <= threshold) {
            //在正方体内，当作是碰撞了

            //判断是碰撞在哪个面上了(离物体中心最远的方向为碰撞面, 各个值的对应面 0:x, 1:y, 2:z)
            int colliType = 0;
            if (fabs(direct.z) > fabs(direct.x)) {
                if (fabs(direct.z) > fabs(direct.y)) {
                    colliType = 2;
                }else{
                    colliType = 1;
                }
            }else{
                if (fabs(direct.x) > fabs(direct.y)) {
                    colliType = 0;
                }else{
                    colliType = 1;
                }
            }

            //判断是-的还是+的面，限制摄像机只能到该面的阈值处
            if (colliType == 0) {
                if (direct.x < 0) {
                    self.camera.position = (vector_float3){position.x-threshold, cameraPosition.y, cameraPosition.z};
                }else{
                    self.camera.position = (vector_float3){position.x+threshold, cameraPosition.y, cameraPosition.z};
                }
            }else if (colliType == 1) {
                if (direct.y < 0) {
                    self.camera.position = (vector_float3){cameraPosition.x, position.y-threshold, cameraPosition.z};
                }else{
                    self.camera.position = (vector_float3){cameraPosition.x, position.y+threshold, cameraPosition.z};
                }
            }else{
                if (direct.z < 0) {
                    self.camera.position = (vector_float3){cameraPosition.x, cameraPosition.y, position.z-threshold};
                }else{
                    self.camera.position = (vector_float3){cameraPosition.x, cameraPosition.y, position.z+threshold};
                }
            }

            //直接撤销移动（往回走，这个处理有可能会卡死）
            //[self.camera moveWithVelocity:-(vector_float2){self.moveVelocity.x, self.moveVelocity.y}];
            //break;
        }
    }

    //限制移动的高度
//    if (self.camera.position.y < 0) {
//        //不能低于地板
//        self.camera.position = (vector_float3){self.camera.position.x, 0, self.camera.position.z};
//    }
}

@end
