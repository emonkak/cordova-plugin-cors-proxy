#import "CDVCorsProxy.h"
#import "GCDWebServerPrivate.h"
#import <Cordova/CDVViewController.h>
#import <Cordova/NSDictionary+CordovaPreferences.h>

@implementation CDVCorsProxy

- (void)pluginInitialize
{
    [GCDWebServer setLogLevel:kGCDWebServerLoggingLevel_Error];

    self.server = [[GCDWebServer alloc] init];

    __weak __typeof(self) weakSelf = self;

    [self.server addHandlerForMethod:@"POST"
                           pathRegex:@".*"
                        requestClass:[GCDWebServerDataRequest class]
                   asyncProcessBlock:^(GCDWebServerRequest* request, GCDWebServerCompletionBlock completionBlock)
    {
        [weakSelf sendProxyResult:request completionBlock:completionBlock];
    }];
    [self.server addHandlerForMethod:@"PUT"
                           pathRegex:@".*"
                        requestClass:[GCDWebServerDataRequest class]
                   asyncProcessBlock:^(GCDWebServerRequest* request, GCDWebServerCompletionBlock completionBlock)
    {
        [weakSelf sendProxyResult:request completionBlock:completionBlock];
    }];
    [self.server addHandlerForMethod:@"PATCH"
                           pathRegex:@".*"
                        requestClass:[GCDWebServerDataRequest class]
                   asyncProcessBlock:^(GCDWebServerRequest* request, GCDWebServerCompletionBlock completionBlock)
    {
        [weakSelf sendProxyResult:request completionBlock:completionBlock];
    }];
    [self.server addHandlerForMethod:@"DELETE"
                           pathRegex:@".*"
                        requestClass:[GCDWebServerDataRequest class]
                   asyncProcessBlock:^(GCDWebServerRequest* request, GCDWebServerCompletionBlock completionBlock)
    {
        [weakSelf sendProxyResult:request completionBlock:completionBlock];
    }];
    [self.server addHandlerForMethod:@"GET"
                           pathRegex:@".*"
                        requestClass:[GCDWebServerDataRequest class]
                   asyncProcessBlock:^(GCDWebServerRequest* request, GCDWebServerCompletionBlock completionBlock)
    {
        [weakSelf sendProxyResult:request completionBlock:completionBlock];
    }];
    [self.server addHandlerForMethod:@"OPTIONS"
                           pathRegex:@".*"
                        requestClass:[GCDWebServerDataRequest class]
                        processBlock:^GCDWebServerResponse* (GCDWebServerRequest* request)
    {
        return [weakSelf createCorsHeadersResponse];
    }];

    NSString *portStr = [[self.commandDelegate settings] cordovaSettingForKey:@"CordovaCorsProxyPort"];
    NSUInteger port = portStr ? [portStr integerValue] : 80;

    [self.server startWithPort:port bonjourName:nil];
}

- (void)sendProxyResult:(GCDWebServerRequest*)request completionBlock:(GCDWebServerCompletionBlock)completionBlock
{
    NSString *query = request.URL.query != nil && [request.URL.query length] > 0
        ? [@"?" stringByAppendingString:request.URL.query]
        : @"";
    NSString* urlStr = [[request.path substringFromIndex:1] stringByAppendingString:query];
    NSURL *url = [NSURL URLWithString:urlStr];

    if (url == nil) {
        [self createErrorResponse:@"Invalid URL"];
        return;
    }

    NSMutableURLRequest *urlRequest =
        [NSMutableURLRequest requestWithURL:url
                                cachePolicy:NSURLRequestReloadIgnoringCacheData
                            timeoutInterval:60];

    urlRequest.HTTPMethod = request.method;

    if ([request hasBody]) {
        urlRequest.HTTPBody = ((GCDWebServerDataRequest*)request).data;
    }

    for (id key in [request.headers keyEnumerator]) {
        if ([key isEqualToString:@"Connection"] || [key isEqualToString:@"Host"]) {
            continue;
        }

        [urlRequest setValue:request.headers[key] forHTTPHeaderField:key];
    }

    NSURLSession *session = [NSURLSession sharedSession];
    NSURLSessionDataTask *task = [session dataTaskWithRequest:urlRequest
               completionHandler:^(NSData *data,
                                   NSURLResponse *urlResponse,
                                   NSError *error) {
        if (error != nil) {
            return completionBlock([self createErrorResponse:error.localizedDescription]);
        }

        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse*)urlResponse;
        NSString *contentType = httpResponse.allHeaderFields[@"Content-Type"] ?: @"";
        GCDWebServerDataResponse *response =
            [GCDWebServerDataResponse responseWithData:data != nil ? data : [NSData data]
                                           contentType:contentType];

        response.statusCode = httpResponse.statusCode;

        for (id key in [httpResponse.allHeaderFields keyEnumerator]) {
            if ([key isEqualToString:@"Content-Encoding"]) {
                continue;
            }

            [response setValue:httpResponse.allHeaderFields[key] forAdditionalHeader:key];
        }

        if (data != nil) {
            NSString *contentLength = [NSString stringWithFormat:@"%@", @(data.length)];

            [response setValue:contentLength forAdditionalHeader:@"Content-Length"];
        }

        [self injectCorsHeaders:response];

        completionBlock(response);
    }];

    [task resume];
}

- (GCDWebServerResponse*)createCorsHeadersResponse
{
    GCDWebServerResponse *response = [GCDWebServerResponse response];

    [self injectCorsHeaders:response];

    return response;
}

- (GCDWebServerResponse*)createErrorResponse:(NSString*)error
{
    GCDWebServerDataResponse *response = [GCDWebServerDataResponse responseWithText:error];

    response.statusCode = 500;

    [self injectCorsHeaders:response];

    return response;
}

- (void)injectCorsHeaders:(GCDWebServerResponse*)response
{
    [response setValue:@"*" forAdditionalHeader:@"Access-Control-Allow-Origin"];
    [response setValue:@"PUT,POST,GET,PATCH,DELETE" forAdditionalHeader:@"Access-Control-Allow-Methods"];
    [response setValue:@"Authorization,Content-Type" forAdditionalHeader:@"Access-Control-Allow-Headers"];
    [response setValue:@"true" forAdditionalHeader:@"Access-Control-Allow-Credentials"];
}

@end
