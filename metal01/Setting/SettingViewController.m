//
//  SettingViewController.m
//  metal01
//
//  Created by yangming on 2019/2/18.
//  Copyright © 2019年 AL. All rights reserved.
//

#import "SettingViewController.h"
#import "SettingManager.h"

@interface SettingViewController ()
@property (weak, nonatomic) IBOutlet UIStepper *xStepper;
@property (weak, nonatomic) IBOutlet UILabel *xLabel;
@property (weak, nonatomic) IBOutlet UIStepper *yStepper;
@property (weak, nonatomic) IBOutlet UILabel *yLabel;
@property (weak, nonatomic) IBOutlet UIStepper *zStepper;
@property (weak, nonatomic) IBOutlet UILabel *zLabel;

@property (weak, nonatomic) IBOutlet UIButton *submitButton;

@property (weak, nonatomic) IBOutlet UISegmentedControl *typeSeg;

@end

@implementation SettingViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.

    if ([SettingManager sharedInstance].yLength == 1) {
        self.typeSeg.selectedSegmentIndex = 1;
        self.xStepper.value = [SettingManager sharedInstance].xLength;
        self.zStepper.value = [SettingManager sharedInstance].zLength;
        self.yStepper.hidden = YES;
        self.yLabel.hidden = YES;
    }else{
        self.typeSeg.selectedSegmentIndex = 0;
        self.xStepper.value = [SettingManager sharedInstance].xLength;
        self.yStepper.value = [SettingManager sharedInstance].yLength;
        self.zStepper.value = [SettingManager sharedInstance].zLength;
        self.yStepper.hidden = NO;
        self.yLabel.hidden = NO;
    }

    self.xLabel.text = [NSString stringWithFormat:@"%ld",(long)self.xStepper.value];
    self.yLabel.text = [NSString stringWithFormat:@"%ld",(long)self.yStepper.value];
    self.zLabel.text = [NSString stringWithFormat:@"%ld",(long)self.zStepper.value];

    self.submitButton.layer.borderColor = [UIColor whiteColor].CGColor;
    self.submitButton.layer.borderWidth = 1;
}

- (IBAction)xStepperDidChange:(id)sender {
    self.xLabel.text = [NSString stringWithFormat:@"%ld",(long)self.xStepper.value];
}

- (IBAction)yStepperDidChange:(id)sender {
    self.yLabel.text = [NSString stringWithFormat:@"%ld",(long)self.yStepper.value];
}

- (IBAction)zStepperDidChange:(id)sender {
    self.zLabel.text = [NSString stringWithFormat:@"%ld",(long)self.zStepper.value];
}

- (IBAction)typeDidChange:(id)sender {
    if (self.typeSeg.selectedSegmentIndex == 1) {
        self.yStepper.hidden = YES;
        self.yLabel.hidden = YES;
    }else{
        self.yStepper.hidden = NO;
        self.yLabel.hidden = NO;
    }
}

- (IBAction)submitDidTap:(id)sender {
    if (self.typeSeg.selectedSegmentIndex == 1) {
        if ([SettingManager sharedInstance].xLength != self.xStepper.value ||
            [SettingManager sharedInstance].yLength != 1 ||
            [SettingManager sharedInstance].zLength != self.zStepper.value) {
            [SettingManager sharedInstance].xLength = self.xStepper.value;
            [SettingManager sharedInstance].yLength = 1;
            [SettingManager sharedInstance].zLength = self.zStepper.value;

            [[SettingManager sharedInstance] postChangeNotification];
        }
    }else{
        if ([SettingManager sharedInstance].xLength != self.xStepper.value ||
            [SettingManager sharedInstance].yLength != self.yStepper.value ||
            [SettingManager sharedInstance].zLength != self.zStepper.value) {
            [SettingManager sharedInstance].xLength = self.xStepper.value;
            [SettingManager sharedInstance].yLength = self.yStepper.value;
            [SettingManager sharedInstance].zLength = self.zStepper.value;

            [[SettingManager sharedInstance] postChangeNotification];
        }
    }

    [self dismissViewControllerAnimated:YES completion:nil];
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
