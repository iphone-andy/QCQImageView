//
//  YZImage.m
//  YZImageViewDemo
//
//  Created by 邱灿清 on 15/12/16.
//  Copyright © 2015年 邱灿清. All rights reserved.
//

#import "YZAnimationImage.h"
#import <ImageIO/ImageIO.h>
#import <MobileCoreServices/MobileCoreServices.h>

static const NSTimeInterval kYZAnimatedImageDelayTimeIntervalMinimum = 0.02;
static const NSUInteger productLimitNum = 10;

inline static YZImageType YZImageDetectType(CFDataRef data) {
    if (!data) return YZImageTypeUnknown;
    uint64_t length = CFDataGetLength(data);
    if (length < 16) return YZImageTypeUnknown;
    
    const char *bytes = (char *)CFDataGetBytePtr(data);
    
    uint32_t magic4 = *((uint32_t *)bytes);
    switch (magic4) {
        case YZ_FOUR_CC(0x4D, 0x4D, 0x00, 0x2A): { // big endian TIFF
            return YZImageTypeTIFF;
        } break;
            
        case YZ_FOUR_CC(0x49, 0x49, 0x2A, 0x00): { // little endian TIFF
            return YZImageTypeTIFF;
        } break;
            
        case YZ_FOUR_CC(0x00, 0x00, 0x01, 0x00): { // ICO
            return YZImageTypeICO;
        } break;
            
        case YZ_FOUR_CC(0x00, 0x00, 0x02, 0x00): { // CUR
            return YZImageTypeICO;
        } break;
            
        case YZ_FOUR_CC('i', 'c', 'n', 's'): { // ICNS
            return YZImageTypeICNS;
        } break;
            
        case YZ_FOUR_CC('G', 'I', 'F', '8'): { // GIF
            return YZImageTypeGIF;
        } break;
            
        case YZ_FOUR_CC(0x89, 'P', 'N', 'G'): {  // PNG
            uint32_t tmp = *((uint32_t *)(bytes + 4));
            if (tmp == YZ_FOUR_CC('\r', '\n', 0x1A, '\n')) {
                return YZImageTypePNG;
            }
        } break;
            
        case YZ_FOUR_CC('R', 'I', 'F', 'F'): { // WebP
            uint32_t tmp = *((uint32_t *)(bytes + 8));
            if (tmp == YZ_FOUR_CC('W', 'E', 'B', 'P')) {
                return YZImageTypeWebP;
            }
        } break;
            /*
             case YZ_FOUR_CC('B', 'P', 'G', 0xFB): { // BPG
             return YZImageTypeBPG;
             } break;
             */
    }
    
    uint16_t magic2 = *((uint16_t *)bytes);
    switch (magic2) {
        case YZ_TWO_CC('B', 'A'):
        case YZ_TWO_CC('B', 'M'):
        case YZ_TWO_CC('I', 'C'):
        case YZ_TWO_CC('P', 'I'):
        case YZ_TWO_CC('C', 'I'):
        case YZ_TWO_CC('C', 'P'): { // BMP
            return YZImageTypeBMP;
        }
        case YZ_TWO_CC(0xFF, 0x4F): { // JPEG2000
            return YZImageTypeJPEG2000;
        }
    }
    
    // JPG             FF D8 FF
    if (memcmp(bytes,"\377\330\377",3) == 0) return YZImageTypeJPEG;
    
    // JP2
    if (memcmp(bytes + 4, "\152\120\040\040\015", 5) == 0) return YZImageTypeJPEG2000;
    
    return YZImageTypeUnknown;
}

inline static YZImageType YZImageTypeFromUTType(CFStringRef uti) {
    static NSDictionary *dic;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        dic = @{(id)kUTTypeJPEG : @(YZImageTypeJPEG),
                (id)kUTTypeJPEG2000 : @(YZImageTypeJPEG2000),
                (id)kUTTypeTIFF : @(YZImageTypeTIFF),
                (id)kUTTypeBMP : @(YZImageTypeBMP),
                (id)kUTTypeICO : @(YZImageTypeICO),
                (id)kUTTypeAppleICNS : @(YZImageTypeICNS),
                (id)kUTTypeGIF : @(YZImageTypeGIF),
                (id)kUTTypePNG : @(YZImageTypePNG)};
    });
    if (!uti) return YZImageTypeUnknown;
    NSNumber *num = dic[(__bridge __strong id)(uti)];
    return num.unsignedIntegerValue;
}

inline static NSString *YZImageTypeGetExtension(YZImageType type) {
    switch (type) {
        case YZImageTypeJPEG: return @"jpg";
        case YZImageTypeJPEG2000: return @"jp2";
        case YZImageTypeTIFF: return @"tiff";
        case YZImageTypeBMP: return @"bmp";
        case YZImageTypeICO: return @"ico";
        case YZImageTypeICNS: return @"icns";
        case YZImageTypeGIF: return @"gif";
        case YZImageTypePNG: return @"png";
        case YZImageTypeWebP: return @"webp";
        default: return nil;
    }
}

 inline static CFStringRef YZImageTypeToUTType(YZImageType type) {
    switch (type) {
        case YZImageTypeJPEG: return kUTTypeJPEG;
        case YZImageTypeJPEG2000: return kUTTypeJPEG2000;
        case YZImageTypeTIFF: return kUTTypeTIFF;
        case YZImageTypeBMP: return kUTTypeBMP;
        case YZImageTypeICO: return kUTTypeICO;
        case YZImageTypeICNS: return kUTTypeAppleICNS;
        case YZImageTypeGIF: return kUTTypeGIF;
        case YZImageTypePNG: return kUTTypePNG;
        default: return NULL;
    }
}

inline static CGFloat _NSStringPathScale(NSString *string) {
    if (string.length == 0 || [string hasSuffix:@"/"]) return 1;
    NSString *name = string.stringByDeletingPathExtension;
    __block CGFloat scale = 1;
    
    NSRegularExpression *pattern = [NSRegularExpression regularExpressionWithPattern:@"@[0-9]+\\.?[0-9]*x$" options:NSRegularExpressionAnchorsMatchLines error:nil];
    [pattern enumerateMatchesInString:name options:kNilOptions range:NSMakeRange(0, name.length) usingBlock:^(NSTextCheckingResult *result, NSMatchingFlags flags, BOOL *stop) {
        if (result.range.location >= 3) {
            scale = [string substringWithRange:NSMakeRange(result.range.location + 1, result.range.length - 2)].doubleValue;
        }
    }];
    
    return scale;
}

inline static NSTimeInterval CGImageSourceGetGifFrameDelay(CGImageSourceRef imageSource, NSUInteger index)
{
    NSTimeInterval frameDuration = 0;
    CFDictionaryRef theImageProperties;
    if ((theImageProperties = CGImageSourceCopyPropertiesAtIndex(imageSource, index, NULL))) {
        CFDictionaryRef gifProperties;
        
        if (CFDictionaryGetValueIfPresent(theImageProperties, kCGImagePropertyGIFDictionary, (const void **)&gifProperties)) {
            const void *frameDurationValue;
            if (CFDictionaryGetValueIfPresent(gifProperties, kCGImagePropertyGIFUnclampedDelayTime, &frameDurationValue)) {
                frameDuration = [(__bridge NSNumber *)frameDurationValue doubleValue];
                if (frameDuration <= 0) {
                    if (CFDictionaryGetValueIfPresent(gifProperties, kCGImagePropertyGIFDelayTime, &frameDurationValue)) {
                        frameDuration = [(__bridge NSNumber *)frameDurationValue doubleValue];
                    }
                }
            }
        }
// CFRelease(gifProperties); //深坑：CFDictionaryGetValueIfPresent If the value is a Core Foundation object, ownership follows the Get Rule
// Get Rule :If you receive an object from any Core Foundation function other than a creation or copy function—such as a Get function—you do not own it and cannot be certain of the object’s life span. If you want to ensure that such an object is not disposed of while you are using it, you must claim ownership (with the CFRetain function). You are then responsible for relinquishing ownership when you have finished with it
        
        CFRelease(theImageProperties);
    }
    //why 0.02 , implement as browsers do.
    //See:  http://nullsleep.tumblr.com/post/16524517190/animated-gif-minimum-frame-delay-browser-compatibility
    
    if (frameDuration < kYZAnimatedImageDelayTimeIntervalMinimum - FLT_EPSILON) {
        frameDuration = 0.1;
    }
    return frameDuration;
}

@interface YZAnimationImage()
{
    CGFloat imageScale;
}

@property (nonatomic, readwrite, strong) NSData *data;           // image data.
@property (nonatomic, readwrite, assign) YZImageType type;       // image type
@property (nonatomic, readwrite, strong) UIImage *firstFrameImage;     // first frame image
@property (nonatomic, readwrite, assign) NSUInteger frameCount;  // image frame count.
@property (nonatomic, readwrite, assign) NSUInteger loopCount;   // 0 means infinite.
@property (nonatomic, readwrite, strong) NSMutableArray *frameImages;
@property (nonatomic, readwrite) NSTimeInterval *frameDurations;
@property (nonatomic, readwrite, assign) NSTimeInterval totalDuration;
@property (nonatomic, readonly, strong) dispatch_queue_t serialQueue;
@property (nonatomic, readonly, strong) __attribute__((NSObject)) CGImageSourceRef imageSource;

@end

@implementation YZAnimationImage

#pragma mark - Class Methods

+ (id)imageNamed:(NSString *)name
{
    NSString *path = [[NSBundle mainBundle] pathForResource:name ofType:@"gif"];
    return ([[NSFileManager defaultManager] fileExistsAtPath:path]) ? [self imageWithContentsOfFile:path] : nil;
}

+ (id)imageWithContentsOfFile:(NSString *)path
{
    return [self imageWithData:[NSData dataWithContentsOfFile:path]
                         scale:_NSStringPathScale(path)];
}

+ (id)imageWithData:(NSData *)data
{
    return [self imageWithData:data scale:1.0f];
}

+ (id)imageWithData:(NSData *)data scale:(CGFloat)scale
{
    if (!data) {
        return nil;
    }
    CGImageSourceRef imageSource = CGImageSourceCreateWithData((__bridge CFDataRef)data,
                                               (__bridge CFDictionaryRef)@{(NSString *)kCGImageSourceShouldCache: @NO});
    UIImage *image;
    YZImageType type = YZImageDetectType((__bridge CFDataRef)(data));
    if ( CGImageSourceGetCount(imageSource) > 1 && (type == YZImageTypeGIF || type  == YZImageTypeWebP)) {
        image = [[self alloc] initWithCGImageSource:imageSource scale:scale type:type];
    } else {
        image = [super imageWithData:data scale:scale];
    }
    if (imageSource) {
        CFRelease(imageSource);
    }
    return image;
}

#pragma mark - Initialization methods

- (id)initWithContentsOfFile:(NSString *)path
{
    return [self initWithData:[NSData dataWithContentsOfFile:path]
                        scale:_NSStringPathScale(path)];
}

- (id)initWithData:(NSData *)data
{
    return [self initWithData:data scale:1.0f];
}

- (id)initWithData:(NSData *)data scale:(CGFloat)scale
{
    if (!data) {
        return nil;
    }
    // no cache
    CGImageSourceRef imageSource = CGImageSourceCreateWithData((__bridge CFDataRef)data,
                                                               (__bridge CFDictionaryRef)@{(NSString *)kCGImageSourceShouldCache: @NO});
    self.type = YZImageDetectType((__bridge CFDataRef)(data));
    self.data = data;
    
    if ( CGImageSourceGetCount(imageSource) > 1 && (self.type == YZImageTypeGIF || self.type  == YZImageTypeWebP)) {
        self = [self initWithCGImageSource:imageSource scale:scale type:self.type];
    } else {
        if (scale == 1.0f) {
            self = [super initWithData:data];
        } else {
            self = [super initWithData:data scale:scale];
        }
    }
    
    if (imageSource) {
        CFRelease(imageSource);
    }
    
    return self;
}

- (id)initWithCGImageSource:(CGImageSourceRef)imageSource scale:(CGFloat)scale type:(YZImageType)type
{
    self = [super init];
    if (!imageSource || !self) {
        return nil;
    }
    // only support decode gif image
    // future will add apng and webp
    if (type != YZImageTypeGIF){
        return nil;
    }
    CFRetain(imageSource);

    NSDictionary *imageProperties = (__bridge_transfer NSDictionary *)CGImageSourceCopyProperties(imageSource, NULL);
    NSDictionary *gifProperties = [imageProperties objectForKey:(NSString *)kCGImagePropertyGIFDictionary];
    imageScale = scale;
    self.frameCount = CGImageSourceGetCount(imageSource) ? : 0;
    self.frameDurations = (NSTimeInterval *)malloc(_frameCount  * sizeof(NSTimeInterval));
    self.loopCount = [gifProperties[(NSString *)kCGImagePropertyGIFLoopCount] unsignedIntegerValue];
    self.frameImages = [NSMutableArray arrayWithCapacity:productLimitNum];
    
    NSNull *aNull = [NSNull null];
    for (NSUInteger i = 0; i < _frameCount; ++i) {
        [self.frameImages addObject:aNull];
        NSTimeInterval frameDuration = CGImageSourceGetGifFrameDelay(imageSource, i);
        self.frameDurations[i] = frameDuration;
        self.totalDuration += frameDuration;
    }
    // Load first productLimitNum frame
    NSUInteger num = MIN(productLimitNum, _frameCount);
    for (NSUInteger i=0; i<num; i++) {
        CGImageRef image = CGImageSourceCreateImageAtIndex(imageSource, i, NULL);

        if (image != NULL) {
            if (i == 0) {
                self.firstFrameImage = [UIImage imageWithCGImage:image scale:scale orientation:UIImageOrientationUp];
            }
            [self.frameImages replaceObjectAtIndex:i withObject:[UIImage imageWithCGImage:image scale:scale orientation:UIImageOrientationUp]];
        } else {
            [self.frameImages replaceObjectAtIndex:i withObject:[NSNull null]];
        }
        CFRelease(image);
    }
    _imageSource = imageSource;
//    CFShow(imageSource);
    CFRetain(_imageSource);
    CFRelease(imageSource);
    
    _serialQueue = dispatch_queue_create("com.youzan.readframe", DISPATCH_QUEUE_SERIAL);
    
    return self;

}

#pragma mark - Original Property

- (CGSize)size
{
    if (self.frameImages.count) {
        return [[self.frameImages objectAtIndex:0] size];
    }
    return [super size];
}

- (CGImageRef)CGImage
{
    if (self.frameImages.count) {
        return [[self.frameImages objectAtIndex:0] CGImage];
    } else {
        return [super CGImage];
    }
}

- (UIImageOrientation)imageOrientation
{
    if (self.frameImages.count) {
        return [[self.frameImages objectAtIndex:0] imageOrientation];
    } else {
        return [super imageOrientation];
    }
}

- (CGFloat)scale
{
    if (self.frameImages.count) {
        return [[self.frameImages objectAtIndex:0] isKindOfClass:[UIImage class]] ? [(UIImage *)[self.frameImages objectAtIndex:0] scale] : (imageScale ? : 1.0);
    } else {
        return [super scale];
    }
}

- (NSTimeInterval)duration
{
    return self.frameImages ? self.totalDuration : [super duration];
}

#pragma mark Public Method

- (UIImage * )getFrameImageAtIndex:(NSUInteger)index
{
    UIImage* frame = nil;
    @synchronized(self.frameImages) {
        frame = self.frameImages[index];
    }
    if (!frame || [frame isKindOfClass:[NSNull class]]) {
//        CGImageSourceStatus state = CGImageSourceGetStatus(_imageSource);
        CGImageRef image = CGImageSourceCreateImageAtIndex(_imageSource, index, NULL);
        if (image != NULL) {
            frame = [UIImage imageWithCGImage:image scale:imageScale orientation:UIImageOrientationUp];
            CFRelease(image);
        }
    }
    
    if (self.frameCount > productLimitNum) {

        [self.frameImages replaceObjectAtIndex:index withObject:[NSNull null]];
        NSUInteger nextReadIdx = (index + productLimitNum);
        nextReadIdx %= self.frameCount;
        if([self.frameImages[nextReadIdx] isKindOfClass:[NSNull class]]) {
            dispatch_async(_serialQueue, ^{
//                CGImageSourceStatus state = CGImageSourceGetStatus(_imageSource);
                CGImageRef image = CGImageSourceCreateImageAtIndex(_imageSource, nextReadIdx, NULL);
                @synchronized(self.frameImages) {
                    if (image != NULL) {
                        [self.frameImages replaceObjectAtIndex:nextReadIdx withObject:[UIImage imageWithCGImage:image scale:imageScale orientation:UIImageOrientationUp]];
                    } else {
                        [self.frameImages replaceObjectAtIndex:nextReadIdx withObject:[NSNull null]];
                    }
                    CFRelease(image);
                }
            });
        }
    }
    return frame;
}

# pragma mark - dealloc

- (void)dealloc {
    if(_imageSource) {
        CFRelease(_imageSource);
    }
    free(_frameDurations);
    self.frameImages = nil;
}
@end
