/*
 Copyright (c) 2009, OpenEmu Team
 
 
 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:
     * Redistributions of source code must retain the above copyright
       notice, this list of conditions and the following disclaimer.
     * Redistributions in binary form must reproduce the above copyright
       notice, this list of conditions and the following disclaimer in the
       documentation and/or other materials provided with the distribution.
     * Neither the name of the OpenEmu Team nor the
       names of its contributors may be used to endorse or promote products
       derived from this software without specific prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY OpenEmu Team ''AS IS'' AND ANY
 EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 DISCLAIMED. IN NO EVENT SHALL OpenEmu Team BE LIABLE FOR ANY
 DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
  LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
  SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import <Foundation/Foundation.h>
#import <CoreServices/CoreServices.h>
#import <QuickLook/QuickLook.h>
#import <CoreData/CoreData.h>
#import "OESaveState.h"

/* -----------------------------------------------------------------------------
 Generate a preview for file
 
 This function's job is to create preview for designated file
 -----------------------------------------------------------------------------
 */
OSStatus GeneratePreviewForURL(void *thisInterface, QLPreviewRequestRef preview, CFURLRef url, CFStringRef contentTypeUTI, CFDictionaryRef options)
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    
    NSManagedObjectModel *managedObjectModel = [NSManagedObjectModel mergedModelFromBundles:[NSArray arrayWithObject:[NSBundle bundleWithIdentifier:@"com.openemu.savestategenerator"]]];
    NSPersistentStoreCoordinator *persistentStoreCoordinator = [[[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel: managedObjectModel] autorelease];
    
    NSError *error = nil;
    NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:
                             [NSNumber numberWithBool:YES], NSMigratePersistentStoresAutomaticallyOption,
                             [NSNumber numberWithBool:YES], NSInferMappingModelAutomaticallyOption,
                             nil];
    if(![persistentStoreCoordinator addPersistentStoreWithType:NSXMLStoreType configuration:nil URL:(NSURL*)url options:options error:&error])
    {
        NSLog(@"Couldn't create store, error: %@", error);
        [pool drain];
        return noErr;
    }
    
    NSManagedObjectContext *managedObjectContext = [[[NSManagedObjectContext alloc] init] autorelease];
    [managedObjectContext setPersistentStoreCoordinator:persistentStoreCoordinator];
    
    NSFetchRequest *request = [[[NSFetchRequest alloc] init] autorelease];
    NSEntityDescription *entity = [NSEntityDescription entityForName:@"SaveState" inManagedObjectContext:managedObjectContext];
    [request setEntity:entity];
    
    NSArray     *array = [managedObjectContext executeFetchRequest:request error:&error];
    
    OESaveState *state = [array objectAtIndex:0];
    
    NSImage     *image = [state screenshot];
    
    NSSize  canvasSize = [image size];
    
    // Preview will be drawn in a vectorized context
    CGContextRef cgContext = QLPreviewRequestCreateContext(preview, *(CGSize *)&canvasSize, true, NULL);
    if(cgContext)
    {
        DLog(@"Got CGContext");
        NSGraphicsContext *context = [NSGraphicsContext graphicsContextWithGraphicsPort:(void *)cgContext flipped:YES];
        if(context)
        {
            DLog(@"Got NSContext");
            NSGraphicsContext *gc = [NSGraphicsContext graphicsContextWithGraphicsPort:cgContext flipped:NO]; 
            [NSGraphicsContext saveGraphicsState]; 
            [NSGraphicsContext setCurrentContext:gc]; 
            [image drawAtPoint:NSZeroPoint fromRect:NSZeroRect operation:NSCompositeCopy fraction:1.0];
            [NSGraphicsContext restoreGraphicsState];
        }
        QLPreviewRequestFlushContext(preview, cgContext);
        CFRelease(cgContext);
    }
    [pool drain];
    return noErr;
}

void CancelPreviewGeneration(void* thisInterface, QLPreviewRequestRef preview)
{
    // implement only if supported
}
