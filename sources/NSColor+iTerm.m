//
//  NSColor+iTerm.m
//  iTerm
//
//  Created by George Nachman on 3/2/14.
//
//

#import "NSColor+iTerm.h"

// Constants for converting RGB to luma.
static const double kRedComponentBrightness = 0.30;
static const double kGreenComponentBrightness = 0.59;
static const double kBlueComponentBrightness = 0.11;

NSString *const kEncodedColorDictionaryRedComponent = @"Red Component";
NSString *const kEncodedColorDictionaryGreenComponent = @"Green Component";
NSString *const kEncodedColorDictionaryBlueComponent = @"Blue Component";
NSString *const kEncodedColorDictionaryAlphaComponent = @"Alpha Component";
NSString *const kEncodedColorDictionaryColorSpace = @"Color Space";
NSString *const kEncodedColorDictionarySRGBColorSpace = @"sRGB";
NSString *const kEncodedColorDictionaryCalibratedColorSpace = @"Calibrated";

static CGFloat PerceivedBrightness(CGFloat r, CGFloat g, CGFloat b) {
    return (kRedComponentBrightness * r +
            kGreenComponentBrightness * g +
            kBlueComponentBrightness * b);
}

@implementation NSColor (iTerm)

+ (NSColor *)colorWith8BitRed:(int)red
                        green:(int)green
                         blue:(int)blue {
    return [NSColor colorWithSRGBRed:red / 255.0
                               green:green / 255.0
                                blue:blue / 255.0
                               alpha:1];
}

+ (NSColor *)colorWith8BitRed:(int)red
                        green:(int)green
                         blue:(int)blue
                       muting:(double)muting
                backgroundRed:(CGFloat)bgRed
              backgroundGreen:(CGFloat)bgGreen
               backgroundBlue:(CGFloat)bgBlue {
    CGFloat r = (red / 255.0) * (1 - muting) + bgRed * muting;
    CGFloat g = (green / 255.0) * (1 - muting) + bgGreen * muting;
    CGFloat b = (blue / 255.0) * (1 - muting) + bgBlue * muting;

    return [NSColor colorWithSRGBRed:r
                               green:g
                                blue:b
                               alpha:1];
}

+ (NSColor *)calibratedColorWithRed:(double)r
                              green:(double)g
                               blue:(double)b
                              alpha:(double)a
                perceivedBrightness:(CGFloat)t
                   towardComponents:(CGFloat *)baseColorComponents {
    /*
     Given:
     a vector c [c1, c2, c3] (the starting color)
     a vector e [e1, e2, e3] (an extreme color we are moving to, normally black or white)
     a vector A [a1, a2, a3] (the perceived brightness transform)
     a linear function f(Y)=AY (perceived brightness for color Y)
     a constant t (target perceived brightness)
     find a vector X such that F(X)=t
     and X lies on a straight line between c and e
     
     Define a parametric vector x(p) = [x1(p), x2(p), x3(p)]:
     x1(p) = p*e1 + (1-p)*c1
     x2(p) = p*e2 + (1-p)*c2
     x3(p) = p*e3 + (1-p)*c3
     
     when p=0, x=c
     when p=1, x=e
     
     the line formed by x(p) from p=0 to p=1 is the line from c to e.
     
     Our goal: find the value of p where f(x(p))=t
     
     We know that:
     [x1(p)]
     f(X) = AX = [a1 a2 a3] [x2(p)] = a1x1(p) + a2x2(p) + a3x3(p)
     [x3(p)]
     Expand and solve for p:
     t = a1*(p*e1 + (1-p)*c1) + a2*(p*e2 + (1-p)*c2) + a3*(p*e3 + (1-p)*c3)
     t = a1*(p*e1 + c1 - p*c1) + a2*(p*e2 + c2 - p*c2) + a3*(p*e3 + c3 - p*c3)
     t = a1*p*e1 + a1*c1 - a1*p*c1 + a2*p*e2 + a2*c2 - a2*p*c2 + a3*p*e3 + a3*c3 - a3*p*c3
     t = a1*p*e1 - a1*p*c1 + a2*p*e2 - a2*p*c2 + a3*p*e3 - a3*p*c3 + a1*c1 + a2*c2 + a3*c3
     t = p*(a2*e1 - a1*c1 + a2*e2 - a2*c2 + a3*e3 - a3*c3) + a1*c1 + a2*c2 + a3*c3
     t - (a1*c1 + a2*c2 + a3*c3) = p*(a1*e1 - a1*c1 + a2*e2 - a2*c2 + a3*e3 - a3*c3)
     p = (t - (a1*c1 + a2*c2 + a3*c3)) / (a1*e1 - a1*c1 + a2*e2 - a2*c2 + a3*e3 - a3*c3)
     
     The PerceivedBrightness() function is a dot product between the a vector and its input, so the
     previous equation is equivalent to:
     p = (t - PerceivedBrightness(c1, c2, c3) / PerceivedBrightness(e1-c1, e2-c2, e3-c3)
     */
    const CGFloat c1 = r;
    const CGFloat c2 = g;
    const CGFloat c3 = b;
    
    CGFloat k;
    if (PerceivedBrightness(r, g, b) < t) {
        k = 1;
    } else {
        k = 0;
    }
    const CGFloat e1 = k;
    const CGFloat e2 = k;
    const CGFloat e3 = k;
    
    CGFloat p = ((t - PerceivedBrightness(c1, c2, c3)) /
                 (PerceivedBrightness(e1 - c1, e2 - c2, e3 - c3)));
    // p can be out of range for e.g., division by 0.
    p = MIN(1, MAX(0, p));

    const CGFloat x1 = p * e1 + (1 - p) * c1;
    const CGFloat x2 = p * e2 + (1 - p) * c2;
    const CGFloat x3 = p * e3 + (1 - p) * c3;

    return [NSColor colorWithCalibratedRed:x1 green:x2 blue:x3 alpha:a];
}

+ (NSColor *)colorForAnsi256ColorIndex:(int)index {
    double r, g, b;
    if (index >= 16 && index < 232) {
        int i = index - 16;
        r = (i / 36) ? ((i / 36) * 40 + 55) / 255.0 : 0.0;
        g = (i % 36) / 6 ? (((i % 36) / 6) * 40 + 55) / 255.0 : 0.0;
        b = (i % 6) ? ((i % 6) * 40 + 55) / 255.0 : 0.0;
    } else if (index >= 232 && index < 256) {
        int i = index - 232;
        r = g = b = (i * 10 + 8) / 255.0;
    } else {
        // The first 16 colors aren't supported here.
        return nil;
    }
    NSColor* srgb = [NSColor colorWithSRGBRed:r
                                        green:g
                                         blue:b
                                        alpha:1];
    return [srgb colorUsingColorSpaceName:NSCalibratedRGBColorSpace];
}

+ (NSColor*)colorWithComponents:(double *)mainComponents
    withContrastAgainstComponents:(double *)otherComponents
                  minimumContrast:(CGFloat)minimumContrast
                          mutedBy:(double)muting
                 towardComponents:(CGFloat *)baseColorComponents {
    const double r = mainComponents[0];
    const double g = mainComponents[1];
    const double b = mainComponents[2];
    const double a = mainComponents[3];

    const double or = otherComponents[0];
    const double og = otherComponents[1];
    const double ob = otherComponents[2];

    double mainBrightness = PerceivedBrightness(r, g, b);
    double otherBrightness = PerceivedBrightness(or, og, ob);
    CGFloat brightnessDiff = fabs(mainBrightness - otherBrightness);

    if (brightnessDiff < minimumContrast) {
        // Muting defines the range of possible brightnesses; with more muting, text colors converge
        // towards the default background color (called otherComponents here). To pick an allowable
        // target brightness, we limit it to the range of brightnesses permitted by the muting
        // level.
        double minBrightness = PerceivedBrightness(baseColorComponents[0] * muting,
                                                   baseColorComponents[1] * muting,
                                                   baseColorComponents[2] * muting);
        double maxBrightness = PerceivedBrightness(1 - muting + baseColorComponents[0] * muting,
                                                   1 - muting + baseColorComponents[1] * muting,
                                                   1 - muting + baseColorComponents[2] * muting);


        CGFloat error = fabs(brightnessDiff - minimumContrast);
        CGFloat targetBrightness = mainBrightness;
        if (mainBrightness < otherBrightness) {
            targetBrightness -= error;
            if (targetBrightness < minBrightness) {
                const double alternative = otherBrightness + minimumContrast;
                const double baseContrast = otherBrightness;
                const double altContrast = MIN(alternative, maxBrightness) - otherBrightness;
                if (altContrast > baseContrast) {
                    targetBrightness = alternative;
                }
            }
        } else {
            targetBrightness += error;
            if (targetBrightness > maxBrightness) {
                const double alternative = otherBrightness - minimumContrast;
                const double baseContrast = maxBrightness - otherBrightness;
                const double altContrast = otherBrightness - MAX(alternative, minBrightness);
                if (altContrast > baseContrast) {
                    targetBrightness = alternative;
                }
            }
        }
        targetBrightness = MIN(MAX(minBrightness, targetBrightness), maxBrightness);
        return [NSColor calibratedColorWithRed:r
                                         green:g
                                          blue:b
                                         alpha:a
                           perceivedBrightness:targetBrightness
                              towardComponents:baseColorComponents];
    } else {
        return nil;
    }
}

- (int)nearestIndexIntoAnsi256ColorTable {
    NSColor *theColor = [self colorUsingColorSpaceName:NSCalibratedRGBColorSpace];
    int r = 5 * [theColor redComponent];
    int g = 5 * [theColor greenComponent];
    int b = 5 * [theColor blueComponent];
    return 16 + b + g * 6 + r * 36;
}

- (NSColor *)colorDimmedBy:(double)dimmingAmount towardsGrayLevel:(double)grayLevel {
    if (dimmingAmount == 0) {
        return self;
    }
    double r = [self redComponent];
    double g = [self greenComponent];
    double b = [self blueComponent];
    double alpha = [self alphaComponent];
    // This algorithm limits the dynamic range of colors as well as brightening
    // them. Both attributes change in proportion to the dimmingAmount.
    
    // Find a linear interpolation between kCenter and the requested color component
    // in proportion to 1- dimmingAmount.
    return [NSColor colorWithCalibratedRed:(1 - dimmingAmount) * r + dimmingAmount * grayLevel
                                     green:(1 - dimmingAmount) * g + dimmingAmount * grayLevel
                                      blue:(1 - dimmingAmount) * b + dimmingAmount * grayLevel
                                     alpha:alpha];
}

- (CGFloat)perceivedBrightness {
    NSColor *safeColor = [self colorUsingColorSpaceName:NSCalibratedRGBColorSpace];
    return PerceivedBrightness([safeColor redComponent],
                               [safeColor greenComponent],
                               [safeColor blueComponent]);
}

- (BOOL)isDark {
    return [self perceivedBrightness] < 0.5;
}

- (NSDictionary *)dictionaryValue {
    NSColor* color = [self colorUsingColorSpaceName:NSCalibratedRGBColorSpace];
    CGFloat red, green, blue, alpha;
    [color getRed:&red green:&green blue:&blue alpha:&alpha];
    return @{ kEncodedColorDictionaryColorSpace: kEncodedColorDictionaryCalibratedColorSpace,
              kEncodedColorDictionaryRedComponent: @(red),
              kEncodedColorDictionaryGreenComponent: @(green),
              kEncodedColorDictionaryBlueComponent: @(blue),
              kEncodedColorDictionaryAlphaComponent: @(alpha) };
}

- (NSColor *)colorMutedBy:(double)muting towards:(NSColor *)baseColor {
    CGFloat r = [self redComponent];
    CGFloat g = [self greenComponent];
    CGFloat b = [self blueComponent];

    CGFloat baseR = [baseColor redComponent];
    CGFloat baseG = [baseColor greenComponent];
    CGFloat baseB = [baseColor blueComponent];

    return [NSColor colorWithCalibratedRed:(1 - muting) * r + muting * baseR
                                     green:(1 - muting) * g + muting * baseG
                                      blue:(1 - muting) * b + muting * baseB
                                     alpha:1.0];
}

@end
