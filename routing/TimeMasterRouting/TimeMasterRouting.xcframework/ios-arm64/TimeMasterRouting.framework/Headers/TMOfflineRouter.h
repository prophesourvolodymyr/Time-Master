#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

NS_SWIFT_SENDABLE
@interface TMRoutingCancellation : NSObject
- (void)cancel;
@property (nonatomic, readonly) BOOL cancelled;
@end

@interface TMOfflineRouter : NSObject
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
- (nullable instancetype)initWithConfiguration:(NSString *)configuration
                            timezoneDirectory:(NSString *)timezoneDirectory
                                        error:(NSError **)error;
- (nullable NSString *)routeWithRequest:(NSString *)request
                         cancellation:(TMRoutingCancellation *)cancellation
                                error:(NSError **)error;
@end

NS_ASSUME_NONNULL_END
