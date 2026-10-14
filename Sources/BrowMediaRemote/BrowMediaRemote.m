// Talks to the private MediaRemote framework. Loaded by Resources/brow-media.pl inside
// /usr/bin/perl, because since macOS 15.4 only Apple-signed processes may read now playing info.
#import <Foundation/Foundation.h>
#include <dlfcn.h>
#include <math.h>
#include <unistd.h>
#include "BrowMediaRemote.h"

typedef void (*MRRegisterFn)(dispatch_queue_t);
typedef void (*MRGetInfoFn)(dispatch_queue_t, void (^)(CFDictionaryRef));
typedef void (*MRGetClientFn)(dispatch_queue_t, void (^)(id));
typedef CFStringRef (*MRClientBundleFn)(id);
typedef Boolean (*MRSendCommandFn)(int, CFDictionaryRef);
typedef void (*MRSetElapsedFn)(double);

enum { kMRPlay = 0, kMRPause = 1, kMRTogglePlayPause = 2, kMRNextTrack = 4, kMRPreviousTrack = 5 };

static void *MediaRemote(void) {
    static void *handle;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        handle = dlopen("/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote", RTLD_LAZY);
    });
    return handle;
}

static void *Symbol(const char *name) {
    void *handle = MediaRemote();
    return handle ? dlsym(handle, name) : NULL;
}

/// Info dictionary keys are exported as CFString constants; fall back to the name itself.
static NSString *InfoKey(const char *name) {
    CFStringRef *constant = Symbol(name);
    return constant ? (__bridge NSString *)*constant : @(name);
}

static NSString *Serialize(NSDictionary *object) {
    if (![NSJSONSerialization isValidJSONObject:object]) return nil;
    NSData *data = [NSJSONSerialization dataWithJSONObject:object options:0 error:NULL];
    return data ? [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] : nil;
}

static void PrintLine(NSString *line) {
    static NSString *lastLine;
    if (!line || [line isEqualToString:lastLine]) return;
    lastLine = line;
    fprintf(stdout, "%s\n", line.UTF8String);
    fflush(stdout);
}

static NSDictionary *Convert(NSDictionary *info) {
    NSMutableDictionary *out = [NSMutableDictionary dictionary];
    NSDictionary *strings = @{ @"title": InfoKey("kMRMediaRemoteNowPlayingInfoTitle"),
                               @"artist": InfoKey("kMRMediaRemoteNowPlayingInfoArtist"),
                               @"album": InfoKey("kMRMediaRemoteNowPlayingInfoAlbum") };
    for (NSString *key in strings) {
        id value = info[strings[key]];
        if ([value isKindOfClass:NSString.class]) out[key] = value;
    }
    NSDictionary *numbers = @{ @"duration": InfoKey("kMRMediaRemoteNowPlayingInfoDuration"),
                               @"elapsed": InfoKey("kMRMediaRemoteNowPlayingInfoElapsedTime"),
                               @"playbackRate": InfoKey("kMRMediaRemoteNowPlayingInfoPlaybackRate") };
    for (NSString *key in numbers) {
        id value = info[numbers[key]];
        // Live streams report an infinite duration; JSON cannot carry NaN or Inf.
        if ([value isKindOfClass:NSNumber.class] && isfinite([value doubleValue])) out[key] = value;
    }
    id artwork = info[InfoKey("kMRMediaRemoteNowPlayingInfoArtworkData")];
    if ([artwork isKindOfClass:NSData.class]) out[@"artworkBase64"] = [artwork base64EncodedStringWithOptions:0];
    id timestamp = info[InfoKey("kMRMediaRemoteNowPlayingInfoTimestamp")];
    NSDate *measured = [timestamp isKindOfClass:NSDate.class] ? timestamp : [NSDate date];
    out[@"timestamp"] = @(measured.timeIntervalSince1970);
    return out;
}

NSString *brow_json_line(NSDictionary *info, NSString *bundleId) {
    NSMutableDictionary *out = [Convert(info) mutableCopy];
    if (bundleId) out[@"bundleId"] = bundleId;
    return Serialize(out);
}

static void Emit(void (^done)(void)) {
    MRGetInfoFn getInfo = Symbol("MRMediaRemoteGetNowPlayingInfo");
    MRGetClientFn getClient = Symbol("MRMediaRemoteGetNowPlayingClient");
    MRClientBundleFn clientBundle = Symbol("MRNowPlayingClientGetBundleIdentifier");
    if (!getInfo) { PrintLine(@"{}"); if (done) done(); return; }
    getInfo(dispatch_get_main_queue(), ^(CFDictionaryRef info) {
        if (!info) { PrintLine(@"{}"); if (done) done(); return; }
        NSDictionary *dictionary = (__bridge NSDictionary *)info;
        if (!getClient || !clientBundle) { PrintLine(brow_json_line(dictionary, nil)); if (done) done(); return; }
        getClient(dispatch_get_main_queue(), ^(id client) {
            CFStringRef bundle = client ? clientBundle(client) : NULL;
            PrintLine(brow_json_line(dictionary, (__bridge NSString *)bundle));
            if (done) done();
        });
    });
}

static void ExitOnStdinEOF(void) {
    static dispatch_source_t source;
    source = dispatch_source_create(DISPATCH_SOURCE_TYPE_READ, STDIN_FILENO, 0, dispatch_get_main_queue());
    dispatch_source_set_event_handler(source, ^{
        char buffer[256];
        if (read(STDIN_FILENO, buffer, sizeof buffer) <= 0) exit(0);
    });
    dispatch_resume(source);
}

void brow_stream(void) {
    if (!MediaRemote()) {
        fprintf(stderr, "brow-media: MediaRemote not available\n");
        exit(1);
    }
    MRRegisterFn registerFn = Symbol("MRMediaRemoteRegisterForNowPlayingNotifications");
    if (registerFn) registerFn(dispatch_get_main_queue());
    for (NSString *name in @[ @"kMRMediaRemoteNowPlayingInfoDidChangeNotification",
                              @"kMRMediaRemoteNowPlayingApplicationIsPlayingDidChangeNotification",
                              @"kMRMediaRemoteNowPlayingApplicationDidChangeNotification" ]) {
        [NSNotificationCenter.defaultCenter addObserverForName:name object:nil queue:NSOperationQueue.mainQueue
                                                    usingBlock:^(NSNotification *note) { Emit(nil); }];
    }
    // Watch stdin only after the first line is out, so a short-lived run still reports once.
    Emit(^{ ExitOnStdinEOF(); });
    CFRunLoopRun();
}

void brow_send(void) {
    const char *command = getenv("BROW_MR_COMMAND");
    const char *argument = getenv("BROW_MR_ARG");
    if (!command) { fprintf(stderr, "brow-media: BROW_MR_COMMAND not set\n"); return; }

    if (strcmp(command, "seek") == 0) {
        MRSetElapsedFn setElapsed = Symbol("MRMediaRemoteSetElapsedTime");
        if (setElapsed && argument) setElapsed(atof(argument));
    } else {
        int code = -1;
        if (strcmp(command, "play") == 0) code = kMRPlay;
        else if (strcmp(command, "pause") == 0) code = kMRPause;
        else if (strcmp(command, "toggle") == 0) code = kMRTogglePlayPause;
        else if (strcmp(command, "next") == 0) code = kMRNextTrack;
        else if (strcmp(command, "previous") == 0) code = kMRPreviousTrack;
        if (code < 0) { fprintf(stderr, "brow-media: unknown command %s\n", command); return; }
        MRSendCommandFn send = Symbol("MRMediaRemoteSendCommand");
        if (send) send(code, NULL);
    }
    // Give the XPC message a moment to leave before perl exits.
    CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.2, false);
}
