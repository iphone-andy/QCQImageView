//
//  ProgressiveViewController.m
//  YZImageViewDemo
//
//  Created by 邱灿清 on 16/1/12.
//  Copyright © 2016年 邱灿清. All rights reserved.
//

#import "ProgressiveViewController.h"
#import <ImageIO/ImageIO.h>
#import <CoreImage/CoreImage.h>
#import <Accelerate/Accelerate.h>

@interface ProgressiveViewController ()<NSURLSessionDataDelegate>
{
    CGImageSourceRef _incrementallyImgSource;
    
    NSMutableData   *_recieveData;
    long long       _expectedLeght;
    bool            _isLoadFinished;
    NSInteger current;
    NSTimer *timer;
    NSTimeInterval lastProgressiveDecodeTimestamp;
    CGFloat radius;
    
}
@property (weak, nonatomic) IBOutlet UIImageView *progressImageView;
@property (nonatomic, strong) CIContext *processingContext;
@property (nonatomic, strong) CIFilter *gaussianFilter;
@property (nonatomic, retain) UIImage *image;
@property (nonatomic, retain) UIImage *thumbImage;
@property (nonatomic , strong) NSArray *progressArray;

@end

@implementation ProgressiveViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    _incrementallyImgSource = CGImageSourceCreateIncremental(NULL);
    _recieveData = [[NSMutableData alloc] init];
    _isLoadFinished = false;
    self.progressArray = @[@(0.2),@(0.3),@(0.4),@(0.6),@(0.8),@(1)];
    current = 0;

    NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
    
    NSURLSession *session = [NSURLSession sessionWithConfiguration:config delegate:self delegateQueue:nil];
    NSURLRequest *request = [[NSURLRequest alloc] initWithURL:[NSURL URLWithString:@"https://s-media-cache-ak0.pinimg.com/1200x/2e/0c/c5/2e0cc5d86e7b7cd42af225c29f21c37f.jpg"]];
    NSURLSessionDataTask *task = [session dataTaskWithRequest:request];
    [task resume];
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask
    didReceiveResponse:(NSURLResponse *)response  completionHandler:(void (^)(NSURLSessionResponseDisposition disposition))completionHandler;
{
        _expectedLeght = response.expectedContentLength;
        NSLog(@"expected Length: %lld", _expectedLeght);
    
        NSString *mimeType = response.MIMEType;
        NSLog(@"MIME TYPE %@", mimeType);
    
        NSArray *arr = [mimeType componentsSeparatedByString:@"/"];
        if (arr.count < 1 || ![[arr objectAtIndex:0] isEqual:@"image"]) {
            NSLog(@"not a image url");
            dispatch_async(dispatch_get_main_queue(), ^{
                self.progressImageView.image = nil;
            });
        }
        completionHandler(NSURLSessionResponseAllow);
}
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask
    didReceiveData:(NSData *)data
{
    NSLog(@"1111");
    current ++;
    [_recieveData appendData:data];
    
    _isLoadFinished = false;
    if (_expectedLeght == _recieveData.length) {
        _isLoadFinished = true;
    }
    
    CGImageSourceUpdateData(_incrementallyImgSource, (CFDataRef)_recieveData, _isLoadFinished);
    CGImageRef imageRef = CGImageSourceCreateImageAtIndex(_incrementallyImgSource, 0, NULL);
    
    NSTimeInterval min = 0.4;
    NSTimeInterval now = CACurrentMediaTime();
    if (now - lastProgressiveDecodeTimestamp < min){
        return;
    }
    
    CFDictionaryRef properties = CGImageSourceCopyPropertiesAtIndex(_incrementallyImgSource, 0, NULL);
    NSDictionary *jpeg = (__bridge NSDictionary *)CFDictionaryGetValue(properties, kCGImagePropertyJFIFDictionary);
    NSNumber *isProg = jpeg[(id)kCGImagePropertyJFIFIsProgressive];
    if (!isProg.boolValue) {
        //不支持渐进加载
        return;
    }
    radius = 32;
    radius *= 1.0 / (3 * _recieveData.length / (CGFloat)_expectedLeght + 0.6) - 0.25;

    self.image = [self imageBySourceImage:[UIImage imageWithCGImage:imageRef] burRadius:radius tintColor:nil tintMode:0 saturation:1 maskImage:nil];
//    self.image = [self postProcessImage:[UIImage imageWithCGImage:imageRef] withProgress:current > self.progressArray.count ? 1.0 : [self.progressArray[current] floatValue]];
    dispatch_async(dispatch_get_main_queue(), ^{
        self.progressImageView.image = self.image;
        lastProgressiveDecodeTimestamp = now;
    });
    CGImageRelease(imageRef);


}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task
    didCompleteWithError:(nullable NSError *)error
{
    NSLog(@"22222");
//    if (!_isLoadFinished) {
//        CGImageSourceUpdateData(_incrementallyImgSource, (CFDataRef)_recieveData, _isLoadFinished);
        CGImageRef imageRef = CGImageSourceCreateImageAtIndex(_incrementallyImgSource, 0, NULL);
//        self.image = [self postProcessImage:[UIImage imageWithCGImage:imageRef] withProgress:1.0];
    radius *= 1.0 / (3 * _recieveData.length / (CGFloat)_expectedLeght + 0.6) - 0.25;
    
    self.image = [self imageBySourceImage:[UIImage imageWithCGImage:imageRef] burRadius:4.3401491606986404 tintColor:nil tintMode:0 saturation:1 maskImage:nil];
        dispatch_async(dispatch_get_main_queue(), ^{
            self.progressImageView.image = self.image;
        });
    CGImageRelease(imageRef);

//    }else{
//        timer = [NSTimer scheduledTimerWithTimeInterval:0.4 target:self selector:@selector(updateImage)userInfo:nil repeats:YES];
//        [[NSRunLoop currentRunLoop] addTimer:timer forMode:NSRunLoopCommonModes];
//        [[NSRunLoop currentRunLoop] run];
//        
//    }
}

- (void)updateImage{
    if (current > 4) {
        [timer invalidate];
        timer = nil;
        self.image = nil;
        CFRelease(_incrementallyImgSource);
        _incrementallyImgSource = NULL;
        return;
    }
    NSData *data = [_recieveData subdataWithRange:NSMakeRange(0 ,_expectedLeght * (current + 1) / 5 )];
    CGImageSourceUpdateData(_incrementallyImgSource, (CFDataRef)data, current == 4 ? YES :NO);
    CGImageRef imageRef = CGImageSourceCreateImageAtIndex(_incrementallyImgSource, 0, NULL);
//    self.image = [self postProcessImage:[UIImage imageWithCGImage:imageRef] withProgress:current > self.progressArray.count ? 1.0 : [self.progressArray[current] floatValue]];
    dispatch_async(dispatch_get_main_queue(), ^{
//        self.progressImageView.image = self.image;
        self.progressImageView.image = [UIImage imageWithCGImage:imageRef];

    });
    current ++ ;

}

- (UIImage *)postProcessImage:(UIImage *)inputImage withProgress:(float)progress
{
    if (inputImage == nil) {
        return nil;
    }
    
    if (self.processingContext == nil) {
        self.processingContext = [CIContext contextWithOptions:@{kCIContextUseSoftwareRenderer : @(NO), kCIContextPriorityRequestLow: @YES}];
    }
    
    if (self.gaussianFilter == nil) {
        self.gaussianFilter = [CIFilter filterWithName:@"CIGaussianBlur"];
        [self.gaussianFilter setDefaults];
    }
    
    UIImage *outputUIImage = nil;
    if (self.processingContext && self.gaussianFilter) {
        [self.gaussianFilter setValue:[CIImage imageWithCGImage:inputImage.CGImage]
                               forKey:kCIInputImageKey];
        
        CGFloat radius = inputImage.size.width / 50.0;
        radius = radius * MAX(0, 1.0 - progress);
        [self.gaussianFilter setValue:[NSNumber numberWithFloat:radius]
                               forKey:kCIInputRadiusKey];
        
        CIImage *outputImage = [self.gaussianFilter outputImage];
        if (outputImage) {
            CGImageRef outputImageRef = [self.processingContext createCGImage:outputImage fromRect:CGRectMake(0, 0, inputImage.size.width, inputImage.size.height)];
            
            if (outputImageRef) {
                //"decoding" the image here copies it to CPU memory?
                outputUIImage = [self pin_decodedImageWithCGImageRef:outputImageRef];
                CGImageRelease(outputImageRef);
            }
        }
    }
    
    if (outputUIImage == nil) {
        outputUIImage = inputImage;
    }
    
    return outputUIImage;
}

- (UIImage *)pin_decodedImageWithCGImageRef:(CGImageRef)imageRef
{
    return [self pin_decodedImageWithCGImageRef:imageRef orientation:UIImageOrientationUp];
}

- (UIImage *)pin_decodedImageWithCGImageRef:(CGImageRef)imageRef orientation:(UIImageOrientation) orientation
{
    BOOL opaque = YES;
    CGImageAlphaInfo alpha = CGImageGetAlphaInfo(imageRef);
    if (alpha == kCGImageAlphaFirst || alpha == kCGImageAlphaLast || alpha == kCGImageAlphaOnly || alpha == kCGImageAlphaPremultipliedFirst || alpha == kCGImageAlphaPremultipliedLast) {
        opaque = NO;
    }
    
    CGSize imageSize = CGSizeMake(CGImageGetWidth(imageRef), CGImageGetHeight(imageRef));
    
    CGBitmapInfo info = opaque ? (kCGImageAlphaNoneSkipFirst | kCGBitmapByteOrder32Host) : (kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Host);
    CGColorSpaceRef colorspace = CGColorSpaceCreateDeviceRGB();
    
    //Use UIGraphicsBeginImageContext parameters from docs: https://developer.apple.com/library/ios/documentation/UIKit/Reference/UIKitFunctionReference/#//apple_ref/c/func/UIGraphicsBeginImageContextWithOptions
    CGContextRef ctx = CGBitmapContextCreate(NULL, imageSize.width, imageSize.height,
                                             8,
                                             0,
                                             colorspace,
                                             info);
    
    CGColorSpaceRelease(colorspace);
    
    UIImage *decodedImage = nil;
    if (ctx) {
        CGContextDrawImage(ctx, CGRectMake(0, 0, imageSize.width, imageSize.height), imageRef);
        
        CGImageRef newImage = CGBitmapContextCreateImage(ctx);
        
        decodedImage = [UIImage imageWithCGImage:newImage scale:1.0 orientation:orientation];
        
        CGImageRelease(newImage);
        CGContextRelease(ctx);
        
    } else {
        decodedImage = [UIImage imageWithCGImage:imageRef scale:1.0 orientation:orientation];
    }
    
    return decodedImage;
}


UIImageOrientation pin_UIImageOrienationFromImageSource(CGImageSourceRef imageSourceRef) {
    UIImageOrientation orientation = UIImageOrientationUp;
    
    if (imageSourceRef != nil) {
        NSDictionary *dict = (NSDictionary *)CFBridgingRelease(CGImageSourceCopyPropertiesAtIndex(imageSourceRef, 0, NULL));
        
        if (dict != nil) {
            
            NSNumber* exifOrientation = dict[(id)kCGImagePropertyOrientation];
            if (exifOrientation != nil) {
                
                switch (exifOrientation.intValue) {
                    case 1: /*kCGImagePropertyOrientationUp*/
                        orientation = UIImageOrientationUp;
                        break;
                        
                    case 2: /*kCGImagePropertyOrientationUpMirrored*/
                        orientation = UIImageOrientationUpMirrored;
                        break;
                        
                    case 3: /*kCGImagePropertyOrientationDown*/
                        orientation = UIImageOrientationDown;
                        break;
                        
                    case 4: /*kCGImagePropertyOrientationDownMirrored*/
                        orientation = UIImageOrientationDownMirrored;
                        break;
                    case 5: /*kCGImagePropertyOrientationLeftMirrored*/
                        orientation = UIImageOrientationLeftMirrored;
                        break;
                        
                    case 6: /*kCGImagePropertyOrientationRight*/
                        orientation = UIImageOrientationRight;
                        break;
                        
                    case 7: /*kCGImagePropertyOrientationRightMirrored*/
                        orientation = UIImageOrientationRightMirrored;
                        break;
                        
                    case 8: /*kCGImagePropertyOrientationLeft*/
                        orientation = UIImageOrientationLeft;
                        break;
                        
                    default:
                        break;
                }
            }
        }
    }
    
    return orientation;
}

- (UIImage *)imageBySourceImage:(UIImage *)sourcImage
                        burRadius:(CGFloat)blurRadius
                        tintColor:(UIColor *)tintColor
                         tintMode:(CGBlendMode)tintBlendMode
                       saturation:(CGFloat)saturation
                        maskImage:(UIImage *)maskImage {
    if (sourcImage.size.width < 1 || sourcImage.size.height < 1) {
        NSLog(@"UIImage+YYAdd error: invalid size: (%.2f x %.2f). Both dimensions must be >= 1: %@", sourcImage.size.width, sourcImage.size.height, self);
        return nil;
    }
    if (!sourcImage.CGImage) {
        NSLog(@"UIImage+YYAdd error: inputImage must be backed by a CGImage: %@", sourcImage);
        return nil;
    }
    if (maskImage && !maskImage.CGImage) {
        NSLog(@"UIImage+YYAdd error: effectMaskImage must be backed by a CGImage: %@", maskImage);
        return nil;
    }
    
    // iOS7 and above can use new func.
    BOOL hasNewFunc = (long)vImageBuffer_InitWithCGImage != 0 && (long)vImageCreateCGImageFromBuffer != 0;
    BOOL hasBlur = blurRadius > __FLT_EPSILON__;
    BOOL hasSaturation = fabs(saturation - 1.0) > __FLT_EPSILON__;
    
    CGSize size = sourcImage.size;
    CGRect rect = { CGPointZero, size };
    CGFloat scale = sourcImage.scale;
    CGImageRef imageRef = sourcImage.CGImage;
    BOOL opaque = NO;
    
    if (!hasBlur && !hasSaturation) {
//        return [self _yy_mergeImageRef:imageRef tintColor:tintColor tintBlendMode:tintBlendMode maskImage:maskImage opaque:opaque];
        return  [self mergeImage:sourcImage imageRef:imageRef tintColor:tintColor tintBlendMode:tintBlendMode maskImage:maskImage opaque:opaque];

    }
    
    vImage_Buffer effect = { 0 }, scratch = { 0 };
    vImage_Buffer *input = NULL, *output = NULL;
    
    vImage_CGImageFormat format = {
        .bitsPerComponent = 8,
        .bitsPerPixel = 32,
        .colorSpace = NULL,
        .bitmapInfo = kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Little, //requests a BGRA buffer.
        .version = 0,
        .decode = NULL,
        .renderingIntent = kCGRenderingIntentDefault
    };
    
    if (hasNewFunc) {
        vImage_Error err;
        err = vImageBuffer_InitWithCGImage(&effect, &format, NULL, imageRef, kvImagePrintDiagnosticsToConsole);
        if (err != kvImageNoError) {
            NSLog(@"UIImage+YYAdd error: vImageBuffer_InitWithCGImage returned error code %zi for inputImage: %@", err, self);
            return nil;
        }
        err = vImageBuffer_Init(&scratch, effect.height, effect.width, format.bitsPerPixel, kvImageNoFlags);
        if (err != kvImageNoError) {
            NSLog(@"UIImage+YYAdd error: vImageBuffer_Init returned error code %zi for inputImage: %@", err, self);
            return nil;
        }
    } else {
        UIGraphicsBeginImageContextWithOptions(size, opaque, scale);
        CGContextRef effectCtx = UIGraphicsGetCurrentContext();
        CGContextScaleCTM(effectCtx, 1.0, -1.0);
        CGContextTranslateCTM(effectCtx, 0, -size.height);
        CGContextDrawImage(effectCtx, rect, imageRef);
        effect.data     = CGBitmapContextGetData(effectCtx);
        effect.width    = CGBitmapContextGetWidth(effectCtx);
        effect.height   = CGBitmapContextGetHeight(effectCtx);
        effect.rowBytes = CGBitmapContextGetBytesPerRow(effectCtx);
        
        UIGraphicsBeginImageContextWithOptions(size, opaque, scale);
        CGContextRef scratchCtx = UIGraphicsGetCurrentContext();
        scratch.data     = CGBitmapContextGetData(scratchCtx);
        scratch.width    = CGBitmapContextGetWidth(scratchCtx);
        scratch.height   = CGBitmapContextGetHeight(scratchCtx);
        scratch.rowBytes = CGBitmapContextGetBytesPerRow(scratchCtx);
    }
    
    input = &effect;
    output = &scratch;
    
    if (hasBlur) {
        // A description of how to compute the box kernel width from the Gaussian
        // radius (aka standard deviation) appears in the SVG spec:
        // http://www.w3.org/TR/SVG/filters.html#feGaussianBlurElement
        //
        // For larger values of 's' (s >= 2.0), an approximation can be used: Three
        // successive box-blurs build a piece-wise quadratic convolution kernel, which
        // approximates the Gaussian kernel to within roughly 3%.
        //
        // let d = floor(s * 3*sqrt(2*pi)/4 + 0.5)
        //
        // ... if d is odd, use three box-blurs of size 'd', centered on the output pixel.
        //
        CGFloat inputRadius = blurRadius * scale;
        if (inputRadius - 2.0 < __FLT_EPSILON__) inputRadius = 2.0;
        uint32_t radius = floor((inputRadius * 3.0 * sqrt(2 * M_PI) / 4 + 0.5) / 2);
        radius |= 1; // force radius to be odd so that the three box-blur methodology works.
        int iterations;
        if (blurRadius * scale < 0.5) iterations = 1;
        else if (blurRadius * scale < 1.5) iterations = 2;
        else iterations = 3;
        NSInteger tempSize = vImageBoxConvolve_ARGB8888(input, output, NULL, 0, 0, radius, radius, NULL, kvImageGetTempBufferSize | kvImageEdgeExtend);
        void *temp = malloc(tempSize);
        for (int i = 0; i < iterations; i++) {
            vImageBoxConvolve_ARGB8888(input, output, temp, 0, 0, radius, radius, NULL, kvImageEdgeExtend);
            // swap
            vImage_Buffer *swap_tmp = input;
            input = output;
            output = swap_tmp;
        }
        free(temp);
    }
    
    
    if (hasSaturation) {
        // These values appear in the W3C Filter Effects spec:
        // https://dvcs.w3.org/hg/FXTF/raw-file/default/filters/Publish.html#grayscaleEquivalent
        CGFloat s = saturation;
        CGFloat matrixFloat[] = {
            0.0722 + 0.9278 * s,  0.0722 - 0.0722 * s,  0.0722 - 0.0722 * s,  0,
            0.7152 - 0.7152 * s,  0.7152 + 0.2848 * s,  0.7152 - 0.7152 * s,  0,
            0.2126 - 0.2126 * s,  0.2126 - 0.2126 * s,  0.2126 + 0.7873 * s,  0,
            0,                    0,                    0,                    1,
        };
        const int32_t divisor = 256;
        NSUInteger matrixSize = sizeof(matrixFloat) / sizeof(matrixFloat[0]);
        int16_t matrix[matrixSize];
        for (NSUInteger i = 0; i < matrixSize; ++i) {
            matrix[i] = (int16_t)roundf(matrixFloat[i] * divisor);
        }
        vImageMatrixMultiply_ARGB8888(input, output, matrix, divisor, NULL, NULL, kvImageNoFlags);
        // swap
        vImage_Buffer *swap_tmp = input;
        input = output;
        output = swap_tmp;
    }
    
    UIImage *outputImage = nil;
    if (hasNewFunc) {
        CGImageRef effectCGImage = NULL;
        effectCGImage = vImageCreateCGImageFromBuffer(input, &format, &_yy_cleanupBuffer, NULL, kvImageNoAllocate, NULL);
        if (effectCGImage == NULL) {
            effectCGImage = vImageCreateCGImageFromBuffer(input, &format, NULL, NULL, kvImageNoFlags, NULL);
            free(input->data);
        }
        free(output->data);
        outputImage = [self mergeImage:sourcImage imageRef:effectCGImage tintColor:tintColor tintBlendMode:tintBlendMode maskImage:maskImage opaque:opaque];
        CGImageRelease(effectCGImage);
    } else {
        CGImageRef effectCGImage;
        UIImage *effectImage;
        if (input != &effect) effectImage = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        if (input == &effect) effectImage = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        effectCGImage = effectImage.CGImage;
        outputImage = [self mergeImage:sourcImage imageRef:effectCGImage tintColor:tintColor tintBlendMode:tintBlendMode maskImage:maskImage opaque:opaque];
    }
    return outputImage;
}

// Helper function to handle deferred cleanup of a buffer.
static void _yy_cleanupBuffer(void *userData, void *buf_data) {
    free(buf_data);
}

// Helper function to add tint and mask.
- (UIImage *)mergeImage:(UIImage *)image
                   imageRef:(CGImageRef)effectCGImage
                     tintColor:(UIColor *)tintColor
                 tintBlendMode:(CGBlendMode)tintBlendMode
                     maskImage:(UIImage *)maskImage
                        opaque:(BOOL)opaque {
    BOOL hasTint = tintColor != nil && CGColorGetAlpha(tintColor.CGColor) > __FLT_EPSILON__;
    BOOL hasMask = maskImage != nil;
    CGSize size = image.size;
    CGRect rect = { CGPointZero, size };
    CGFloat scale = image.scale;
    
    if (!hasTint && !hasMask) {
        return [UIImage imageWithCGImage:effectCGImage];
    }
    
    UIGraphicsBeginImageContextWithOptions(size, opaque, scale);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextScaleCTM(context, 1.0, -1.0);
    CGContextTranslateCTM(context, 0, -size.height);
    if (hasMask) {
        CGContextDrawImage(context, rect, image.CGImage);
        CGContextSaveGState(context);
        CGContextClipToMask(context, rect, maskImage.CGImage);
    }
    CGContextDrawImage(context, rect, effectCGImage);
    if (hasTint) {
        CGContextSaveGState(context);
        CGContextSetBlendMode(context, tintBlendMode);
        CGContextSetFillColorWithColor(context, tintColor.CGColor);
        CGContextFillRect(context, rect);
        CGContextRestoreGState(context);
    }
    if (hasMask) {
        CGContextRestoreGState(context);
    }
    UIImage *outputImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return outputImage;
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
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
