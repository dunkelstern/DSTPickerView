DSTPickerView
=============

Drop-in replacement for UIPickerView with additional features.

If you use MTStatusBarOverlay in your app, please drop me a line so that I can add your app here!

1. Fully resizable, no 216 pixels maximum size
2. Themeable, change the background gradient, the color of the selection bar, enable and disable shine
3. Set element distance. Have small elements but many? Increase the padding to make the picker better to touch
4. Configure the font and color of individual rows in the picker
5. Add images to the picker
6. Add custom views to the picker
7. Mix em all up
8. Provide titles for the components

The good:
- No additional images needed, just drop `DSTPickerView.h` and `DSTPickerView.m` into your Project and start using it.
- If you already have implemented a `UIPickerView` just replace it's class name with `DSTPickerView` and you're ready to go.

The ugly:
- Clicking sounds are not 100% identical to the original picker.
- Uses "Magic Number" to access the click sound from iOS, so it may not disable the click sounds even if the user did so in the settings App.
- Not 100% pixel perfect but damn close

The Bad:
- Has not been tested for accessibility

Screenshots
===========

## Original Apple `UIPickerView`
![UIPickerView]()

## Custom `DSTPickerView`
![DSTPickerView]()
