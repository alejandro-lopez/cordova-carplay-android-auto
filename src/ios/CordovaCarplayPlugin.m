// copyright 2019 by Mike Nelson, beweb
// open source by MIT license terms

#import "CordovaCarplayPlugin.h"
#import <Cordova/CDV.h>
#import <AVFoundation/AVFoundation.h>
#import <MediaPlayer/MediaPlayer.h>
@interface NSIndexPath (DBExtensions)
- (NSString *)indexPathString;
@end


@implementation CordovaCarplayPlugin

static NSString* currentCallbackId;
static CordovaCarplayPlugin* carplayPlugin;
static void (^currentCompletionHandler)(NSError *);
static NSMutableArray *mediaItems;
//static NSMutableDictionary *mediaItems;
static NSMutableDictionary *completionHandlers;

+ (CordovaCarplayPlugin *) carplayPlugin {
    return carplayPlugin;
}

- (void)pluginInitialize {
    // called automatically by cordova
    NSLog(@"Starting carplay plugin");
    carplayPlugin = self;
    mediaItems = [NSMutableArray new];
    //mediaItems = [NSMutableDictionary new];
    
    MPPlayableContentManager *contentManager = [MPPlayableContentManager sharedContentManager];
    contentManager.dataSource = self;
    contentManager.delegate = self;
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
       // item.playable = YES;
        BOOL isContainer = [[arrayResult valueForKey:@"isContainer"] boolValue];
        item.container = isContainer;
        item.playable = YES;  //!item.container;
       // item.streamingContent = YES;
        mediaItems[i] = item;
    }
    
    // refresh
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [MPPlayableContentManager.sharedContentManager reloadData];
    });
    //[[MPPlayableContentManager sharedContentManager]reloadData];
}

- (void)registerHandler:(CDVInvokedUrlCommand*)command{
    // called by js to set up media items and register callback which will handle all the carplay events
    NSLog(@"CordovaCarplayPlugin - registerHandler");

    // keep callback
    currentCallbackId = command.callbackId;
    
    [self invokeCallback:@"registerHandlerDone" param:@""];
}

// send a cordova callback / event to javascript land
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

- (void)reloadMediaItems:(CDVInvokedUrlCommand*)command{
    NSLog(@"CordovaCarplayPlugin - reload");
    [[MPPlayableContentManager sharedContentManager]reloadData];
}

- (void)finishedPlaying:(CDVInvokedUrlCommand*)command{
    NSLog(@"CordovaCarplayPlugin - finishedPlaying");
    // not needed actually
    //if (currentCompletionHandler!=nil){
    //     currentCompletionHandler(nil);
    //     currentCompletionHandler = nil;
    // }
}

// https://forums.developer.apple.com/thread/112101

//[[MPPlayableContentManager sharedContentManager]reloadData];



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
    info = item.identifier;
    
    // play
    [self invokeCallback:@"handlePlayback" param:info];
    
    //[MPRemoteCommandCenter sharedCommandCenter]
    
    
    // tell carplay we are all good, ready to play
    completionHandler(nil);
    
    // completionhandler of a container may be useful if it is called before getchilditemcount, as js could insert the items
    
   // return;
    
  //  dispatch_async(dispatch_get_main_queue(), ^{
        
 //       [[UIApplication sharedApplication] beginReceivingRemoteControlEvents];
       // MPNowPlayingInfoCenter *nowPlaying = [MPNowPlayingInfoCenter defaultCenter];
        NSMutableDictionary *songInfo = [[NSMutableDictionary alloc] init];
      //  MPMediaItemArtwork *albumArt = [[MPMediaItemArtwork alloc] initWithImage:[UIImage imageNamed:@"series_placeholder"]];
        [songInfo setObject:item.title forKey:MPMediaItemPropertyTitle];
        [songInfo setObject:item.subtitle forKey:MPMediaItemPropertyArtist];
        //[songInfo setObject:albumArt forKey:MPMediaItemPropertyArtwork];
        
        [[MPNowPlayingInfoCenter defaultCenter] setNowPlayingInfo:songInfo];
        

      
        
        //      [[UIApplication delegate] fooBar];
        
            // Workaround to make the Now Playing working on the simulator:
        #if TARGET_OS_SIMULATOR
   //             [[UIApplication sharedApplication] endReceivingRemoteControlEvents];
     //           [[UIApplication sharedApplication] beginReceivingRemoteControlEvents];
        
        #endif
        
  //  });
    
//   NSDictionary *message = @{
//               @"action": @"handlePlayback",
 //              @"param": info
  //              };
 //     CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:message];
 //   CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:"hey"];
 //   [pluginResult setKeepCallback:[NSNumber numberWithBool:YES]];
  //  [self.commandDelegate sendPluginResult:pluginResult callbackId:currentCallbackId];
}


// implementation of MPPlayableContentDataSource
// plays the media item
// called by carplay when user taps a media item
- (void)playableContentManager:(MPPlayableContentManager *)contentManager
initiatePlaybackOfContentItemAtIndexPath:(NSIndexPath *)indexPath
             completionHandler:(void (^)(NSError *))completionHandler{
    
    int index = (int)[indexPath indexAtPosition:0];
    NSLog(@"contentItemAtIndexPath: %i", index);
    NSLog(@"IndexPath: %i %@", index, [indexPath indexPathString]);
    
    // if playable then play else do another callback eg expand
    [CordovaCarplayPlugin.carplayPlugin handlePlayback:index completionHandler:completionHandler];
    
    //completionHandler(nil);
}

// implementation of MPPlayableContentDataSource or MPPlayableContentDelegate
// not sure what this is for, not currently in use
// seems to be called by carplay only once after user taps the first media item, happens after the play message
- (void)beginLoadingChildItemsAtIndexPath:(NSIndexPath *)indexPath
                        completionHandler:(void (^)(NSError *))completionHandler{
    
    int index = (int)[indexPath indexAtPosition:0];
    NSLog(@"beginLoadingChildItemsAtIndexPath1: %i", index);
    NSLog(@"IndexPath: %i %@", index, [indexPath indexPathString]);
    
    // call out to js to load the stuff, then call the completion handler
    // we need this!!!
    // this is where we load the emails for the given account, and switch accounts too, since there is nowhere else to do this
    
    
    completionHandler(nil);
}


// implementation of MPPlayableContentDataSource or MPPlayableContentDelegate
// called by carplay when user browses a media list
// supplies number of child items in a list or sublist
- (NSInteger)numberOfChildItemsAtIndexPath:(NSIndexPath *)indexPath{
    NSLog(@"numberOfChildItemsAtIndexPath");
    int index = (int)[indexPath indexAtPosition:0];
    NSLog(@"IndexPath: %i %@", index, [indexPath indexPathString]);
   // int count = [CordovaCarplayPlugin.carplayPlugin requestItemCount];

    [self invokeCallback:@"queriedChildItems" param:[indexPath indexPathString]];

    int count = (int)mediaItems.count;
    
    return count;
}

// implementation of MPPlayableContentDataSource or MPPlayableContentDelegate
// returns a media item given the index path parameter
// called by carplay when user taps a media item
// supplies media item metadata (title, subtitle) to cparplay for the given array index
- (nullable MPContentItem *)contentItemAtIndexPath:(nonnull NSIndexPath *)indexPath {
    NSLog(@"contentItemAtIndexPath");
    
    // MPContentItem* item = [[MPContentItem alloc] initWithIdentifier:@"Email 1"];
    // item.title = @"Subject: my email test";
    // item.subtitle = @"From: Mike Nelson";
    // item.playable = YES;
    
    int index = (int)[indexPath indexAtPosition:0];
    MPContentItem* item = mediaItems[index];
    
    NSLog(@"contentItemAtIndexPath %@", [indexPath indexPathString]);
    
    //streamingContent
    //container
    return item;
}

@end

@implementation NSIndexPath (DBExtensions)
- (NSString *)indexPathString;
{
    NSMutableString *indexString = [NSMutableString stringWithFormat:@"%lu",[self indexAtPosition:0]];
    for (int i = 1; i < [self length]; i++){
        [indexString appendString:[NSString stringWithFormat:@".%lu", [self indexAtPosition:i]]];
    }
    return indexString;
}
@end

// https://blog.fethica.com/add-carplay-support-to-swiftradio/
// https://developer.apple.com/documentation/sirikit/media?language=objc
// https://developer.apple.com/documentation/mediaplayer/mpnowplayinginfocenter?language=objc
// https://developer.apple.com/documentation/mediaplayer/mpremotecommandcenter?language=objc

