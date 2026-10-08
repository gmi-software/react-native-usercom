#import "UserComPresentationDelegate.h"
#import <UserNotifications/UserNotifications.h>

@interface UserComPresentationDelegate () <UNUserNotificationCenterDelegate>
@property(nonatomic, weak) id<UNUserNotificationCenterDelegate> previous;
@end

@implementation UserComPresentationDelegate

+ (void)install {
  static UserComPresentationDelegate *shared;
  static dispatch_once_t once;
  dispatch_once(&once, ^{ shared = [UserComPresentationDelegate new]; });
  UNUserNotificationCenter *center = UNUserNotificationCenter.currentNotificationCenter;
  if (center.delegate == shared) return;
  shared.previous = center.delegate;
  center.delegate = shared;
}

- (void)userNotificationCenter:(UNUserNotificationCenter *)center
      willPresentNotification:(UNNotification *)notification
        withCompletionHandler:(void (^)(UNNotificationPresentationOptions))completionHandler {
  if ([notification.request.identifier hasPrefix:@"usercom-"]) {
    NSUserDefaults *storage = NSUserDefaults.standardUserDefaults;
    NSString *owner = notification.request.content.userInfo[@"_nitro_user_id"];
    BOOL enabled = [storage boolForKey:@"nitro.usercom.push-enabled"] &&
      [owner isEqualToString:[storage stringForKey:@"nitro.usercom.message-owner"]];
    completionHandler(enabled ? UNNotificationPresentationOptionBanner |
      UNNotificationPresentationOptionSound | UNNotificationPresentationOptionBadge : 0);
  } else if ([self.previous respondsToSelector:_cmd]) {
    [self.previous userNotificationCenter:center willPresentNotification:notification
                   withCompletionHandler:completionHandler];
  } else { completionHandler(0); }
}

- (void)userNotificationCenter:(UNUserNotificationCenter *)center
  didReceiveNotificationResponse:(UNNotificationResponse *)response
           withCompletionHandler:(void (^)(void))completionHandler {
  if ([self.previous respondsToSelector:_cmd]) {
    [self.previous userNotificationCenter:center didReceiveNotificationResponse:response
                   withCompletionHandler:completionHandler];
  } else { completionHandler(); }
}

- (void)userNotificationCenter:(UNUserNotificationCenter *)center
  openSettingsForNotification:(UNNotification *)notification {
  if ([self.previous respondsToSelector:_cmd])
    [self.previous userNotificationCenter:center openSettingsForNotification:notification];
}

@end
