//
//  SettingManager.m
//  metal01
//
//  Created by yangming on 2019/2/18.
//  Copyright © 2019年 AL. All rights reserved.
//

#import "SettingManager.h"

@implementation SettingManager

+ (instancetype)sharedInstance
{
    static dispatch_once_t onceToken;
    static id Instance;
    dispatch_once(&onceToken, ^{
        Instance = [[self alloc] init];
    });
    return Instance;
}

- (instancetype)init{
    if (self = [super init]) {
        _xLength = 20;
        _yLength = 10;
        _zLength = 20;
    }
    return self;
}

- (void)postChangeNotification{
    [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationSettingDidChange object:nil];
}

@end
