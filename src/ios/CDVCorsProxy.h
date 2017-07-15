#import <Cordova/CDVPlugin.h>
#import "GCDWebServer.h"

@interface CDVCorsProxy : CDVPlugin

@property (nonatomic, strong) GCDWebServer* server;

@end
