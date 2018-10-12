//
//  UserNotification.m
//  NotificationTestDemo
//
//  Created by licl on 2018/9/12.
//  Copyright © 2018年 licl. All rights reserved.
//

#import "UserNotification.h"
#import <UserNotifications/UserNotifications.h>
#import <AVFoundation/AVFoundation.h>
//#import <AVFoundation/AVAudioPlayer.h>

@interface UserNotification ()<UNUserNotificationCenterDelegate>

@property (nonatomic, strong) NSDictionary * apsUserInfo;     //aps 信息
@property (nonatomic, strong) AVAudioPlayer *player;

@end

@implementation UserNotification

+ (instancetype)sharedNotification {
    static dispatch_once_t onceToken;
    static id instance;
    dispatch_once(&onceToken, ^{
        instance = [[[self class] alloc] init];
    });
    return instance;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
        center.delegate = self;
    }
    return self;
}


#pragma mark - 注册远程通知

- (void)registerNotification {
    if ([[UIDevice currentDevice].systemVersion floatValue] >= 10.0){
        UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];        
        UNAuthorizationOptions options = UNAuthorizationOptionBadge | UNAuthorizationOptionSound | UNAuthorizationOptionAlert;
        [center requestAuthorizationWithOptions:options completionHandler:^(BOOL granted, NSError * _Nullable error) {
            if (granted) {
                //允许
                NSLog(@"允许注册通知");
                //获取用户授权设置信息
                [center getNotificationSettingsWithCompletionHandler:^(UNNotificationSettings * _Nonnull settings) {
                    if (settings.authorizationStatus == UNAuthorizationStatusNotDetermined)
                    {
                        NSLog(@"未选择");
                    }else if (settings.authorizationStatus == UNAuthorizationStatusDenied){
                        NSLog(@"未授权");
                    }else if (settings.authorizationStatus == UNAuthorizationStatusAuthorized){
                        NSLog(@"已授权");
                    }
                }];
                //注册
                dispatch_async(dispatch_get_main_queue(), ^{
                    [[UIApplication sharedApplication] registerForRemoteNotifications];
                });
            } else{
                //不允许
                NSLog(@"不允许注册通知");
            }
        }];
        
    } else if ([[UIDevice currentDevice].systemVersion floatValue] >= 8.0
               && [[UIDevice currentDevice].systemVersion floatValue] < 10.0) {
        if ([[UIApplication sharedApplication] respondsToSelector:@selector(registerUserNotificationSettings:)]) {
            UIUserNotificationType type = UIUserNotificationTypeBadge|UIUserNotificationTypeSound|UIUserNotificationTypeAlert;
            UIUserNotificationSettings *settings = [UIUserNotificationSettings settingsForTypes:type categories:nil];
            [[UIApplication sharedApplication] registerUserNotificationSettings:settings];
        }
    } else {//iOS8以下
        [[UIApplication sharedApplication] registerForRemoteNotificationTypes: UIRemoteNotificationTypeBadge | UIRemoteNotificationTypeAlert | UIRemoteNotificationTypeSound];
    }
}

#pragma mark - Category

//管理通知
- (void)dealNotifications {
    
    UNUserNotificationCenter * center = [UNUserNotificationCenter currentNotificationCenter];
    [center getDeliveredNotificationsWithCompletionHandler:^(NSArray<UNNotification *> * _Nonnull notifications) {
        [center removeDeliveredNotificationsWithIdentifiers:@[@"my_notification"]];
    }];
}


#pragma mark - AppDelegate

- (void)application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken
{
    NSString *token_str=[NSString stringWithFormat:@"%@",deviceToken];
    @try {
        token_str = [token_str stringByReplacingOccurrencesOfString:@"<" withString:@""];
        token_str = [token_str stringByReplacingOccurrencesOfString:@" " withString:@""];
        token_str = [token_str stringByReplacingOccurrencesOfString:@">" withString:@""];
        [[NSUserDefaults standardUserDefaults] setObject:token_str forKey:@"apns-token"];
    }
    @catch (NSException *exception) {
        NSLog(@"application exception:%@",exception.reason);
    }
    
    if(![token_str isEqualToString:@""]) {
        //deviceToken字符串上传服务器
    }
}

- (void)application:(UIApplication *)application didFailToRegisterForRemoteNotificationsWithError:(NSError *)error
{
    //注册通知失败
    NSLog(@"\n>>>[DeviceToken Error]:%@\n\n", error.description);
}

//ios 10 之前 APP不在前台收到通知 ，静默推送
- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo fetchCompletionHandler:(void (^)(UIBackgroundFetchResult result))completionHandler
{
    //前台状态收到远程通知
    NSLog(@"didReceiveRemoteNotification---application.state=%ld", application.applicationState);
    self.apsUserInfo = userInfo;
}


#pragma mark - UNUserNotificationCenterDelegate

//当APP在前台收到通知时候，代理回调方法，通知即将展示的时候,可以处理数据加解密、数据下载工作
- (void)userNotificationCenter:(UNUserNotificationCenter *)center willPresentNotification:(UNNotification *)notification withCompletionHandler:(void (^)(UNNotificationPresentationOptions options))completionHandler
{
    //解析 notification
    NSDictionary * userInfo = notification.request.content.userInfo;
    UNNotificationRequest *request = notification.request; // 收到推送的请求
    UNNotificationContent *content = request.content; // 收到推送的消息内容
    NSNumber *badge = content.badge; // 推送消息的角标
    NSString *body = content.body; // 推送消息体
    UNNotificationSound *sound = content.sound; // 推送消息的声音
    NSString *subtitle = content.subtitle; // 推送消息的副标题
    NSString *title = content.title; // 推送消息的标题
    NSString *categoryId = content.categoryIdentifier;  //推送消息的分类id
    
    if ([notification.request.trigger isKindOfClass:[UNPushNotificationTrigger class]]) {
        NSLog(@"iOS10 前台收到远程通知:%@", userInfo);
        self.apsUserInfo = userInfo;
        //        NSSet * set = [self createNotificationCategoryActions];
        //        UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
        //        [center setNotificationCategories:set];
        
    } else {
        // 判断为本地通知
        NSLog(@"iOS10 前台收到本地通知:{\\\\nbody:%@，\\\\ntitle:%@,\\\\nsubtitle:%@,\\\\nbadge：%@，\\\\nsound：%@，\\\\nuserInfo：%@\\\\ncategoryId：%@\\\\n}",body,title,subtitle,badge,sound,userInfo,categoryId);
    }
    
    completionHandler(UNNotificationPresentationOptionBadge|UNNotificationPresentationOptionSound|UNNotificationPresentationOptionAlert); // 需要执行这个方法，选择是否提醒用户，有Badge、Sound、Alert三种类型可以设置
}

//用户与通知进行交互后的response，比如说用户直接点开通知打开App、用户点击通知的按钮或者进行输入文本框的文本
- (void)userNotificationCenter:(UNUserNotificationCenter *)center didReceiveNotificationResponse:(UNNotificationResponse *)response withCompletionHandler:(void (^)(void))completionHandler {
    //处理 response
    NSLog(@"didReceiveNotificationResponse : %@", response);
    
//    NSDictionary * userInfo = response.notification.request.content.userInfo;//userInfo数据
//    UNNotificationContent *content = request.content; // 原始内容
//    NSString *title = content.title;  // 标题
//    NSString *subtitle = content.subtitle;  // 副标题
//    NSNumber *badge = content.badge;  // 角标
//    NSString *body = content.body;    // 推送消息体
//    UNNotificationSound *sound = content.sound;
    
    //文本编辑框
    if ([response isKindOfClass:[UNTextInputNotificationResponse class]]) {
        UNTextInputNotificationResponse *textResponse = (UNTextInputNotificationResponse *)response;
        //处理文本信息
        NSString * text = textResponse.userText;
        //do something
        UIAlertController * alert = [UIAlertController alertControllerWithTitle:@"文本框输入" message:text preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
        [[UIApplication sharedApplication].keyWindow.rootViewController presentViewController:alert animated:YES completion:nil];
    }
    
    //通知行为触发情况
    if ([response.actionIdentifier isEqualToString:UNNotificationDismissActionIdentifier]) {
       //用户隐藏通知
    }
    else if ([response.actionIdentifier isEqualToString:UNNotificationDefaultActionIdentifier]) {
        //用户点击通知打开APP
    }
    else {
        //自定义按钮
        if ([response.actionIdentifier isEqualToString:@"action-like"]) {
            //"赞"的处理
        }
        if ([response.actionIdentifier isEqualToString:@"action-collect"]) {
            //"收藏"的处理
            [[UNUserNotificationCenter currentNotificationCenter] removeDeliveredNotificationsWithIdentifiers:@[response.notification.request.identifier]];
        }
    }
    
    completionHandler();
}

@end
