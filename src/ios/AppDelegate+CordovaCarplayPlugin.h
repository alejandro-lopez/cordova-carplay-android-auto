// copyright 2019 by Mike Nelson, beweb
// open source by MIT license terms

#import "AppDelegate.h"

#import <MediaPlayer/MediaPlayer.h>

@interface AppDelegate (CordovaCarplayPlugin)
@property (nonatomic, strong) NSNumber * _Nonnull applicationInBackground;
@property (NS_NONATOMIC_IOSONLY, nullable, weak) id <MPPlayableContentDelegate> delegate;
@end

