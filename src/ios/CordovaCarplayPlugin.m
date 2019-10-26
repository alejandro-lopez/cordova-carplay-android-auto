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
//static NSMutableArray *mediaItems;
static NSMutableDictionary *mediaItems;
static NSMutableDictionary *completionHandlers;

+ (CordovaCarplayPlugin *) carplayPlugin {
    return carplayPlugin;
}

- (void)pluginInitialize {
    // called automatically by cordova
    NSLog(@"Starting carplay plugin");
    carplayPlugin = self;
    //mediaItems = [NSMutableArray new];
    mediaItems = [NSMutableDictionary new];
    
    MPPlayableContentManager *contentManager = [MPPlayableContentManager sharedContentManager];
    contentManager.dataSource = self;
    contentManager.delegate = self;
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [[UIApplication sharedApplication] beginReceivingRemoteControlEvents];
        
    });
  
}

- (void)setMediaItems:(CDVInvokedUrlCommand*)command{
    // called by js to set up media items and register callback which will handle all the carplay events
    NSLog(@"CordovaCarplayPlugin - registerMediaItems called");
    NSString* mediaItemsJson = [NSString stringWithFormat:@"%@", [command.arguments objectAtIndex:0]];
    NSData* jsonData = [mediaItemsJson dataUsingEncoding:NSUTF8StringEncoding];
    
    NSError *jsonError;
    id allKeys = [NSJSONSerialization JSONObjectWithData:jsonData options:NSJSONWritingPrettyPrinted error:&jsonError];
    
    [MPPlayableContentManager.sharedContentManager beginUpdates];
    for (int i=0; i<[allKeys count]; i++) {
        NSDictionary *arrayResult = [allKeys objectAtIndex:i];
        NSLog(@"title=%@",[arrayResult objectForKey:@"title"]);
        NSLog(@"subtitle=%@",[arrayResult objectForKey:@"subtitle"]);
        NSString* itemKey = [arrayResult objectForKey:@"itemKey"];
        // itemKey is the index position eg "0:1"
        BOOL isRemove = [[arrayResult valueForKey:@"isRemove"] boolValue];
        
        if (isRemove){
            [mediaItems removeObjectForKey:itemKey];
        }else{
            MPContentItem* item = [[MPContentItem alloc] initWithIdentifier:[arrayResult objectForKey:@"id"]];
            item.title = [arrayResult objectForKey:@"title"];
            item.subtitle = [arrayResult objectForKey:@"subtitle"];
    //        NSString* imageUrl = [arrayResult objectForKey:@"artworkUrl"];
    //        if ([imageUrl length] > 0){
    //            UIImage *artworkImage = [UIImage imageWithData:[NSData dataWithContentsOfURL:imageUrl]];
    //            if(artworkImage) {
    //                MPMediaItemArtwork *albumArt = [[MPMediaItemArtwork alloc] initWithImage: artworkImage];
    //                item.artwork = albumArt;
    //            }
    //        }
            BOOL isContainer = [[arrayResult valueForKey:@"isContainer"] boolValue];
            BOOL isPlayable = [[arrayResult valueForKey:@"isPlayable"] boolValue];
            item.container = isContainer;
            item.playable = isPlayable;
            //item.playable = YES;
           // item.streamingContent = YES;
            //mediaItems[i] = item;
            
            // every item added should have a unique key anyway
            [mediaItems setValue:item forKey:itemKey];
        }
            
    }
    [MPPlayableContentManager.sharedContentManager endUpdates];
    
    // refresh
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [MPPlayableContentManager.sharedContentManager reloadData];
    });
    //[[MPPlayableContentManager sharedContentManager]reloadData];
}

- (void)registerHandler:(CDVInvokedUrlCommand*)command{
    // called by js to set up media items and register callback which will handle all the carplay events
    NSLog(@"CordovaCarplayPlugin - registerHandler");

    // keep callback id
    currentCallbackId = command.callbackId;
    
    // register handlers for now playing buttons
    // Get the shared command center.
//    MPRemoteCommandCenter *commandCenter = [MPRemoteCommandCenter sharedCommandCenter];
//
//    // Add a handler for the play command.
//    [commandCenter.playCommand addTargetWithHandler:^MPRemoteCommandHandlerStatus(MPRemoteCommandEvent * _Nonnull event) {
//        if (YES) {
//            [self invokeCallback:@"playCommand" param:@""];
//            return MPRemoteCommandHandlerStatusSuccess;
//        }
//        return MPRemoteCommandHandlerStatusCommandFailed;
//    }];
//    [commandCenter.likeCommand addTargetWithHandler:^MPRemoteCommandHandlerStatus(MPRemoteCommandEvent * _Nonnull event) {
//        [self invokeCallback:@"likeCommand" param:@""];
//        return MPRemoteCommandHandlerStatusSuccess;
//    }];
//    [commandCenter.dislikeCommand addTargetWithHandler:^MPRemoteCommandHandlerStatus(MPRemoteCommandEvent * _Nonnull event) {
//        [self invokeCallback:@"dislikeCommand" param:@""];
//        return MPRemoteCommandHandlerStatusSuccess;
//    }];
//    [commandCenter.ratingCommand addTargetWithHandler:^MPRemoteCommandHandlerStatus(MPRemoteCommandEvent * _Nonnull event) {
//        [self invokeCallback:@"ratingCommand" param:@""];
//        return MPRemoteCommandHandlerStatusSuccess;
//    }];
//    [commandCenter.ratingCommand setEnabled:YES];
//    [commandCenter.dislikeCommand setEnabled:YES];
//    [commandCenter.nextTrackCommand setEnabled:YES];
//
//    [commandCenter.enableLanguageOptionCommand addTargetWithHandler:^MPRemoteCommandHandlerStatus(MPRemoteCommandEvent * _Nonnull event) {
//        [self invokeCallback:@"ratingCommand" param:@""];
//        return MPRemoteCommandHandlerStatusSuccess;
//    }];
//    [commandCenter.skipForwardCommand addTargetWithHandler:^MPRemoteCommandHandlerStatus(MPRemoteCommandEvent * _Nonnull event) {
//        [self invokeCallback:@"ratingCommand" param:@""];
//        return MPRemoteCommandHandlerStatusSuccess;
//    }];
//    [commandCenter.skipBackwardCommand addTargetWithHandler:^MPRemoteCommandHandlerStatus(MPRemoteCommandEvent * _Nonnull event) {
//        [self invokeCallback:@"ratingCommand" param:@""];
//        return MPRemoteCommandHandlerStatusSuccess;
//    }];
//    [commandCenter.playCommand addTargetWithHandler:^MPRemoteCommandHandlerStatus(MPRemoteCommandEvent * _Nonnull event) {
//        [self invokeCallback:@"ratingCommand" param:@""];
//        return MPRemoteCommandHandlerStatusSuccess;
//    }];
//    [commandCenter.stopCommand addTargetWithHandler:^MPRemoteCommandHandlerStatus(MPRemoteCommandEvent * _Nonnull event) {
//        [self invokeCallback:@"ratingCommand" param:@""];
//        return MPRemoteCommandHandlerStatusSuccess;
//    }];
//    [commandCenter.pauseCommand addTargetWithHandler:^MPRemoteCommandHandlerStatus(MPRemoteCommandEvent * _Nonnull event) {
//        [self invokeCallback:@"ratingCommand" param:@""];
//        return MPRemoteCommandHandlerStatusSuccess;
//    }];
//    [commandCenter.bookmarkCommand addTargetWithHandler:^MPRemoteCommandHandlerStatus(MPRemoteCommandEvent * _Nonnull event) {
//        [self invokeCallback:@"bookmarkCommand" param:@""];
//        return MPRemoteCommandHandlerStatusSuccess;
//    }];
//    [commandCenter.nextTrackCommand addTargetWithHandler:^MPRemoteCommandHandlerStatus(MPRemoteCommandEvent * _Nonnull event) {
//        [self invokeCallback:@"nextTrackCommand" param:@""];
//        return MPRemoteCommandHandlerStatusSuccess;
//    }];
//    [commandCenter.previousTrackCommand addTargetWithHandler:^MPRemoteCommandHandlerStatus(MPRemoteCommandEvent * _Nonnull event) {
//        [self invokeCallback:@"previousTrackCommand" param:@""];
//        return MPRemoteCommandHandlerStatusSuccess;
//    }];
//    [commandCenter.togglePlayPauseCommand addTargetWithHandler:^MPRemoteCommandHandlerStatus(MPRemoteCommandEvent * _Nonnull event) {
//        [self invokeCallback:@"togglePlayPauseCommand" param:@""];
//        return MPRemoteCommandHandlerStatusSuccess;
//    }];
//    [commandCenter.changeRepeatModeCommand addTargetWithHandler:^MPRemoteCommandHandlerStatus(MPRemoteCommandEvent * _Nonnull event) {
//        [self invokeCallback:@"ratingCommand" param:@""];
//        return MPRemoteCommandHandlerStatusSuccess;
//    }];
//    [commandCenter.changeShuffleModeCommand addTargetWithHandler:^MPRemoteCommandHandlerStatus(MPRemoteCommandEvent * _Nonnull event) {
//        [self invokeCallback:@"ratingCommand" param:@""];
//        return MPRemoteCommandHandlerStatusSuccess;
//    }];


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
    // call this from js to clear the now playing info and return the user to the carplay item list screen
    NSLog(@"CordovaCarplayPlugin - finishedPlaying");
    
    //To clear the now playing info center dictionary, set it to nil.
    [[MPNowPlayingInfoCenter defaultCenter] setNowPlayingInfo:nil];
   // MPNowPlayingInfoMediaTypeNone
  
    // also update content manager to hide playing icon
    MPPlayableContentManager.sharedContentManager.nowPlayingIdentifiers = @[ ];
    
    // not needed actually
    //if (currentCompletionHandler!=nil){
    //     currentCompletionHandler(nil);
    //     currentCompletionHandler = nil;
    // }
}

// https://forums.developer.apple.com/thread/112101
//[[MPPlayableContentManager sharedContentManager]reloadData];

// implementation of MPPlayableContentDataSource
// plays the media item
// called by carplay when user taps a media item
- (void)playableContentManager:(MPPlayableContentManager *)contentManager initiatePlaybackOfContentItemAtIndexPath:(NSIndexPath *)indexPath
             completionHandler:(void (^)(NSError *))completionHandler{
    
    int index = (int)[indexPath indexAtPosition:0];
    NSString* itemKey = [indexPath indexPathString];
    NSLog(@"initiatePlaybackOfContentItemAtIndexPath IndexPath itemKey: %@", itemKey );
    
    // if playable then play else do another callback eg expand
    // get the item we picked
    //MPContentItem* item = mediaItems[index];
    MPContentItem* item = [mediaItems objectForKey:itemKey];
    if (item==nil){
        NSLog(@"initiatePlaybackOfContentItemAtIndexPath item has been removed: %@", itemKey );
        
        // tell carplay we are all good, ready to play
        completionHandler(nil);
        
    }else{
        NSLog(@"initiatePlaybackOfContentItemAtIndexPath item found: %@", itemKey );
        NSString *info = item.identifier;
        
        // update now playing
        NSMutableDictionary *songInfo = [[NSMutableDictionary alloc] init];
        //  MPMediaItemArtwork *albumArt = [[MPMediaItemArtwork alloc] initWithImage:[UIImage imageNamed:@"series_placeholder"]];
        //[songInfo setObject:albumArt forKey:MPMediaItemPropertyArtwork];
        [songInfo setObject:item.title forKey:MPMediaItemPropertyTitle];
        [songInfo setObject:item.subtitle forKey:MPMediaItemPropertyArtist];
        [MPNowPlayingInfoCenter.defaultCenter setNowPlayingInfo:songInfo];
        // also update content manager to show playing icon
        MPPlayableContentManager.sharedContentManager.nowPlayingIdentifiers = @[ info ];
    
        
        //      [[UIApplication delegate] fooBar];
        // Workaround to make the Now Playing working on the simulator:
    //#if TARGET_OS_SIMULATOR
        dispatch_async(dispatch_get_main_queue(), ^{
            [[UIApplication sharedApplication] endReceivingRemoteControlEvents];
            [[UIApplication sharedApplication] beginReceivingRemoteControlEvents];
        });
    //#endif
        
        // tell carplay we are all good, ready to play
        completionHandler(nil);

        // play
        [self invokeCallback:@"handlePlayback" param:info];
    }
}

// implementation of MPPlayableContentDataSource or MPPlayableContentDelegate
// not sure what this is for, not currently in use
// seems to be called by carplay only once after user taps the first media item, happens after the play message
- (void)beginLoadingChildItemsAtIndexPath:(NSIndexPath *)indexPath
                        completionHandler:(void (^)(NSError *))completionHandler{
    
    int index = (int)[indexPath indexAtPosition:0];
    NSLog(@"beginLoadingChildItemsAtIndexPath1: %@", [indexPath indexPathString]);
    
    // call out to js to load the stuff, then call the completion handler
    // we need this!!!
    // this is where we load the emails for the given account, and switch accounts too, since there is nowhere else to do this
    
    completionHandler(nil);
}

// implementation of MPPlayableContentDataSource or MPPlayableContentDelegate
// called by carplay when user browses a media list
// supplies number of child items in a list or sublist
- (NSInteger)numberOfChildItemsAtIndexPath:(NSIndexPath *)indexPath{
    int index = (int)[indexPath indexAtPosition:0];
   // int count = [CordovaCarplayPlugin.carplayPlugin requestItemCount];
    NSString* itemKey =[indexPath indexPathString];

    [self invokeCallback:@"queriedChildItems" param:[indexPath indexPathString]];

    NSUInteger childLevel = indexPath.length+1;
    
    //int count = (int)mediaItems.count;
    // eg
    // "0" - acc1
    // "1" - acc2
    // "0:0" - e1
    // "0:1" - e2
    // "0:2" - e3
    // "0:0:0" - a sub item of "0:0"
    // "0:0:1" - a sub item
    int count = 0;
    for (NSString* key in mediaItems){
        NSArray *items = [key componentsSeparatedByString:@":"];
        NSUInteger len = [items count];
        if (childLevel == len) {
            if (indexPath.length==0 || [key hasPrefix:itemKey]){
                count++;
            }
        }
    }

    NSLog(@"numberOfChildItemsAtIndexPath: '%@' is %i", itemKey, count);

    return count;
}

// implementation of MPPlayableContentDataSource or MPPlayableContentDelegate
// returns a media item given the index path parameter
// called by carplay when user taps a media item
// supplies media item metadata (title, subtitle) to cparplay for the given array index
- (nullable MPContentItem *)contentItemAtIndexPath:(nonnull NSIndexPath *)indexPath {
    // MPContentItem* item = [[MPContentItem alloc] initWithIdentifier:@"Email 1"];
    // item.title = @"Subject: my email test";
    // item.subtitle = @"From: Mike Nelson";
    // item.playable = YES;
    
    int index = (int)[indexPath indexAtPosition:0];
    NSString* itemKey = [indexPath indexPathString];
    
    NSLog(@"contentItemAtIndexPath itemKey: %@", itemKey );
    
    // if playable then play else do another callback eg expand
    // get the item we picked
    //MPContentItem* item = mediaItems[index];
    MPContentItem* item = [mediaItems objectForKey:itemKey];
    
    //streamingContent
    //container
    return item;
}

@end

@implementation NSIndexPath (DBExtensions)
- (NSString *)indexPathString;
{
    NSMutableString *indexString = [NSMutableString stringWithString:@""];
    if (self.length>0){
        indexString = [NSMutableString stringWithFormat:@"%lu",[self indexAtPosition:0]];
        for (int i = 1; i < self.length; i++){
            [indexString appendString:[NSString stringWithFormat:@":%lu", [self indexAtPosition:i]]];
        }
    }
    return indexString;
}

-(void)dealloc {
   // [[UIApplication sharedApplication] endReceivingRemoteControlEvents];
   // [[NSNotificationCenter defaultCenter] removeObserver:self name:@"receivedEvent" object:nil];
}

@end

// https://blog.fethica.com/add-carplay-support-to-swiftradio/
// https://developer.apple.com/documentation/sirikit/media?language=objc
// https://developer.apple.com/documentation/mediaplayer/mpnowplayinginfocenter?language=objc
// https://developer.apple.com/documentation/mediaplayer/mpremotecommandcenter?language=objc

// avoid remotecontrolevents
// https://stackoverflow.com/questions/23848928/uiapplication-beginreceivingremotecontrolevents-causes-music-app-to-take-over-a
