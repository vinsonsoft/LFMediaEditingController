//
//  LFVideoEditingController.m
//  LFMediaEditingController
//
//  Created by LamTsanFeng on 2017/7/17.
//  Copyright © 2017年 LamTsanFeng. All rights reserved.
//

#import "LFVideoEditingController.h"
#import "LFMediaEditingHeader.h"
#import "UIView+LFMEFrame.h"
#import "UIImage+LFMECommon.h"
#import "LFMediaEditingType.h"
#import "LFMECancelBlock.h"

#import "LFVideoEditingView.h"
#import "LFEditToolbar.h"
#import "LFStickerBar.h"
#import "LFTextBar.h"
#import "LFVideoClipToolbar.h"
#import "LFAudioTrackBar.h"
#import "JRFilterBar.h"
#import "FilterSuiteUtils.h"
#import "AVAsset+LFMECommon.h"
#import "UIColor+CustomColors.h"
#import "NSObject+LFTipsGuideView.h"

/************************ Attributes ************************/
/** NSNumber containing LFVideoEditOperationSubType, default 0 */
LFVideoEditOperationStringKey const LFVideoEditDrawColorAttributeName = @"LFVideoEditDrawColorAttributeName";
/** NSNumber containing LFVideoEditOperationSubType, default 0 */
LFVideoEditOperationStringKey const LFVideoEditDrawBrushAttributeName = @"LFVideoEditDrawBrushAttributeName";
/** NSString containing string path, default nil. sticker resource path. */
LFVideoEditOperationStringKey const LFVideoEditStickerAttributeName = @"LFVideoEditStickerAttributeName";
/** NSArray containing NSArray<LFStickerContent *>, default @[[LFStickerContent stickerContentWithTitle:@"默认" contents:@[LFStickerContentDefaultSticker]]]. */
LFVideoEditOperationStringKey const LFVideoEditStickerContentsAttributeName = @"LFVideoEditStickerContentsAttributeName";
/** NSNumber containing LFVideoEditOperationSubType, default 0 */
LFVideoEditOperationStringKey const LFVideoEditTextColorAttributeName = @"LFVideoEditTextColorAttributeName";
/** NSNumber containing BOOL, default false: default audioTrack ,true: mute. */
LFVideoEditOperationStringKey const LFVideoEditAudioMuteAttributeName = @"LFVideoEditAudioMuteAttributeName";
/** NSArray  containing NSURL(fileURLWithPath:), default nil. audio resource paths. */
LFVideoEditOperationStringKey const LFVideoEditAudioUrlsAttributeName = @"LFVideoEditAudioUrlsAttributeName";
/** NSNumber containing LFVideoEditOperationSubType, default 0 */
LFVideoEditOperationStringKey const LFVideoEditFilterAttributeName = @"LFVideoEditFilterAttributeName";
/** NSNumber containing double, default 1, Range of 0.5 to 2.0. */
LFVideoEditOperationStringKey const LFVideoEditRateAttributeName = @"LFVideoEditRateAttributeName";
/** NSNumber containing double, default 1.0. Must be greater than 0 and less than LFVideoEditClipMaxDurationAttributeName, otherwise invalid. */
LFVideoEditOperationStringKey const LFVideoEditClipMinDurationAttributeName = @"LFVideoEditClipMinDurationAttributeName";
/** NSNumber containing double, default 0. Must be greater than min, otherwise invalid. 0 is not limited. */
LFVideoEditOperationStringKey const LFVideoEditClipMaxDurationAttributeName = @"LFVideoEditClipMaxDurationAttributeName";
/************************ Attributes ************************/

@interface LFVideoEditingController () <LFEditToolbarDelegate, LFStickerBarDelegate, LFTextBarDelegate, JRFilterBarDelegate, JRFilterBarDataSource, LFAudioTrackBarDelegate, LFVideoClipToolbarDelegate, LFPhotoEditDelegate, UIGestureRecognizerDelegate, LFVideoEditingPlayerDelegate>
{
    /** 编辑模式 */
    LFVideoEditingView *_EditingView;
    
    UIView *_edit_naviBar;
    /** 底部栏菜单 */
    LFEditToolbar *_edit_toolBar;
    
    /** 贴图菜单 */
    LFStickerBar *_edit_sticker_toolBar;
    /** 滤镜菜单 */
    JRFilterBar *_edit_filter_toolBar;
    /** 剪切菜单 */
    LFVideoClipToolbar *_edit_clipping_toolBar;
    
    /** 单击手势 */
    UITapGestureRecognizer *singleTapRecognizer;
}

/** 隐藏控件 */
@property (nonatomic, assign) BOOL isHideNaviBar;
/** 初始化以选择的功能类型，已经初始化过的将被去掉类型，最终类型为0 */
@property (nonatomic, assign) LFVideoEditOperationType initSelectedOperationType;

@property (nonatomic, copy) lf_me_dispatch_cancelable_block_t delayCancelBlock;

/** 滤镜缩略图 */
@property (nonatomic, strong) UIImage *filterSmallImage;

@property (nonatomic, strong, nullable) NSDictionary *editData;

@property (nonatomic, strong, nullable) id stickerBarCacheResource;

@end

@implementation LFVideoEditingController

- (instancetype)initWithOrientation:(UIInterfaceOrientation)orientation
{
    self = [super initWithOrientation:orientation];
    if (self) {
        _operationType = LFVideoEditOperationType_All;
        _minClippingDuration = 1.f;
    }
    return self;
}

- (void)setVideoURL:(NSURL *)url placeholderImage:(UIImage *)image;
{
    AVAsset *asset = [AVURLAsset assetWithURL:url];
    [self setVideoAsset:asset placeholderImage:image];
}

- (void)setVideoAsset:(AVAsset *)asset placeholderImage:(UIImage *)image
{
    _asset = asset;
    _placeholderImage = image;
}

- (void)setVideoEdit:(LFVideoEdit *)videoEdit
{
    [self setVideoAsset:videoEdit.editAsset placeholderImage:videoEdit.editPreviewImage];
    _editData = videoEdit.editData;
}

- (void)setMinClippingDuration:(double)minClippingDuration
{
    if (minClippingDuration > 0.999) {
        _minClippingDuration = minClippingDuration;
        _EditingView.minClippingDuration = minClippingDuration;
    }
}

- (void)setDefaultOperationType:(LFVideoEditOperationType)defaultOperationType
{
    _defaultOperationType = defaultOperationType;
    _initSelectedOperationType = defaultOperationType;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    /** 为了适配iOS13的UIModalPresentationPageSheet模态，它会在viewDidLoad之后对self.view的大小调整，迫不得已暂时只能在viewWillAppear加载视图 */
    if (@available(iOS 13.0, *)) {
        if (isiPhone && self.presentingViewController && self.navigationController.modalPresentationStyle == UIModalPresentationPageSheet) {
            return;
        }
    }
    
    [self configEditingView];
    [self configCustomNaviBar];
    [self configBottomToolBar];
    [self configDefaultOperation];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    if (_EditingView == nil) {
        [self configEditingView];
        [self configCustomNaviBar];
        [self configBottomToolBar];
        [self configDefaultOperation];
    }
}

- (void)viewWillLayoutSubviews
{
    [super viewWillLayoutSubviews];
    
    if (@available(iOS 11.0, *)) {
        _edit_naviBar.lfme_height = kCustomTopbarHeight_iOS11;
    } else {
        _edit_naviBar.lfme_height = kCustomTopbarHeight;
    }
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    
    // 部分视图需要获取安全区域。统一在这里执行用户指引；
    [self configUserGuide];
}

- (void)dealloc
{
    
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - 创建视图
- (void)configEditingView
{
    CGRect editRect = self.view.bounds;
    
//    if (@available(iOS 11.0, *)) {
//        if (hasSafeArea) {
//            editRect.origin.x += self.navigationController.view.safeAreaInsets.left;
//            editRect.origin.y += self.navigationController.view.safeAreaInsets.top;
//            editRect.size.width -= (self.navigationController.view.safeAreaInsets.left+self.navigationController.view.safeAreaInsets.right);
//            editRect.size.height -= (self.navigationController.view.safeAreaInsets.top+self.navigationController.view.safeAreaInsets.bottom);
//        }
//    }
    
    _EditingView = [[LFVideoEditingView alloc] initWithFrame:editRect];
    _EditingView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _EditingView.editDelegate = self;
    _EditingView.playerDelegate = self;
    
    /** 单击的 Recognizer */
    singleTapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(singlePressed)];
    /** 点击的次数 */
    singleTapRecognizer.numberOfTapsRequired = 1; // 单击
    singleTapRecognizer.delegate = self;
    /** 给view添加一个手势监测 */
    [self.view addGestureRecognizer:singleTapRecognizer];
    
    [self.view addSubview:_EditingView];
    
    double minClippingDuration = [self operationDoubleForKey:LFVideoEditClipMinDurationAttributeName];
    double maxClippingDuration = [self operationDoubleForKey:LFVideoEditClipMaxDurationAttributeName];
    NSAssert(minClippingDuration > 0 && (maxClippingDuration == 0 || minClippingDuration < maxClippingDuration), @"Must be greater than 0 and less than LFVideoEditClipMaxDurationAttributeName");
    NSAssert(maxClippingDuration == 0 || maxClippingDuration > minClippingDuration, @"Must be greater than LFVideoEditClipMinDurationAttributeName");
    _EditingView.minClippingDuration = minClippingDuration;
    _EditingView.maxClippingDuration = maxClippingDuration;
    
    [_EditingView setVideoAsset:_asset placeholderImage:_placeholderImage];
    if (self.editData) {
        // 设置编辑数据
        _EditingView.photoEditData = self.editData;
        // 释放销毁
        self.editData = nil;
    } else {
        
        /** default audio urls */
        NSMutableArray *m_audioUrls = [_EditingView.audioUrls mutableCopy];
        for (LFAudioItem *audioItem in m_audioUrls) {
            if (audioItem.isOriginal) {
                audioItem.isEnable = ![self operationBOOLForKey:LFVideoEditAudioMuteAttributeName];
                break;
            }
        }
        /** 音频资源 */
        NSArray <NSURL *>*defaultAudioUrls = [self operationArrayURLForKey:LFVideoEditAudioUrlsAttributeName];
        
        if (defaultAudioUrls.count) {
            for (NSURL *url in defaultAudioUrls) {
                if ([url isKindOfClass:[NSURL class]]) {
                    LFAudioItem *item = [LFAudioItem new];
                    item.title = [url.lastPathComponent stringByDeletingPathExtension];;
                    item.url = url;
                    item.isEnable = YES;
                    [m_audioUrls addObject:item];
                }
            }
            _EditingView.audioUrls = m_audioUrls;
        }
        
        /** 设置默认滤镜 */
        if (@available(iOS 9.0, *)) {
            if (self.operationType&LFVideoEditOperationType_filter) {
                LFVideoEditOperationSubType subType = [self operationSubTypeForKey:LFVideoEditFilterAttributeName];
                NSInteger index = 0;
                switch (subType) {
                    case LFVideoEditOperationSubTypeLinearCurveFilter:
                    case LFVideoEditOperationSubTypeChromeFilter:
                    case LFVideoEditOperationSubTypeFadeFilter:
                    case LFVideoEditOperationSubTypeInstantFilter:
                    case LFVideoEditOperationSubTypeMonoFilter:
                    case LFVideoEditOperationSubTypeNoirFilter:
                    case LFVideoEditOperationSubTypeProcessFilter:
                    case LFVideoEditOperationSubTypeTonalFilter:
                    case LFVideoEditOperationSubTypeTransferFilter:
                    case LFVideoEditOperationSubTypeCurveLinearFilter:
                    case LFVideoEditOperationSubTypeInvertFilter:
                    case LFVideoEditOperationSubTypeMonochromeFilter:
                        index = subType % 400 + 1;
                        break;
                    default:
                        break;
                }
                
                if (index > 0) {
                    [_EditingView changeFilterType:index];
                }
            }
        }
    }
}

- (void)configCustomNaviBar
{
    if (self.hideCustomNavBar) {
        return;
    }
    CGFloat margin = 5, topbarHeight = 0;
    if (@available(iOS 11.0, *)) {
        topbarHeight = kCustomTopbarHeight_iOS11;
    } else {
        topbarHeight = kCustomTopbarHeight;
    }
    CGFloat naviHeight = CGRectGetHeight(self.navigationController.navigationBar.frame);
    
    _edit_naviBar = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.lfme_width, topbarHeight)];
    _edit_naviBar.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleBottomMargin;
    _edit_naviBar.backgroundColor = [UIColor colorWithRed:(34/255.0) green:(34/255.0)  blue:(34/255.0) alpha:0.7];
    
    UIView *naviBar = [[UIView alloc] initWithFrame:CGRectMake(0, topbarHeight-naviHeight, _edit_naviBar.frame.size.width, naviHeight)];
    naviBar.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
    [_edit_naviBar addSubview:naviBar];
    
    UIFont *font = [UIFont systemFontOfSize:15];
    CGFloat editCancelWidth = [[NSBundle LFME_localizedStringForKey:@"_LFME_cancelButtonTitle"] boundingRectWithSize:CGSizeMake(CGFLOAT_MAX, CGFLOAT_MAX) options:NSStringDrawingUsesFontLeading attributes:@{NSFontAttributeName:font} context:nil].size.width + 30;
    UIButton *_edit_cancelButton = [[UIButton alloc] initWithFrame:CGRectMake(margin, 0, editCancelWidth, naviHeight)];
    _edit_cancelButton.autoresizingMask = UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
    [_edit_cancelButton setTitle:[NSBundle LFME_localizedStringForKey:@"_LFME_cancelButtonTitle"] forState:UIControlStateNormal];
    _edit_cancelButton.titleLabel.font = font;
    [_edit_cancelButton setTitleColor:self.cancelButtonTitleColorNormal forState:UIControlStateNormal];
    [_edit_cancelButton addTarget:self action:@selector(cancelButtonClick) forControlEvents:UIControlEventTouchUpInside];
    [naviBar addSubview:_edit_cancelButton];
    
    CGFloat editOkWidth = [[NSBundle LFME_localizedStringForKey:@"_LFME_oKButtonTitle"] boundingRectWithSize:CGSizeMake(CGFLOAT_MAX, CGFLOAT_MAX) options:NSStringDrawingUsesFontLeading attributes:@{NSFontAttributeName:font} context:nil].size.width + 30;
    
    UIButton *_edit_finishButton = [[UIButton alloc] initWithFrame:CGRectMake(self.view.lfme_width - editOkWidth-margin, 0, editOkWidth, naviHeight)];
    _edit_finishButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
    [_edit_finishButton setTitle:[NSBundle LFME_localizedStringForKey:@"_LFME_oKButtonTitle"] forState:UIControlStateNormal];
    _edit_finishButton.titleLabel.font = font;
    [_edit_finishButton setTitleColor:self.oKButtonTitleColorNormal forState:UIControlStateNormal];
    [_edit_finishButton addTarget:self action:@selector(finishButtonClick) forControlEvents:UIControlEventTouchUpInside];
    [naviBar addSubview:_edit_finishButton];
    
    [self.view addSubview:_edit_naviBar];
}

- (void)configBottomToolBar
{
    LFEditToolbarType toolbarType = 0;
    if (self.operationType&LFVideoEditOperationType_draw) {
        toolbarType |= LFEditToolbarType_draw;
    }
    if (self.operationType&LFVideoEditOperationType_sticker) {
        toolbarType |= LFEditToolbarType_sticker;
    }
    if (self.operationType&LFVideoEditOperationType_text) {
        toolbarType |= LFEditToolbarType_text;
    }
    if (self.operationType&LFVideoEditOperationType_audio) {
        toolbarType |= LFEditToolbarType_audio;
    }
    if (@available(iOS 9.0, *)) {
        if (self.operationType&LFVideoEditOperationType_filter) {
            toolbarType |= LFEditToolbarType_filter;
        }
    }
    if (self.operationType&LFVideoEditOperationType_rate) {
        toolbarType |= LFEditToolbarType_rate;
    }
    if (self.operationType&LFVideoEditOperationType_clip) {
        toolbarType |= LFEditToolbarType_clip;
    }
    
    _edit_toolBar = [[LFEditToolbar alloc] initWithType:toolbarType];
    _edit_toolBar.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
    _edit_toolBar.delegate = self;
    
    NSInteger index = 2; /** 红色 */
    
    /** 设置默认绘画颜色 */
    if (self.operationType&LFVideoEditOperationType_draw) {
        LFVideoEditOperationSubType subType = [self operationSubTypeForKey:LFVideoEditDrawColorAttributeName];
        switch (subType) {
            case LFVideoEditOperationSubTypeDrawWhiteColor:
            case LFVideoEditOperationSubTypeDrawBlackColor:
            case LFVideoEditOperationSubTypeDrawRedColor:
            case LFVideoEditOperationSubTypeDrawLightYellowColor:
            case LFVideoEditOperationSubTypeDrawYellowColor:
            case LFVideoEditOperationSubTypeDrawLightGreenColor:
            case LFVideoEditOperationSubTypeDrawGreenColor:
            case LFVideoEditOperationSubTypeDrawAzureColor:
            case LFVideoEditOperationSubTypeDrawRoyalBlueColor:
            case LFVideoEditOperationSubTypeDrawBlueColor:
            case LFVideoEditOperationSubTypeDrawPurpleColor:
            case LFVideoEditOperationSubTypeDrawLightPinkColor:
            case LFVideoEditOperationSubTypeDrawVioletRedColor:
            case LFVideoEditOperationSubTypeDrawPinkColor:
                index = subType - 1;
                break;
            default:
                break;
        }
        [_edit_toolBar setDrawSliderColorAtIndex:index];
        
        subType = [self operationSubTypeForKey:LFVideoEditDrawBrushAttributeName];

        EditToolbarBrushType brushType = 0;
        EditToolbarStampBrushType stampBrushType = 0;
        switch (subType) {
            case LFVideoEditOperationSubTypeDrawPaintBrush:
            case LFVideoEditOperationSubTypeDrawHighlightBrush:
            case LFVideoEditOperationSubTypeDrawChalkBrush:
            case LFVideoEditOperationSubTypeDrawFluorescentBrush:
                brushType = subType % 50;
                break;
            case LFVideoEditOperationSubTypeDrawStampAnimalBrush:
                brushType = EditToolbarBrushTypeStamp;
                stampBrushType = EditToolbarStampBrushTypeAnimal;
                break;
            case LFVideoEditOperationSubTypeDrawStampFruitBrush:
                brushType = EditToolbarBrushTypeStamp;
                stampBrushType = EditToolbarStampBrushTypeFruit;
                break;
            case LFVideoEditOperationSubTypeDrawStampHeartBrush:
                brushType = EditToolbarBrushTypeStamp;
                stampBrushType = EditToolbarStampBrushTypeHeart;
                break;
            default:
                break;
        }
        [_edit_toolBar setDrawBrushAtIndex:brushType subIndex:stampBrushType];
    }
    
    
    /** 设置默认速率 */
    if (self.operationType&LFVideoEditOperationType_rate && _EditingView.rate == 1.f) {
        double rate = [self operationDoubleForKey:LFVideoEditRateAttributeName];
        [_edit_toolBar setRate:rate];
        [_EditingView setRate:rate];
    }
    
    [self.view addSubview:_edit_toolBar];
}

- (void)configDefaultOperation
{
    if (self.initSelectedOperationType > 0) {
        
        __weak typeof(self) weakSelf = self;
        BOOL (^containOperation)(LFVideoEditOperationType type) = ^(LFVideoEditOperationType type){
            if (weakSelf.operationType&type && weakSelf.initSelectedOperationType&type) {
                weakSelf.initSelectedOperationType ^= type;
                return YES;
            }
            return NO;
        };
        
        if (containOperation(LFVideoEditOperationType_clip)) {
//            [_EditingView setIsClipping:YES animated:NO];
//            [self changeClipMenu:YES animated:NO];
            [_edit_toolBar selectMainMenuIndex:LFEditToolbarType_clip];
        } else {
            if (containOperation(LFVideoEditOperationType_draw)) {
                [_edit_toolBar selectMainMenuIndex:LFEditToolbarType_draw];
            } else if (containOperation(LFVideoEditOperationType_sticker)) {
                [_edit_toolBar selectMainMenuIndex:LFEditToolbarType_sticker];
            } else if (containOperation(LFVideoEditOperationType_text)) {
                [_edit_toolBar selectMainMenuIndex:LFEditToolbarType_text];
            } else if (containOperation(LFVideoEditOperationType_audio)) {
                [_edit_toolBar selectMainMenuIndex:LFEditToolbarType_audio];
            } else {
                BOOL isDoIt = YES;
                if (@available(iOS 9.0, *)) {
                    if (containOperation(LFVideoEditOperationType_filter)) {
                        [_edit_toolBar selectMainMenuIndex:LFEditToolbarType_filter];
                        isDoIt = NO;
                    }
                }
                if (isDoIt) {
                    if (containOperation(LFVideoEditOperationType_rate)) {
                        [_edit_toolBar selectMainMenuIndex:LFEditToolbarType_rate];
                    }
                }
            }
            self.initSelectedOperationType = 0;
        }
    }
}

- (void)configUserGuide
{
    // 设置首次启动其他功能，需要返回后再提示
    if (self.defaultOperationType&LFVideoEditOperationType_clip && _EditingView.isClipping) {
        return;
    }
    
    UIView *mainView = self.navigationController.view;
    {
        if (_edit_toolBar.items > kToolbar_MaxItems) {
            CGFloat height = kToolbar_MainHeight;
            if (@available(iOS 11.0, *)) {
                height += self.view.safeAreaInsets.bottom;
            }
            CGRect toolbarFrame = CGRectMake(0, CGRectGetHeight(self.view.frame)-height, CGRectGetWidth(self.view.frame), height);
            [self lf_showInView:mainView maskRects:@[[NSValue valueWithCGRect:toolbarFrame]] withTips:@[[NSBundle LFME_localizedStringForKey:@"_LFME_UserGuide_ToolBar_Scroll"]]];
        }
    }
}

#pragma mark - 顶部栏(action)
- (void)singlePressed
{
    [self singlePressedWithAnimated:YES];
}
- (void)singlePressedWithAnimated:(BOOL)animated
{
    if (!(_EditingView.isDrawing || _EditingView.isSplashing)) {
        _isHideNaviBar = !_isHideNaviBar;
        [self changedBarStateWithAnimated:animated];
    }
}
- (void)pauseVideo
{
    [_EditingView pauseVideo];
    
}

- (void)cancelButtonClick
{
    [_EditingView pauseVideo];
    /** 恢复原来的音频 */
    [[AVAudioSession sharedInstance] setActive:NO withOptions:AVAudioSessionSetActiveOptionNotifyOthersOnDeactivation error:nil];
    if ([self.delegate respondsToSelector:@selector(lf_VideoEditingControllerDidCancel:)]) {
        [self.delegate lf_VideoEditingControllerDidCancel:self];
    }
    #pragma clang diagnostic push
    #pragma clang diagnostic ignored "-Wdeprecated-declarations"
    else if ([self.delegate respondsToSelector:@selector(lf_VideoEditingController:didCancelPhotoEdit:)]) {
        [self.delegate lf_VideoEditingController:self didCancelPhotoEdit:nil];
    }
    #pragma clang diagnostic pop
    
}

- (void)finishButtonClick
{
    [self showProgressVideoHUD];
    /** 取消贴图激活 */
    [_EditingView stickerDeactivated];
    /** 处理编辑图片 */
    __block LFVideoEdit *videoEdit = nil;
    NSDictionary *data = [_EditingView photoEditData];
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        if (data) {
            dispatch_async(dispatch_get_main_queue(), ^{
                __strong typeof(weakSelf) strongSelf = weakSelf;
                [strongSelf->_EditingView exportAsynchronouslyWithTrimVideo:^(NSURL *trimURL, NSError *error) {
                    if (error) {
                        [weakSelf showErrorMessage:error.description];
                    } else {
                        videoEdit = [[LFVideoEdit alloc] initWithEditAsset:weakSelf.asset editFinalURL:trimURL data:data];
                        [[AVAudioSession sharedInstance] setActive:NO withOptions:AVAudioSessionSetActiveOptionNotifyOthersOnDeactivation error:nil];
                        if ([weakSelf.delegate respondsToSelector:@selector(lf_VideoEditingController:didFinishPhotoEdit:)]) {
                            [weakSelf.delegate lf_VideoEditingController:weakSelf didFinishPhotoEdit:videoEdit];
                        }
                    }
                    [weakSelf hideProgressHUD];
                } progress:^(float progress) {
                    [weakSelf setProgress:progress];
                }];
            });
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
                __strong typeof(weakSelf) strongSelf = weakSelf;
                [strongSelf->_EditingView pauseVideo];
                [[AVAudioSession sharedInstance] setActive:NO withOptions:AVAudioSessionSetActiveOptionNotifyOthersOnDeactivation error:nil];
                if ([weakSelf.delegate respondsToSelector:@selector(lf_VideoEditingController:didFinishPhotoEdit:)]) {
                    [weakSelf.delegate lf_VideoEditingController:weakSelf didFinishPhotoEdit:videoEdit];
                }
                [weakSelf hideProgressHUD];
            });
        }
    });
}

#pragma mark - UIGestureRecognizerDelegate
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch
{
    if ([touch.view isDescendantOfView:_EditingView]) {
        return YES;
    }
    return NO;
}

#pragma mark - LFEditToolbarDelegate 底部栏(action)

/** 一级菜单点击事件 */
- (void)lf_editToolbar:(LFEditToolbar *)editToolbar mainDidSelectAtIndex:(NSUInteger)index
{
    /** 取消贴图激活 */
    [_EditingView stickerDeactivated];
    
    switch (index) {
        case LFEditToolbarType_draw:
        {
            /** 关闭涂抹 */
            _EditingView.splashEnable = NO;
            /** 打开绘画 */
            _EditingView.drawEnable = !_EditingView.drawEnable;
        }
            break;
        case LFEditToolbarType_sticker:
        {
            _EditingView.splashEnable = NO;
            _EditingView.drawEnable = NO;
            [self singlePressed];
            [self changeStickerMenu:YES animated:YES];
        }
            break;
        case LFEditToolbarType_text:
        {
            _EditingView.splashEnable = NO;
            _EditingView.drawEnable = NO;
            [self showTextBarController:nil];
        }
            break;
        case LFEditToolbarType_splash:
        {
            /** 关闭绘画 */
            _EditingView.drawEnable = NO;
            /** 打开涂抹 */
            _EditingView.splashEnable = !_EditingView.splashEnable;
        }
            break;
        case LFEditToolbarType_audio:
        {
            /** 音轨编辑UI */
            _EditingView.splashEnable = NO;
            _EditingView.drawEnable = NO;
            [self showAudioTrackBar];
        }
            break;
        case LFEditToolbarType_filter:
        {
            _EditingView.splashEnable = NO;
            _EditingView.drawEnable = NO;
            [self singlePressed];
            [self changeFilterMenu:YES animated:YES];
        }
            break;
        case LFEditToolbarType_clip:
        {
            _EditingView.splashEnable = NO;
            _EditingView.drawEnable = NO;
            [_EditingView setIsClipping:YES animated:YES];
            [self changeClipMenu:YES];
        }
            break;
        case LFEditToolbarType_rate:
        {
            _EditingView.splashEnable = NO;
            _EditingView.drawEnable = NO;
            editToolbar.rate = _EditingView.rate;
        }
            break;
        default:
            break;
    }
}
/** 二级菜单点击事件-撤销 */
- (void)lf_editToolbar:(LFEditToolbar *)editToolbar subDidRevokeAtIndex:(NSUInteger)index
{
    switch (index) {
        case LFEditToolbarType_draw:
        {
            [_EditingView drawUndo];
        }
            break;
        case LFEditToolbarType_sticker:
            break;
        case LFEditToolbarType_text:
            break;
        case LFEditToolbarType_splash:
        {
            [_EditingView splashUndo];
        }
            break;
        case LFEditToolbarType_audio:
            break;
        case LFEditToolbarType_clip:
            break;
        default:
            break;
    }
}
/** 二级菜单点击事件-按钮 */
- (void)lf_editToolbar:(LFEditToolbar *)editToolbar subDidSelectAtIndex:(NSIndexPath *)indexPath
{
    switch (indexPath.section) {
        case LFEditToolbarType_draw:
            break;
        case LFEditToolbarType_sticker:
            break;
        case LFEditToolbarType_text:
            break;
        case LFEditToolbarType_splash:
            break;
        case LFEditToolbarType_audio:
            break;
        case LFEditToolbarType_clip:
            break;
        default:
            break;
    }
}
/** 撤销允许权限获取 */
- (BOOL)lf_editToolbar:(LFEditToolbar *)editToolbar canRevokeAtIndex:(NSUInteger)index
{
    BOOL canUndo = NO;
    switch (index) {
        case LFEditToolbarType_draw:
        {
            canUndo = [_EditingView drawCanUndo];
        }
            break;
        case LFEditToolbarType_sticker:
            break;
        case LFEditToolbarType_text:
            break;
        case LFEditToolbarType_splash:
        {
            canUndo = [_EditingView splashCanUndo];
        }
            break;
        case LFEditToolbarType_audio:
            break;
        case LFEditToolbarType_clip:
            break;
        default:
            break;
    }
    
    return canUndo;
}
/** 二级菜单滑动事件-绘画 */
- (void)lf_editToolbar:(LFEditToolbar *)editToolbar drawColorDidChange:(UIColor *)color
{
    [_EditingView setDrawColor:color];
}
/** 二级菜单笔刷事件-绘画 */
- (void)lf_editToolbar:(LFEditToolbar *)editToolbar drawBrushDidChange:(LFBrush *)brush
{
    [_EditingView setDrawBrush:brush];
}
/** 二级菜单滑动事件-速率 */
- (void)lf_editToolbar:(LFEditToolbar *)editToolbar rateDidChange:(float)value
{
    _EditingView.rate = value;
}

#pragma mark - LFStickerBarDelegate
- (void)lf_stickerBar:(LFStickerBar *)lf_stickerBar didSelectImage:(UIImage *)image
{
    if (image) {
        LFStickerItem *item = [LFStickerItem new];
        item.image = image;
        [_EditingView createSticker:item];
    }
    [self singlePressed];
}

#pragma mark - LFTextBarDelegate
/** 完成回调 */
- (void)lf_textBarController:(LFTextBar *)textBar didFinishText:(LFText *)text
{
    if (text) {
        LFStickerItem *item = [LFStickerItem new];
        item.text = text;
        /** 判断是否更改文字 */
        if (textBar.showText) {
            [_EditingView changeSelectSticker:item];
        } else {
            [_EditingView createSticker:item];
        }
    } else {
        if (textBar.showText) { /** 文本被清除，删除贴图 */
            [_EditingView removeSelectStickerView];
        }
    }
    [self lf_textBarControllerDidCancel:textBar];
}
/** 取消回调 */
- (void)lf_textBarControllerDidCancel:(LFTextBar *)textBar
{
    /** 显示顶部栏 */
    _isHideNaviBar = NO;
    [self changedBarState];
    /** 更改文字情况才重新激活贴图 */
    if (textBar.showText) {
        [_EditingView activeSelectStickerView];
    }
    [textBar resignFirstResponder];
    
    [UIView animateWithDuration:0.25f delay:0.f options:UIViewAnimationOptionCurveLinear animations:^{
        textBar.lfme_y = self.view.lfme_height;
    } completion:^(BOOL finished) {
        [textBar removeFromSuperview];
    }];
}

/** 输入数量已经达到最大值 */
- (void)lf_textBarControllerDidReachMaximumLimit:(LFTextBar *)textBar
{
    [self showInfoMessage:[NSBundle LFME_localizedStringForKey:@"_LFME_reachMaximumLimitTitle"]];
}

#pragma mark - LFAudioTrackBarDelegate
/** 完成回调 */
- (void)lf_audioTrackBar:(LFAudioTrackBar *)audioTrackBar didFinishAudioUrls:(NSArray <LFAudioItem *> *)audioUrls
{
    _EditingView.audioUrls = audioUrls;
    [self lf_audioTrackBarDidCancel:audioTrackBar];
}
/** 取消回调 */
- (void)lf_audioTrackBarDidCancel:(LFAudioTrackBar *)audioTrackBar
{
    [_EditingView playVideo];
    /** 显示顶部栏 */
    _isHideNaviBar = NO;
    [self changedBarState];
    
    [UIView animateWithDuration:0.25f delay:0.f options:UIViewAnimationOptionCurveLinear animations:^{
        audioTrackBar.lfme_y = self.view.lfme_height;
    } completion:^(BOOL finished) {
        [audioTrackBar removeFromSuperview];
        
        self->singleTapRecognizer.enabled = YES;
    }];
}

#pragma mark - LFVideoClipToolbarDelegate
/** 取消 */
- (void)lf_videoClipToolbarDidCancel:(LFVideoClipToolbar *)clipToolbar
{
    if (self.initSelectedOperationType == 0 && self.operationType == LFVideoEditOperationType_clip && self.defaultOperationType == LFVideoEditOperationType_clip) { /** 证明initSelectedOperationType已消耗完毕，defaultOperationType是有值的。只有LFVideoEditOperationType_clip的情况，无需返回，直接完成整个编辑 */
        [self cancelButtonClick];
    } else {
        [_EditingView cancelClipping:YES];
        [self changeClipMenu:NO];
        [self configDefaultOperation];
        [self configUserGuide];
    }
}
/** 完成 */
- (void)lf_videoClipToolbarDidFinish:(LFVideoClipToolbar *)clipToolbar
{
    if (self.initSelectedOperationType == 0 && self.operationType == LFVideoEditOperationType_clip && self.defaultOperationType == LFVideoEditOperationType_clip) { /** 证明initSelectedOperationType已消耗完毕，defaultOperationType是有值的。只有LFVideoEditOperationType_clip的情况，无需返回，直接完成整个编辑 */
        [self finishButtonClick];
    } else {
        [_EditingView setIsClipping:NO animated:YES];
        [self changeClipMenu:NO];
        [self configDefaultOperation];
        [self configUserGuide];
    }
}

#pragma mark - LFPhotoEditDelegate
#pragma mark - LFPhotoEditDrawDelegate
/** 开始绘画 */
- (void)lf_photoEditDrawBegan
{
    _isHideNaviBar = YES;
    [self changedBarState];
}
/** 结束绘画 */
- (void)lf_photoEditDrawEnded
{
    /** 撤销生效 */
    if (_EditingView.drawCanUndo) [_edit_toolBar setRevokeAtIndex:LFEditToolbarType_draw];
    
    __weak typeof(self) weakSelf = self;
    lf_me_dispatch_cancel(self.delayCancelBlock);
    self.delayCancelBlock = lf_dispatch_block_t(1.f, ^{
        weakSelf.isHideNaviBar = NO;
        [weakSelf changedBarState];
    });
}

#pragma mark - LFPhotoEditStickerDelegate
/** 点击贴图 isActive=YES 选中的情况下点击 */
- (void)lf_photoEditStickerDidSelectViewIsActive:(BOOL)isActive
{
    _isHideNaviBar = NO;
    [self changedBarState];
    if (isActive) { /** 选中的情况下点击 */
        LFStickerItem *item = [_EditingView getSelectSticker];
        if (item.text) {
            [_EditingView stickerDeactivated];
            [self showTextBarController:item.text];
        }
    }
}
/** 贴图移动开始，可以通过getSelectSticker获取选中贴图 */
- (void)lf_photoEditStickerMovingBegan
{
    _isHideNaviBar = YES;
    [self changedBarState];
}
/** 贴图移动结束，可以通过getSelectSticker获取选中贴图 */
- (void)lf_photoEditStickerMovingEnded
{
    _isHideNaviBar = NO;
    [self changedBarState];
}

#pragma mark - LFPhotoEditSplashDelegate
/** 开始模糊 */
- (void)lf_photoEditSplashBegan
{
    _isHideNaviBar = YES;
    [self changedBarState];
}
/** 结束模糊 */
- (void)lf_photoEditSplashEnded
{
    /** 撤销生效 */
    if (_EditingView.splashCanUndo) [_edit_toolBar setRevokeAtIndex:LFEditToolbarType_splash];
    
    __weak typeof(self) weakSelf = self;
    lf_me_dispatch_cancel(self.delayCancelBlock);
    self.delayCancelBlock = lf_dispatch_block_t(1.f, ^{
        weakSelf.isHideNaviBar = NO;
        [weakSelf changedBarState];
    });
}

#pragma mark - LFVideoEditingPlayerDelegate
/** 错误回调 */
- (void)lf_videoEditingViewFailedToPrepare:(LFVideoEditingView *)editingView error:(NSError *)error
{
    [self showErrorMessage:error.localizedDescription];
}

#pragma mark - private
- (void)changedBarState
{
    [self changedBarStateWithAnimated:YES];
}
- (void)changedBarStateWithAnimated:(BOOL)animated
{
    CGFloat naviBarAlpha = self.isHideNaviBar ? 0.f : 1.f;
    NSDictionary *userInfo = @{ @"naviBarAlpha": @(naviBarAlpha),
                                @"animated": @(animated)};

    // Post the notification with the userInfo dictionary
    [[NSNotificationCenter defaultCenter] postNotificationName:@"BarStateChangedNotificationName"
                                                        object:nil
                                                      userInfo:userInfo];
    lf_me_dispatch_cancel(self.delayCancelBlock);
    /** 隐藏贴图菜单 */
    [self changeStickerMenu:NO animated:animated];
    /** 隐藏滤镜菜单 */
    [self changeFilterMenu:NO animated:animated];
    
    if (animated) {
        [UIView animateWithDuration:.25f animations:^{
            CGFloat alpha = self->_isHideNaviBar ? 0.f : 1.f;
            self->_edit_naviBar.alpha = alpha;
            self->_edit_toolBar.alpha = alpha;
        }];
        
        [UIView animateWithDuration:.25f animations:^{
            self->_isHideNaviBar ? [self->_EditingView hideButtons] : [self->_EditingView showButtons];
        }];
    } else {
        CGFloat alpha = _isHideNaviBar ? 0.f : 1.f;
        _edit_naviBar.alpha = alpha;
        _edit_toolBar.alpha = alpha;
    }
}

- (void)changeClipMenu:(BOOL)isChanged
{
    [self changeClipMenu:isChanged animated:YES];
}

- (void)changeClipMenu:(BOOL)isChanged animated:(BOOL)animated
{
    if (isChanged) {
        /** 关闭所有编辑 */
        [_EditingView photoEditEnable:NO];
        /** 切换菜单 */
        [self.view addSubview:self.edit_clipping_toolBar];
        if (animated) {
            [UIView animateWithDuration:0.25f animations:^{
                self->_edit_clipping_toolBar.alpha = 1.f;
            }];
        } else {
            _edit_clipping_toolBar.alpha = 1.f;
        }
        singleTapRecognizer.enabled = NO;
        [self singlePressedWithAnimated:animated];
    } else {
        if (_edit_clipping_toolBar.superview == nil) return;
        
        /** 开启编辑 */
        [_EditingView photoEditEnable:YES];
        
        singleTapRecognizer.enabled = YES;
        if (animated) {
            [UIView animateWithDuration:.25f animations:^{
                self->_edit_clipping_toolBar.alpha = 0.f;
            } completion:^(BOOL finished) {
                [self->_edit_clipping_toolBar removeFromSuperview];
            }];
        } else {
            [_edit_clipping_toolBar removeFromSuperview];
        }
        
        [self singlePressedWithAnimated:animated];
    }
}

- (void)changeStickerMenu:(BOOL)isChanged animated:(BOOL)animated
{
    if (isChanged) {
        [self.view addSubview:self.edit_sticker_toolBar];
        CGRect frame = self.edit_sticker_toolBar.frame;
        frame.origin.y = self.view.lfme_height-frame.size.height;
        if (animated) {
            [UIView animateWithDuration:.25f animations:^{
                self->_edit_sticker_toolBar.frame = frame;
            }];
        } else {
            _edit_sticker_toolBar.frame = frame;
        }
    } else {
        if (_edit_sticker_toolBar.superview == nil) return;
        
        CGRect frame = self.edit_sticker_toolBar.frame;
        frame.origin.y = self.view.lfme_height;
        if (animated) {
            [UIView animateWithDuration:.25f animations:^{
                self->_edit_sticker_toolBar.frame = frame;
            } completion:^(BOOL finished) {
                self.stickerBarCacheResource = self->_edit_sticker_toolBar.cacheResources;
                [self->_edit_sticker_toolBar removeFromSuperview];
                self->_edit_sticker_toolBar = nil;
            }];
        } else {
            self.stickerBarCacheResource = self->_edit_sticker_toolBar.cacheResources;
            [_edit_sticker_toolBar removeFromSuperview];
            _edit_sticker_toolBar = nil;
        }
    }
}

- (void)showTextBarController:(LFText *)text
{
    static NSInteger LFTextBarTag = 32735;
    if ([self.view viewWithTag:LFTextBarTag]) {
        return;
    }
    
    LFTextBar *textBar = [[LFTextBar alloc] initWithFrame:CGRectMake(0, self.view.lfme_height, self.view.lfme_width, self.view.lfme_height) layout:^(LFTextBar *textBar) {
        textBar.oKButtonTitleColorNormal = self.oKButtonTitleColorNormal;
        textBar.cancelButtonTitleColorNormal = self.cancelButtonTitleColorNormal;
        textBar.oKButtonTitle = [NSBundle LFME_localizedStringForKey:@"_LFME_oKButtonTitle"];
        textBar.cancelButtonTitle = [NSBundle LFME_localizedStringForKey:@"_LFME_cancelButtonTitle"];
        if (self->_hideCustomNavBar) {
            CGFloat topbarHeight = 0;
            if (@available(iOS 11.0, *)) {
                topbarHeight = kCustomTopbarHeight_iOS11;
            } else {
                topbarHeight = kCustomTopbarHeight;
            }
            textBar.customTopbarHeight = topbarHeight;
        } else {
            textBar.customTopbarHeight = self->_edit_naviBar.lfme_height;
        }
        textBar.naviHeight = CGRectGetHeight(self.navigationController.navigationBar.frame);
    }];
    textBar.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    textBar.showText = text;
    textBar.delegate = self;
    textBar.tag = LFTextBarTag;
    
    if (text == nil) {
        /** 设置默认文字颜色 */
        LFVideoEditOperationSubType subType = [self operationSubTypeForKey:LFVideoEditTextColorAttributeName];
        
        NSInteger index = 0;
        switch (subType) {
            case LFVideoEditOperationSubTypeTextWhiteColor: index = 0; break;
            case LFVideoEditOperationSubTypeTextBlackColor: index = 1; break;
            case LFVideoEditOperationSubTypeTextRedColor: index = 2; break;
            case LFVideoEditOperationSubTypeTextLightYellowColor: index = 3; break;
            case LFVideoEditOperationSubTypeTextYellowColor: index = 4; break;
            case LFVideoEditOperationSubTypeTextLightGreenColor: index = 5; break;
            case LFVideoEditOperationSubTypeTextGreenColor: index = 6; break;
            case LFVideoEditOperationSubTypeTextAzureColor: index = 7; break;
            case LFVideoEditOperationSubTypeTextRoyalBlueColor: index = 8; break;
            case LFVideoEditOperationSubTypeTextBlueColor: index = 9; break;
            case LFVideoEditOperationSubTypeTextPurpleColor: index = 10; break;
            case LFVideoEditOperationSubTypeTextLightPinkColor: index = 11; break;
            case LFVideoEditOperationSubTypeTextVioletRedColor: index = 12; break;
            case LFVideoEditOperationSubTypeTextPinkColor: index = 13; break;
            default:
                break;
        }
        [textBar setTextSliderColorAtIndex:index];
    }
    
    [self.view addSubview:textBar];
    
    [textBar becomeFirstResponder];
    [UIView animateWithDuration:0.25f animations:^{
        textBar.lfme_y = 0;
    } completion:^(BOOL finished) {
        /** 隐藏顶部栏 */
        self->_isHideNaviBar = YES;
        [self changedBarState];
    }];
}

#pragma mark - 音轨菜单
- (void)showAudioTrackBar
{
    LFAudioTrackBar *audioTrackBar = [[LFAudioTrackBar alloc] initWithFrame:CGRectMake(0, self.view.lfme_height, self.view.lfme_width, self.view.lfme_height) layout:^(LFAudioTrackBar *audioTrackBar) {
        audioTrackBar.oKButtonTitleColorNormal = self.oKButtonTitleColorNormal;
        audioTrackBar.cancelButtonTitleColorNormal = self.cancelButtonTitleColorNormal;
        audioTrackBar.oKButtonTitle = [NSBundle LFME_localizedStringForKey:@"_LFME_oKButtonTitle"];
        audioTrackBar.cancelButtonTitle = [NSBundle LFME_localizedStringForKey:@"_LFME_cancelButtonTitle"];
        if (self->_hideCustomNavBar) {
            CGFloat topbarHeight = 0;
            if (@available(iOS 11.0, *)) {
                topbarHeight = kCustomTopbarHeight_iOS11;
            } else {
                topbarHeight = kCustomTopbarHeight;
            }
            audioTrackBar.customTopbarHeight = topbarHeight;
        } else {
            audioTrackBar.customTopbarHeight = self->_edit_naviBar.lfme_height;
        }
        audioTrackBar.naviHeight = CGRectGetHeight(self.navigationController.navigationBar.frame);
        if (@available(iOS 11.0, *)) {
            audioTrackBar.customToolbarHeight = 44.f+self.navigationController.view.safeAreaInsets.bottom;
        } else {
            audioTrackBar.customToolbarHeight = 44.f;
        }
    }];
    
    audioTrackBar.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    audioTrackBar.delegate = self;
    audioTrackBar.audioUrls = _EditingView.audioUrls;
    
    [self.view addSubview:audioTrackBar];
    
    [UIView animateWithDuration:0.25f animations:^{
        audioTrackBar.lfme_y = 0;
    } completion:^(BOOL finished) {
        /** 隐藏顶部栏 */
        self->_isHideNaviBar = YES;
        [self changedBarState];
        self->singleTapRecognizer.enabled = NO;
        [self->_EditingView resetVideoDisplay];
    }];
}

- (void)changeFilterMenu:(BOOL)isChanged animated:(BOOL)animated
{
    if (isChanged) {
        [self.view addSubview:self.edit_filter_toolBar];
        CGRect frame = self.edit_filter_toolBar.frame;
        frame.origin.y = self.view.lfme_height-frame.size.height;
        if (animated) {
            [UIView animateWithDuration:.25f animations:^{
                self->_edit_filter_toolBar.frame = frame;
            }];
        } else {
            _edit_filter_toolBar.frame = frame;
        }
    } else {
        if (_edit_filter_toolBar.superview == nil) return;
        
        CGRect frame = self.edit_filter_toolBar.frame;
        frame.origin.y = self.view.lfme_height;
        if (animated) {
            [UIView animateWithDuration:.25f animations:^{
                self->_edit_filter_toolBar.frame = frame;
            } completion:^(BOOL finished) {
                [self->_edit_filter_toolBar removeFromSuperview];
                self->_edit_filter_toolBar = nil;
            }];
        } else {
            [_edit_filter_toolBar removeFromSuperview];
            _edit_filter_toolBar = nil;
        }
    }
}

#pragma mark - 贴图菜单（懒加载）
- (LFStickerBar *)edit_sticker_toolBar
{
    if (_edit_sticker_toolBar == nil) {
        CGFloat row = 4;
        CGFloat w=self.view.lfme_width, h=lf_stickerSize*row+lf_stickerMargin*(row+1);
        if (@available(iOS 11.0, *)) {
            h += self.navigationController.view.safeAreaInsets.bottom;
        }
        CGRect frame = CGRectMake(0, self.view.lfme_height, w, h);
        
        if (self.stickerBarCacheResource) {
            _edit_sticker_toolBar = [[LFStickerBar alloc] initWithFrame:frame cacheResources:self.stickerBarCacheResource];
        } else {
            /** 设置默认贴图资源路径 */
            NSArray <LFStickerContent *>*stickerContents = [self operationArrayForKey:LFVideoEditStickerContentsAttributeName];
            
            if (stickerContents == nil) {
                stickerContents = @[
                    [LFStickerContent stickerContentWithTitle:[NSBundle LFME_localizedStringForKey:@"_LFME_default"] contents:@[LFStickerContentDefaultSticker]],
                    [LFStickerContent stickerContentWithTitle: [NSBundle LFME_localizedStringForKey:@"_LFME_album"] contents:@[LFStickerContentAllAlbum]]
                ];
            }
            
            _edit_sticker_toolBar = [[LFStickerBar alloc] initWithFrame:frame resources:stickerContents];
        }
        
        _edit_sticker_toolBar.delegate = self;
    }
    return _edit_sticker_toolBar;
}

#pragma mark - 剪切底部栏（懒加载）
- (UIView *)edit_clipping_toolBar
{
    if (_edit_clipping_toolBar == nil) {
        CGFloat h = 44.f;
        if (@available(iOS 11.0, *)) {
            h += self.navigationController.view.safeAreaInsets.bottom;
        }
        _edit_clipping_toolBar = [[LFVideoClipToolbar alloc] initWithFrame:CGRectMake(0, self.view.lfme_height - h, self.view.lfme_width, h)];
        _edit_clipping_toolBar.alpha = 0.f;
        _edit_clipping_toolBar.delegate = self;
    }
    return _edit_clipping_toolBar;
}

#pragma mark - 滤镜菜单（懒加载）
- (JRFilterBar *)edit_filter_toolBar
{
    if (_edit_filter_toolBar == nil) {
        CGFloat w=self.view.lfme_width, h=100.f;
        if (@available(iOS 11.0, *)) {
            h += self.navigationController.view.safeAreaInsets.bottom;
        }
        _edit_filter_toolBar = [[JRFilterBar alloc] initWithFrame:CGRectMake(0, self.view.lfme_height, w, h) defalutEffectType:[_EditingView getFilterType] dataSource:@[
                                                                                                                                                                    @(LFFilterNameType_None),
                                                                                                                                                                    @(LFFilterNameType_LinearCurve),
                                                                                                                                                                    @(LFFilterNameType_Chrome),
                                                                                                                                                                    @(LFFilterNameType_Fade),
                                                                                                                                                                    @(LFFilterNameType_Instant),
                                                                                                                                                                    @(LFFilterNameType_Mono),
                                                                                                                                                                    @(LFFilterNameType_Noir),
                                                                                                                                                                    @(LFFilterNameType_Process),
                                                                                                                                                                    @(LFFilterNameType_Tonal),
                                                                                                                                                                    @(LFFilterNameType_Transfer),
                                                                                                                                                                    @(LFFilterNameType_CurveLinear),
                                                                                                                                                                    @(LFFilterNameType_Invert),
                                                                                                                                                                    @(LFFilterNameType_Monochrome),                                                                                    ]];
        CGFloat rgb = 34 / 255.0;
        _edit_filter_toolBar.backgroundColor = [UIColor colorWithRed:rgb green:rgb blue:rgb alpha:0.85];
        _edit_filter_toolBar.defaultColor = self.cancelButtonTitleColorNormal;
        _edit_filter_toolBar.selectColor = self.oKButtonTitleColorNormal;
        _edit_filter_toolBar.delegate = self;
        _edit_filter_toolBar.dataSource = self;
        
        
    }
    return _edit_filter_toolBar;
}

#pragma mark - JRFilterBarDelegate
- (void)jr_filterBar:(JRFilterBar *)jr_filterBar didSelectImage:(UIImage *)image effectType:(NSInteger)effectType
{
    [_EditingView changeFilterType:effectType];
}

#pragma mark - JRFilterBarDataSource
- (UIImage *)jr_async_filterBarImageForEffectType:(NSInteger)type
{
    if (_filterSmallImage == nil) {
        CGSize videoSize = [self.asset videoNaturalSize];
        CGSize size = CGSizeZero;
        size.width = MIN(JR_FilterBar_MAX_WIDTH*[UIScreen mainScreen].scale, videoSize.width);
        size.height = ((int)(videoSize.height*size.width/videoSize.width))*1.f;
        self.filterSmallImage = [self.asset lf_firstImageWithSize:size error:nil];
    }
    return lf_filterImageWithType(self.filterSmallImage, type);
}

- (NSString *)jr_filterBarNameForEffectType:(NSInteger)type
{
    NSString *defaultName = lf_descWithType(type);
    if (defaultName) {
        NSString *languageName = [@"_LFME_filter_" stringByAppendingString:defaultName];
        return [NSBundle LFME_localizedStringForKey:languageName];
    }
    return @"";
}

#pragma mark - 配置数据
- (LFVideoEditOperationSubType)operationSubTypeForKey:(LFVideoEditOperationStringKey)key
{
    id obj = [self.operationAttrs objectForKey:key];
    if ([obj isKindOfClass:[NSNumber class]]) {
        return (LFVideoEditOperationSubType)[obj integerValue];
    } else if (obj) {
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Wunused-variable"
                
        BOOL isContain = [key isEqualToString:LFVideoEditDrawColorAttributeName]
        || [key isEqualToString:LFVideoEditDrawBrushAttributeName]
        || [key isEqualToString:LFVideoEditTextColorAttributeName]
        || [key isEqualToString:LFVideoEditFilterAttributeName];
        NSAssert(!isContain, @"The type corresponding to this key %@ is LFVideoEditOperationSubType", key);
        #pragma clang diagnostic pop
    }
    return 0;
}

- (BOOL)operationBOOLForKey:(LFVideoEditOperationStringKey)key
{
    id obj = [self.operationAttrs objectForKey:key];
    if ([obj isKindOfClass:[NSNumber class]]) {
        return [obj boolValue];
    } else if (obj) {
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Wunused-variable"
                
        BOOL isContain = [key isEqualToString:LFVideoEditAudioMuteAttributeName];
        NSAssert(!isContain, @"The type corresponding to this key %@ is BOOL", key);
        #pragma clang diagnostic pop
    } else {
        if ([key isEqualToString:LFVideoEditAudioMuteAttributeName]) {
            return NO;
        }
    }
    return NO;
}

- (double)operationDoubleForKey:(LFVideoEditOperationStringKey)key
{
    id obj = [self.operationAttrs objectForKey:key];
    if ([obj isKindOfClass:[NSNumber class]]) {
        double value = [obj doubleValue];
        if ([key isEqualToString:LFVideoEditRateAttributeName]) {
            if (value >= LFMediaEditMinRate && value <= LFMediaEditMaxRate) {
                return value;
            } else {
                return 1.f;
            }
        } else {
            return value;
        }
    } else if (obj) {
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Wunused-variable"
                
        BOOL isContain = [key isEqualToString:LFVideoEditRateAttributeName]
        || [key isEqualToString:LFVideoEditClipMinDurationAttributeName]
        || [key isEqualToString:LFVideoEditClipMaxDurationAttributeName];
        NSAssert(!isContain, @"The type corresponding to this key %@ is double", key);
        #pragma clang diagnostic pop
    } else {
        if ([key isEqualToString:LFVideoEditRateAttributeName]) {
            return 1.f;
        } else if ([key isEqualToString:LFVideoEditClipMinDurationAttributeName]) {
            return 1.f;
        } else if ([key isEqualToString:LFVideoEditClipMaxDurationAttributeName]) {
            return 0;
        }
    }
    return 0;
}

//- (NSString *)operationStringForKey:(LFVideoEditOperationStringKey)key
//{
//    id obj = [self.operationAttrs objectForKey:key];
//    if ([obj isKindOfClass:[NSString class]]) {
//        return (NSString *)obj;
//    } else if (obj) {
//        #pragma clang diagnostic push
//        #pragma clang diagnostic ignored "-Wunused-variable"
//
//        BOOL isContain = [key isEqualToString:LFVideoEditStickerContentsAttributeName];
//        NSAssert(!isContain, @"The type corresponding to this key %@ is NSString", key);
//        #pragma clang diagnostic pop
//    }
//    return nil;
//}

- (NSArray *)operationArrayForKey:(LFVideoEditOperationStringKey)key
{
    id obj = [self.operationAttrs objectForKey:key];
    if ([obj isKindOfClass:[NSArray class]]) {
        return (NSArray *)obj;
    } else if (obj) {
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Wunused-variable"
                
        BOOL isContain = [key isEqualToString:LFVideoEditStickerContentsAttributeName];
        NSAssert(!isContain, @"The type corresponding to this key %@ is NSArray", key);
        #pragma clang diagnostic pop
    }
    return nil;
}

- (NSArray<NSURL *>*)operationArrayURLForKey:(LFVideoEditOperationStringKey)key
{
    id obj = [self.operationAttrs objectForKey:key];
    if ([obj isKindOfClass:[NSArray class]]) {
        NSArray *identifiers = (NSArray *)obj;
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Wunused-variable"
                
        NSPredicate *p = [NSPredicate predicateWithFormat:@"self isKindOfClass: %@",
                          [NSURL class]];
        NSArray *filtered = [identifiers filteredArrayUsingPredicate:p];
        NSAssert(filtered.count == identifiers.count,
                 @"The value of key %@ can only contain NSURL.", key);
        #pragma clang diagnostic pop
        return identifiers;
    } else if (obj) {
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Wunused-variable"
                
        BOOL isContain = [key isEqualToString:LFVideoEditAudioUrlsAttributeName];
        NSAssert(!isContain, @"The type corresponding to this key %@ is NSArray<NSURL *>*", key);
        #pragma clang diagnostic pop
    }
    return nil;
}

@end
