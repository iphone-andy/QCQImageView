//
//  YZImageView.m
//  YZImageViewDemo
//
//  Created by 邱灿清 on 15/12/16.
//  Copyright © 2015年 邱灿清. All rights reserved.
//

#import "YZImageView.h"
#import <pthread.h>

@interface YZImageView()

@property (nonatomic, strong, readwrite) UIImage *currentFrame;
@property (nonatomic, assign, readwrite) NSUInteger currentFrameIndex;
@property (nonatomic, assign) NSUInteger loopCountdown;
@property (nonatomic, assign) NSTimeInterval accumulator;
@property (nonatomic, strong) CADisplayLink *displayLink;
@property (nonatomic, assign) BOOL shouldAnimate;
@property (nonatomic, assign) BOOL needsDisplayWhenImageBecomesAvailable;

@end
@implementation YZImageView

#pragma mark - Setter/Getter

- (CADisplayLink *)displayLink
{
    if (self.superview && self.animatedImage) {
        if (_displayLink) {
            return _displayLink;
        }else{
            _displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(changeCurrentFrame:)];
            [_displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
        }
    } else {
        [_displayLink invalidate];
        _displayLink = nil;
    }
    return _displayLink;
}

- (void)setAnimatedImage:(YZAnimationImage *)animatedImage{
    
    if (![_animatedImage isEqual:animatedImage]) {
        if (animatedImage && animatedImage.frameCount > 0) {
            super.image = nil;
            //adjust new content size
            [self invalidateIntrinsicContentSize];
            _animatedImage = animatedImage;
            
            self.currentFrame = animatedImage.firstFrameImage;
            self.currentFrameIndex = 0;
            self.accumulator = 0.0;

            if (animatedImage.loopCount > 0) {
                self.loopCountdown = animatedImage.loopCount;
            } else {
                self.loopCountdown = NSUIntegerMax;// infinite loop
            }
            // Start animating after the new animated image has been set.
            [self updateShouldAnimate];
            if (self.shouldAnimate) {
                [self startAnimating];
            }
            [self.layer setNeedsDisplay];
        } else {
            // Stop animating before the animated image gets cleared out.
            [self stopAnimating];
        }
    }
}

- (void)setPresentIndex:(NSUInteger)currentFrameIndex{
    if (!_currentFrame)  return;
    if (!_animatedImage)  return;
    if (currentFrameIndex > _animatedImage.frameCount) return;
    if (_currentFrameIndex == currentFrameIndex) return;
    _currentFrameIndex = currentFrameIndex;
//    if (pthread_main_np()) {
//    }
    YZWeak(self);
    dispatch_async(dispatch_get_main_queue(), ^{
        YZStrong(self);
        if (self.isAnimating) {
            self.displayLink.paused = YES;
        }
        [self changeCurrentFrame:self.displayLink];
    });
    
}
#pragma mark Override Method

- (BOOL)isAnimating
{
    return [super isAnimating] || (self.displayLink && !self.displayLink.isPaused);
}

- (void)stopAnimating
{
    if (!self.animatedImage) {
        [super stopAnimating];
        return;
    }
    self.loopCountdown = 0;
    self.displayLink.paused = YES;
}

- (void)startAnimating
{
    if (!self.animatedImage) {
        [super startAnimating];
        return;
    }
    if (self.isAnimating) {
        return;
    }
    self.loopCountdown = self.animatedImage.loopCount ?: NSUIntegerMax;
    self.displayLink.paused = NO;
}

- (void)displayLayer:(CALayer *)layer
{
    if (!self.animatedImage || self.animatedImage.frameCount == 0) {
        return;
    }
    if(self.currentFrame && ![self.currentFrame isKindOfClass:[NSNull class]])
        layer.contents = (__bridge id)([self.currentFrame CGImage]);
}

- (void)didMoveToWindow
{
    [super didMoveToWindow];
    if (self.window) {
        [self startAnimating];
    } else {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (!self.window) {
                [self stopAnimating];
            }
        });
    }
}

- (void)didMoveToSuperview
{
    [super didMoveToSuperview];
    if (self.superview) {
        //Has a superview, make sure it has a displayLink
        [self displayLink];
    } else {
        //Doesn't have superview, let's check later if we need to remove the displayLink
        dispatch_async(dispatch_get_main_queue(), ^{
            [self displayLink];
        });
    }
}

#pragma mark - Help Method

- (void)updateShouldAnimate
{
    BOOL isVisible = (self.window || self.superview) && ![self isHidden] && self.alpha > 0.0;
    self.shouldAnimate = self.animatedImage && isVisible;
}

- (void)changeCurrentFrame:(CADisplayLink *)displayLink
{
    if (self.currentFrameIndex >= self.animatedImage.frameCount) {
        return;
    }
    self.accumulator += fmin(displayLink.duration, 0.1);
    
    while (self.accumulator >= self.animatedImage.frameDurations[self.currentFrameIndex]) {
        self.accumulator -= self.animatedImage.frameDurations[self.currentFrameIndex];
        if (++self.currentFrameIndex >= self.animatedImage.frameCount) {
            if (--self.loopCountdown == 0) {
                [self stopAnimating];
                return;
            }
            self.currentFrameIndex = 0;
        }
        self.currentFrameIndex = MIN(self.currentFrameIndex, [self.animatedImage.images count] - 1);
        self.currentFrame = [self.animatedImage getFrameImageAtIndex:self.currentFrameIndex];
        [self.layer setNeedsDisplay];
    }
}

#pragma mark - Life Cycle

- (void)dealloc
{
    [_displayLink invalidate];
    _displayLink = nil;
    self.animatedImage = nil;
}
@end
