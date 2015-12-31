//
//  YZImage.h
//  YZImageViewDemo
//
//  Created by 邱灿清 on 15/12/16.
//  Copyright © 2015年 邱灿清. All rights reserved.
//

#import <UIKit/UIKit.h>

typedef NS_ENUM(NSUInteger, YZImageType) {
    YZImageTypeUnknown = 0, ///< unknown
    YZImageTypeJPEG,        ///< jpeg, jpg
    YZImageTypeJPEG2000,    ///< jp2
    YZImageTypeTIFF,        ///< tiff, tif
    YZImageTypeBMP,         ///< bmp
    YZImageTypeICO,         ///< ico
    YZImageTypeICNS,        ///< icns
    YZImageTypeGIF,         ///< gif
    YZImageTypePNG,         ///< png
    YZImageTypeWebP,        ///< webp
    YZImageTypeOther,       ///< other image format
};

#define YZ_FOUR_CC(c1,c2,c3,c4) ((uint32_t)(((c4) << 24) | ((c3) << 16) | ((c2) << 8) | (c1)))
#define YZ_TWO_CC(c1,c2) ((uint16_t)(((c2) << 8) | (c1)))

@interface YZAnimationImage : UIImage

@property (nonatomic, readonly) NSData *data;       ///< Image data.
@property (nonatomic, readonly) YZImageType type;   ///< Image data type.
@property (nonatomic, readonly) NSUInteger frameCount;     ///< Image frame count.
@property (nonatomic, readonly) NSUInteger loopCount;      ///< Image loop count, 0 means infinite.
@property (nonatomic, readonly) UIImage *firstFrameImage;      ///< Image loop count, 0 means infinite.
@property (nonatomic, readonly) NSTimeInterval *frameDurations;


- (UIImage * )getFrameImageAtIndex:(NSUInteger)index;
@end
