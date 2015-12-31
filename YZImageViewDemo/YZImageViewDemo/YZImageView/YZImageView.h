//
//  YZImageView.h
//  YZImageViewDemo
//
//  Created by 邱灿清 on 15/12/16.
//  Copyright © 2015年 邱灿清. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "YZAnimationImage.h"
#import "YZWeakDefine.h"

@interface YZImageView : UIImageView

@property (nonatomic, strong) YZAnimationImage *animatedImage;
@property (nonatomic, copy) void(^loopCompletionBlock)(NSUInteger loopCountRemaining);

@property (nonatomic, strong, readonly) UIImage *currentFrame;
@property (nonatomic, assign, readonly) NSUInteger currentFrameIndex;
- (void)setPresentIndex:(NSUInteger)currentFrameIndex;

@end
