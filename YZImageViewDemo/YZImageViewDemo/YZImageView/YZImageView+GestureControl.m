//
//  YZImageView+GestureControl.m
//  YZImageViewDemo
//
//  Created by 邱灿清 on 15/12/23.
//  Copyright © 2015年 邱灿清. All rights reserved.
//

#import "YZImageView+GestureControl.h"

@implementation YZImageView (GestureControl)

- (void)addTapControl{
    if (!self || self.animatedImage.frameCount < 2) return;
    self.userInteractionEnabled = YES;
    
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapAction:)];
    [self addGestureRecognizer:tap];
}

- (void)addPanControl{

    if (!self || self.animatedImage.frameCount < 2) return;
    self.userInteractionEnabled = YES;
    
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(panAction:)];
    [self addGestureRecognizer:pan];
}


- (void)tapAction:(UITapGestureRecognizer *)tap{
    
    if ([self isAnimating]){
        [self stopAnimating];
    } else {
        [self startAnimating];
    }
    UIViewAnimationOptions op = UIViewAnimationOptionCurveEaseInOut | UIViewAnimationOptionAllowAnimatedContent | UIViewAnimationOptionBeginFromCurrentState;
    [UIView animateWithDuration:0.1 delay:0 options:op animations:^{
        [self.layer setValue:@(0.97) forKeyPath:@"transform.scale"];
    } completion:^(BOOL finished) {
        [UIView animateWithDuration:0.1 delay:0 options:op animations:^{
            [self.layer setValue:@(1.03) forKeyPath:@"transform.scale"];
        } completion:^(BOOL finished) {
            [UIView animateWithDuration:0.1 delay:0 options:op animations:^{
                [self.layer setValue:@(1) forKeyPath:@"transform.scale"];
            } completion:NULL];
        }];
    }];

}

- (void)panAction:(UIPanGestureRecognizer *)pan{
    
    CGPoint p = [pan locationInView:pan.view];
    CGFloat progress = p.x / pan.view.frame.size.width;
    if (pan.state == UIGestureRecognizerStateBegan) {
        [self stopAnimating];
        NSUInteger currentIndex = self.animatedImage.frameCount * progress;
        if (currentIndex > self.animatedImage.frameCount) {
            currentIndex = self.animatedImage.frameCount;
        }
        [self setPresentIndex:currentIndex];
    } else if (pan.state == UIGestureRecognizerStateEnded ||
        pan.state == UIGestureRecognizerStateCancelled) {
        
        [self startAnimating];
        
    } else {
        [self setPresentIndex:self.animatedImage.frameCount * progress];
    }

}

@end
