//
//  Xcode44.h
//  mps
//
//  Created by Johannes Schriewer on 2012-08-09.
//  Copyright (c) 2012 planetmutlu. All rights reserved.
//

#if __IPHONE_OS_VERSION_MAX_ALLOWED < 60000

#ifndef NS_ENUM
#define NS_ENUM(_type, _name) enum _name : _type _name; enum _name : _type
#endif

@interface NSDictionary(subscripts)
- (id)objectForKeyedSubscript:(id)key;
@end

@interface NSMutableDictionary(subscripts)
- (void)setObject:(id)obj forKeyedSubscript:(id <NSCopying>)key;
@end

@interface NSArray(subscripts)
- (id)objectAtIndexedSubscript:(NSUInteger)idx;
@end

@interface NSMutableArray(subscripts)
- (void)setObject:(id)obj atIndexedSubscript:(NSUInteger)idx;
@end
#endif