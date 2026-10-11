//
//  LFBaseEditingController.h
//  LFMediaEditingController
//
//  Created by LamTsanFeng on 2017/6/9.
//  Copyright © 2017年 LamTsanFeng. All rights reserved.
//

#import <UIKit/UIKit.h>

/** Top safe-area inset (status bar / notch) of the app's windows, in window coordinates.
 Sampled from every window and cached at its maximum, because the editor raises the key window above the status bar level and a raised window — or a view inside a scroll container — may report 0. Always >= what the windows have ever reported. */
UIKIT_EXTERN CGFloat LFMEWindowTopSafeInset(void);

/** Top inset to apply to a view: the window inset minus the view's own offset in the window (so hosts that already inset the view are not inset twice), never less than the view's own safeAreaInsets.top. */
UIKIT_EXTERN CGFloat LFMETopSafeInsetForView(UIView *view);

@interface LFBaseEditingController : UIViewController

/** 是否隐藏状态栏 默认YES */
@property (nonatomic, assign) BOOL isHiddenStatusBar;

/// 自定义外观颜色
@property (nonatomic, strong) UIColor *oKButtonTitleColorNormal;
@property (nonatomic, strong) UIColor *cancelButtonTitleColorNormal;
/// 自定义文字
@property (nonatomic, copy) NSString *oKButtonTitle __deprecated_msg("Property deprecated. Use `LFMediaEditingController.strings`");
@property (nonatomic, copy) NSString *cancelButtonTitle __deprecated_msg("Property deprecated. Use `LFMediaEditingController.strings`");
@property (nonatomic, copy) NSString *processHintStr __deprecated_msg("Property deprecated. Use `LFMediaEditingController.strings`");

//- (void)showProgressHUDText:(NSString *)text;
- (void)showProgressHUD;
- (void)hideProgressHUD;

- (void)showProgressVideoHUD;
- (void)setProgress:(float)progress;

- (void)showInfoMessage:(NSString *)text;
- (void)showErrorMessage:(NSString *)text;

/** 初始化 */
- (instancetype)initWithOrientation:(UIInterfaceOrientation)orientation;

@end
