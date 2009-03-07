//
//  OEGamePreferenceController.h
//  OpenEmu
//
//  Created by Remy Demarest on 25/02/2009.
//  Copyright 2009 Psycho Inc.. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class PluginInfo;

@interface OEGamePreferenceController : NSWindowController
{
    IBOutlet NSView *controlsView;
    IBOutlet NSView *videoView;
    IBOutlet NSView *pluginsView;
    IBOutlet NSView *audioView;
    IBOutlet NSDrawer *pluginDrawer;
    NSArray *plugins;
    NSString *currentViewIdentifier;
    NSIndexSet *selectedPlugins;
    PluginInfo *currentPlugin;
}

//@property(readonly) NSArray *controlPlugins;
@property(readonly) NSArray *plugins;
@property(assign) NSIndexSet *selectedPlugins;

@end