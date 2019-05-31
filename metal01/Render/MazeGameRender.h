//
//  MazeGameRender.h
//  metal01
//
//  Created by yangming on 2019/2/13.
//  Copyright © 2019年 AL. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MazeGame.h"

@interface MazeGameInfo : NSObject

@end


@class MazeGameRender;
@protocol MazeGameRenderDelegate <NSObject>

- (void)mazeGameRender:(MazeGameRender*)render didUpdateInfo:(MazeGame*)game;

- (void)mazeGameRender:(MazeGameRender *)render didFinishGame:(MazeGame *)game;

@end


@import MetalKit;

NS_ASSUME_NONNULL_BEGIN

@interface MazeGameRender : NSObject

@property (nonatomic, weak) id<MazeGameRenderDelegate> delegate;

- (instancetype)initWithMTKView:(MTKView*)mtkView;


- (void)setPosMoveVec:(CGPoint)posVec;
- (void)setViewMoveVec:(CGPoint)viewVec;
- (void)setFovyAngle:(CGFloat)angle;

- (void)updateComputeWithName:(NSString *)name;

- (CGFloat)getFovyAngle;


- (MazeGameInfo*)getGameInfo;

@end

NS_ASSUME_NONNULL_END
