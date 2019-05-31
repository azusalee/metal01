//
//  SettingManager.h
//  metal01
//
//  Created by yangming on 2019/2/18.
//  Copyright © 2019年 AL. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

#define kNotificationSettingDidChange @"kNotificationSettingDidChange"

@interface SettingManager : NSObject


@property (nonatomic, assign) int xLength;
@property (nonatomic, assign) int yLength;
@property (nonatomic, assign) int zLength;



+ (instancetype)sharedInstance;

//發送設置改變的通知
- (void)postChangeNotification;



@end

NS_ASSUME_NONNULL_END
