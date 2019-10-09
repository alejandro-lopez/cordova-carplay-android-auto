// copyright 2019 by Mike Nelson, beweb
// open source by MIT license terms

#import "CordovaCarplayPlugin.h"
#import <Cordova/CDV.h>
#import <AVFoundation/AVFoundation.h>
#import <MediaPlayer/MediaPlayer.h>

@implementation CordovaCarplayPlugin

static NSString* currentCallbackId;
static CordovaCarplayPlugin* carplayPlugin;
static void (^currentCompletionHandler)(NSError *);
static NSMutableArray *mediaItems;

+ (CordovaCarplayPlugin *) carplayPlugin {
    return carplayPlugin;
}

- (void)pluginInitialize {
    // called automatically by cordova
    NSLog(@"Starting carplay plugin");
    carplayPlugin = self;
    mediaItems = [NSMutableArray new];
}

- (void)setSingleMediaItem:(CDVInvokedUrlCommand*)command{
    // called by js to set up media items and register callback which will handle all the carplay events
    NSLog(@"CordovaCarplayPlugin - setSingleMediaItem called");
    NSString* mediaItemsJson = [NSString stringWithFormat:@"%@", [command.arguments objectAtIndex:0]];
    NSData* jsonData = [mediaItemsJson dataUsingEncoding:NSUTF8StringEncoding];
    
    NSError *jsonError;
    id allKeys = [NSJSONSerialization JSONObjectWithData:jsonData options:NSJSONWritingPrettyPrinted error:&jsonError];
    
    for (int i=0; i<[allKeys count]; i++) {
        NSDictionary *arrayResult = [allKeys objectAtIndex:i];
        NSLog(@"title=%@",[arrayResult objectForKey:@"title"]);
        NSLog(@"subtitle=%@",[arrayResult objectForKey:@"subtitle"]);
        
        MPContentItem* item = [[MPContentItem alloc] initWithIdentifier:[arrayResult objectForKey:@"id"]];
        item.title = [arrayResult objectForKey:@"title"];
        item.subtitle = [arrayResult objectForKey:@"subtitle"];
        item.playable = YES;
        mediaItems[i] = item;
    }
}

- (void)setMediaItems:(CDVInvokedUrlCommand*)command{
    // called by js to set up media items and register callback which will handle all the carplay events
    NSLog(@"CordovaCarplayPlugin - registerMediaItems called");
    NSString* mediaItemsJson = [NSString stringWithFormat:@"%@", [command.arguments objectAtIndex:0]];
    NSData* jsonData = [mediaItemsJson dataUsingEncoding:NSUTF8StringEncoding];
    
    NSError *jsonError;
    id allKeys = [NSJSONSerialization JSONObjectWithData:jsonData options:NSJSONWritingPrettyPrinted error:&jsonError];
    
    for (int i=0; i<[allKeys count]; i++) {
        NSDictionary *arrayResult = [allKeys objectAtIndex:i];
        NSLog(@"title=%@",[arrayResult objectForKey:@"title"]);
        NSLog(@"subtitle=%@",[arrayResult objectForKey:@"subtitle"]);
        
        MPContentItem* item = [[MPContentItem alloc] initWithIdentifier:[arrayResult objectForKey:@"id"]];
        item.title = [arrayResult objectForKey:@"title"];
        item.subtitle = [arrayResult objectForKey:@"subtitle"];
        item.playable = YES;
        mediaItems[i] = item;
    }
}

- (void)registerHandler:(CDVInvokedUrlCommand*)command{
    // called by js to set up media items and register callback which will handle all the carplay events
    NSLog(@"CordovaCarplayPlugin - registerHandler");

    // keep callback
    currentCallbackId = command.callbackId;
    
    [self invokeCallback:@"registerHandlerDone" param:@""];
}
    
- (int)requestItemCount{
    // called by carplay
    int itemCount = (int)mediaItems.count;
    return itemCount;
}

- (MPContentItem*)requestItemMetaDataByIndex:(int)trackIndex{
    // called by carplay
    return mediaItems[trackIndex];
}

- (void)finishedPlaying:(CDVInvokedUrlCommand*)command{
    NSLog(@"CordovaCarplayPlugin - finishedPlaying");
    // not needed actually
    //if (currentCompletionHandler!=nil){
   //     currentCompletionHandler(nil);
   //     currentCompletionHandler = nil;
   // }
}

- (void)handlePlayback:(int)trackIndex completionHandler:(void (^)(NSError *))completionHandler{
    NSLog(@"CordovaCarplayPlugin - carplayInitPlayback - called");
    NSString* info = @"carplay is starting playback of an audio track";

//    if (currentCompletionHandler!=nil){
//        // complete the last item otherwise it will crash
  //      currentCompletionHandler(nil);
    //    currentCompletionHandler = nil;
//    }
 //   // set the new completion callback
 //   currentCompletionHandler = completionHandler;
    
    // get the item we picked
    MPContentItem* item = mediaItems[trackIndex];
    info = item.title;  //identifier
    
    // play
    [self invokeCallback:@"handlePlayback" param:info];
    
    // tell carplay we are all good, ready to play
    completionHandler(nil);
    
   // [MPRemoteCommandCenter sharedCommandCenter]
    //(MPNowPlayingInfoCenter *)defaultCenter = [MPNowPlayingInfoCenter];
    //defaultCenter.
    
    // Workaround to make the Now Playing working on the simulator:
#if TARGET_OS_SIMULATOR
[[UIApplication sharedApplication] endReceivingRemoteControlEvents];
[[UIApplication sharedApplication] beginReceivingRemoteControlEvents];
#endif
    
//   NSDictionary *message = @{
//               @"action": @"handlePlayback",
 //              @"param": info
  //              };
 //     CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:message];
 //   CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:"hey"];
 //   [pluginResult setKeepCallback:[NSNumber numberWithBool:YES]];
  //  [self.commandDelegate sendPluginResult:pluginResult callbackId:currentCallbackId];
}

- (void)invokeCallback:(NSString*)action param:(NSString*)param{
    NSLog(@"CordovaCarplayPlugin - invokeCallback - called");  
   NSDictionary *message = @{
               @"action": action,
               @"param": param 
            };
      CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:message];
 //   CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:"hey"];
    [pluginResult setKeepCallback:[NSNumber numberWithBool:YES]];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:currentCallbackId];
}

@end

// https://blog.fethica.com/add-carplay-support-to-swiftradio/
// https://developer.apple.com/documentation/sirikit/media?language=objc
// https://developer.apple.com/documentation/mediaplayer/mpnowplayinginfocenter?language=objc
// https://developer.apple.com/documentation/mediaplayer/mpremotecommandcenter?language=objc

