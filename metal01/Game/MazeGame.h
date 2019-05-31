//
//  MazeGame.h
//  metal01
//
//  Created by yangming on 2019/2/13.
//  Copyright © 2019年 AL. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MapModel.h"
#import "AZLCamera.h"

typedef NS_ENUM(NSUInteger, MazeGameState) {
    MazeGameStatePause,
    MazeGameStatePlaying,
    MazeGameStateFinish,
    MazeGameStateFail,
};

NS_ASSUME_NONNULL_BEGIN

@class MazeGame;
@protocol MazeGameDelegate <NSObject>

- (void)mazeGameDidFinishGame:(MazeGame*)game;

@end

@interface MazeGame : NSObject

@property (nonatomic, weak) id<MazeGameDelegate> delegate;

@property (nonatomic, readonly) MapModel *map;
@property (nonatomic, readonly) AZLCamera *camera;
@property (nonatomic, assign) vector_float2 positionMoveVec;
@property (nonatomic, assign) vector_float2 viewMoveVec;


@property (nonatomic, assign, readonly) NSInteger useTime;

//更新遊戲里的信息(每幀調用)
- (void)updateGame;
- (MazeGameState)gameState;
//重置遊戲
- (void)resetGame;
//開始遊戲
- (void)startGame;
//暫停遊戲
- (void)pauseGame;
- (BOOL)checkIsGoal;

@end

NS_ASSUME_NONNULL_END
