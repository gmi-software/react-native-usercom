#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Preserves the host notification delegate while displaying User.com local banners.
@interface UserComPresentationDelegate : NSObject
+ (void)install;
@end

NS_ASSUME_NONNULL_END
