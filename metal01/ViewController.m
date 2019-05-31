//
//  ViewController.m
//  metal01
//
//  Created by yangming on 2018/12/17.
//  Copyright © 2018年 AL. All rights reserved.
//

#import "ViewController.h"
#import "ALShaderTypes.h"

#import "MazeGameRender.h"
#import "AAPLMathUtilities.h"
#import "SettingViewController.h"

@interface ViewController ()<MazeGameRenderDelegate>


@property (nonatomic, strong) MTKView *mtkView;

@property (nonatomic, assign) CGPoint rotate;
@property (nonatomic, assign) CGPoint transRotate;
@property (nonatomic, assign) matrix_float4x4 modelMatrix;

@property (weak, nonatomic) IBOutlet UIView *viewAngleControl;
@property (weak, nonatomic) IBOutlet UIView *moveControl;

//观察方向移动速度向量(/帧)
@property (nonatomic, assign) CGPoint viewVelocity;
//位置移动速度向量(/帧)
@property (nonatomic, assign) CGPoint moveVelocity;

//debug
@property (weak, nonatomic) IBOutlet UILabel *debugPositionLabel;
@property (weak, nonatomic) IBOutlet UILabel *debugFrontLabel;
@property (weak, nonatomic) IBOutlet UILabel *debugRightLabel;
@property (weak, nonatomic) IBOutlet UILabel *debugTimeLabel;
@property (weak, nonatomic) IBOutlet UILabel *endLabel;

@property (nonatomic, strong) MazeGameRender *gameRender;



@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.

    MTKView *mtkView = [[MTKView alloc] initWithFrame:self.view.bounds];
    mtkView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    mtkView.device = MTLCreateSystemDefaultDevice();
    mtkView.depthStencilPixelFormat = MTLPixelFormatDepth32Float_Stencil8;
    self.mtkView = mtkView;
    [self.view insertSubview:self.mtkView atIndex:0];
    self.gameRender = [[MazeGameRender alloc] initWithMTKView:mtkView];
    self.gameRender.delegate = self;

    //增加控制手勢
    [self setupGesture];
}

- (void)mazeGameRender:(MazeGameRender *)render didUpdateInfo:(MazeGame *)game{
    self.debugPositionLabel.text = [NSString stringWithFormat:@"%0.2f, %0.2f, %0.2f", game.camera.position.x, game.camera.position.y, game.camera.position.z];
    self.debugFrontLabel.text = [NSString stringWithFormat:@"%0.2f, %0.2f, %0.2f", game.camera.front.x, game.camera.front.y, game.camera.front.z];
    self.debugRightLabel.text = [NSString stringWithFormat:@"%0.2f, %0.2f, %0.2f", game.camera.right.x, game.camera.right.y, game.camera.right.z];
    self.debugTimeLabel.text = [NSString stringWithFormat:@"%0.2f", game.useTime/60.0f];
    vector_float3 endPosition = [game.map endPosition];
    self.endLabel.text = [NSString stringWithFormat:@"%0.1f, %0.1f, %0.1f", endPosition.x, endPosition.y, endPosition.z];
}

- (void)mazeGameRender:(MazeGameRender *)render didFinishGame:(MazeGame *)game{
    NSString *message = [NSString stringWithFormat:@"遊戲完成，耗時%0.2fs，點擊確定重新開始", game.useTime/60.0f];
    UIAlertController *alertVc = [UIAlertController alertControllerWithTitle:@"提示" message:message preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *action = [UIAlertAction actionWithTitle:@"確定" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [game resetGame];
        [game startGame];
    }];
    [alertVc addAction:action];
    [self presentViewController:alertVc animated:YES completion:nil];
}

- (void)setupGesture{
    //控制箱子旋转
//    UIPanGestureRecognizer *panGesture = [[UIPanGestureRecognizer alloc] init];
//    [panGesture addTarget:self action:@selector(viewDidPan:)];
//    [self.mtkView addGestureRecognizer:panGesture];

    {
        //添加视角控制
        UIPanGestureRecognizer *viewPanGesture = [[UIPanGestureRecognizer alloc] init];
        [viewPanGesture addTarget:self action:@selector(viewControlDidPan:)];
        [self.viewAngleControl addGestureRecognizer:viewPanGesture];
    }

    {
        //添加移动控制
        UIPanGestureRecognizer *movePanGesture = [[UIPanGestureRecognizer alloc] init];
        [movePanGesture addTarget:self action:@selector(moveControlDidPan:)];
        [self.moveControl addGestureRecognizer:movePanGesture];

    }

    {
        //添加放大縮小
        UIPinchGestureRecognizer *pinchGesture = [[UIPinchGestureRecognizer alloc] init];
        [pinchGesture addTarget:self action:@selector(viewDidPinch:)];
        [self.mtkView addGestureRecognizer:pinchGesture];
    }

}

- (void)viewDidPinch:(UIPinchGestureRecognizer*)gesture{
    static float lastAngle = 0;
    if (gesture.state == UIGestureRecognizerStateBegan) {
        lastAngle = [self.gameRender getFovyAngle];
    }else if (gesture.state == UIGestureRecognizerStateChanged) {
        CGFloat scale = gesture.scale;
        [self.gameRender setFovyAngle:lastAngle/scale];
    }else if (gesture.state == UIGestureRecognizerStateEnded){

    }
}

- (void)viewDidPan:(UIPanGestureRecognizer *)gesture{
    if (gesture.state == UIGestureRecognizerStateBegan) {

    }else if (gesture.state == UIGestureRecognizerStateChanged) {
        CGPoint trans = [gesture translationInView:self.mtkView];
        self.transRotate = CGPointMake(trans.x/150.0f, trans.y/150.0f);
    }else if (gesture.state == UIGestureRecognizerStateEnded) {
        self.rotate = CGPointMake(self.rotate.x+self.transRotate.x, self.rotate.y+self.transRotate.y);
        matrix_float4x4 modelMatrixRotateX = matrix4x4_rotation(-(self.transRotate.x), 0, 1, 0);
        matrix_float4x4 modelMatrixRotateY = matrix4x4_rotation(self.transRotate.y, 1, 0, 0);
        matrix_float4x4 modelMatrix = matrix_multiply(modelMatrixRotateX, modelMatrixRotateY);
        modelMatrix = matrix_multiply(modelMatrix, self.modelMatrix);
        self.modelMatrix = modelMatrix;
        self.transRotate = CGPointZero;
    }
}

- (void)viewControlDidPan:(UIPanGestureRecognizer *)gesture{
    if (gesture.state == UIGestureRecognizerStateBegan) {
        CGPoint tapLocation = [gesture locationInView:gesture.view];
        self.viewVelocity = CGPointMake((tapLocation.x-50)/2000, -(tapLocation.y-50)/2000);
    }else if (gesture.state == UIGestureRecognizerStateChanged) {
        CGPoint tapLocation = [gesture locationInView:gesture.view];
        self.viewVelocity = CGPointMake((tapLocation.x-50)/2000, -(tapLocation.y-50)/2000);
    }else if (gesture.state == UIGestureRecognizerStateEnded) {
        self.viewVelocity = CGPointZero;
    }

    [self.gameRender setViewMoveVec:self.viewVelocity];
}

- (void)moveControlDidPan:(UIPanGestureRecognizer *)gesture{
    if (gesture.state == UIGestureRecognizerStateBegan) {
        CGPoint tapLocation = [gesture locationInView:gesture.view];
        self.moveVelocity = CGPointMake((tapLocation.x-50)/2000, -(tapLocation.y-50)/2000);
    }else if (gesture.state == UIGestureRecognizerStateChanged) {
        CGPoint tapLocation = [gesture locationInView:gesture.view];
        self.moveVelocity = CGPointMake((tapLocation.x-50)/2000, -(tapLocation.y-50)/2000);
    }else if (gesture.state == UIGestureRecognizerStateEnded) {
        self.moveVelocity = CGPointZero;
    }
    [self.gameRender setPosMoveVec:self.moveVelocity];
}

- (IBAction)settingDidTap:(id)sender {
    SettingViewController *controller = [[SettingViewController alloc] init];
    [self presentViewController:controller animated:YES completion:nil];
}
- (IBAction)changeEffectDidTap:(id)sender {
    static int effectValue = 0;
    
    NSArray *array = @[@"originalKernel",
                        @"grayKernel",
                        @"sobelKernel",
                        @"bgrKernel",
                        @"mosaicKernel",
                        @"waveKernel",
                        @"embossingKernel",
                        @"motionBlurKernel"];
    
    effectValue++;
    if (effectValue >= array.count) {
        effectValue = 0;
    }
    
    NSString *effectString = array[effectValue];

    [self.gameRender updateComputeWithName:effectString];
}

@end
