//
//  DSTCustomPickerView.m
//  custompicker
//
//  Created by Johannes Schriewer on 20.09.2012.
//  Copyright (c) 2012 Johannes Schriewer. All rights reserved.
//

#import <QuartzCore/QuartzCore.h>
#import <AudioToolbox/AudioToolbox.h>

#import "DSTPickerView.h"

#pragma mark - DSTPickerTableViewCell

@interface DSTPickerTableViewCell : UITableViewCell {
}
- (DSTPickerTableViewCell *)initWithReuseIdentifier:(NSString *)reuseIdentifier;

@property (nonatomic, assign) NSInteger row;
@property (nonatomic, assign) NSInteger section;
@end

@implementation DSTPickerTableViewCell

- (DSTPickerTableViewCell *)initWithReuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:UITableViewCellStyleDefault reuseIdentifier:reuseIdentifier];
    if (self) {
        _row = -1;
        _section = -1;
        [self setContentMode:UIViewContentModeRedraw];
        [self setSelectionStyle:UITableViewCellSelectionStyleNone];
    }
    return self;
}

@end


#pragma mark - DSTPickerContentView

@interface DSTPickerContentView : UIView

@end

@implementation  DSTPickerContentView

- (DSTPickerContentView *)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {

    }
    return self;
}

- (void)drawRect:(CGRect)rect {
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSaveGState(context);

    [self.backgroundColor setFill];
    CGContextFillRect(context, CGRectMake(0, 0, self.bounds.size.width, self.bounds.size.height));

    // black border
    [[UIColor blackColor] setFill];
    CGContextFillRect(context, CGRectMake(0, 0, 1, self.bounds.size.height));
    CGContextFillRect(context, CGRectMake(self.bounds.size.width - 1, 0, 1, self.bounds.size.height));

    // inner border
    [[UIColor lightGrayColor] setFill];
    CGContextFillRect(context, CGRectMake(1, 0, 3, self.bounds.size.height));
    CGContextFillRect(context, CGRectMake(self.bounds.size.width - 4, 0, 3, self.bounds.size.height));

    CGContextRestoreGState(context);
}

@end

static void cubicInterpolation(void *info, const float *input, float *output) {
    BOOL drawInverse = *(BOOL *)info;
    float position = *input;

    CGFloat intensity;
    if (drawInverse) {
        intensity = pow((1.0 - position) - 1.0, 2);
    } else {
        intensity = pow(position - 1.0, 2);
    }

    output[0] = 0.3 * (1.0 - intensity);
    output[1] = 0.3 * (1.0 - intensity);
    output[2] = 0.3 * (1.0 - intensity);
    output[3] = 0.95 * intensity;
}

#pragma mark - DSTPickerView

@interface DSTPickerView () <UITableViewDataSource, UITableViewDelegate> {
    CGColorSpaceRef colorspace;
    CGGradientRef backgroundGradient;
    CGGradientRef shineGradient;

    // contains titles for components
    NSMutableArray *components;
    NSMutableArray *componentWidths;
    NSMutableArray *rowSizes;

    // contains NSMutableArrays of rows
    NSMutableArray *cols;

    // contains index of item per component that is selected
    NSMutableArray *selectedItems;
    NSMutableArray *currentItems;

    // while this is set to yes, ui updates are locked
    BOOL updateLocked;

    //
    // UI Elements
    //

    // One tableview per component
    NSMutableArray *contentViews;
    NSMutableArray *tableViews;
    UIImageView *selectionIndicator;
    UIImageView *darkenTop;
    UIImageView *darkenBottom;
    UIView *roundCorners;
}
@end

@implementation DSTPickerView

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code
        colorspace = CGColorSpaceCreateDeviceRGB();
        _backgroundGradientStartColor = [UIColor colorWithRed:26.0/255.0 green:35.0/255.0 blue:78.0/255.0 alpha:1.0];
//        _backgroundGradientStartColor = [UIColor blackColor];
//        _backgroundGradientEndColor = [UIColor colorWithWhite:0.2 alpha:1.0];
        _backgroundGradientEndColor = [UIColor colorWithRed:32.0/255.0 green:34.0/255.0 blue:41.0/255.0 alpha:1.0];
        _selectionIndicatorBaseColor = [UIColor colorWithRed:118.0/255.0 green:126.0/255.0 blue:180.0/255.0 alpha:0.5];
        _addShine = YES;
        _elementDistance = 20;

        components = [NSMutableArray array];
        componentWidths = [NSMutableArray array];
        rowSizes = [NSMutableArray array];
        cols = [NSMutableArray array];
        selectedItems = [NSMutableArray array];
        currentItems = [NSMutableArray array];
        tableViews = [NSMutableArray array];
        contentViews = [NSMutableArray array];
        updateLocked = NO;

        // round corners for selector
        roundCorners = [[UIView alloc] init];
        [roundCorners setClipsToBounds:YES];
        [roundCorners.layer setMasksToBounds:YES];
        [roundCorners.layer setCornerRadius:5.0];
        [self addSubview:roundCorners];

        // selection indicator
        selectionIndicator = [[UIImageView alloc] init];
        [selectionIndicator setHidden:YES];
        [roundCorners addSubview:selectionIndicator];

        // darkener
        darkenTop = [[UIImageView alloc] init];
        [roundCorners addSubview:darkenTop];

        darkenBottom = [[UIImageView alloc] init];
        [roundCorners addSubview:darkenBottom];

        [self setClipsToBounds:YES];
        [self setContentMode:UIViewContentModeRedraw];
        [self reloadAllComponents];
    }
    return self;
}

- (void)dealloc {
    CGColorSpaceRelease(colorspace);
    if (backgroundGradient) {
        CGGradientRelease(backgroundGradient);
    }
    if (shineGradient) {
        CGGradientRelease(shineGradient);
    }
}

- (void)drawRect:(CGRect)rect {
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSaveGState(context);

    if (!CGColorEqualToColor(_backgroundGradientEndColor.CGColor, _backgroundGradientStartColor.CGColor)) {
        // Background gradient
        if (!backgroundGradient) {
            CGFloat locations[] = { 0.0, 1.0 };
            const CGColorRef cgColors[] = { _backgroundGradientStartColor.CGColor, _backgroundGradientEndColor.CGColor };
            CFArrayRef colors = CFArrayCreate(kCFAllocatorDefault, (void *)&cgColors, 2, NULL);
            backgroundGradient = CGGradientCreateWithColors(colorspace, colors, locations);
            CFRelease(colors);
        }

        CGContextDrawLinearGradient(context, backgroundGradient, CGPointZero, CGPointMake(0.0, self.bounds.size.height), 0);
    } else {
        // No gradient, just fill with color
        [_backgroundGradientStartColor setFill];
        CGContextFillRect(context, CGRectMake(0, 0, self.bounds.size.width, self.bounds.size.height));
    }

    // add shine to background gradient?
    if (_addShine) {
        if (!shineGradient) {
            CGFloat colorComponents[] = {
                1.0, 1.0, 1.0, 0.4,
                1.0, 1.0, 1.0, 0.1
            };
            CGFloat locations[] = { 0.0, 1.0 };
            shineGradient = CGGradientCreateWithColorComponents(colorspace, colorComponents, locations, 2);
        }
        CGContextSaveGState(context);
        CGContextClipToRect(context, CGRectMake(0, 0, self.bounds.size.width, floorf(self.bounds.size.height / 2.0)));
        CGContextDrawLinearGradient(context, shineGradient, CGPointZero, CGPointMake(0.0, floorf(self.bounds.size.height / 2.0)), 0);
        CGContextRestoreGState(context);

        CGContextSetAlpha(context, 0.2);
        [[UIColor whiteColor] setFill];
        CGFloat offset = [self calculateTableViewOffset];
        CGContextFillRect(context, CGRectMake(offset + 4, self.bounds.size.height - 10, self.bounds.size.width - offset * 2 - 8, 1));

        CGContextSetAlpha(context, 0.5);
        CGContextFillRect(context, CGRectMake(0, 1, self.bounds.size.width, 1));

        [[UIColor blackColor] setFill];
        CGContextFillRect(context, CGRectMake(0, 0, self.bounds.size.width, 1));
    }

    CGContextRestoreGState(context);
}

#pragma mark - API

- (void)setDataSource:(id<DSTPickerViewDataSource>)dataSource {
    if (dataSource != _dataSource) {
        _dataSource = dataSource;
        if (_delegate) {
            [self reloadAllComponents];
        }
    }
}

- (void)setDelegate:(id<DSTPickerViewDelegate>)delegate {
    if (delegate != _delegate) {
        _delegate = delegate;
        if (_dataSource) {
            [self reloadAllComponents];
        }
    }
}

- (NSInteger)numberOfRowsInComponent:(NSInteger)component {
    return [cols[component] count];
}

- (void)reloadAllComponents {
    NSInteger numberOfComponents = [_dataSource numberOfComponentsInPickerView:self];
    updateLocked = YES;

    // fill components array with placeholders
    [components removeAllObjects];
    for (NSMutableArray *rows in cols) {
        [rows makeObjectsPerformSelector:@selector(removeFromSuperview)];
        [rows removeAllObjects];
    }
    [cols removeAllObjects];
    [rowSizes removeAllObjects];
    [componentWidths removeAllObjects];
    [selectedItems removeAllObjects];
    [currentItems removeAllObjects];
    for (NSUInteger i = 0; i < numberOfComponents; i++) {
        NSString *title = @"";
        if ([_delegate respondsToSelector:@selector(pickerView:titleForComponent:)]) {
            title = [_delegate pickerView:self titleForComponent:i];
        }
        [components addObject:title];
        [cols addObject:[NSMutableArray array]];
        [rowSizes addObject:@(37.0)];
        [componentWidths addObject:@((self.bounds.size.width - 30) / 2.0)];
        [selectedItems addObject:@(0)];
        [currentItems addObject:@(0)];

        [self reloadComponent:i];
    }
    updateLocked = NO;

    [self updateView];
}

- (void)reloadComponent:(NSInteger)component {
    NSMutableArray *rows = cols[component];
    [rows makeObjectsPerformSelector:@selector(removeFromSuperview)];
    [rows removeAllObjects];

    // fetch number of rows
    NSInteger numberOfRows = [_dataSource pickerView:self numberOfRowsInComponent:component];

    // if delegate implements rowHeightForComponent fetch it, else default to 37.0
    CGFloat rowSize = 0;
    BOOL calculateRowSize = YES;
    if ([_delegate respondsToSelector:@selector(pickerView:rowHeightForComponent:)]) {
        rowSize = [_delegate pickerView:self rowHeightForComponent:component];
        calculateRowSize = NO;
    }

    // fetch width of the current component
    componentWidths[component] = @([_delegate pickerView:self widthForComponent:component] - 4);

    // fetch rows for the component
    for (NSUInteger i = 0; i < numberOfRows; i++) {
        NSString *title = nil;
        if ([_delegate respondsToSelector:@selector(pickerView:titleForRow:forComponent:)]) {
            title = [_delegate pickerView:self titleForRow:i forComponent:component];
        }

        UIView *item = nil;
        if ((title) && ([title length] > 0)) {
            // fetch font if possible
            UIFont *font = nil;
            if ([_delegate respondsToSelector:@selector(pickerView:fontForRow:forComponent:)]) {
                font = [_delegate pickerView:self fontForRow:i forComponent:component];
            }
            if (font == nil) {
                font = [UIFont boldSystemFontOfSize:20.0];
            }

            UIColor *color = nil;
            if ([_delegate respondsToSelector:@selector(pickerView:colorForRow:forComponent:)]) {
                color = [_delegate pickerView:self colorForRow:i forComponent:component];
            }
            if (color == nil) {
                color = [UIColor blackColor];
            }
            CGFloat height = -[font ascender] + [font descender];

            // create an UILabel for the title
            UILabel *label = [[UILabel alloc] init];
            [label setBackgroundColor:[UIColor clearColor]];
            [label setAdjustsFontSizeToFitWidth:YES];
            [label setTextColor:color];
            if (!calculateRowSize) {
                font = [UIFont fontWithName:[font fontName] size:rowSize * 0.8];
                height = rowSize;
            }
            [label setFrame:CGRectMake(0, 0, [componentWidths[component] floatValue], height)];
            [label setFont:font];
            [label setText:title];

            item = label;
        }

        // if no title was supplied item is nil, try next function
        if (!item) {
            if ([_delegate respondsToSelector:@selector(pickerView:imageForRow:forComponent:)]) {
                UIImage *image = [_delegate pickerView:self imageForRow:i forComponent:component];
                if (image) {
                    UIImageView *imageView = [[UIImageView alloc] initWithImage:image];
                    [imageView setContentMode:UIViewContentModeScaleAspectFit];
                    [imageView setBackgroundColor:[UIColor clearColor]];
                    if (!calculateRowSize) {
                        [imageView setFrame:CGRectMake(0, 0, [componentWidths[component] floatValue], rowSize)];
                    } else {
                        [imageView setFrame:CGRectMake(0, 0, [componentWidths[component] floatValue], image.size.height)];
                    }
                    item = imageView;
                }
            }
        }

        // image was either not implemented or did not yield an element
        if (!item) {
            if ([_delegate respondsToSelector:@selector(pickerView:viewForRow:forComponent:)]) {
                item = [_delegate pickerView:self viewForRow:i forComponent:component reusingView:nil];
                if (calculateRowSize) {
                    [item setFrame:CGRectMake(0, 0, [componentWidths[component] floatValue], item.frame.size.height)];
                } else {
                    [item setFrame:CGRectMake(0, 0, [componentWidths[component] floatValue], rowSize)];
                }
            }
        }

        if (!item) {
            @throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"At least one of titleForRow:, imageForRow: or viewForRow: have to return a non nil value" userInfo:@{ @"row" : @(i), @"component" : @(component)}];
        }

        if (calculateRowSize) {
            if (rowSize < item.bounds.size.height) {
                rowSize = item.bounds.size.height;
            }
        }
        cols[component][i] = item;
    }

    rowSizes[component] = @(rowSize);
    selectedItems[component] = @(0);
    currentItems[component] = @(0);

    [self updateView];
}

- (CGSize)rowSizeForComponent:(NSInteger)component {
    return CGSizeMake([componentWidths[component] floatValue], [rowSizes[component] floatValue]);
}

- (NSInteger)selectedRowInComponent:(NSInteger)component {
    return [selectedItems[component] integerValue];
}

- (void)selectRow:(NSInteger)row inComponent:(NSInteger)component animated:(BOOL)animated {
    [self selectRow:row inComponent:component animated:animated notify:YES];
}

- (UIView *)viewForRow:(NSInteger)row forComponent:(NSInteger)component {
    return cols[component][row];
}

- (void)setShowsSelectionIndicator:(BOOL)showsSelectionIndicator {
    _showsSelectionIndicator = showsSelectionIndicator;
    [selectionIndicator setHidden:!showsSelectionIndicator];
}
#pragma mark - Internal

- (void)selectRow:(NSInteger)row inComponent:(NSInteger)component animated:(BOOL)animated notify:(BOOL)notify {
    UIScrollView *scrollView = tableViews[component];
    CGFloat inset = floorf((scrollView.frame.size.height - [rowSizes[component] floatValue] - _elementDistance) / 2.0);
    CGFloat rowHeight = [rowSizes[component] floatValue] + _elementDistance;

    CGPoint offset = CGPointMake(0, floorf(-inset + rowHeight * row));
    [scrollView setContentOffset:offset animated:animated];

    selectedItems[component] = @(row);

    if (notify) {
        if (animated) {
            [self performSelector:@selector(notifyDelegateOfRowChange:) withObject:@{ @"row" : @(row), @"component" : @(component) } afterDelay:0.25];
        } else {
            [self notifyDelegateOfRowChange:@{ @"row" : @(row), @"component" : @(component) }];
        }
    }
}

- (void)notifyDelegateOfRowChange:(NSDictionary *)data {
    [_delegate pickerView:self didSelectRow:[data[@"row"] integerValue] inComponent:[data[@"component"] integerValue]];

    // play final tock sound
    if ([data[@"row"] integerValue] != [currentItems[[data[@"component"] integerValue]] integerValue]) {
        AudioServicesPlaySystemSound(1104);
    }
}

- (void)updateView {
    if (updateLocked) {
        return;
    }

    // TODO: recycle tableviews instead of creating new ones all the time

    // setup tableviews
    [contentViews makeObjectsPerformSelector:@selector(removeFromSuperview)];
    [contentViews removeAllObjects];
    [tableViews makeObjectsPerformSelector:@selector(removeFromSuperview)];
    [tableViews removeAllObjects];

    __block CGFloat x = 0.0;
    [components enumerateObjectsUsingBlock:^(NSString *componentTitle, NSUInteger idx, BOOL *stop) {
        DSTPickerContentView *content = [[DSTPickerContentView alloc] initWithFrame:CGRectMake(x, 0, [componentWidths[idx] floatValue] + 8, self.bounds.size.height - 20)];
        [content setBackgroundColor:[UIColor whiteColor]];
        [contentViews addObject:content];

        CGFloat top = 0;
        if ([components[idx] length] > 0) {
            UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, [componentWidths[idx] floatValue], 20.0)];
            [label setBackgroundColor:[UIColor clearColor]];
            [label setTextColor:[UIColor blackColor]];
            [label setFont:[UIFont systemFontOfSize:13.0]];
            [label setAdjustsFontSizeToFitWidth:YES];
            [label setTextAlignment:UITextAlignmentCenter];
            [label setText:components[idx]];
            [content addSubview:label];
            top += 20.0;
        }

        UITableView *tableView = [[UITableView alloc] initWithFrame:CGRectMake(4, top, [componentWidths[idx] floatValue], self.bounds.size.height - 20) style:UITableViewStylePlain];
        [tableViews addObject:tableView];

        [tableView setSeparatorStyle:UITableViewCellSeparatorStyleNone];
        [tableView setScrollIndicatorInsets:UIEdgeInsetsMake(0, 0, 0, -10)];
        [tableView setClipsToBounds:YES];
        [tableView setDataSource:self];
        [tableView setDelegate:self];

        [content addSubview:tableView];
        [roundCorners addSubview:content];

        x += [componentWidths[idx] floatValue] + 8;
    }];

    [components enumerateObjectsUsingBlock:^(NSString *componentTitle, NSUInteger idx, BOOL *stop) {
        [self selectRow:[selectedItems[idx] integerValue] inComponent:idx animated:NO notify:NO];
    }];

    CGFloat offset = [self calculateTableViewOffset];
    [roundCorners setFrame:CGRectMake(offset, 10, self.bounds.size.width - offset * 2.0, self.bounds.size.height - 20)];

    [self setupDarkeners];
}

- (void)layoutSubviews {
    __block CGFloat x = 0.0;
    [contentViews enumerateObjectsUsingBlock:^(DSTPickerContentView *contentView, NSUInteger idx, BOOL *stop) {
        [contentView setFrame:CGRectMake(x, 0, [componentWidths[idx] floatValue] + 8, self.bounds.size.height - 20)];
        x += [componentWidths[idx] floatValue] + 8;
    }];
    [tableViews enumerateObjectsUsingBlock:^(UITableView *tableView, NSUInteger idx, BOOL *stop) {
        CGFloat top = 0;
        if ([components[idx] length] > 0) {
            top += 20;
        }
        [tableView setFrame:CGRectMake(4, top, [componentWidths[idx] floatValue], self.bounds.size.height - 20 - top)];
        CGFloat inset = floorf((tableView.frame.size.height - [rowSizes[idx] floatValue] - _elementDistance) / 2.0);
        [tableView setContentInset:UIEdgeInsetsMake(inset, 0, inset, 0)];
    }];

    CGFloat offset = [self calculateTableViewOffset];
    [roundCorners setFrame:CGRectMake(offset, 10, self.bounds.size.width - offset * 2.0, self.bounds.size.height - 20)];

    [darkenTop setImage:nil];
    [darkenBottom setImage:nil];
    [self setupDarkeners];
}

- (void)setupDarkeners {
    if ([darkenTop image] == nil) {
        UIGraphicsBeginImageContext(CGSizeMake(16, floorf((self.bounds.size.height - 20) / 4)));
        CGContextRef context = UIGraphicsGetCurrentContext();

        static const float input_value_range[2] = {0, 1};
        static const float output_value_ranges[8] = {0, 1, 0, 1, 0, 1, 0, 1};
        CGFunctionCallbacks callbacks = {0, cubicInterpolation, NULL};

        BOOL drawInverse = NO;
        CGFunctionRef gradientFunction = CGFunctionCreate(
                                                          (void *)&drawInverse,
                                                          1, // number of input values to the callback
                                                          input_value_range,
                                                          4, // number of components (r, g, b, a)
                                                          output_value_ranges,
                                                          &callbacks);
        CGShadingRef shading = CGShadingCreateAxial(colorspace,
                                                    CGPointZero,
                                                    CGPointMake(0.0, floorf((self.bounds.size.height - 20) / 4)),
                                                    gradientFunction,
                                                    NO,
                                                    NO);
        CGContextSetAlpha(context, 0.9);
        CGContextDrawShading(context, shading);
        CGShadingRelease(shading);
        CGFunctionRelease(gradientFunction);

        UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
        [darkenTop setImage:image];
        UIGraphicsEndImageContext();
    }

    if ([darkenBottom image] == nil) {
        UIGraphicsBeginImageContext(CGSizeMake(16, floorf((self.bounds.size.height - 20) / 4)));
        CGContextRef context = UIGraphicsGetCurrentContext();

        static const float input_value_range[2] = {0, 1};
        static const float output_value_ranges[8] = {0, 1, 0, 1, 0, 1, 0, 1};
        CGFunctionCallbacks callbacks = {0, cubicInterpolation, NULL};

        BOOL drawInverse = YES;
        CGFunctionRef gradientFunction = CGFunctionCreate(
                                                          (void *)&drawInverse,
                                                          1, // number of input values to the callback
                                                          input_value_range,
                                                          4, // number of components (r, g, b, a)
                                                          output_value_ranges,
                                                          &callbacks);
        CGShadingRef shading = CGShadingCreateAxial(colorspace,
                                                    CGPointZero,
                                                    CGPointMake(0.0, floorf((self.bounds.size.height - 20) / 4)),
                                                    gradientFunction,
                                                    NO,
                                                    NO);
        CGContextSetAlpha(context, 0.9);
        CGContextDrawShading(context, shading);
        CGShadingRelease(shading);
        CGFunctionRelease(gradientFunction);

        UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
        [darkenBottom setImage:image];
        UIGraphicsEndImageContext();
    }

    CGFloat height = 44;
    if ([rowSizes count] > 0) {
        height = [rowSizes[0] floatValue] + _elementDistance;
    }

    if ([selectionIndicator image] == nil) {
        UIGraphicsBeginImageContext(CGSizeMake(16, height + 15));
        CGContextRef context = UIGraphicsGetCurrentContext();

        [_selectionIndicatorBaseColor setFill];
        CGContextFillRect(context, CGRectMake(0, 0, 16, height));

        CGGradientRef gradient;
        CGFloat locations[] = { 0.0, 1.0 };

        CGFloat colorComponents[] = {
            1.0, 1.0, 1.0, 0.55,
            1.0, 1.0, 1.0, 0.15
        };
        gradient = CGGradientCreateWithColorComponents(colorspace, colorComponents, locations, 2);

        CGContextSaveGState(context);
        CGContextClipToRect(context, CGRectMake(0, 1, 16, floorf(height / 2.0) - 1.0));
        CGContextDrawLinearGradient(context, gradient, CGPointZero, CGPointMake(0.0, floorf(height / 2.0)), 0);
        CGContextRestoreGState(context);
        CGGradientRelease(gradient);

        static const float input_value_range[2] = {0, 1};
        static const float output_value_ranges[8] = {0, 1, 0, 1, 0, 1, 0, 1};
        CGFunctionCallbacks callbacks = {0, cubicInterpolation, NULL};

        BOOL drawInverse = NO;
        CGFunctionRef gradientFunction = CGFunctionCreate(
                                                          (void *)&drawInverse,
                                                          1, // number of input values to the callback
                                                          input_value_range,
                                                          4, // number of components (r, g, b, a)
                                                          output_value_ranges,
                                                          &callbacks);
        CGShadingRef shading = CGShadingCreateAxial(colorspace,
                                                    CGPointMake(0.0, height),
                                                    CGPointMake(0.0, height + 15),
                                                    gradientFunction,
                                                    NO,
                                                    NO);

        CGContextSaveGState(context);
        CGContextClipToRect(context, CGRectMake(0, height, 16, 15));
        CGContextSetAlpha(context, 0.3);
        CGContextDrawShading(context, shading);
        CGContextRestoreGState(context);
        CGShadingRelease(shading);
        CGFunctionRelease(gradientFunction);

        [[UIColor darkGrayColor] setFill];
        CGContextSetAlpha(context, 1.0);
        CGContextFillRect(context, CGRectMake(0, 0, 16, 1));
        CGContextFillRect(context, CGRectMake(0, height - 1, 16, 1));
        [[UIColor whiteColor] setFill];
        CGContextFillRect(context, CGRectMake(0, 1, 16, 1));

        UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
        [selectionIndicator setImage:image];
        UIGraphicsEndImageContext();
    }

    [roundCorners bringSubviewToFront:darkenTop];
    [darkenTop setFrame:CGRectMake(0, 0, roundCorners.bounds.size.width, floorf((self.bounds.size.height - 20) / 4))];

    [roundCorners bringSubviewToFront:darkenBottom];
    [darkenBottom setFrame:CGRectMake(0, roundCorners.bounds.size.height - floorf((self.bounds.size.height - 20) / 4), roundCorners.bounds.size.width, floorf((self.bounds.size.height - 20) / 4))];

    [roundCorners bringSubviewToFront:selectionIndicator];
    [selectionIndicator setFrame:CGRectMake(0, floorf((roundCorners.bounds.size.height - height) / 2.0), roundCorners.bounds.size.width, height + 15)];
}

- (CGFloat)calculateTableViewOffset {
    CGFloat sumSize = 0;
    for (NSNumber *width in componentWidths) {
        sumSize += [width integerValue] + 8; // include frame
    }
    return floorf((self.bounds.size.width - sumSize) / 2.0);
}

#pragma mark - Tableview Delegate

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSUInteger idx = [tableViews indexOfObject:tableView];
    return [rowSizes[idx] floatValue] + _elementDistance;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    NSUInteger idx = [tableViews indexOfObject:tableView];
    [self selectRow:indexPath.row inComponent:idx animated:YES];
}

#pragma mark - Tableview Datasource

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSUInteger idx = [tableViews indexOfObject:tableView];

    DSTPickerTableViewCell *cell = (DSTPickerTableViewCell *)[tableView dequeueReusableCellWithIdentifier:@"cell"];
    if (!cell) {
        cell = [[DSTPickerTableViewCell alloc] initWithReuseIdentifier:@"cell"];
    }

    NSMutableArray *subviews = [[NSMutableArray alloc] initWithCapacity:[[cell.contentView subviews] count]];
    for (UIView *subview in [cell.contentView subviews]) {
        if ([subview respondsToSelector:@selector(removeFromSuperview)]) {
            [subviews addObject:subview];
        }
    }
    [subviews makeObjectsPerformSelector:@selector(removeFromSuperview)];
    UIView *view = cols[idx][indexPath.row];
    CGRect frame = [view frame];
    frame.origin.x = 4;
    frame.origin.y = floorf(_elementDistance / 2.0);
    [view setFrame:frame];
    [cell.contentView addSubview:view];
    [cell setRow:indexPath.row];
    [cell setSection:indexPath.section];

    return cell;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    NSUInteger idx = [tableViews indexOfObject:tableView];
    return [cols[idx] count];
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    // play tock sound if row changed
    NSUInteger idx = [tableViews indexOfObject:scrollView];
    CGFloat inset = floorf((scrollView.frame.size.height - [rowSizes[idx] floatValue] - _elementDistance) / 2.0);
    CGFloat middlePosition = scrollView.contentOffset.y + inset;
    if (middlePosition < 0) middlePosition = 0;
    CGFloat rowHeight = [rowSizes[idx] floatValue] + _elementDistance;
    CGFloat remainder = fmodf(middlePosition, rowHeight);
    NSInteger row = (middlePosition - remainder) / rowHeight;
    if (remainder >= rowHeight / 2.0) {
        row++;
    }
    if (row != [currentItems[idx] integerValue]) {
        currentItems[idx] = @(row);
        AudioServicesPlaySystemSound(1104);
    }
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate {
    if (!decelerate) {
        [self scrollViewDidEndDecelerating:scrollView];
    }
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView {
    NSUInteger idx = [tableViews indexOfObject:scrollView];
    CGFloat inset = floorf((scrollView.frame.size.height - [rowSizes[idx] floatValue] - _elementDistance) / 2.0);
    CGFloat middlePosition = scrollView.contentOffset.y + inset;
    if (middlePosition < 0) middlePosition = 0;
    CGFloat rowHeight = [rowSizes[idx] floatValue] + _elementDistance;
    CGFloat remainder = fmodf(middlePosition, rowHeight);
    NSInteger row = (middlePosition - remainder) / rowHeight;

    CGPoint offset;
    if (remainder < rowHeight / 2.0) {
        // scroll up
        offset = CGPointMake(0, middlePosition - remainder - inset);
    } else {
        // scroll down
        offset = CGPointMake(0, middlePosition - remainder + rowHeight - inset);
        row++;
    }

    // clamp row
    if (row > [cols[idx] count] - 1) {
        row = [cols[idx] count] - 1;
    }

    // notify delegate
    if (remainder < 0.1) {
        if (row != [selectedItems[idx] integerValue]) {
            selectedItems[idx] = @(row);
            currentItems[idx] = @(row);
            [self notifyDelegateOfRowChange:@{ @"row" : @(row), @"component" : @(idx) }];
        }
        // do not scroll anymore if we're there already
        return;
    } else {
        if (row != [selectedItems[idx] integerValue]) {
            selectedItems[idx] = @(row);
            currentItems[idx] = @(row);
            [self performSelector:@selector(notifyDelegateOfRowChange:) withObject:@{ @"row" : @(row), @"component" : @(idx) } afterDelay:0.25];
        }

    }

    [scrollView setContentOffset:offset animated:YES];
}

@end
