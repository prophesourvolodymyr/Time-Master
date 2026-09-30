#import "TMOfflineRouter.h"
#include <valhalla/tyr/actor.h>
#include <boost/property_tree/json_parser.hpp>
#include <date/tz.h>
#include <atomic>
#include <mutex>
#include <sstream>
#include <rapidjson/stringbuffer.h>
#include <rapidjson/writer.h>

@implementation TMRoutingCancellation {
    std::atomic_bool _cancelled;
}
- (instancetype)init {
    self = [super init];
    if (self) { _cancelled.store(false); }
    return self;
}
- (void)cancel { _cancelled.store(true, std::memory_order_relaxed); }
- (BOOL)cancelled { return _cancelled.load(std::memory_order_relaxed); }
@end

@implementation TMOfflineRouter {
    std::unique_ptr<valhalla::baldr::GraphReader> _reader;
    std::unique_ptr<valhalla::tyr::actor_t> _actor;
}

- (instancetype)initWithConfiguration:(NSString *)configuration
                   timezoneDirectory:(NSString *)timezoneDirectory
                               error:(NSError **)error {
    self = [super init];
    if (!self) { return nil; }
    try {
        if ([NSThread isMainThread]) { throw std::runtime_error("Routing must run off the main thread."); }
        std::stringstream input(configuration.UTF8String);
        boost::property_tree::ptree config;
        boost::property_tree::read_json(input, config);
        if (!config.get<std::string>("mjolnir.tile_url", "").empty()) {
            throw std::runtime_error("Remote graph tiles are not supported.");
        }
        static std::once_flag timezoneOnce;
        std::call_once(timezoneOnce, [&] { date::set_install(timezoneDirectory.UTF8String); });
        _reader = std::make_unique<valhalla::baldr::GraphReader>(config.get_child("mjolnir"));
        _actor = std::make_unique<valhalla::tyr::actor_t>(config, *_reader, true);
        return self;
    } catch (const std::exception &failure) {
        if (error) {
            *error = [NSError errorWithDomain:@"TimeMasterRouting" code:1 userInfo:@{
                NSLocalizedDescriptionKey: [NSString stringWithUTF8String:failure.what()] ?: @"Could not open the offline routing graph."
            }];
        }
        return nil;
    }
}

- (NSString *)routeWithRequest:(NSString *)request
                 cancellation:(TMRoutingCancellation *)cancellation
                        error:(NSError **)error {
    @synchronized (self) {
        __block NSString *result = nil;
        __block NSError *failure = nil;
        dispatch_semaphore_t finished = dispatch_semaphore_create(0);
        NSThread *worker = [[NSThread alloc] initWithBlock:^{
            @autoreleasepool {
                try {
                    const std::function<void()> interrupt = [cancellation] {
                        if (cancellation.cancelled) { throw std::runtime_error("Routing cancelled."); }
                    };
                    interrupt();
                    valhalla::Api api;
                    std::string response = self->_actor->route(request.UTF8String, &interrupt, &api);
                    rapidjson::StringBuffer metadata;
                    rapidjson::Writer<rapidjson::StringBuffer> writer(metadata);
                    writer.StartArray();
                    if (api.trip().routes_size() > 0) {
                        for (const auto &leg : api.trip().routes(0).legs()) {
                            writer.StartArray();
                            for (const auto &node : leg.node()) {
                                if (!node.has_edge()) { continue; }
                                const auto &edge = node.edge();
                                writer.StartArray();
                                writer.Uint64(edge.way_id());
                                writer.Double(edge.length_km() * 1000.0);
                                writer.Int(edge.road_class());
                                writer.EndArray();
                            }
                            writer.EndArray();
                        }
                    }
                    writer.EndArray();
                    if (response.empty() || response.back() != '}') {
                        throw std::runtime_error("The offline router returned invalid JSON.");
                    }
                    response.pop_back();
                    response.append(",\"tm_edges\":");
                    response.append(metadata.GetString(), metadata.GetSize());
                    response.push_back('}');
                    interrupt();
                    result = [[NSString alloc] initWithBytes:response.data() length:response.size() encoding:NSUTF8StringEncoding];
                    if (!result) { throw std::runtime_error("The offline router returned invalid text."); }
                } catch (const std::exception &exception) {
                    failure = [NSError errorWithDomain:@"TimeMasterRouting" code:cancellation.cancelled ? NSUserCancelledError : 2 userInfo:@{
                        NSLocalizedDescriptionKey: [NSString stringWithUTF8String:exception.what()] ?: @"Could not calculate an offline route."
                    }];
                } catch (...) {
                    failure = [NSError errorWithDomain:@"TimeMasterRouting" code:3 userInfo:@{NSLocalizedDescriptionKey: @"The offline routing engine failed."}];
                }
                dispatch_semaphore_signal(finished);
            }
        }];
        worker.name = @"TimeMaster offline routing";
        worker.stackSize = 16 * 1024 * 1024;
        worker.qualityOfService = NSQualityOfServiceUserInitiated;
        @try {
            [worker start];
            dispatch_semaphore_wait(finished, DISPATCH_TIME_FOREVER);
        } @catch (NSException *exception) {
            failure = [NSError errorWithDomain:@"TimeMasterRouting" code:4 userInfo:@{
                NSLocalizedDescriptionKey: exception.reason ?: @"Could not start the offline routing worker."
            }];
        }
        if (failure && error) { *error = failure; }
        return result;
    }
}
@end
