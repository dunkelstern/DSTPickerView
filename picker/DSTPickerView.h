//
//  DSTCustomPickerView.h
//  custompicker
//
//  Created by Johannes Schriewer on 20.09.2012.
//  Copyright (c) 2012 Johannes Schriewer. All rights reserved.
//

#import <UIKit/UIKit.h>

@class DSTPickerView;

@protocol DSTPickerViewDelegate <NSObject>
- (void)pickerView:(DSTPickerView *)pickerView didSelectRow:(NSInteger)row inComponent:(NSInteger)component;

// components are horizontally centered on picker view
- (CGFloat)pickerView:(DSTPickerView *)pickerView widthForComponent:(NSInteger)component;

@optional
// if not implemented defaults to size of biggest element
- (CGFloat)pickerView:(DSTPickerView *)pickerView rowHeightForComponent:(NSInteger)component;

// if not implemented no titles will be displayed
- (NSString *)pickerView:(DSTPickerView *)pickerView titleForComponent:(NSInteger)component;

// if either one of these returns nil the next one is tried
// title may also return @"" to skip to the next to be
// compatible with the original UIPicker
- (NSString *)pickerView:(DSTPickerView *)pickerView titleForRow:(NSInteger)row forComponent:(NSInteger)component;
- (UIImage *)pickerView:(DSTPickerView *)pickerView imageForRow:(NSInteger)row forComponent:(NSInteger)component;
- (UIView *)pickerView:(DSTPickerView *)pickerView viewForRow:(NSInteger)row forComponent:(NSInteger)component reusingView:(UIView *)view;

// if title-text is returned these are called too (return nil for default)
- (UIFont *)pickerView:(DSTPickerView *)pickerView fontForRow:(NSInteger)row forComponent:(NSInteger)component;
- (UIColor *)pickerView:(DSTPickerView *)pickerView colorForRow:(NSInteger)row forComponent:(NSInteger)component;

// implement if you wanna be notified when the user starts interacting with the picker view
- (void)pickerViewWillBeginDragging:(DSTPickerView *)pickerView;
@end

@protocol DSTPickerViewDataSource <NSObject>
- (NSInteger)numberOfComponentsInPickerView:(DSTPickerView *)pickerView;
- (NSInteger)pickerView:(DSTPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component;
@end

@interface DSTPickerView : UIView

@property (nonatomic, weak) id<DSTPickerViewDelegate> delegate;
@property (nonatomic, weak) id<DSTPickerViewDataSource> dataSource;

@property(nonatomic, readonly) NSInteger numberOfComponents;
@property(nonatomic) BOOL showsSelectionIndicator;

@property (nonatomic, strong) UIColor *backgroundGradientStartColor;
@property (nonatomic, strong) UIColor *backgroundGradientEndColor;
@property (nonatomic, strong) UIColor *selectionIndicatorBaseColor;
@property (nonatomic, strong) UIColor *componentBackgroundColor;
@property (nonatomic, assign) BOOL addShine;
@property (nonatomic, assign) BOOL drawComponentBorders;
@property (nonatomic, assign) BOOL drawDarkeners;
@property (nonatomic, assign) CGFloat elementDistance;
@property (nonatomic, assign) CGFloat verticalPadding;

- (NSInteger)numberOfRowsInComponent:(NSInteger)component;
- (void)reloadAllComponents;
- (void)reloadComponent:(NSInteger)component;
- (CGSize)rowSizeForComponent:(NSInteger)component;
- (NSInteger)selectedRowInComponent:(NSInteger)component;
- (void)selectRow:(NSInteger)row inComponent:(NSInteger)component animated:(BOOL)animated;
- (UIView *)viewForRow:(NSInteger)row forComponent:(NSInteger)component;

@end
