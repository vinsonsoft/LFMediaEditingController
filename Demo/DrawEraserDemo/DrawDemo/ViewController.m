//
//  ViewController.m
//  DrawDemo
//
//  Created by TsanFeng Lam on 2020/3/24.
//  Copyright © 2020 lfsampleprojects. All rights reserved.
//

#import "ViewController.h"
#import "LFDrawViewHeader.h"

#import <CoreImage/CoreImage.h>

@interface ViewController ()

@property (weak, nonatomic) IBOutlet LFDrawView *drawView;
@property (weak, nonatomic) IBOutlet UIImageView *imageView;

@property (strong, nonatomic) UIImage *image;

@property (assign, nonatomic) BOOL eraser;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    self.drawView.brush = [LFPaintBrush new];
    self.image = self.imageView.image;
    [LFEraserBrush loadEraserImage:self.image canvasSize:self.drawView.frame.size useCache:YES complete:^(BOOL success) {
        NSLog(@"loadEraserImage:%d", success);
    }];
}

- (IBAction)editAction:(UIBarButtonItem *)sender {
    
    self.eraser = !self.eraser;
    
    self.drawView.brush = self.eraser ? [LFEraserBrush new] : [LFPaintBrush new];
    
}
- (IBAction)filterAction:(id)sender {
    if (self.image == self.imageView.image) {
        CIFilter *coreImageFilter = [CIFilter filterWithName:@"CIPhotoEffectTransfer"];
        [coreImageFilter setDefaults];
        
        CIImage *filterImage = [CIImage imageWithCGImage:self.image.CGImage];
        
        [coreImageFilter setValue:filterImage forKey:kCIInputImageKey];
        CIImage *ciimage = [coreImageFilter valueForKey:kCIOutputImageKey];

        static dispatch_once_t onceToken;
        static CIContext *context;
        dispatch_once(&onceToken, ^{
            context = [CIContext contextWithOptions:@{kCIContextUseSoftwareRenderer: @(NO)}];
        });
        
        CGImageRef outImage = [context createCGImage:ciimage fromRect:[ciimage extent]];
        UIImage *image = [UIImage imageWithCGImage:outImage];
        CGImageRelease(outImage);
        [LFEraserBrush loadEraserImage:image canvasSize:self.drawView.frame.size useCache:NO complete:^(BOOL success) {
            NSLog(@"loadEraserImage:%d", success);
            self.imageView.image = image;
        }];
        
    } else {
        [LFEraserBrush loadEraserImage:self.image canvasSize:self.drawView.frame.size useCache:NO complete:^(BOOL success) {
            NSLog(@"loadEraserImage:%d", success);
            self.imageView.image = self.image;
        }];
    }
}
- (IBAction)undoAction:(id)sender {
    if ([self.drawView canUndo]) {
        [self.drawView undo];
    }
}

@end
