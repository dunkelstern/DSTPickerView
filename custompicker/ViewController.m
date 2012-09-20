//
//  ViewController.m
//  custompicker
//
//  Created by Johannes Schriewer on 20.09.2012.
//  Copyright (c) 2012 Johannes Schriewer. All rights reserved.
//

#import "ViewController.h"
#import "DSTPickerView.h"

@interface ViewController () <DSTPickerViewDataSource, DSTPickerViewDelegate, UIPickerViewDataSource, UIPickerViewDelegate> {
    DSTPickerView *picker;
    UIPickerView *uiPicker;
}

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self.view setBackgroundColor:[UIColor whiteColor]];

    CGFloat height = floorf(self.view.bounds.size.height / 2.0);
    height = 216.0;

    picker = [[DSTPickerView alloc] initWithFrame:CGRectMake(0, 10, self.view.bounds.size.width, height)];
    [picker setShowsSelectionIndicator:YES];
    [picker setDelegate:self];
    [picker setDataSource:self];
    [self.view addSubview:picker];

    uiPicker = [[UIPickerView alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, height)];
    [uiPicker setShowsSelectionIndicator:YES];
    [uiPicker setDelegate:self];
    [uiPicker setDataSource:self];
    [self.view addSubview:uiPicker];

}

- (void)viewWillLayoutSubviews {
    CGFloat height = floorf(self.view.bounds.size.height / 2.0);
    height = 216.0;

    [picker setFrame:CGRectMake(0, 10, self.view.bounds.size.width, height)];
    [uiPicker setFrame:CGRectMake(0, floorf(self.view.bounds.size.height / 2.0), self.view.bounds.size.width, height)];
}

- (void)viewDidUnload
{
    [super viewDidUnload];
    // Release any retained subviews of the main view.
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
        return YES;
}

#pragma mark - Pickerview

- (NSInteger)numberOfComponentsInPickerView:(DSTPickerView *)pickerView {
    return 4;
}

- (NSInteger)pickerView:(DSTPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component {
    return 10;
}


- (void)pickerView:(DSTPickerView *)pickerView didSelectRow:(NSInteger)row inComponent:(NSInteger)component {
    NSLog(@"Did select row: %d component: %d", row, component);
    if (component < 3) {
        //[pickerView selectRow:row inComponent:component + 1 animated:YES];
    }
}

- (CGFloat)pickerView:(DSTPickerView *)pickerView widthForComponent:(NSInteger)component {
    if (component == 0) return 200;
    if (component == 1) return 150;

    return 80;
}

- (NSString *)pickerView:(DSTPickerView *)pickerView titleForRow:(NSInteger)row forComponent:(NSInteger)component {
    if (row == 2) {
        return @"";
    }
    return [NSString stringWithFormat:@"Row %d", row];
}

- (UIImage *)pickerView:(DSTPickerView *)pickerView imageForRow:(NSInteger)row forComponent:(NSInteger)component {
    if (row == 2) {
        return [UIImage imageNamed:@"demo"];
    }
    return nil;
}

- (UIFont *)pickerView:(DSTPickerView *)pickerView fontForRow:(NSInteger)row forComponent:(NSInteger)component {
    if (row == 0) {
        return [UIFont fontWithName:@"SnellRoundhand" size:20.0];
    }
    return nil; // default
}

- (UIColor *)pickerView:(DSTPickerView *)pickerView colorForRow:(NSInteger)row forComponent:(NSInteger)component {
    if (row == 1) {
        return [UIColor blueColor];
    }
    return nil;
}
@end
