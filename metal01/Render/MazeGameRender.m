//
//  MazeGameRender.m
//  metal01
//
//  Created by yangming on 2019/2/13.
//  Copyright © 2019年 AL. All rights reserved.
//

#import "MazeGameRender.h"


#import "MazeGame.h"
#import "ALShaderTypes.h"
#import "AAPLMathUtilities.h"

#import "BoxModel.h"

@implementation MazeGameInfo



@end

@interface MazeGameRender()<MTKViewDelegate, MazeGameDelegate>
{
    id <MTLTexture> _skyMapTexture;
    id <MTLTexture> _woodTexture;

    id <MTLTexture> _boxTexture;
    id <MTLTexture> _boxSpecTexture;
    
    id <MTLTexture> _desTexture;
    MTLVertexDescriptor *_skyVertexDescriptor;
    MTKMesh *_skyMesh;
}


@property (nonatomic, strong) id <MTLRenderPipelineState> pipelineState;
@property (nonatomic, strong) id <MTLRenderPipelineState> skyboxPipelineState;
@property (nonatomic, strong) id <MTLRenderPipelineState> planePipelineState;
@property (nonatomic, strong) id<MTLComputePipelineState> computePipelineState;


//沒有深度測試的模板
@property (nonatomic, strong) id <MTLDepthStencilState> dontWriteDepthStencilState;
//有深度測試的模板
@property (nonatomic, strong) id <MTLDepthStencilState> doWriteDepthStencilState;

@property (nonatomic, strong) id <MTLCommandQueue> commandQueue;

@property (nonatomic, strong) id<MTLBuffer> vertices;
@property (nonatomic, assign) NSUInteger verticesCount;
@property (nonatomic, strong) id<MTLBuffer> matrixBuffer;

// 路径顶点
@property (nonatomic, strong) id <MTLRenderPipelineState> routePipelineState;
@property (nonatomic, strong) id<MTLBuffer> routeVertices;
@property (nonatomic, assign) NSUInteger routeVerticesCount;

@property (nonatomic, assign) MTLSize groupSize;
@property (nonatomic, assign) MTLSize groupCount;

//總共跑了的幀數(正常60幀/s)
@property (assign, nonatomic) NSInteger runTime;


@property (nonatomic, strong) MazeGame *game;
@property (nonatomic, strong) MTKView* mtkView;

@property (nonatomic, assign) vector_uint2 viewportSize;

@end

@implementation MazeGameRender

- (instancetype)initWithMTKView:(MTKView*)mtkView{
    if (self = [super init]) {
        [self setupWithMTKView:mtkView];
    }

    return self;
}

- (void)setPosMoveVec:(CGPoint)posVec{
    self.game.positionMoveVec = (vector_float2){posVec.x, posVec.y};
}

- (void)setViewMoveVec:(CGPoint)viewVec{
    self.game.viewMoveVec = (vector_float2){viewVec.x, viewVec.y};
}

- (void)setFovyAngle:(CGFloat)angle{
    [self.game.camera updateProjectionMatrixWithAngle:angle viewPort:self.viewportSize];
}

- (CGFloat)getFovyAngle{
    return self.game.camera.fovyAngle;
}

- (MazeGameInfo *)getGameInfo{
    MazeGameInfo *info = [[MazeGameInfo alloc] init];
    return info;
}

- (void)setupWithMTKView:(MTKView*)mtkView{
    self.mtkView = mtkView;
    self.game = [[MazeGame alloc] init];
    self.game.delegate = self;

    mtkView.delegate = self;

    [self mtkView:mtkView drawableSizeWillChange:mtkView.drawableSize];

    [self setupVertex];
    [self setupDepthStencil];
    [self setupPipeline];
    [self setupTexture];
    [self setupSafeRouteVertices];

    [self setupThreadGroup];
}

- (void)setupThreadGroup {
    self.groupSize = MTLSizeMake(16, 16, 1); // 太大某些GPU不支持，太小效率低；

    //保证每个像素都有处理到
    _groupCount.width  = (_boxTexture.width  + self.groupSize.width -  1) / self.groupSize.width;
    _groupCount.height = (_boxTexture.height + self.groupSize.height - 1) / self.groupSize.height;
    _groupCount.depth = 1; // 我们是2D纹理，深度设为1
}

- (void)setupVertex {
    //metalkit 默认顺时针是正面，先定义一个正方体的顶点，计算的时候以右手坐标系计算
    const float yNum = 0.5;
    const ALVertex quadVertices[] =
    {   // 顶点坐标，分别是x、y、z；    颜色rgba                  纹理坐标          法向量
        //前
        { {  0.5, -yNum,  0.5 },  { 1.f, 0.f, 0.f, 1.f }, {1.0f, 1.0f}, {0.0f, 0.0f, 1.0f} },
        { { -0.5, -yNum,  0.5 },  { 1.f, 0.f, 0.f, 1.f }, {0.0f, 1.0f}, {0.0f, 0.0f, 1.0f} },
        { { -0.5,  yNum,  0.5 },  { 1.f, 0.f, 0.f, 1.f }, {0.0f, 0.0f}, {0.0f, 0.0f, 1.0f} },

        { {  0.5, -yNum,  0.5 },  { 1.f, 0.f, 0.f, 1.f }, {1.0f, 1.0f}, {0.0f, 0.0f, 1.0f} },
        { { -0.5,  yNum,  0.5 },  { 1.f, 0.f, 0.f, 1.f }, {0.0f, 0.0f}, {0.0f, 0.0f, 1.0f} },
        { {  0.5,  yNum,  0.5 },  { 1.f, 0.f, 0.f, 1.f }, {1.0f, 0.0f}, {0.0f, 0.0f, 1.0f} },

        //左
        { {  0.5, -yNum,  -0.5 },  { 0.f, 1.f, 0.f, 1.f }, {1.0f, 1.0f}, {1.0f, 0.0f, 0.0f} },
        { {  0.5, -yNum,   0.5 },  { 0.f, 1.f, 0.f, 1.f }, {0.0f, 1.0f}, {1.0f, 0.0f, 0.0f} },
        { {  0.5,  yNum,   0.5 },  { 0.f, 1.f, 0.f, 1.f }, {0.0f, 0.0f}, {1.0f, 0.0f, 0.0f} },

        { {  0.5, -yNum,  -0.5 },  { 0.f, 1.f, 0.f, 1.f }, {1.0f, 1.0f}, {1.0f, 0.0f, 0.0f} },
        { {  0.5,  yNum,   0.5 },  { 0.f, 1.f, 0.f, 1.f }, {0.0f, 0.0f}, {1.0f, 0.0f, 0.0f} },
        { {  0.5,  yNum,  -0.5 },  { 0.f, 1.f, 0.f, 1.f }, {1.0f, 0.0f}, {1.0f, 0.0f, 0.0f} },

        //后
        { { -0.5, -yNum,  -0.5 },  { 0.f, 0.f, 1.f, 1.f }, {1.0f, 1.0f}, {0.0f, 0.0f, -1.0f} },
        { {  0.5, -yNum,  -0.5 },  { 0.f, 0.f, 1.f, 1.f }, {0.0f, 1.0f}, {0.0f, 0.0f, -1.0f} },
        { {  0.5,  yNum,  -0.5 },  { 0.f, 0.f, 1.f, 1.f }, {0.0f, 0.0f}, {0.0f, 0.0f, -1.0f} },

        { { -0.5, -yNum,  -0.5 },  { 0.f, 0.f, 1.f, 1.f }, {1.0f, 1.0f}, {0.0f, 0.0f, -1.0f} },
        { {  0.5,  yNum,  -0.5 },  { 0.f, 0.f, 1.f, 1.f }, {0.0f, 0.0f}, {0.0f, 0.0f, -1.0f} },
        { { -0.5,  yNum,  -0.5 },  { 0.f, 0.f, 1.f, 1.f }, {1.0f, 0.0f}, {0.0f, 0.0f, -1.0f} },

        //右
        { { -0.5, -yNum,   0.5 },  { 1.f, 1.f, 0.f, 1.f }, {1.0f, 1.0f}, {-1.0f, 0.0f, 0.0f} },
        { { -0.5, -yNum,  -0.5 },  { 1.f, 1.f, 0.f, 1.f }, {0.0f, 1.0f}, {-1.0f, 0.0f, 0.0f} },
        { { -0.5,  yNum,  -0.5 },  { 1.f, 1.f, 0.f, 1.f }, {0.0f, 0.0f}, {-1.0f, 0.0f, 0.0f} },

        { { -0.5, -yNum,   0.5 },  { 1.f, 1.f, 0.f, 1.f }, {1.0f, 1.0f}, {-1.0f, 0.0f, 0.0f} },
        { { -0.5,  yNum,  -0.5 },  { 1.f, 1.f, 0.f, 1.f }, {0.0f, 0.0f}, {-1.0f, 0.0f, 0.0f} },
        { { -0.5,  yNum,   0.5 },  { 1.f, 1.f, 0.f, 1.f }, {1.0f, 0.0f}, {-1.0f, 0.0f, 0.0f} },

        //上
        { {  0.5,  yNum,   0.5 },  { 1.f, 0.f, 1.f, 1.f }, {1.0f, 1.0f}, {0.0f, 1.0f, 0.0f} },
        { { -0.5,  yNum,   0.5 },  { 1.f, 0.f, 1.f, 1.f }, {0.0f, 1.0f}, {0.0f, 1.0f, 0.0f} },
        { { -0.5,  yNum,  -0.5 },  { 1.f, 0.f, 1.f, 1.f }, {0.0f, 0.0f}, {0.0f, 1.0f, 0.0f} },

        { {  0.5,  yNum,   0.5 },  { 1.f, 0.f, 1.f, 1.f }, {1.0f, 1.0f}, {0.0f, 1.0f, 0.0f} },
        { { -0.5,  yNum,  -0.5 },  { 1.f, 0.f, 1.f, 1.f }, {0.0f, 0.0f}, {0.0f, 1.0f, 0.0f} },
        { {  0.5,  yNum,  -0.5 },  { 1.f, 0.f, 1.f, 1.f }, {1.0f, 0.0f}, {0.0f, 1.0f, 0.0f} },

        //下
        { {  0.5, -yNum,  -0.5 },  { 0.f, 1.f, 1.f, 1.f }, {1.0f, 1.0f}, {0.0f, -1.0f, 0.0f} },
        { { -0.5, -yNum,  -0.5 },  { 0.f, 1.f, 1.f, 1.f }, {0.0f, 1.0f}, {0.0f, -1.0f, 0.0f} },
        { { -0.5, -yNum,   0.5 },  { 0.f, 1.f, 1.f, 1.f }, {0.0f, 0.0f}, {0.0f, -1.0f, 0.0f} },

        { {  0.5, -yNum,  -0.5 },  { 0.f, 1.f, 1.f, 1.f }, {1.0f, 1.0f}, {0.0f, -1.0f, 0.0f} },
        { { -0.5, -yNum,   0.5 },  { 0.f, 1.f, 1.f, 1.f }, {0.0f, 0.0f}, {0.0f, -1.0f, 0.0f} },
        { {  0.5, -yNum,   0.5 },  { 0.f, 1.f, 1.f, 1.f }, {1.0f, 0.0f}, {0.0f, -1.0f, 0.0f} },

    };

    self.vertices = [self.mtkView.device newBufferWithBytes:quadVertices
                                                     length:sizeof(quadVertices)
                                                    options:MTLResourceStorageModeShared]; // 创建顶点缓存

    self.verticesCount = sizeof(quadVertices) / sizeof(ALVertex); // 顶点个数
}

/// 生成路径的顶点数组
- (void)setupSafeRouteVertices{
    NSArray *routeArray = [self.game.map safeRouteArray];
    ALRouteVertex routeVertices[routeArray.count*2-2];
    BOOL is3D = [self.game.map is3D];
    NSInteger x, y, z;
    NSInteger index = 0;
    for (int i = 0; i < routeArray.count; ++i) {
        NSInteger routeID = [routeArray[i] integerValue];
        if (is3D) {
            z = routeID/10000;
            y = (routeID/100)%100;
            x = routeID%100;
        }else{
            z = routeID/100;
            y = 0;
            x = routeID%100;
        }
        if (i != 0 && i != routeArray.count-1) {
            routeVertices[index++] = (ALRouteVertex){ {  x, y, z }};
        }
        routeVertices[index++] = (ALRouteVertex){ {  x, y, z }};
    }
    self.routeVertices = [self.mtkView.device newBufferWithBytes:routeVertices
                                                     length:sizeof(routeVertices)
                                                    options:MTLResourceStorageModeShared];
    self.routeVerticesCount = routeArray.count*2-2;
    
}

- (void)setupAllVertices{
    const float width = 0.5;

    NSArray *boxArray = [self.game.map boxArray];
    unsigned long verCount = boxArray.count*36;

    ALVertex allQuadVertices[verCount];//這個數組過大會崩，解決方案？
    for (int i = 0; i < boxArray.count; ++i) {
        BoxModel *boxModel = [boxArray objectAtIndex:i];
        vector_float3 position = boxModel.position;
        allQuadVertices[i] = (ALVertex){ {  width+position.x, -width+position.y,  width+position.z },  { 1.f, 0.f, 0.f, 1.f }, {0.0f, 1.0f}, {0.0f, 0.0f, 1.0f} };
        allQuadVertices[i+1] = (ALVertex){ { -width+position.x, -width+position.y,  width+position.z },  { 1.f, 0.f, 0.f, 1.f }, {1.0f, 1.0f}, {0.0f, 0.0f, 1.0f} };
        allQuadVertices[i+2] = (ALVertex){ { -width+position.x,  width+position.y,  width+position.z },  { 1.f, 0.f, 0.f, 1.f }, {1.0f, 0.0f}, {0.0f, 0.0f, 1.0f} };

        allQuadVertices[i+3] = (ALVertex){ {  width+position.x, -width+position.y,  width+position.z },  { 1.f, 0.f, 0.f, 1.f }, {0.0f, 1.0f}, {0.0f, 0.0f, 1.0f} };
        allQuadVertices[i+4] = (ALVertex){ { -width+position.x,  width+position.y,  width+position.z },  { 1.f, 0.f, 0.f, 1.f }, {1.0f, 0.0f}, {0.0f, 0.0f, 1.0f} };
        allQuadVertices[i+5] = (ALVertex){ {  width+position.x,  width+position.y,  width+position.z },  { 1.f, 0.f, 0.f, 1.f }, {0.0f, 0.0f}, {0.0f, 0.0f, 1.0f} };

        allQuadVertices[i+6] = (ALVertex){ {  width+position.x, -width+position.y,  -width+position.z },  { 0.f, 1.f, 0.f, 1.f }, {0.0f, 1.0f}, {1.0f, 0.0f, 0.0f} };
        allQuadVertices[i+7] = (ALVertex){ {  width+position.x, -width+position.y,   width+position.z },  { 0.f, 1.f, 0.f, 1.f }, {1.0f, 1.0f}, {1.0f, 0.0f, 0.0f} };
        allQuadVertices[i+8] = (ALVertex){ {  width+position.x,  width+position.y,   width+position.z },  { 0.f, 1.f, 0.f, 1.f }, {1.0f, 0.0f}, {1.0f, 0.0f, 0.0f} };

        allQuadVertices[i+9] = (ALVertex){ {  width+position.x, -width+position.y,  -width+position.z },  { 0.f, 1.f, 0.f, 1.f }, {0.0f, 1.0f}, {1.0f, 0.0f, 0.0f} };
        allQuadVertices[i+10] = (ALVertex){ {  width+position.x,  width+position.y,   width+position.z },  { 0.f, 1.f, 0.f, 1.f }, {1.0f, 0.0f}, {1.0f, 0.0f, 0.0f} };
        allQuadVertices[i+11] = (ALVertex){ {  width+position.x,  width+position.y,  -width+position.z },  { 0.f, 1.f, 0.f, 1.f }, {0.0f, 0.0f}, {1.0f, 0.0f, 0.0f} };

        allQuadVertices[i+12] = (ALVertex){ { -width+position.x, -width+position.y,  -width+position.z },  { 0.f, 0.f, 1.f, 1.f }, {0.0f, 1.0f}, {0.0f, 0.0f, -1.0f} };
        allQuadVertices[i+13] = (ALVertex){ {  width+position.x, -width+position.y,  -width+position.z },  { 0.f, 0.f, 1.f, 1.f }, {1.0f, 1.0f}, {0.0f, 0.0f, -1.0f} };
        allQuadVertices[i+14] = (ALVertex){ {  width+position.x,  width+position.y,  -width+position.z },  { 0.f, 0.f, 1.f, 1.f }, {1.0f, 0.0f}, {0.0f, 0.0f, -1.0f} };

        allQuadVertices[i+15] = (ALVertex){ { -width+position.x, -width+position.y,  -width+position.z },  { 0.f, 0.f, 1.f, 1.f }, {0.0f, 1.0f}, {0.0f, 0.0f, -1.0f} };
        allQuadVertices[i+16] = (ALVertex){ {  width+position.x,  width+position.y,  -width+position.z },  { 0.f, 0.f, 1.f, 1.f }, {1.0f, 0.0f}, {0.0f, 0.0f, -1.0f} };
        allQuadVertices[i+17] = (ALVertex){ { -width+position.x,  width+position.y,  -width+position.z },  { 0.f, 0.f, 1.f, 1.f }, {0.0f, 0.0f}, {0.0f, 0.0f, -1.0f} };

        allQuadVertices[i+18] = (ALVertex){ { -width+position.x, -width+position.y,   width+position.z },  { 1.f, 1.f, 0.f, 1.f }, {0.0f, 1.0f}, {-1.0f, 0.0f, 0.0f} };
        allQuadVertices[i+19] = (ALVertex){ { -width+position.x, -width+position.y,  -width+position.z },  { 1.f, 1.f, 0.f, 1.f }, {1.0f, 1.0f}, {-1.0f, 0.0f, 0.0f} };
        allQuadVertices[i+20] = (ALVertex){ { -width+position.x,  width+position.y,  -width+position.z },  { 1.f, 1.f, 0.f, 1.f }, {1.0f, 0.0f}, {-1.0f, 0.0f, 0.0f} };

        allQuadVertices[i+21] = (ALVertex){ { -width+position.x, -width+position.y,   width+position.z },  { 1.f, 1.f, 0.f, 1.f }, {0.0f, 1.0f}, {-1.0f, 0.0f, 0.0f} };
        allQuadVertices[i+22] = (ALVertex){ { -width+position.x,  width+position.y,  -width+position.z },  { 1.f, 1.f, 0.f, 1.f }, {1.0f, 0.0f}, {-1.0f, 0.0f, 0.0f} };
        allQuadVertices[i+23] = (ALVertex){ { -width+position.x,  width+position.y,   width+position.z },  { 1.f, 1.f, 0.f, 1.f }, {0.0f, 0.0f}, {-1.0f, 0.0f, 0.0f} };

        allQuadVertices[i+24] = (ALVertex){ {  width+position.x,  width+position.y,   width+position.z },  { 1.f, 0.f, 1.f, 1.f }, {0.0f, 1.0f}, {0.0f, 1.0f, 0.0f} };
        allQuadVertices[i+25] = (ALVertex){ { -width+position.x,  width+position.y,   width+position.z },  { 1.f, 0.f, 1.f, 1.f }, {1.0f, 1.0f}, {0.0f, 1.0f, 0.0f} };
        allQuadVertices[i+26] = (ALVertex){ { -width+position.x,  width+position.y,  -width+position.z },  { 1.f, 0.f, 1.f, 1.f }, {1.0f, 0.0f}, {0.0f, 1.0f, 0.0f} };

        allQuadVertices[i+27] = (ALVertex){ {  width+position.x,  width+position.y,   width+position.z },  { 1.f, 0.f, 1.f, 1.f }, {0.0f, 1.0f}, {0.0f, 1.0f, 0.0f} };
        allQuadVertices[i+28] = (ALVertex){ { -width+position.x,  width+position.y,  -width+position.z },  { 1.f, 0.f, 1.f, 1.f }, {1.0f, 0.0f}, {0.0f, 1.0f, 0.0f} };
        allQuadVertices[i+29] = (ALVertex){ {  width+position.x,  width+position.y,  -width+position.z },  { 1.f, 0.f, 1.f, 1.f }, {0.0f, 0.0f}, {0.0f, 1.0f, 0.0f} };

        allQuadVertices[i+30] = (ALVertex){ {  width+position.x, -width+position.y,  -width+position.z },  { 0.f, 1.f, 1.f, 1.f }, {0.0f, 1.0f}, {0.0f, -1.0f, 0.0f} };
        allQuadVertices[i+31] = (ALVertex){ { -width+position.x, -width+position.y,  -width+position.z },  { 0.f, 1.f, 1.f, 1.f }, {1.0f, 1.0f}, {0.0f, -1.0f, 0.0f} };
        allQuadVertices[i+32] = (ALVertex){ { -width+position.x, -width+position.y,   width+position.z },  { 0.f, 1.f, 1.f, 1.f }, {1.0f, 0.0f}, {0.0f, -1.0f, 0.0f} };

        allQuadVertices[i+33] = (ALVertex){ {  width+position.x, -width+position.y,  -width+position.z },  { 0.f, 1.f, 1.f, 1.f }, {0.0f, 1.0f}, {0.0f, -1.0f, 0.0f} };
        allQuadVertices[i+34] = (ALVertex){ { -width+position.x, -width+position.y,   width+position.z },  { 0.f, 1.f, 1.f, 1.f }, {1.0f, 0.0f}, {0.0f, -1.0f, 0.0f} };
        allQuadVertices[i+35] = (ALVertex){ {  width+position.x, -width+position.y,   width+position.z },  { 0.f, 1.f, 1.f, 1.f }, {0.0f, 0.0f}, {0.0f, -1.0f, 0.0f} };
    }

    self.vertices = [self.mtkView.device newBufferWithBytes:allQuadVertices
                                                     length:sizeof(allQuadVertices)
                                                    options:MTLResourceStorageModeShared]; // 创建顶点缓存
    self.verticesCount = sizeof(allQuadVertices) / sizeof(ALVertex); // 顶点个数
}

- (void)setupDepthStencil{
    {
        MTLDepthStencilDescriptor *depthStateDesc = [[MTLDepthStencilDescriptor alloc] init];
        depthStateDesc.depthCompareFunction = MTLCompareFunctionLess;
        depthStateDesc.depthWriteEnabled = NO;
        _dontWriteDepthStencilState = [self.mtkView.device newDepthStencilStateWithDescriptor:depthStateDesc];
    }

    {
        MTLDepthStencilDescriptor *depthStateDesc = [[MTLDepthStencilDescriptor alloc] init];
        depthStateDesc.depthCompareFunction = MTLCompareFunctionLess;
        depthStateDesc.depthWriteEnabled = YES;
        _doWriteDepthStencilState = [self.mtkView.device newDepthStencilStateWithDescriptor:depthStateDesc];
    }
}

- (void)setupPipeline{
    self.commandQueue = [self.mtkView.device newCommandQueue]; // CommandQueue是渲染指令队列，保证渲染指令有序地提交到GPU
    {
        id<MTLLibrary> defaultLibrary = [self.mtkView.device newDefaultLibrary]; // .metal
        id<MTLFunction> vertexFunction = [defaultLibrary newFunctionWithName:@"vertexShader"]; // 顶点shader，vertexShader是函数名
        id<MTLFunction> fragmentFunction = [defaultLibrary newFunctionWithName:@"fragmentShader"]; // 片元shader，samplingShader是函数名

        MTLRenderPipelineDescriptor *pipelineStateDescriptor = [[MTLRenderPipelineDescriptor alloc] init];
        pipelineStateDescriptor.vertexFunction = vertexFunction;
        pipelineStateDescriptor.fragmentFunction = fragmentFunction;
        pipelineStateDescriptor.colorAttachments[0].pixelFormat = self.mtkView.colorPixelFormat;
        pipelineStateDescriptor.depthAttachmentPixelFormat =  self.mtkView.depthStencilPixelFormat;
        pipelineStateDescriptor.stencilAttachmentPixelFormat =  self.mtkView.depthStencilPixelFormat;
        self.pipelineState = [self.mtkView.device newRenderPipelineStateWithDescriptor:pipelineStateDescriptor
                                                                                 error:NULL]; // 创建图形渲染管道，耗性能操作不宜频繁调用

        id<MTLFunction> kernelFunction = [defaultLibrary newFunctionWithName:@"originalKernel"];
        // 创建计算管道，耗性能操作不宜频繁调用
        self.computePipelineState = [self.mtkView.device newComputePipelineStateWithFunction:kernelFunction
                                                                                       error:NULL];
    }

    {
        id<MTLLibrary> defaultLibrary = [self.mtkView.device newDefaultLibrary]; // .metal
        _skyVertexDescriptor = [[MTLVertexDescriptor alloc] init];
        _skyVertexDescriptor.attributes[AAPLVertexAttributePosition].format = MTLVertexFormatFloat3;
        _skyVertexDescriptor.attributes[AAPLVertexAttributePosition].offset = 0;
        _skyVertexDescriptor.attributes[AAPLVertexAttributePosition].bufferIndex = AAPLBufferIndexMeshPositions;
        _skyVertexDescriptor.layouts[AAPLBufferIndexMeshPositions].stride = 12;
        _skyVertexDescriptor.attributes[AAPLVertexAttributeNormal].format = MTLVertexFormatFloat3;
        _skyVertexDescriptor.attributes[AAPLVertexAttributeNormal].offset = 0;
        _skyVertexDescriptor.attributes[AAPLVertexAttributeNormal].bufferIndex = AAPLBufferIndexMeshGenerics;
        _skyVertexDescriptor.layouts[AAPLBufferIndexMeshGenerics].stride = 12;

        id <MTLFunction> skyboxVertexFunction = [defaultLibrary newFunctionWithName:@"skybox_vertex"];
        id <MTLFunction> skyboxFragmentFunction = [defaultLibrary newFunctionWithName:@"skybox_fragment"];

        MTLRenderPipelineDescriptor *renderPipelineDescriptor = [MTLRenderPipelineDescriptor new];
        renderPipelineDescriptor.label = @"Sky";
        renderPipelineDescriptor.vertexDescriptor = _skyVertexDescriptor;
        renderPipelineDescriptor.vertexFunction = skyboxVertexFunction;
        renderPipelineDescriptor.fragmentFunction = skyboxFragmentFunction;
        renderPipelineDescriptor.colorAttachments[AAPLRenderTargetLighting].pixelFormat = self.mtkView.colorPixelFormat;

        //    if(_GBuffersAttachedInFinalPass)
        //    {
        //        renderPipelineDescriptor.colorAttachments[AAPLRenderTargetAlbedo].pixelFormat = _albedo_specular_GBufferFormat;
        //        renderPipelineDescriptor.colorAttachments[AAPLRenderTargetNormal].pixelFormat = _normal_shadow_GBufferFormat;
        //        renderPipelineDescriptor.colorAttachments[AAPLRenderTargetDepth].pixelFormat = _depth_GBufferFormat;
        //    }

        renderPipelineDescriptor.depthAttachmentPixelFormat = self.mtkView.depthStencilPixelFormat;
        renderPipelineDescriptor.stencilAttachmentPixelFormat = self.mtkView.depthStencilPixelFormat;

        _skyboxPipelineState = [self.mtkView.device newRenderPipelineStateWithDescriptor:renderPipelineDescriptor
                                                                                   error:nil];
        //    if (!_skyboxPipelineState) {
        //        NSLog(@"Failed to create render pipeline state, error %@", error);
        //    }

        MTLDepthStencilDescriptor *depthStateDesc = [[MTLDepthStencilDescriptor alloc] init];
        depthStateDesc.depthCompareFunction = MTLCompareFunctionLess;
        depthStateDesc.depthWriteEnabled = NO;

        _dontWriteDepthStencilState = [self.mtkView.device newDepthStencilStateWithDescriptor:depthStateDesc];
    }

    {
        id<MTLLibrary> defaultLibrary = [self.mtkView.device newDefaultLibrary]; // .metal

        id <MTLFunction> vertexFunction = [defaultLibrary newFunctionWithName:@"plane_vertex"];
        id <MTLFunction> fragmentFunction = [defaultLibrary newFunctionWithName:@"plane_fragment"];

        MTLRenderPipelineDescriptor *renderPipelineDescriptor = [MTLRenderPipelineDescriptor new];
        renderPipelineDescriptor.label = @"Plane";
        //renderPipelineDescriptor.vertexDescriptor = vertexDescriptor;
        renderPipelineDescriptor.vertexFunction = vertexFunction;
        renderPipelineDescriptor.fragmentFunction = fragmentFunction;
        renderPipelineDescriptor.colorAttachments[AAPLRenderTargetLighting].pixelFormat = self.mtkView.colorPixelFormat;

        renderPipelineDescriptor.depthAttachmentPixelFormat = self.mtkView.depthStencilPixelFormat;
        renderPipelineDescriptor.stencilAttachmentPixelFormat = self.mtkView.depthStencilPixelFormat;

        _planePipelineState = [self.mtkView.device newRenderPipelineStateWithDescriptor:renderPipelineDescriptor
                                                                                  error:nil];
    }
    
    // 路径渲染管道
    {
        id<MTLLibrary> defaultLibrary = [self.mtkView.device newDefaultLibrary]; // .metal

        id <MTLFunction> vertexFunction = [defaultLibrary newFunctionWithName:@"routeVertexShader"];
        id <MTLFunction> fragmentFunction = [defaultLibrary newFunctionWithName:@"routeFragmentShader"];

        MTLRenderPipelineDescriptor *renderPipelineDescriptor = [MTLRenderPipelineDescriptor new];
        renderPipelineDescriptor.label = @"route";
        //renderPipelineDescriptor.vertexDescriptor = vertexDescriptor;
        renderPipelineDescriptor.vertexFunction = vertexFunction;
        renderPipelineDescriptor.fragmentFunction = fragmentFunction;
        renderPipelineDescriptor.colorAttachments[AAPLRenderTargetLighting].pixelFormat = self.mtkView.colorPixelFormat;

        renderPipelineDescriptor.depthAttachmentPixelFormat = self.mtkView.depthStencilPixelFormat;
        renderPipelineDescriptor.stencilAttachmentPixelFormat = self.mtkView.depthStencilPixelFormat;

        self.routePipelineState = [self.mtkView.device newRenderPipelineStateWithDescriptor:renderPipelineDescriptor
                                                                                  error:nil];
    }

}

- (void)updateComputeWithName:(NSString *)name{
    id<MTLLibrary> defaultLibrary = [self.mtkView.device newDefaultLibrary]; // .metal
    id<MTLFunction> kernelFunction = [defaultLibrary newFunctionWithName:name];
    // 创建计算管道，耗性能操作不宜频繁调用
    self.computePipelineState = [self.mtkView.device newComputePipelineStateWithFunction:kernelFunction
                                                                                   error:NULL];
}

- (Byte *)loadImage:(UIImage *)image {
    // 1获取图片的CGImageRef
    CGImageRef spriteImage = image.CGImage;
    
    // 2 读取图片的大小
    size_t width = CGImageGetWidth(spriteImage);
    size_t height = CGImageGetHeight(spriteImage);
    
    Byte * spriteData = (Byte *) calloc(width * height * 4, sizeof(Byte)); //rgba共4个byte
    
    CGContextRef spriteContext = CGBitmapContextCreate(spriteData, width, height, 8, width*4,
                                                       CGImageGetColorSpace(spriteImage), kCGImageAlphaPremultipliedLast);
    
    // 3在CGContextRef上绘图
    CGContextDrawImage(spriteContext, CGRectMake(0, 0, width, height), spriteImage);
    
    CGContextRelease(spriteContext);
    
    return spriteData;
}

- (void)setupTexture{
    NSError *error = nil;
    MTKTextureLoader *textureLoader = [[MTKTextureLoader alloc] initWithDevice:self.mtkView.device];

    NSDictionary *textureLoaderOptions =
    @{
      MTKTextureLoaderOptionTextureUsage       : @(MTLTextureUsageShaderRead),
      MTKTextureLoaderOptionTextureStorageMode : @(MTLStorageModeShared),
      };

    {
        //用uiimage转texture
//        UIImage *image = [UIImage imageNamed:@"abc"];
//        // 纹理描述符
//        MTLTextureDescriptor *textureDescriptorb = [[MTLTextureDescriptor alloc] init];
//        textureDescriptorb.pixelFormat = MTLPixelFormatRGBA8Unorm;
//        textureDescriptorb.width = image.size.width;
//        textureDescriptorb.height = image.size.height;
//        _boxTexture = [self.mtkView.device newTextureWithDescriptor:textureDescriptorb]; // 创建纹理
//
//        MTLRegion region = {{ 0, 0, 0 }, {image.size.width, image.size.height, 1}}; // 纹理上传的范围
//        Byte *imageBytes = [self loadImage:image];
//        if (imageBytes) { // UIImage的数据需要转成二进制才能上传，且不用jpg、png的NSData
//            [_boxTexture replaceRegion:region
//                            mipmapLevel:0
//                              withBytes:imageBytes
//                            bytesPerRow:4 * image.size.width];
//            free(imageBytes); // 需要释放资源
//            imageBytes = NULL;
//        }
        _boxTexture = [textureLoader newTextureWithName:@"sample_buding"
                                            scaleFactor:1.0
                                                 bundle:nil
                                                options:textureLoaderOptions
                                                  error:&error];

        if(!_boxTexture) {
            NSLog(@"Could not load sky texture %@", error);
        }

        MTLTextureDescriptor *textureDescriptor = [[MTLTextureDescriptor alloc] init];
        textureDescriptor.pixelFormat = MTLPixelFormatRGBA8Unorm; // 图片的格式要和数据一致
        textureDescriptor.width = _boxTexture.width;
        textureDescriptor.height = _boxTexture.height;
        textureDescriptor.usage = MTLTextureUsageShaderRead | MTLTextureUsageShaderWrite; // 原图片只需要读取

        _desTexture = [self.mtkView.device newTextureWithDescriptor:textureDescriptor];

    }

    {
        _boxSpecTexture = [textureLoader newTextureWithName:@"container2_specular"
                                                scaleFactor:1.0
                                                     bundle:nil
                                                    options:textureLoaderOptions
                                                      error:&error];
    }

    {
        _woodTexture = [textureLoader newTextureWithName:@"Wood"
                                             scaleFactor:1.0
                                                  bundle:nil
                                                 options:@{
                                                           MTKTextureLoaderOptionTextureUsage       : @(MTLTextureUsageShaderRead),
                                                           MTKTextureLoaderOptionTextureStorageMode : @(MTLStorageModeShared),
                                                           MTKTextureLoaderOptionAllocateMipmaps : @(YES),
                                                           }
                                                   error:&error];
    }


    {
        _skyMapTexture = [textureLoader newTextureWithName:@"SkyMap2"
                                        scaleFactor:1.0
                                             bundle:nil
                                                   options:@{MTKTextureLoaderOptionTextureUsage       : @(MTLTextureUsageShaderRead),
                                                             MTKTextureLoaderOptionTextureStorageMode : @(MTLStorageModePrivate)}
                                              error:&error];

        if(!_skyMapTexture) {
            NSLog(@"Could not load sky texture %@", error);
        }

        {
            MTKMeshBufferAllocator *bufferAllocator =
            [[MTKMeshBufferAllocator alloc] initWithDevice:self.mtkView.device];

            MDLMesh *sphereMDLMesh = [MDLMesh newEllipsoidWithRadii:40
                                                     radialSegments:10
                                                   verticalSegments:10
                                                       geometryType:MDLGeometryTypeTriangles
                                                      inwardNormals:YES
                                                         hemisphere:NO
                                                          allocator:bufferAllocator];

            MDLVertexDescriptor *sphereDescriptor = MTKModelIOVertexDescriptorFromMetal(_skyVertexDescriptor);
            sphereDescriptor.attributes[AAPLVertexAttributePosition].name = MDLVertexAttributePosition;
            sphereDescriptor.attributes[AAPLVertexAttributeNormal].name   = MDLVertexAttributeNormal;

            // Set our vertex descriptor to relayout vertices
            sphereMDLMesh.vertexDescriptor = sphereDescriptor;

            _skyMesh = [[MTKMesh alloc] initWithMesh:sphereMDLMesh
                                              device:self.mtkView.device
                                               error:nil];

            if(!_skyMesh) {
                NSLog(@"Could not create mesh %@", error);
            }
        }

        self.matrixBuffer = [self.mtkView.device newBufferWithLength:sizeof(ALMatrix) options:MTLResourceStorageModeShared];
    }

}

- (void)drawInMTKView:(MTKView *)view{
    //计算总共跑了多少帧，可以当作时间处理（60帧/秒）
    self.runTime += 1;

    id<MTLCommandBuffer> commandBuffer = [self.commandQueue commandBuffer];

    {
        // 创建计算指令的编码器
        id<MTLComputeCommandEncoder> computeEncoder = [commandBuffer computeCommandEncoder];
        // 设置计算管道，以调用shaders.metal中的内核计算函数
        [computeEncoder setComputePipelineState:self.computePipelineState];
        // 输入纹理
        [computeEncoder setTexture:_boxTexture
                           atIndex:ALComputeTextureIndexTextureSource];
        // 输出纹理
        [computeEncoder setTexture:_desTexture
                           atIndex:ALComputeTextureIndexTextureDest];
        float time = (float)self.runTime;
        [computeEncoder setBytes:&time length:sizeof(time) atIndex:ALComputeTextureIndexTime];
        // 计算区域
        [computeEncoder dispatchThreadgroups:self.groupCount
                       threadsPerThreadgroup:self.groupSize];
        // 调用endEncoding释放编码器，下个encoder才能创建
        [computeEncoder endEncoding];
    }

    MTLRenderPassDescriptor *renderPassDescriptor = [view currentRenderPassDescriptor];
    renderPassDescriptor.depthAttachment.texture = self.mtkView.depthStencilTexture;
    renderPassDescriptor.stencilAttachment.texture = self.mtkView.depthStencilTexture;

    if (renderPassDescriptor) {
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(0, 0.6, 0.6, 1);
        renderPassDescriptor.colorAttachments[0].loadAction = MTLLoadActionClear;

        id<MTLRenderCommandEncoder> renderEncoder = [commandBuffer renderCommandEncoderWithDescriptor:renderPassDescriptor];
        [renderEncoder setViewport:(MTLViewport){0.0, 0.0, self.viewportSize.x, self.viewportSize.y, -1.0, 1.0}];

        //移动箱子
        //[self moveBox];
        //更新视角
        [self.game updateGame];
        matrix_float4x4 viewMatrix = self.game.camera.view_matrix;

        //画天空盒
        {
            [renderEncoder setCullMode:MTLCullModeBack];
            [renderEncoder setRenderPipelineState:_skyboxPipelineState];
            [renderEncoder setDepthStencilState:_dontWriteDepthStencilState];

            //让天空盒子跟着观察位置移动
            matrix_float4x4 trans = matrix4x4_translation(self.game.camera.position);
            ALMatrix *matrix = self.matrixBuffer.contents;
            matrix->modelMatrix = matrix_multiply(trans, matrix_make4x4());;
            matrix->projectionMatrix = self.game.camera.projection_matrix;
            matrix->viewMatrix = viewMatrix;

            [renderEncoder setVertexBuffer:self.matrixBuffer offset:0 atIndex:AAPLBufferIndexUniforms];
            [renderEncoder setFragmentTexture:_skyMapTexture atIndex:AAPLTextureIndexBaseColor];

            // Set mesh's vertex buffers
            for (NSUInteger bufferIndex = 0; bufferIndex < _skyMesh.vertexBuffers.count; bufferIndex++)
            {
                __unsafe_unretained MTKMeshBuffer *vertexBuffer = _skyMesh.vertexBuffers[bufferIndex];
                if((NSNull*)vertexBuffer != [NSNull null])
                {
                    [renderEncoder setVertexBuffer:vertexBuffer.buffer
                                            offset:vertexBuffer.offset
                                           atIndex:bufferIndex];
                }
            }

            MTKSubmesh *sphereSubmesh = _skyMesh.submeshes[0];
            [renderEncoder drawIndexedPrimitives:sphereSubmesh.primitiveType
                                      indexCount:sphereSubmesh.indexCount
                                       indexType:sphereSubmesh.indexType
                                     indexBuffer:sphereSubmesh.indexBuffer.buffer
                               indexBufferOffset:sphereSubmesh.indexBuffer.offset];
        }


        //画地板
//        {
//            [renderEncoder setCullMode:MTLCullModeNone];
//            [renderEncoder setRenderPipelineState:_planePipelineState];
//            [renderEncoder setDepthStencilState:_doWriteDepthStencilState];
//
//
//            float sideLength = 100;
//            const vector_float3 quadVertices[] =
//            {   // 顶点坐标，分别是x、y、z；
//                //
//                {  sideLength,  -0.5,   sideLength },
//                { -sideLength,  -0.5,   sideLength },
//                { -sideLength,  -0.5,  -sideLength },
//
//
//                {  sideLength,  -0.5,   sideLength },
//                { -sideLength,  -0.5,  -sideLength },
//                {  sideLength,  -0.5,  -sideLength }
//            };
//
//
//            const vector_float2 coorVertices[] =
//            {   // 纹理坐标
//
//                {0.0f, 1.0f},
//                {1.0f, 1.0f},
//                {1.0f, 0.0f},
//
//                {0.0f, 1.0f},
//                {1.0f, 0.0f},
//                {0.0f, 0.0f},
//            };
//
//
//            [renderEncoder setVertexBytes:quadVertices length:sizeof(quadVertices) atIndex:AAPLVertexAttributePosition];
//            [renderEncoder setVertexBytes:coorVertices length:sizeof(coorVertices) atIndex:AAPLVertexAttributeTexcoord];
//
//
//            ALMatrix matrix = {self.game.camera.projection_matrix, matrix_make4x4(), viewMatrix}; // 转成Metal能接受的格式
//            [renderEncoder setVertexBytes:&matrix
//                                   length:sizeof(matrix)
//                                  atIndex:2]; // 设置buffer
//
//            [renderEncoder setFragmentTexture:_woodTexture atIndex:AAPLTextureIndexBaseColor];
//
//            [renderEncoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:6];
//        }

        //画正方体
        [renderEncoder setCullMode:MTLCullModeBack];
        [renderEncoder setRenderPipelineState:self.pipelineState];

        [renderEncoder setDepthStencilState:_doWriteDepthStencilState];

        //设置顺时针为正面
        //[renderEncoder setFrontFacingWinding:MTLWindingClockwise];

        //[renderEncoder setDepthClipMode:MTLDepthClipModeClip];

        //更新模型旋转
        //matrix_float4x4 modelMatrixRotateX = matrix4x4_rotation(-(self.transRotate.x), 0, 1, 0);
        //matrix_float4x4 modelMatrixRotateY = matrix4x4_rotation(self.transRotate.y, 1, 0, 0);

        matrix_float4x4 modelMatrix = matrix_make4x4();//matrix_multiply(modelMatrixRotateX, modelMatrixRotateY);
        //modelMatrix = matrix_multiply(modelMatrix, self.modelMatrix);

        [renderEncoder setVertexBuffer:self.vertices offset:0 atIndex:ALVertexInputIndexVertices];

        [renderEncoder setFragmentTexture:_desTexture
                                  atIndex:0]; // 设置纹理
        [renderEncoder setFragmentTexture:_boxSpecTexture atIndex:1];


        //光照设置
        vector_float3 lightColor = {1.0f, 1.0f, 1.0f};
        vector_float3 diffuseColor = lightColor*(vector_float3){0.5f, 0.5f, 0.5f};
        vector_float3 ambientColor = lightColor*(vector_float3){0.05f, 0.05f, 0.05f};

        //设置平行光
        ALDirectLight directLight = {{0.0f, -1.0f, -1.0f}, diffuseColor, ambientColor, lightColor};
        [renderEncoder setFragmentBytes:&directLight length:sizeof(directLight) atIndex:ALFragmentInputIndexDirectLight];

        //设置聚光(用摄像机的位置和朝向)
        ALSpotLight spotLight = {self.game.camera.position, self.game.camera.front, cos(15.5*M_PI/180), cos(20.5*M_PI/180), 1.0f, 0.09f, 0.032f, lightColor*0.7f, lightColor*0.3f, lightColor};
        [renderEncoder setFragmentBytes:&spotLight length:sizeof(spotLight) atIndex:ALFragmentInputIndexSpotLight];

        //设置摄像位置
        vector_float3 viewpos = self.game.camera.position;
        [renderEncoder setFragmentBytes:&viewpos length:sizeof(viewpos) atIndex:ALFragmentInputIndexViewpos];
        
        float time = (float)self.runTime;
        [renderEncoder setFragmentBytes:&time length:sizeof(time) atIndex:ALFragmentInputIndexTime];

        //全部一起渲染(頂點數組過大，程序崩了，貌似超過1萬多個頂點就會問題)
//        {
//            ALMatrix matrix = {self.game.camera.projection_matrix, modelMatrix, viewMatrix}; // 转成Metal能接受的格式
//            [renderEncoder setVertexBytes:&matrix
//                                   length:sizeof(matrix)
//                                  atIndex:ALVertexInputIndexMatrix]; // 设置buffer
//
//            matrix_float4x4 transposeInverse = matrix_transpose_inverse(modelMatrix);
//
//            matrix_float3x3 transposeInverse33 = matrix_make(
//                                                             vector3(transposeInverse.columns[0].x, transposeInverse.columns[0].y, transposeInverse.columns[0].z),
//                                                             vector3(transposeInverse.columns[1].x, transposeInverse.columns[1].y, transposeInverse.columns[1].z),
//                                                             vector3(transposeInverse.columns[2].x, transposeInverse.columns[2].y, transposeInverse.columns[2].z));
//            [renderEncoder setVertexBytes:&transposeInverse33
//                                   length:sizeof(transposeInverse33)
//                                  atIndex:ALVertexInputIndexTransposInverse]; // 设置buffer
//
//            [renderEncoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:self.verticesCount];
//        }

        //逐個box渲染(用這個方法同時渲染1000個箱子會有明顯的卡頓，測試手機iphone6)
        //獲取附近看到的箱子（去掉背向的箱子和距离远的箱子，減少渲染的數量）
        NSArray *boxArray = [self.game.map nearBoxArrayWithPosition:viewpos andFront:self.game.camera.front];

        for (int i = 0; i < boxArray.count; ++i) {
            BoxModel *boxModel = boxArray[i];

            matrix_float4x4 transModelMatrix = matrix4x4_translation(boxModel.position);

            //對模型位置進行變換
            transModelMatrix = matrix_multiply(transModelMatrix, modelMatrix);

            ALMatrix matrix = {self.game.camera.projection_matrix, transModelMatrix, viewMatrix}; // 转成Metal能接受的格式
            [renderEncoder setVertexBytes:&matrix
                                   length:sizeof(matrix)
                                  atIndex:ALVertexInputIndexMatrix]; // 设置buffer

            //模型进行了变换，法向量也需要进行对应的变换
            matrix_float4x4 transposeInverse = matrix_transpose_inverse(transModelMatrix);

            matrix_float3x3 transposeInverse33 = matrix_make(
                                                             vector3(transposeInverse.columns[0].x, transposeInverse.columns[0].y, transposeInverse.columns[0].z),
                                                             vector3(transposeInverse.columns[1].x, transposeInverse.columns[1].y, transposeInverse.columns[1].z),
                                                             vector3(transposeInverse.columns[2].x, transposeInverse.columns[2].y, transposeInverse.columns[2].z));
            [renderEncoder setVertexBytes:&transposeInverse33
                                   length:sizeof(transposeInverse33)
                                  atIndex:ALVertexInputIndexTransposInverse]; // 设置buffer

            [renderEncoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:self.verticesCount];
        }
        
        // 画出安全路径
        if (self.isShowRoute) {
            [renderEncoder setRenderPipelineState:self.routePipelineState];
            [renderEncoder setDepthStencilState:_dontWriteDepthStencilState];
            ALMatrix matrix = {self.game.camera.projection_matrix, matrix_make4x4(), viewMatrix};
            [renderEncoder setVertexBuffer:self.routeVertices offset:0 atIndex:0];
            [renderEncoder setFragmentBytes:&time length:sizeof(time) atIndex:1];
            [renderEncoder setVertexBytes:&matrix
                                   length:sizeof(matrix)
                                  atIndex:1];
            [renderEncoder drawPrimitives:MTLPrimitiveTypeLine vertexStart:0 vertexCount:self.routeVerticesCount];
        }

        [renderEncoder endEncoding];
        [commandBuffer presentDrawable:view.currentDrawable];
    }

    [commandBuffer commit];

    if (self.delegate) {
        //告訴代理，數據發生改變
        [self.delegate mazeGameRender:self didUpdateInfo:self.game];
    }
}

- (void)mtkView:(nonnull MTKView *)view drawableSizeWillChange:(CGSize)size {
    self.viewportSize = (vector_uint2){size.width, size.height};
    [self.game.camera setViewportSize:self.viewportSize];
}

// MazeGame類的回調
// 遊戲完成回調
- (void)mazeGameDidFinishGame:(MazeGame *)game{
    if (self.delegate) {
        [self.delegate mazeGameRender:self didFinishGame:game];
    }
}

@end
