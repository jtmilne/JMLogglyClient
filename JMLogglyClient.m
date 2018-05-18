//
//    Copyright (c) 2018 Joel Milne
//
//    Permission is hereby granted, free of charge, to any person obtaining a copy of
//    this software and associated documentation files (the "Software"), to deal in
//    the Software without restriction, including without limitation the rights to
//    use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
//    the Software, and to permit persons to whom the Software is furnished to do so,
//    subject to the following conditions:
//
//    The above copyright notice and this permission notice shall be included in all
//    copies or substantial portions of the Software.
//
//    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
//    FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
//    COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
//    IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
//    CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

#import "JMLogglyClient.h"

#define kLogglyBaseUrl      @"https://logs-01.loggly.com/inputs/%@"
#define kLogglyTagsUrl      @"%@/tag/%@"
#define kMaxRetries         10
#define kRetryInterval      5 //seconds

@interface JMLogglyClient ()

@property (nonatomic, strong) NSURLSessionConfiguration *sessionConfiguration;

- (NSError *)errorWithMessage:(NSString *)errorMessage;
- (NSURL *)urlWithTags:(NSArray *)tags;
- (void)logRequest:(NSMutableURLRequest *)request withCompletion:(JMCompletion)completion;
- (void)logRequest:(NSMutableURLRequest *)request withCompletion:(JMCompletion)completion andRetryCount:(NSUInteger)retryCount;

@end

@implementation JMLogglyClient

////////////////////////////////////////////////////////////////
#pragma mark Object Lifecycle
////////////////////////////////////////////////////////////////

+ (JMLogglyClient *)sharedClient
{
    static JMLogglyClient *_sharedClient = nil;
    static dispatch_once_t oncePredicate;
    dispatch_once(&oncePredicate, ^{
        _sharedClient = [[self alloc] init];
    });
    return _sharedClient;
}

- (id)init
{
    self = [super init];
    if (self) {
        NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
        [config setURLCache:nil];
        [config setRequestCachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData];
        [self setSessionConfiguration:config];
    }
    return self;
}

////////////////////////////////////////////////////////////////
#pragma mark Private Methods
////////////////////////////////////////////////////////////////

- (NSError *)errorWithMessage:(NSString *)errorMessage
{
    return [NSError errorWithDomain:@"loggly" code:0 userInfo:@{NSLocalizedDescriptionKey:errorMessage}];
}

- (NSURL *)urlWithTags:(NSArray *)tags
{
    //get the base url
    NSString *urlString = [NSString stringWithFormat:kLogglyBaseUrl, self.token];
    
    //add the tags
    NSArray* allTags = @[];
    if (self.tags && self.tags.count > 0) allTags = [allTags arrayByAddingObjectsFromArray:self.tags];
    if (tags && tags.count > 0) allTags = [allTags arrayByAddingObjectsFromArray:tags];
    if (allTags.count > 0) {
        urlString = [NSString stringWithFormat:kLogglyTagsUrl, urlString, [allTags componentsJoinedByString:@","]];
    }

    return [NSURL URLWithString:urlString];
}

- (void)logRequest:(NSMutableURLRequest *)request withCompletion:(JMCompletion)completion
{
    //log in background
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        [self logRequest:request withCompletion:completion andRetryCount:0];
    });
}

- (void)logRequest:(NSMutableURLRequest *)request withCompletion:(JMCompletion)completion andRetryCount:(NSUInteger)retryCount
{
    NSURLSession *session = [NSURLSession sessionWithConfiguration:self.sessionConfiguration];
    [[session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {

        //return if it's a good response
        NSUInteger responseStatusCode = [(NSHTTPURLResponse*)response statusCode];
        if (responseStatusCode == 200) {
            if (completion) completion(data, nil);
            return;
        }
        
        //return if max retries hit
        if (retryCount >= kMaxRetries) {
            if (completion) completion (nil, error);
            return;
        }
        
        //retry with exponential backoff
        double delayInSeconds = kRetryInterval * pow(2, retryCount);
        dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, delayInSeconds * NSEC_PER_SEC);
        dispatch_after(popTime, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^(void){
            [self logRequest:request withCompletion:completion andRetryCount:retryCount+1];
        });
        
    }] resume];
}

////////////////////////////////////////////////////////////////
#pragma mark Public Methods
////////////////////////////////////////////////////////////////

- (void)logMessage:(NSString *)message
{
    [self logMessage:message andTags:nil];
}

- (void)logMessage:(NSString *)message andTags:(NSArray *)tags
{
    [self logMessage:message andTags:tags withCompletion:nil];
}

- (void)logMessage:(NSString *)message andTags:(NSArray *)tags withCompletion:(JMCompletion)completion
{
    //validate params
    if (!message) {
        if (completion) completion(nil, [self errorWithMessage:@"Invalid parameter to log."]);
        return;
    }
    
    //ensure we have a token
    if (!self.token) {
        if (completion) completion(nil, [self errorWithMessage:@"Loggly client token required."]);
        return;
    }
    
    //create a request
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[self urlWithTags:tags]];
    [request addValue:@"text/plain" forHTTPHeaderField:@"Content-Type"];
    [request setHTTPBody:[message dataUsingEncoding:NSUTF8StringEncoding]];
    [request setHTTPMethod:@"POST"];
    
    [self logRequest:request withCompletion:completion];
}

- (void)logDictionary:(NSDictionary *)dict
{
    [self logDictionary:dict andTags:nil];
}

- (void)logDictionary:(NSDictionary *)dict andTags:(NSArray *)tags
{
    [self logDictionary:dict andTags:tags withCompletion:nil];
}

- (void)logDictionary:(NSDictionary *)dict andTags:(NSArray *)tags withCompletion:(JMCompletion)completion
{
    //validate params
    if (!dict) {
        if (completion) completion(nil, [self errorWithMessage:@"Invalid parameter to log."]);
        return;
    }
    
    //ensure we have a token
    if (!self.token) {
        if (completion) completion(nil, [self errorWithMessage:@"Loggly client token required."]);
        return;
    }

    //encode body
    NSError *errorJSON = nil;
    NSData *postData = [NSJSONSerialization dataWithJSONObject:dict options:0 error:&errorJSON];
    if (errorJSON) {
        if (completion) completion(nil, errorJSON);
        return;
    }

    //create a request
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[self urlWithTags:tags]];
    [request addValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
    [request setHTTPBody:postData];
    [request setHTTPMethod:@"POST"];
    
    [self logRequest:request withCompletion:completion];
}

@end
