//
//  ViewController.m
//  YZImageViewDemo
//
//  Created by 邱灿清 on 15/12/16.
//  Copyright © 2015年 邱灿清. All rights reserved.
//

#import "ViewController.h"
#import "YZImageView.h"
#import "YZImageView+GestureControl.h"
@interface ViewController ()
@property (weak, nonatomic) IBOutlet YZImageView *test1;
@property (weak, nonatomic) IBOutlet YZImageView *test2;
@property (weak, nonatomic) IBOutlet YZImageView *test3;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    self.test1.animatedImage = (YZAnimationImage *)[YZAnimationImage imageNamed:@"test1"];
    [self.test1 addTapControl];
    [self.test1 addPanControl];
    self.test2.animatedImage = (YZAnimationImage *)[YZAnimationImage imageNamed:@"test2"];
    self.test3.animatedImage = (YZAnimationImage *)[YZAnimationImage imageNamed:@"test3@2x"];
    [self.test3 addPanControl];
    UIImageView *imageView;
    NSArray *imgArray;
    
    
    //把存有UIImage的数组赋给动画图片数组
    imageView.animationImages = imgArray;
    //设置执行一次完整动画的时长
    imageView.animationDuration = 6*0.15;
    //动画重复次数 （0为重复播放）
    imageView.animationRepeatCount = 0;
    //开始播放动画
    [imageView startAnimating];
    

}



- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
