//
//  Created by Jesse Squires
//  http://www.jessesquires.com
//
//
//  Documentation
//  http://cocoadocs.org/docsets/JSQMessagesViewController
//
//
//  GitHub
//  https://github.com/jessesquires/JSQMessagesViewController
//
//
//  License
//  Copyright (c) 2014 Jesse Squires
//  Released under an MIT license: http://opensource.org/licenses/MIT
//

#import "UIDevice+JSQMessages.h"

@implementation UIDevice (JSQMessages)

+ (BOOL)jsq_isCurrentDeviceBeforeiOS8
{
    // iOS < 8.0
    return [[UIDevice currentDevice].systemVersion compare:@"8.0" options:NSNumericSearch] == NSOrderedAscending;
}

+ (BOOL)jsq_isCurrentDeviceAfteriOS9
{
    // iOS > 9.0
    return [[UIDevice currentDevice].systemVersion compare:@"9.0" options:NSNumericSearch] == NSOrderedDescending;
}

+ (BOOL)jsq_isCurrentDeviceEqualOrAfteriOS13
{
    // iOS >= 13
    return [[[UIDevice currentDevice] systemVersion] compare:@"13.0" options:NSNumericSearch] != NSOrderedAscending;
}

@end
