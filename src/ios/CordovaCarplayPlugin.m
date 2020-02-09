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
static NSMutableDictionary *thumbnails;
static bool isDebug = NO;

+ (CordovaCarplayPlugin *) carplayPlugin {
    return carplayPlugin;
}

- (void)pluginInitialize {
    // called automatically by cordova
    NSLog(@"Starting carplay plugin");
    carplayPlugin = self;
    //mediaItems = [NSMutableArray new];
    mediaItems = [NSMutableDictionary new];
    thumbnails = [NSMutableDictionary new];
    
    MPPlayableContentManager *contentManager = [MPPlayableContentManager sharedContentManager];
    contentManager.dataSource = self;
    contentManager.delegate = self;
    
    // make calls to these component to get them warmed up...
    
    //To clear the now playing info center dictionary, set it to nil.
    [[MPNowPlayingInfoCenter defaultCenter] setNowPlayingInfo:nil];
    
    // also update content manager to hide playing icon
    MPPlayableContentManager.sharedContentManager.nowPlayingIdentifiers = @[ ];
    
    MPRemoteCommandCenter *commandCenter = [MPRemoteCommandCenter sharedCommandCenter];
    // Add a handler just for one command to ensure this is connected
    [commandCenter.likeCommand addTargetWithHandler:^MPRemoteCommandHandlerStatus(MPRemoteCommandEvent * _Nonnull event) {
        [self invokeCallback:@"likeCommand"];
        return MPRemoteCommandHandlerStatusSuccess;
    }];
    
    
    // dont use beginReceivingRemoteControlEvents as it tends to cause fakiness
  //  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
 //       [[UIApplication sharedApplication] beginReceivingRemoteControlEvents];
        
   // });
}

- (void)setMediaItems:(CDVInvokedUrlCommand*)command{
    // called by js to set up any number of media items
    NSLog(@"CordovaCarplayPlugin - registerMediaItems called");
    NSString* mediaItemsJson = [NSString stringWithFormat:@"%@", [command.arguments objectAtIndex:0]];
    NSData* jsonData = [mediaItemsJson dataUsingEncoding:NSUTF8StringEncoding];
    
    NSError *jsonError;
    id allKeys = [NSJSONSerialization JSONObjectWithData:jsonData options:NSJSONWritingPrettyPrinted error:&jsonError];
    
    [MPPlayableContentManager.sharedContentManager beginUpdates];
    for (int i=0; i<[allKeys count]; i++) {
        NSDictionary *arrayResult = [allKeys objectAtIndex:i];
        //NSLog(@"title=%@",[arrayResult objectForKey:@"title"]);
        //NSLog(@"subtitle=%@",[arrayResult objectForKey:@"subtitle"]);
        NSString* indexPathKey = [arrayResult objectForKey:@"itemKey"];
        NSString* mediaItemID = [arrayResult objectForKey:@"id"];
        // itemKey is the index position eg "0:1"
        BOOL isRemove = [[arrayResult valueForKey:@"isRemove"] boolValue];
        
        if (isRemove){
            [mediaItems removeObjectForKey:indexPathKey];
        }else{
            MPContentItem* item = [[MPContentItem alloc] initWithIdentifier:mediaItemID];
            item.title = [arrayResult objectForKey:@"title"];
            item.subtitle = [arrayResult objectForKey:@"subtitle"];
            BOOL isContainer = [[arrayResult valueForKey:@"isContainer"] boolValue];
            BOOL isPlayable = [[arrayResult valueForKey:@"isPlayable"] boolValue];
            NSString* artworkUrl = [arrayResult objectForKey:@"artworkUrl"];
            item.container = isContainer;
            item.playable = isPlayable;
            
            //item.playable = YES;
           // item.streamingContent = YES;
            //mediaItems[i] = item;
            
            // every item added has a unique key which is its index position eg 0:0:1
            //@synchronized(mediaItems){
                [mediaItems setValue:item forKey:indexPathKey];
            //}
            
            if (!isEmpty(artworkUrl)){
                //MPMediaItemArtwork *artwork = [MPMediaItemArtwork alloc];
                //UIImage *appIcon = [UIImage imageNamed:@"AppIcon40x40"];
                //MPMediaItemArtwork *artwork = [[MPMediaItemArtwork alloc] initWithImage: appIcon];
                //item.artwork = artwork;
                [self loadArtworkInBackground:artworkUrl contentItem:item];
              
//                // load image in background if not already loaded
//                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
//                    UIImage *image = nil;
//                    NSURL *imageURL = [NSURL URLWithString:artworkUrl];
//                    NSData *imageData = [NSData dataWithContentsOfURL:imageURL];
//                    image = [UIImage imageWithData:imageData];
//                    if(image) {
//                        MPMediaItemArtwork *artwork = [[MPMediaItemArtwork alloc] initWithImage: image];
//                        item.artwork = artwork;
//                    }
//
//                    // update the corresponing media item when loading finishes
//                    //[mediaItems setValue:item forKey:indexPathKey];
//                });
            }
        }
    }
    [MPPlayableContentManager.sharedContentManager endUpdates];
    
    // refresh
    //dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.01 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
    //dispatch_async(dispatch_get_main_queue(), ^{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        [MPPlayableContentManager.sharedContentManager reloadData];
    });
    //[[MPPlayableContentManager sharedContentManager]reloadData];
}

- (void)loadArtworkInBackground:(NSString*)artworkUrl contentItem:(MPContentItem*)contentItem{
    MPMediaItemArtwork* artwork = [thumbnails objectForKey:artworkUrl];
    if(artwork){
        // cached image
        //NSLog(@"mediaItem using cached image %@", artworkUrl);
        contentItem.artwork = artwork;
    }else{
        // perform loading in background either from url or filesystem  -- note saw a firebase crashlytics on next line
        //dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
            MPMediaItemArtwork *artwork = [self loadArtwork:artworkUrl];
            //dispatch_async(dispatch_get_main_queue(), ^{
                if (artwork){
                    contentItem.artwork = artwork;
                }
            //});
        //});
    }
}

- (void)loadArtworkInBackground:(NSString*)artworkUrl nowPlayingDictionary:(NSMutableDictionary*)songInfo{
    MPMediaItemArtwork* artwork = [thumbnails objectForKey:artworkUrl];
    if(artwork){
        // cached image
        [songInfo setObject:artwork forKey:MPMediaItemPropertyArtwork];
    }else{
        // perform loading in background either from url or filesystem
        //dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
            MPMediaItemArtwork *artwork = [self loadArtwork:artworkUrl];
            //dispatch_async(dispatch_get_main_queue(), ^{
                if (artwork){
                    // update in media data
                    [songInfo setObject:artwork forKey:MPMediaItemPropertyArtwork];
                    // show image now it has loaded
                    [MPNowPlayingInfoCenter.defaultCenter setNowPlayingInfo:songInfo];
                }
            //});
        //});
    }
}

- (MPMediaItemArtwork*)loadArtwork:(NSString*)cover{
    // load image in background if not already loaded
    MPMediaItemArtwork* artwork = nil;
    UIImage *image = nil;
//    NSURL *imageURL = [NSURL URLWithString:artworkUrl];
//    NSData *imageData = [NSData dataWithContentsOfURL:imageURL];
//    image = [UIImage imageWithData:imageData];
//    if(image) {
//        MPMediaItemArtwork *artwork = [[MPMediaItemArtwork alloc] initWithImage: image];
//        return artwork;
//        //item.artwork = artwork;
//    }
    
    // image not already cached
    if ([cover hasPrefix: @"http://"] || [cover hasPrefix: @"https://"]) {
        // cover is remote file
        NSLog(@"carplayplugin loading URL image MPNowPlayingInfoCenter 2a.");
        NSURL *imageURL = [NSURL URLWithString:cover];

        NSLog(@"carplayplugin loading URL image MPNowPlayingInfoCenter 2b.");
        NSData *imageData = [NSData dataWithContentsOfURL:imageURL];

        NSLog(@"carplayplugin loading URL image MPNowPlayingInfoCenter 2c.");
        image = [UIImage imageWithData:imageData];

        NSLog(@"carplayplugin loading URL image MPNowPlayingInfoCenter 2d.");
        
    }
    else if ([cover hasPrefix: @"file://"]) {
        // cover is full path to local file
        NSString *fullPath = [cover stringByReplacingOccurrencesOfString:@"file://" withString:@""];
        BOOL fileExists = [[NSFileManager defaultManager] fileExistsAtPath:fullPath];
        
        NSLog(@"fullPath %@ 2d.",fullPath);
        
        if (fileExists) {
            NSLog(@"localfile image fileexists %@ 2d.",fullPath);
            image = [[UIImage alloc] initWithContentsOfFile:fullPath];
        }
    }
    else {
        // cover is relative path to local file in documents directory
        NSString *basePath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
        NSString *fullPath = [NSString stringWithFormat:@"%@%@", basePath, cover];
        BOOL fileExists = [[NSFileManager defaultManager] fileExistsAtPath:fullPath];
        if (fileExists) {
            image = [UIImage imageNamed:fullPath];
        }
    }

    // if we got an image, turn it into an artwork
    if (image){
        // create artwork
        // check whether image is loaded
        CGImageRef cgref = [image CGImage];
        CIImage *cim = [image CIImage];
        if (cim != nil || cgref != NULL) {
            artwork = [[MPMediaItemArtwork alloc] initWithImage: image];
            // cache image
            @synchronized (thumbnails) {
                [thumbnails setValue:artwork forKey:cover];
                // 17 jan 2020 - crash here in firebase crashlytics - 23 jan added back @sync wrapper
            }
            
        }
    }

    return artwork;
}

//    // async image loading
//    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
//        UIImage *image = nil;
//        // check whether cover path is present
//        if (![cover isEqual: @""]) {
//            // cover is remote file
//            if ([cover hasPrefix: @"http://"] || [cover hasPrefix: @"https://"]) {
//                NSURL *imageURL = [NSURL URLWithString:cover];
//                NSData *imageData = [NSData dataWithContentsOfURL:imageURL];
//                image = [UIImage imageWithData:imageData];
//            }
//            // cover is full path to local file
//            else if ([cover hasPrefix: @"file://"]) {
//                NSString *fullPath = [cover stringByReplacingOccurrencesOfString:@"file://" withString:@""];
//                BOOL fileExists = [[NSFileManager defaultManager] fileExistsAtPath:fullPath];
//                if (fileExists) {
//                    image = [[UIImage alloc] initWithContentsOfFile:fullPath];
//                }
//            }
//            // cover is relative path to local file
//            else {
//                NSString *basePath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
//                NSString *fullPath = [NSString stringWithFormat:@"%@%@", basePath, cover];
//                BOOL fileExists = [[NSFileManager defaultManager] fileExistsAtPath:fullPath];
//                if (fileExists) {
//                    image = [UIImage imageNamed:fullPath];
//                }
//            }
//        }
//        else {
//            // default named "no-image"
//            image = [UIImage imageNamed:@"no-image"];
//        }
//        // check whether image is loaded
//        CGImageRef cgref = [image CGImage];
//        CIImage *cim = [image CIImage];
//        if (cim != nil || cgref != NULL) {
//            dispatch_async(dispatch_get_main_queue(), ^{
//                if (NSClassFromString(@"MPNowPlayingInfoCenter")) {
//                    NSLog(@"RemoteControls set dictionary on MPNowPlayingInfoCenter.");
//                    MPMediaItemArtwork *artwork = [[MPMediaItemArtwork alloc] initWithImage: image];
//                    MPNowPlayingInfoCenter *center = [MPNowPlayingInfoCenter defaultCenter];
//                    center.nowPlayingInfo = [NSDictionary dictionaryWithObjectsAndKeys:
//                                             artist, MPMediaItemPropertyArtist,
//                                             title, MPMediaItemPropertyTitle,
//                                             album, MPMediaItemPropertyAlbumTitle,
//                                             artwork, MPMediaItemPropertyArtwork,
//                                             duration, MPMediaItemPropertyPlaybackDuration,
//                                             elapsed, MPNowPlayingInfoPropertyElapsedPlaybackTime,
//                                             [NSNumber numberWithInt:1], MPNowPlayingInfoPropertyPlaybackRate, nil];
//                }
//            });
//        }
//    });

    
    
- (void)removeMediaItems:(CDVInvokedUrlCommand*)command{
    // called by js to clear media items starting with a specific indexPath eg "1:0:" will clear all keys like 1:0:?
    NSLog(@"CordovaCarplayPlugin - removeMediaItems called");
    NSString* indexPath = [NSString stringWithFormat:@"%@", [command.arguments objectAtIndex:0]];
		if (isEmpty(indexPath)){
            [mediaItems removeAllObjects];
		}else{
			for (NSString *key in [mediaItems allKeys]) {
					if ([key hasPrefix:indexPath]) {
							[mediaItems removeObjectForKey:key];
					}
			}
		}
}

- (void)registerHandler:(CDVInvokedUrlCommand*)command{
    // called by js to set up media items and register callback which will handle all the carplay events
    NSLog(@"CordovaCarplayPlugin - registerHandler");
    
    // keep callback id
    currentCallbackId = command.callbackId;
    
    // register handlers for now playing buttons
    // Get the shared command center.
    MPRemoteCommandCenter *commandCenter = [MPRemoteCommandCenter sharedCommandCenter];

    // Add a handler for each command
    [commandCenter.likeCommand addTargetWithHandler:^MPRemoteCommandHandlerStatus(MPRemoteCommandEvent * _Nonnull event) {
        [self invokeCallback:@"likeCommand"];
        return MPRemoteCommandHandlerStatusSuccess;
    }];
    [commandCenter.dislikeCommand addTargetWithHandler:^MPRemoteCommandHandlerStatus(MPRemoteCommandEvent * _Nonnull event) {
        [self invokeCallback:@"dislikeCommand"];
        return MPRemoteCommandHandlerStatusSuccess;
    }];
    //[commandCenter.ratingCommand setEnabled:YES];
//    [commandCenter.ratingCommand addTargetWithHandler:^MPRemoteCommandHandlerStatus(MPRemoteCommandEvent * _Nonnull event) {
//        [self invokeCallback:@"ratingCommand"];
//        return MPRemoteCommandHandlerStatusSuccess;
//    }];

//    [commandCenter.enableLanguageOptionCommand setEnabled:YES];
//    [commandCenter.enableLanguageOptionCommand addTargetWithHandler:^MPRemoteCommandHandlerStatus(MPRemoteCommandEvent * _Nonnull event) {
//        [self invokeCallback:@"enableLanguageOptionCommand"];
//        return MPRemoteCommandHandlerStatusSuccess;
//    }];
    //    [commandCenter.skipForwardCommand setEnabled:YES];
//    [commandCenter.skipForwardCommand addTargetWithHandler:^MPRemoteCommandHandlerStatus(MPRemoteCommandEvent * _Nonnull event) {
//        [self invokeCallback:@"skipForwardCommand"];
//        return MPRemoteCommandHandlerStatusSuccess;
//    }];
//    //    [commandCenter.skipBackwardCommand setEnabled:YES];
//    [commandCenter.skipBackwardCommand addTargetWithHandler:^MPRemoteCommandHandlerStatus(MPRemoteCommandEvent * _Nonnull event) {
//        [self invokeCallback:@"skipBackwardCommand"];
//        return MPRemoteCommandHandlerStatusSuccess;
//    }];
    [commandCenter.playCommand addTargetWithHandler:^MPRemoteCommandHandlerStatus(MPRemoteCommandEvent * _Nonnull event) {
        // note: weirdly, the play button sometimes looks like a stop button and returns user to the media list screen
        [self invokeCallback:@"playCommand"];
        return MPRemoteCommandHandlerStatusSuccess;
    }];
    [commandCenter.stopCommand addTargetWithHandler:^MPRemoteCommandHandlerStatus(MPRemoteCommandEvent * _Nonnull event) {
        // stop button does not seem to work
        [self invokeCallback:@"stopCommand"];
        return MPRemoteCommandHandlerStatusSuccess;
    }];
    [commandCenter.pauseCommand addTargetWithHandler:^MPRemoteCommandHandlerStatus(MPRemoteCommandEvent * _Nonnull event) {
        [self invokeCallback:@"pauseCommand"];
        return MPRemoteCommandHandlerStatusSuccess;
    }];
    
    [commandCenter.bookmarkCommand addTargetWithHandler:^MPRemoteCommandHandlerStatus(MPRemoteCommandEvent * _Nonnull event) {
        [self invokeCallback:@"bookmarkCommand"];
        return MPRemoteCommandHandlerStatusSuccess;
    }];
    
    [commandCenter.nextTrackCommand addTargetWithHandler:^MPRemoteCommandHandlerStatus(MPRemoteCommandEvent * _Nonnull event) {
        [self invokeCallback:@"nextTrackCommand"];
        return MPRemoteCommandHandlerStatusSuccess;
    }];
    [commandCenter.previousTrackCommand addTargetWithHandler:^MPRemoteCommandHandlerStatus(MPRemoteCommandEvent * _Nonnull event) {
        [self invokeCallback:@"previousTrackCommand"];
        return MPRemoteCommandHandlerStatusSuccess;
    }];
    [commandCenter.togglePlayPauseCommand addTargetWithHandler:^MPRemoteCommandHandlerStatus(MPRemoteCommandEvent * _Nonnull event) {
        [self invokeCallback:@"togglePlayPauseCommand"];
        return MPRemoteCommandHandlerStatusSuccess;
    }];
    [commandCenter.changeRepeatModeCommand addTargetWithHandler:^MPRemoteCommandHandlerStatus(MPRemoteCommandEvent * _Nonnull event) {
        [self invokeCallback:@"changeRepeatModeCommand"];
        return MPRemoteCommandHandlerStatusSuccess;
    }];
    [commandCenter.changeShuffleModeCommand addTargetWithHandler:^MPRemoteCommandHandlerStatus(MPRemoteCommandEvent * _Nonnull event) {
        [self invokeCallback:@"changeShuffleModeCommand"];
        return MPRemoteCommandHandlerStatusSuccess;
    }];


    [self invokeCallback:@"registerHandlerDone" indexPathKey:@"" mediaItemID:@""];
}

- (void)setCommandEnabled:(CDVInvokedUrlCommand*)command{
    // called by js to set up media items and register callback which will handle all the carplay events
    NSLog(@"CordovaCarplayPlugin - registerHandler");
    NSString* commandName = [NSString stringWithString:[command.arguments objectAtIndex:0]];
    BOOL isEnabled = [[command.arguments objectAtIndex:1] boolValue];
    
    // Get the shared command center.
    MPRemoteCommandCenter *commandCenter = [MPRemoteCommandCenter sharedCommandCenter];
    
    if ([commandName isEqualToString:@"previousTrackCommand"]){
        [commandCenter.previousTrackCommand setEnabled:isEnabled];
    } else if ([commandName isEqualToString:@"nextTrackCommand"]){
        [commandCenter.nextTrackCommand setEnabled:isEnabled];
    } else if ([commandName isEqualToString:@"changeShuffleModeCommand"]){
        [commandCenter.changeShuffleModeCommand setEnabled:isEnabled];
    } else if ([commandName isEqualToString:@"changeRepeatModeCommand"]){
        [commandCenter.changeRepeatModeCommand setEnabled:isEnabled];
    }
}


// send a cordova callback / event to javascript land
- (void)invokeCallback:(NSString*)action {
    [self invokeCallback:action indexPathKey:@"" mediaItemID:@""];
}

// send a cordova callback / event to javascript land
- (void)invokeCallback:(NSString*)action indexPathKey:(NSString*)param{
    [self invokeCallback:action indexPathKey:param mediaItemID:@""];
}

// send a cordova callback / event to javascript land
- (void)invokeCallback:(NSString*)action indexPathKey:(NSString*)param mediaItemID:(NSString*)mediaItemID{
    //NSLog(@"CordovaCarplayPlugin - invokeCallback - called");
    NSDictionary *message = @{
                              @"action": action,
                              @"indexPathKey": param,
                              @"mediaItemID": mediaItemID
                              };
    CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:message];
    [pluginResult setKeepCallback:[NSNumber numberWithBool:YES]];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:currentCallbackId];
}

- (void)reloadMediaItems:(CDVInvokedUrlCommand*)command{
    NSLog(@"CordovaCarplayPlugin - reload");
    [[MPPlayableContentManager sharedContentManager]reloadData];
}

- (void)updateNowPlayingMetaData:(CDVInvokedUrlCommand*)command{
    // call this from js to set the now playing info including the carplay item list screen

    // code modified from RemoteControls plugin
    // Copyright 2013 François LASSERRE. All rights reserved.
    // MIT Licensed
    
    NSString *title = [command.arguments objectAtIndex:0];
    NSString *subtitle = [command.arguments objectAtIndex:1];
    NSString *album = [command.arguments objectAtIndex:2];
    NSString *cover = [command.arguments objectAtIndex:3];
    NSNumber *duration = [command.arguments objectAtIndex:4];
    NSNumber *elapsed = [command.arguments objectAtIndex:5];
    NSString *mediaItemID = [command.arguments objectAtIndex:6];
    NSNumber *playlistIndex = [command.arguments objectAtIndex:7];
    NSNumber *playlistCount = [command.arguments objectAtIndex:8];
    NSNumber *playButtonState = [command.arguments objectAtIndex:9];
    
    // Get the shared command center.
    MPRemoteCommandCenter *commandCenter = [MPRemoteCommandCenter sharedCommandCenter];
  
    #if TARGET_OS_SIMULATOR
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.01 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [[UIApplication sharedApplication] endReceivingRemoteControlEvents];
            [[UIApplication sharedApplication] beginReceivingRemoteControlEvents];
        });
    #endif
    
    if (!isEmpty(mediaItemID)){
        // also update content manager to show playing icon
        MPPlayableContentManager.sharedContentManager.nowPlayingIdentifiers = @[ mediaItemID ];
        
        // show all the buttons relevant to media items
        //playButtonState
        [commandCenter.togglePlayPauseCommand setEnabled:YES];
        [commandCenter.likeCommand setEnabled:YES];
        [commandCenter.dislikeCommand setEnabled:YES];
        [commandCenter.bookmarkCommand setEnabled:YES];
        [commandCenter.nextTrackCommand setEnabled:YES];
        [commandCenter.previousTrackCommand setEnabled:YES];
        [commandCenter.changeRepeatModeCommand setEnabled:YES];
        [commandCenter.changeShuffleModeCommand setEnabled:YES];
    }else{
        // hide all the buttons relevant to media items
        [commandCenter.togglePlayPauseCommand setEnabled:NO];
        [commandCenter.pauseCommand setEnabled:NO];
        [commandCenter.stopCommand setEnabled:NO];
        [commandCenter.playCommand setEnabled:NO];
        if ([playButtonState intValue]==1){
            [commandCenter.pauseCommand setEnabled:YES];
        }else if ([playButtonState intValue]==2){
            [commandCenter.playCommand setEnabled:YES];
        }else{
            // zero = off
            
        }
        [commandCenter.likeCommand setEnabled:NO];
        [commandCenter.dislikeCommand setEnabled:NO];
        [commandCenter.bookmarkCommand setEnabled:NO];
        [commandCenter.nextTrackCommand setEnabled:NO];
        [commandCenter.previousTrackCommand setEnabled:NO];
        [commandCenter.changeRepeatModeCommand setEnabled:NO];
        [commandCenter.changeShuffleModeCommand setEnabled:NO];
    }
    
    //NSLog(@"CordovaCarplayPlugin - updateNowPlayingMetaData to %@, %@", title, subtitle);
    

    // async cover loading
//    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
//        UIImage *image = nil;
//        MPMediaItemArtwork *artwork;
//
//        NSLog(@"carplayplugin set dictionary on MPNowPlayingInfoCenter 1.");// check whether cover path is present
//        if (!isEmpty(cover)) {
//            artwork = [thumbnails objectForKey:cover];
//            if(artwork){
//                // cached image
//                NSLog(@"Loading image from cache %@", cover);
//            }else{
//                // image not already cached
//                if ([cover hasPrefix: @"http://"] || [cover hasPrefix: @"https://"]) {
//                // cover is remote file
////                NSLog(@"carplayplugin set dictionary on MPNowPlayingInfoCenter 2a.");
////                NSURL *imageURL = [NSURL URLWithString:cover];
////
////                NSLog(@"carplayplugin set dictionary on MPNowPlayingInfoCenter 2b.");
////                NSData *imageData = [NSData dataWithContentsOfURL:imageURL];
////
////                NSLog(@"carplayplugin set dictionary on MPNowPlayingInfoCenter 2c.");
////                image = [UIImage imageWithData:imageData];
////
////                NSLog(@"carplayplugin set dictionary on MPNowPlayingInfoCenter 2d.");
//
//                }
//                // cover is full path to local file
//                else if ([cover hasPrefix: @"file://"]) {
//                    NSString *fullPath = [cover stringByReplacingOccurrencesOfString:@"file://" withString:@""];
//                    BOOL fileExists = [[NSFileManager defaultManager] fileExistsAtPath:fullPath];
//                    if (fileExists) {
//                        image = [[UIImage alloc] initWithContentsOfFile:fullPath];
//                    }
//                }
//                // cover is relative path to local file in documents directory
//                else {
//                    NSString *basePath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
//                    NSString *fullPath = [NSString stringWithFormat:@"%@%@", basePath, cover];
//                    BOOL fileExists = [[NSFileManager defaultManager] fileExistsAtPath:fullPath];
//                    if (fileExists) {
//                        image = [UIImage imageNamed:fullPath];
//                    }
//                }
//                if (image){
//                    // create artwork
//                    // check whether image is loaded
//                    CGImageRef cgref = [image CGImage];
//                    CIImage *cim = [image CIImage];
//                    if (cim != nil || cgref != NULL) {
//                        MPMediaItemArtwork* artwork = [[MPMediaItemArtwork alloc] initWithImage: image];
//                        // cache image
//                        [thumbnails setValue:artwork forKey:cover];
//                    }
//                }
//            }
//
//        }
//        else {
//            // default named "no-image"
//            //image = [UIImage imageNamed:@"no-image"];
//        }
//
//        NSLog(@"carplayplugin set dictionary on MPNowPlayingInfoCenter 3.");
//        // check whether image is loaded
// //       CGImageRef cgref = [image CGImage];
// //       CIImage *cim = [image CIImage];
//           dispatch_async(dispatch_get_main_queue(), ^{
                if (NSClassFromString(@"MPNowPlayingInfoCenter")) {
                    //NSLog(@"carplayplugin set dictionary on MPNowPlayingInfoCenter 4.");

                    NSMutableDictionary *songInfo = [[NSMutableDictionary alloc] init];
                    //  MPMediaItemArtwork *albumArt = [[MPMediaItemArtwork alloc] initWithImage:[UIImage imageNamed:@"series_placeholder"]];
                    //[songInfo setObject:albumArt forKey:MPMediaItemPropertyArtwork];
                    [songInfo setObject:title forKey:MPMediaItemPropertyTitle];
                    [songInfo setObject:subtitle forKey:MPMediaItemPropertyArtist];
                    if (!isEmpty(album)){
                        [songInfo setObject:album forKey:MPMediaItemPropertyAlbumTitle];
                    }
//                    MPMediaItemArtwork *artwork;
//                    if (cim != nil || cgref != NULL) {
//                        artwork = [[MPMediaItemArtwork alloc] initWithImage: image];
//                    if (artwork){
//                        [songInfo setObject:artwork forKey:MPMediaItemPropertyArtwork];
//                    }
                    if (!isEmpty(cover)){
                        //MPMediaItemArtwork *artwork = [MPMediaItemArtwork alloc];
                        //UIImage *appIcon = [UIImage imageNamed:@"AppIcon40x40"];
                        //MPMediaItemArtwork *artwork = [[MPMediaItemArtwork alloc] initWithImage: appIcon];
                        //item.artwork = artwork;
                        [self loadArtworkInBackground:cover nowPlayingDictionary:songInfo];
                    }
                    
                    [songInfo setObject:duration forKey:MPMediaItemPropertyPlaybackDuration];
                    [songInfo setObject:elapsed forKey:MPNowPlayingInfoPropertyElapsedPlaybackTime];
                    if ([playButtonState intValue]==1){
                        [songInfo setObject:[NSNumber numberWithInt:1] forKey:MPNowPlayingInfoPropertyPlaybackRate];
                    }
                    [songInfo setObject:[NSNumber numberWithInt:1] forKey:MPNowPlayingInfoPropertyDefaultPlaybackRate];
                    if (playlistCount>0){
                        [songInfo setObject:playlistCount forKey:MPNowPlayingInfoPropertyPlaybackQueueCount];
                        [songInfo setObject:playlistIndex forKey:MPNowPlayingInfoPropertyPlaybackQueueIndex];
                    }
                    [MPNowPlayingInfoCenter.defaultCenter setNowPlayingInfo:songInfo];
                    
//                    if (artwork!=nil){
//                    MPNowPlayingInfoCenter *center = [MPNowPlayingInfoCenter defaultCenter];
//                    center.nowPlayingInfo = [NSDictionary dictionaryWithObjectsAndKeys:
//                                             subtitle, MPMediaItemPropertyArtist,
//                                             title, MPMediaItemPropertyTitle,
//                                             album, MPMediaItemPropertyAlbumTitle,
//                                             artwork, MPMediaItemPropertyArtwork,
//                                             duration, MPMediaItemPropertyPlaybackDuration,
//                                             elapsed, MPNowPlayingInfoPropertyElapsedPlaybackTime,
//                                             [NSNumber numberWithInt:1], MPNowPlayingInfoPropertyPlaybackRate, nil];
//                    }
                    
            
                }
                
//            });
//    });

    
}

- (void)finishedPlaying:(CDVInvokedUrlCommand*)command{
    // call this from js to clear the now playing info and return the user to the carplay item list screen
    
    if (MPNowPlayingInfoCenter.defaultCenter.nowPlayingInfo==nil){
        NSLog(@"CordovaCarplayPlugin - finishedPlaying but was already finished");
    }else{
        NSLog(@"CordovaCarplayPlugin - finishedPlaying");
        
    }
    
    //To clear the now playing info center dictionary, set it to nil.
    [[MPNowPlayingInfoCenter defaultCenter] setNowPlayingInfo:nil];
    
    // also update content manager to hide playing icon
    MPPlayableContentManager.sharedContentManager.nowPlayingIdentifiers = @[ ];
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
    #if TARGET_OS_SIMULATOR
        dispatch_async(dispatch_get_main_queue(), ^{
            [[UIApplication sharedApplication] endReceivingRemoteControlEvents];
            [[UIApplication sharedApplication] beginReceivingRemoteControlEvents];
        });
    #endif
        
        // tell carplay we are all good, ready to play
        completionHandler(nil);

        // play
        [self invokeCallback:@"handlePlayback" indexPathKey:itemKey mediaItemID:info];
    }
}

// implementation of MPPlayableContentDataSource or MPPlayableContentDelegate
- (void)beginLoadingChildItemsAtIndexPath:(NSIndexPath *)indexPath
                        completionHandler:(void (^)(NSError *))completionHandler{
    
    int index = (int)[indexPath indexAtPosition:0];
    if(isDebug) NSLog(@"beginLoadingChildItemsAtIndexPath1: %@", [indexPath indexPathString]);
    
    // not implemented
    // could all out to js to load the stuff, then call the completion handler, but more flexible if we just reload items when we want
    
    completionHandler(nil);
}

// implementation of MPPlayableContentDataSource or MPPlayableContentDelegate
// called by carplay when user browses a media list
// supplies number of child items in a list or sublist
- (NSInteger)numberOfChildItemsAtIndexPath:(NSIndexPath *)indexPath{
    int index = (int)[indexPath indexAtPosition:0];
   // int count = [CordovaCarplayPlugin.carplayPlugin requestItemCount];
    NSString* itemKey =[indexPath indexPathString];

    [self invokeCallback:@"queriedChildItems" indexPathKey:[indexPath indexPathString]];

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
    for (NSString *key in [mediaItems allKeys]) {
    //for (NSString* key in mediaItems){
        NSArray *items = [key componentsSeparatedByString:@":"];
        NSUInteger len = [items count];
        if (childLevel == len) {
            if (indexPath.length==0 || [key hasPrefix:itemKey]){
                count++;
            }
        }
    }

    if(isDebug) NSLog(@"numberOfChildItemsAtIndexPath: '%@' is %i", itemKey, count);

    MPPlayableContentManager *contentManager = [MPPlayableContentManager sharedContentManager];
    
    if(isDebug) NSLog(@"limitsEnforced: %i", contentManager.context.contentLimitsEnforced);
    if(isDebug) NSLog(@"limit depth: %li", contentManager.context.enforcedContentTreeDepth);
    if(isDebug) NSLog(@"limit items: %li", contentManager.context.enforcedContentItemsCount);

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
    
    if(isDebug) NSLog(@"contentItemAtIndexPath itemKey: %@", itemKey );
    
    // if playable then play else do another callback eg expand
    // get the item we picked
    //MPContentItem* item = mediaItems[index];
    MPContentItem* item = [mediaItems objectForKey:itemKey];
    
    
    //#if TARGET_OS_SIMULATOR
//    dispatch_async(dispatch_get_main_queue(), ^{
//        [[UIApplication sharedApplication] endReceivingRemoteControlEvents];
//        [[UIApplication sharedApplication] beginReceivingRemoteControlEvents];
//    });
    //#endif
    
    //streamingContent
    //container
    return item;
}

- (void)contentItemForIdentifier:(NSString *)identifier completionHandler:(void(^)(MPContentItem *__nullable, NSError * __nullable))completionHandler {
    
    if(isDebug) NSLog(@"contentItemForIdentifier async identifier: %@", identifier );
    
}

// Check if the "thing" passed is empty
static inline BOOL isEmpty(id thing) {
    return thing == nil
    || [thing isKindOfClass:[NSNull class]]
    || ([thing respondsToSelector:@selector(length)]
        && [(NSData *)thing length] == 0)
    || ([thing respondsToSelector:@selector(count)]
        && [(NSArray *)thing count] == 0);
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

// nice article showing how others do it
// https://www.cleveroad.com/blog/discover-apple-carplay-apps-list-from-third-party-developers
