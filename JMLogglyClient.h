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


#import <Foundation/Foundation.h>

typedef void (^JMCompletion)(id result, NSError *error);

@interface JMLogglyClient : NSObject

+ (JMLogglyClient *)sharedClient;

@property (nonatomic, strong) NSArray * tags;
@property (nonatomic, strong) NSString * token;

- (void)logMessage:(NSString *)message;
- (void)logMessage:(NSString *)message andTags:(NSArray *)tags;
- (void)logMessage:(NSString *)message andTags:(NSArray *)tags withCompletion:(JMCompletion)completion;
- (void)logDictionary:(NSDictionary *)dict;
- (void)logDictionary:(NSDictionary *)dict andTags:(NSArray *)tags;
- (void)logDictionary:(NSDictionary *)dict andTags:(NSArray *)tags withCompletion:(JMCompletion)completion;

@end
