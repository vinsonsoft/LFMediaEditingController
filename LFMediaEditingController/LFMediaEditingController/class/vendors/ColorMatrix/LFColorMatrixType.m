//
//  LFColorMatrixType.m
//  LFMediaEditingController
//
//  Created by TsanFeng Lam on 2018/8/7.
//  Copyright © 2018年 LamTsanFeng. All rights reserved.
//

#import "LFColorMatrixType.h"
#import "LFImageUtil.h"
#import "LFColorMatrix.h"

NSString *lf_colorMatrixName(LFColorMatrixType type)
{
    NSString *colorStr = @"Original";
    switch (type) {
        case LFColorMatrixType_None:
            break;
        case LFColorMatrixType_LOMO:
            colorStr = @"LOMO";
            break;
        case LFColorMatrixType_Heibai:
            colorStr = @"B&W";
            break;
        case LFColorMatrixType_Fugu:
            colorStr = @"Vintage";
            break;
        case LFColorMatrixType_Gete:
            colorStr = @"Gothic";
            break;
        case LFColorMatrixType_Ruise:
            colorStr = @"Sharpen";
            break;
        case LFColorMatrixType_Danya:
            colorStr = @"Elegant";
            break;
        case LFColorMatrixType_Jiuhong:
            colorStr = @"Wine";
            break;
        case LFColorMatrixType_Qingning:
            colorStr = @"Serene";
            break;
        case LFColorMatrixType_Langman:
            colorStr = @"Romantic";
            break;
        case LFColorMatrixType_Huaijiu:
            colorStr = @"Nostalgia";
            break;
        case LFColorMatrixType_Landiao:
            colorStr = @"Blues";
            break;
        case LFColorMatrixType_Menghuan:
            colorStr = @"Dreamy";
            break;
        case LFColorMatrixType_Yese:
            colorStr = @"Night";
            break;
        case LFColorMatrixType_Huidu:
            colorStr = @"Grayscale";
            break;
        case LFColorMatrixType_Imagerevolve:
            colorStr = @"Cool";
            break;
        case LFColorMatrixType_Heighsaturatedcolour:
            colorStr = @"Saturated";
            break;
        case LFColorMatrixType_Cleancolor:
            colorStr = @"Desaturate";
            break;
    }
    return colorStr;
}

UIImage * lf_colorMatrixImage(UIImage *image, LFColorMatrixType type)
{
    UIImage *cmImage = image;
    switch (type) {
        case LFColorMatrixType_None:
            break;
        case LFColorMatrixType_LOMO:
            cmImage = [LFImageUtil lf_imageWithImage:image withColorMatrix:lf_colormatrix_lomo];
            break;
        case LFColorMatrixType_Heibai:
            cmImage = [LFImageUtil lf_imageWithImage:image withColorMatrix:lf_colormatrix_heibai];
            break;
        case LFColorMatrixType_Fugu:
            cmImage = [LFImageUtil lf_imageWithImage:image withColorMatrix:lf_colormatrix_fugu];
            break;
        case LFColorMatrixType_Gete:
            cmImage = [LFImageUtil lf_imageWithImage:image withColorMatrix:lf_colormatrix_gete];
            break;
        case LFColorMatrixType_Ruise:
            cmImage = [LFImageUtil lf_imageWithImage:image withColorMatrix:lf_colormatrix_ruise];
            break;
        case LFColorMatrixType_Danya:
            cmImage = [LFImageUtil lf_imageWithImage:image withColorMatrix:lf_colormatrix_danya];
            break;
        case LFColorMatrixType_Jiuhong:
            cmImage = [LFImageUtil lf_imageWithImage:image withColorMatrix:lf_colormatrix_jiuhong];
            break;
        case LFColorMatrixType_Qingning:
            cmImage = [LFImageUtil lf_imageWithImage:image withColorMatrix:lf_colormatrix_qingning];
            break;
        case LFColorMatrixType_Langman:
            cmImage = [LFImageUtil lf_imageWithImage:image withColorMatrix:lf_colormatrix_langman];
            break;
        case LFColorMatrixType_Huaijiu:
            cmImage = [LFImageUtil lf_imageWithImage:image withColorMatrix:lf_colormatrix_huaijiu];
            break;
        case LFColorMatrixType_Landiao:
            cmImage = [LFImageUtil lf_imageWithImage:image withColorMatrix:lf_colormatrix_landiao];
            break;
        case LFColorMatrixType_Menghuan:
            cmImage = [LFImageUtil lf_imageWithImage:image withColorMatrix:lf_colormatrix_menghuan];
            break;
        case LFColorMatrixType_Yese:
            cmImage = [LFImageUtil lf_imageWithImage:image withColorMatrix:lf_colormatrix_yese];
            break;
        case LFColorMatrixType_Huidu:
            cmImage = [LFImageUtil lf_imageWithImage:image withColorMatrix:lf_colormatrix_huidu];
            break;
        case LFColorMatrixType_Imagerevolve:
            cmImage = [LFImageUtil lf_imageWithImage:image withColorMatrix:lf_colormatrix_imagerevolve];
            break;
        case LFColorMatrixType_Heighsaturatedcolour:
            cmImage = [LFImageUtil lf_imageWithImage:image withColorMatrix:lf_colormatrix_heighsaturatedcolour];
            break;
        case LFColorMatrixType_Cleancolor:
            cmImage = [LFImageUtil lf_imageWithImage:image withColorMatrix:lf_colormatrix_cleancolor];
            break;
    }
    return cmImage;
}
