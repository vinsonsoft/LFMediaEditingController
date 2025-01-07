//
//  UIColor+CustomColors.m
//  LFMediaEditingController
//
//  Created by Mohamed Alsheikh on 07/01/2025.
//  Copyright © 2025 LamTsanFeng. All rights reserved.
//

// UIColor+CustomColors.m
#import "UIColor+CustomColors.h"

@implementation UIColor (CustomColors)

+ (UIColor *)colorPrimary {
    // This method assumes you have a color in your asset catalog named "colorPrimary(FA561E)"
    return [UIColor colorNamed:@"colorPrimary(FA561E)" inBundle:nil compatibleWithTraitCollection:nil];
}

+ (UIColor *)colorTextWhite {
    // This method assumes you have a color in your asset catalog named "colorTextWhite(FFFFFF)"
    return [UIColor colorNamed:@"colorTextWhite(FFFFFF)" inBundle:nil compatibleWithTraitCollection:nil];
}

@end
