//
//  LFVideoClippingView.m
//  LFMediaEditingController
//
//  Created by LamTsanFeng on 2017/7/17.
//  Copyright © 2017年 LamTsanFeng. All rights reserved.
//

#import "LFVideoClippingView.h"
#import "LFVideoPlayer.h"
#import "UIView+LFMECommon.h"
#import "UIView+LFMEFrame.h"
#import "LFMediaEditingHeader.h"
#import "UIColor+CustomColors.h"
/** 编辑功能 */
#import "LFDrawView.h"
#import "LFStickerView.h"

/** 滤镜框架 */
#import "LFDataFilterVideoView.h"

NSString *const kLFVideoCLippingViewData = @"LFVideoCLippingViewData";

NSString *const kLFVideoCLippingViewData_startTime = @"LFVideoCLippingViewData_startTime";
NSString *const kLFVideoCLippingViewData_endTime = @"LFVideoCLippingViewData_endTime";
NSString *const kLFVideoCLippingViewData_rate = @"LFVideoCLippingViewData_rate";

NSString *const kLFVideoCLippingViewData_draw = @"LFVideoCLippingViewData_draw";
NSString *const kLFVideoCLippingViewData_sticker = @"LFVideoCLippingViewData_sticker";
NSString *const kLFVideoCLippingViewData_filter = @"LFVideoCLippingViewData_filter";

@interface LFVideoClippingView () <LFVideoPlayerDelegate, UIScrollViewDelegate>

@property (nonatomic, weak) LFDataFilterVideoView *playerView;
@property (nonatomic, strong) LFVideoPlayer *videoPlayer;

/** 原始坐标 */
@property (nonatomic, assign) CGRect originalRect;

/** 缩放视图 */
@property (nonatomic, weak) UIView *zoomingView;

/** 绘画 */
@property (nonatomic, weak) LFDrawView *drawView;
/** 贴图 */
@property (nonatomic, weak) LFStickerView *stickerView;


@property (nonatomic, assign) BOOL muteOriginal;
@property (nonatomic, strong) NSArray <NSURL *>*audioUrls;
@property (nonatomic, strong) AVAsset *asset;



#pragma mark 编辑数据
/** 开始播放时间 */
@property (nonatomic, assign) double old_startTime;
/** 结束播放时间 */
@property (nonatomic, assign) double old_endTime;

@end

@implementation LFVideoClippingView

@synthesize rate = _rate;

/*
 1、播放功能（无限循环）
 2、暂停／继续功能
 3、视频编辑功能
*/

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        _originalRect = frame;
        [self customInit];
    }
    return self;
}

- (void)customInit
{
    self.backgroundColor = [UIColor clearColor];
    self.scrollEnabled = NO;
    self.delegate = self;
    self.showsVerticalScrollIndicator = NO;
    self.showsHorizontalScrollIndicator = NO;
    
    /** 缩放视图 */
    UIView *zoomingView = [[UIView alloc] initWithFrame:self.bounds];
    [self addSubview:zoomingView];
    _zoomingView = zoomingView;
    
    
    /** 播放视图 */
    LFDataFilterVideoView *playerView = [[LFDataFilterVideoView alloc] initWithFrame:self.bounds];
    playerView.contentMode = UIViewContentModeScaleAspectFit;
    [self.zoomingView addSubview:playerView];
    _playerView = playerView;
    
    /** 绘画 */
    LFDrawView *drawView = [[LFDrawView alloc] initWithFrame:self.bounds];
    /**
     默认画笔
     */
    drawView.brush = [LFPaintBrush new];
    /** 默认不能触发绘画 */
    drawView.userInteractionEnabled = NO;
    [self.zoomingView addSubview:drawView];
    self.drawView = drawView;
    
    /** 贴图 */
    LFStickerView *stickerView = [[LFStickerView alloc] initWithFrame:self.bounds];
    __weak typeof(self) weakSelf = self;
    stickerView.moveCenter = ^BOOL(CGRect rect) {
        /** 判断缩放后贴图是否超出边界线 */
        CGRect newRect = [weakSelf.zoomingView convertRect:rect toView:weakSelf];
        CGRect clipTransRect = CGRectApplyAffineTransform(weakSelf.frame, weakSelf.transform);
        CGRect screenRect = (CGRect){weakSelf.contentOffset, clipTransRect.size};
        screenRect = CGRectInset(screenRect, 44, 44);
        return !CGRectIntersectsRect(screenRect, newRect);
    };
    /** 禁止后，贴图将不能拖到，设计上，贴图是永远可以拖动的 */
    //    stickerView.userInteractionEnabled = NO;
    [self.zoomingView addSubview:stickerView];
    self.stickerView = stickerView;
    
    // 实现LFEditingProtocol协议
    {
        self.lf_displayView = self.playerView;
        self.lf_drawView = self.drawView;
        self.lf_stickerView = self.stickerView;
    }
    /** Play and Pause Buttons */
    [self setupPlayPauseButtons];
}

- (void)setupPlayPauseButtons
{
    // Create play button
    self.playButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.playButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [self.playButton addTarget:self action:@selector(playButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
    self.playButton.translatesAutoresizingMaskIntoConstraints = NO;  // Disable Autoresizing Mask
    self.playButton.backgroundColor = [UIColor colorIcon];
    self.playButton.layer.cornerRadius = 35; // Make it round
    self.playButton.clipsToBounds = YES; // Ensure the contents are clipped within the rounded boundary

    // Create pause button
    self.pauseButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.pauseButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [self.pauseButton addTarget:self action:@selector(pauseButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
    self.pauseButton.translatesAutoresizingMaskIntoConstraints = NO;  // Disable Autoresizing Mask
    self.pauseButton.backgroundColor = [UIColor colorIcon];
    self.pauseButton.layer.cornerRadius = 35; // Make it round
    self.pauseButton.clipsToBounds = YES; // Ensure the contents are clipped within the rounded boundary
    
    [self.playButton setImage:bundleEditImageNamed(@"ic_play_icon.png") forState:UIControlStateNormal];
    [self.pauseButton setImage:bundleEditImageNamed(@"ic_pause_icon.png") forState:UIControlStateNormal];
    
    // Add the buttons to the view
    [self addSubview:self.playButton];
    [self addSubview:self.pauseButton];

    // Bring buttons to the front of the view hierarchy to make sure they aren't hidden behind other views
    [self bringSubviewToFront:self.playButton];
    [self bringSubviewToFront:self.pauseButton];
    
    // Add Auto Layout Constraints

    // Center the Play Button
    [NSLayoutConstraint activateConstraints:@[
        [self.playButton.centerXAnchor constraintEqualToAnchor:self.centerXAnchor], // Horizontally center
        [self.playButton.centerYAnchor constraintEqualToAnchor:self.centerYAnchor], // Vertically center
        [self.playButton.widthAnchor constraintEqualToConstant:70],  // Width of the button
        [self.playButton.heightAnchor constraintEqualToConstant:70]  // Height of the button
    ]];

    // Center the Pause Button
    [NSLayoutConstraint activateConstraints:@[
        [self.pauseButton.centerXAnchor constraintEqualToAnchor:self.centerXAnchor], // Horizontally center
        [self.pauseButton.centerYAnchor constraintEqualToAnchor:self.centerYAnchor], // Vertically center
        [self.pauseButton.widthAnchor constraintEqualToConstant:70],  // Width of the button
        [self.pauseButton.heightAnchor constraintEqualToConstant:70]  // Height of the button
    ]];
    // Initially, hide pause button since video is not playing
    self.pauseButton.hidden = YES;
    // Force layout updates
    [self setNeedsLayout];
    [self layoutIfNeeded];
}



- (void)dealloc
{
    [self pauseVideo];
    self.videoPlayer.delegate = nil;
    self.videoPlayer = nil;
    self.playerView = nil;
    // 释放LFEditingProtocol协议
    [self clearProtocolxecutor];
}

- (void)playButtonTapped:(UIButton *)sender
{
    if ([self isPlaying]) {
        // If the video is already playing, do nothing or you can add logic to toggle
        return;
    }

    // Play the video from the current start time
    [self playVideo];
    
    // Optionally hide the Play button and show the Pause button if you have visibility logic
    self.playButton.hidden = YES;
    self.pauseButton.hidden = NO;
}


- (void)pauseButtonTapped:(UIButton *)sender
{
    [self pauseVideo];
    self.playButton.hidden = NO;
    self.pauseButton.hidden = YES;
}

- (void)setVideoAsset:(AVAsset *)asset placeholderImage:(UIImage *)image
{
    _asset = asset;
    [self.playerView setImageByUIImage:image];
    if (self.videoPlayer == nil) {
        self.videoPlayer = [LFVideoPlayer new];
        self.videoPlayer.delegate = self;
    }
    [self.videoPlayer setAsset:asset];
    [self.videoPlayer setAudioUrls:self.audioUrls];
    if (_rate > 0 && !(_rate + FLT_EPSILON > 1.0 && _rate - FLT_EPSILON < 1.0)) {
        self.videoPlayer.rate = _rate;
    }
    
    /** 重置编辑UI位置 */
    CGSize videoSize = self.videoPlayer.size;
    if (CGSizeEqualToSize(CGSizeZero, videoSize) || isnan(videoSize.width) || isnan(videoSize.height)) {
        videoSize = self.zoomingView.lfme_size;
    }
    CGRect editRect = AVMakeRectWithAspectRatioInsideRect(videoSize, self.originalRect);
    
    /** 参数取整，否则可能会出现1像素偏差 */
    editRect = LFMediaEditProundRect(editRect);
    
    self.frame = editRect;
    _zoomingView.lfme_size = editRect.size;
    
    /** 子控件更新 */
    [[self.zoomingView subviews] enumerateObjectsUsingBlock:^(__kindof UIView * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        obj.frame = self.zoomingView.bounds;
    }];
}

- (void)setCropRect:(CGRect)cropRect
{
    _cropRect = cropRect;
    
    self.frame = cropRect;
//    _playerLayerView.center = _drawView.center = _splashView.center = _stickerView.center = self.center;
    
    /** 重置最小缩放比例 */
    CGRect rotateNormalRect = CGRectApplyAffineTransform(self.originalRect, self.transform);
    CGFloat minimumZoomScale = MAX(CGRectGetWidth(self.frame) / CGRectGetWidth(rotateNormalRect), CGRectGetHeight(self.frame) / CGRectGetHeight(rotateNormalRect));
    self.minimumZoomScale = minimumZoomScale;
    self.maximumZoomScale = minimumZoomScale;
    
    [self setZoomScale:minimumZoomScale];
}

/** 保存 */
- (void)save
{
    self.old_startTime = self.startTime;
    self.old_endTime = self.endTime;
}
/** 取消 */
- (void)cancel
{
    self.startTime = self.old_startTime;
    self.endTime = self.old_endTime;
}

/** 播放 */
- (void)playVideo
{
    [self.videoPlayer play];
    [self seekToTime:self.startTime];
    if ([self.clipDelegate respondsToSelector:@selector(lf_videoClippingViewPlay:)]) {
        [self.clipDelegate lf_videoClippingViewPlay:self];
    }
    
    self.playButton.hidden = YES;
    self.pauseButton.hidden = NO;
}

/** 暂停 */
- (void)pauseVideo
{
    [self.videoPlayer pause];
    if ([self.clipDelegate respondsToSelector:@selector(lf_videoClippingViewPause:)]) {
        [self.clipDelegate lf_videoClippingViewPause:self];
    }
    
    self.playButton.hidden = NO;
    self.pauseButton.hidden = YES;
}

/** 静音原音 */
- (void)muteOriginalVideo:(BOOL)mute
{
    _muteOriginal = mute;
    self.videoPlayer.muteOriginalSound = mute;
}

- (float)rate
{
    return self.videoPlayer.rate ?: 1.0;
}

- (void)setRate:(float)rate
{
    _rate = rate;
    self.videoPlayer.rate = rate;
}

/** 是否播放 */
- (BOOL)isPlaying
{
    return [self.videoPlayer isPlaying];
}

/** 重新播放 */
- (void)replayVideo
{
    [self.videoPlayer resetDisplay];
    if (![self.videoPlayer isPlaying]) {
        [self playVideo];
    } else {
        [self seekToTime:self.startTime];
    }
}

/** 重置视频 */
- (void)resetVideoDisplay
{
    [self.videoPlayer pause];
    [self.videoPlayer resetDisplay];
    [self seekToTime:self.startTime];
    if ([self.clipDelegate respondsToSelector:@selector(lf_videoClippingViewPause:)]) {
        [self.clipDelegate lf_videoClippingViewPause:self];
    }
}

/** 增加音效 */
- (void)setAudioMix:(NSArray <NSURL *>*)audioMix
{
    _audioUrls = audioMix;
    [self.videoPlayer setAudioUrls:self.audioUrls];
}

/** 移动到某帧 */
- (void)seekToTime:(CGFloat)time
{
    [self.videoPlayer seekToTime:time];
}

- (void)beginScrubbing
{
    _isScrubbing = YES;
    [self.videoPlayer beginScrubbing];
}

- (void)endScrubbing
{
    _isScrubbing = NO;
    [self.videoPlayer endScrubbing];
}

/** 是否存在水印 */
- (BOOL)hasWatermark
{
    return self.drawView.canUndo || self.stickerView.subviews.count;
}

- (UIView *)overlayView
{
    if (self.hasWatermark) {
        
        UIView *copyZoomView = [[UIView alloc] initWithFrame:self.zoomingView.bounds];
        copyZoomView.backgroundColor = [UIColor clearColor];
        copyZoomView.userInteractionEnabled = NO;
        
        if (self.drawView.canUndo) {
            /** 绘画 */
            UIView *drawView = [[UIView alloc] initWithFrame:copyZoomView.bounds];
            drawView.layer.contents = (__bridge id _Nullable)([self.drawView LFME_captureImage].CGImage);
            [copyZoomView addSubview:drawView];
        }
        
        if (self.stickerView.subviews.count) {
            /** 贴图 */
            UIView *stickerView = [[UIView alloc] initWithFrame:copyZoomView.bounds];
            stickerView.layer.contents = (__bridge id _Nullable)([self.stickerView LFME_captureImage].CGImage);
            [copyZoomView addSubview:stickerView];
        }
        
        return copyZoomView;
    }
    return nil;
}

- (LFFilter *)filter
{
    return self.playerView.filter;
}

#pragma mark - UIScrollViewDelegate
- (UIView *)viewForZoomingInScrollView:(UIScrollView *)scrollView
{
    return self.zoomingView;
}

#pragma mark - LFVideoPlayerDelegate
/** 画面回调 */
- (void)LFVideoPlayerLayerDisplay:(LFVideoPlayer *)player avplayer:(AVPlayer *)avplayer
{
    if (self.startTime > 0) {
        [player seekToTime:self.startTime];
    }
    [self.playerView setPlayer:avplayer];
//    [self.playerLayerView setImage:nil];
}
/** 可以播放 */
- (void)LFVideoPlayerReadyToPlay:(LFVideoPlayer *)player duration:(double)duration
{
    if (_endTime == 0) { /** 读取配置优于视频初始化的情况 */
        _endTime = duration;
    }
    _totalDuration = duration;
    self.videoPlayer.muteOriginalSound = self.muteOriginal;
//    [self playVideo];
    if ([self.clipDelegate respondsToSelector:@selector(lf_videoClippingViewReadyToPlay:)]) {
        [self.clipDelegate lf_videoClippingViewReadyToPlay:self];
    }
}

/** 播放结束 */
- (void)LFVideoPlayerPlayDidReachEnd:(LFVideoPlayer *)player
{
    if ([self.clipDelegate respondsToSelector:@selector(lf_videoClippingViewPlayToEndTime:)]) {
        [self.clipDelegate lf_videoClippingViewPlayToEndTime:self];
    }
//    [self playVideo];
}
/** 错误回调 */
- (void)LFVideoPlayerFailedToPrepare:(LFVideoPlayer *)player error:(NSError *)error
{
    if ([self.clipDelegate respondsToSelector:@selector(lf_videoClippingViewFailedToPrepare:error:)]) {
        [self.clipDelegate lf_videoClippingViewFailedToPrepare:self error:error];
    }
}

/** 进度回调2-手动实现 */
- (void)LFVideoPlayerSyncScrub:(LFVideoPlayer *)player duration:(double)duration
{
    if (self.isScrubbing) return;
    if (duration > self.endTime) {
        [self replayVideo];
    } else {
        if ([self.clipDelegate respondsToSelector:@selector(lf_videoClippingView:duration:)]) {
            [self.clipDelegate lf_videoClippingView:self duration:duration];
        }
    }
}

/** 进度长度 */
- (CGFloat)LFVideoPlayerSyncScrubProgressWidth:(LFVideoPlayer *)player
{
    if ([self.clipDelegate respondsToSelector:@selector(lf_videoClippingViewProgressWidth:)]) {
        return [self.clipDelegate lf_videoClippingViewProgressWidth:self];
    }
    return [UIScreen mainScreen].bounds.size.width;
}


#pragma mark - LFEditingProtocol

#pragma mark - 数据
- (NSDictionary *)photoEditData
{
    NSDictionary *drawData = _drawView.data;
    NSDictionary *stickerData = _stickerView.data;
    NSDictionary *filterData = _playerView.data;
    
    NSMutableDictionary *data = [@{} mutableCopy];
    if (drawData) [data setObject:drawData forKey:kLFVideoCLippingViewData_draw];
    if (stickerData) [data setObject:stickerData forKey:kLFVideoCLippingViewData_sticker];
    if (filterData) [data setObject:filterData forKey:kLFVideoCLippingViewData_filter];
    
    if (self.startTime > 0 || self.endTime < self.totalDuration || (_rate > 0 && !(_rate + FLT_EPSILON > 1.0 && _rate - FLT_EPSILON < 1.0))) {
        NSDictionary *myData = @{kLFVideoCLippingViewData_startTime:@(self.startTime)
                                 , kLFVideoCLippingViewData_endTime:@(self.endTime)
                                 , kLFVideoCLippingViewData_rate:@(self.rate)};
        [data setObject:myData forKey:kLFVideoCLippingViewData];
    }
    
    if (data.count) {
        return data;
    }
    return nil;
}

- (void)setPhotoEditData:(NSDictionary *)photoEditData
{
    NSDictionary *myData = photoEditData[kLFVideoCLippingViewData];
    if (myData) {
        self.startTime = self.old_startTime = [myData[kLFVideoCLippingViewData_startTime] doubleValue];
        self.endTime = self.old_endTime = [myData[kLFVideoCLippingViewData_endTime] doubleValue];
        self.rate = [myData[kLFVideoCLippingViewData_rate] floatValue];
    }
    _drawView.data = photoEditData[kLFVideoCLippingViewData_draw];
    _stickerView.data = photoEditData[kLFVideoCLippingViewData_sticker];
    _playerView.data = photoEditData[kLFVideoCLippingViewData_filter];
}

@end
