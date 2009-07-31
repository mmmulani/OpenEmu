// 
//  SaveState.m
//  OpenEmu
//
//  Created by Joshua Weinberg on 7/30/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import "SaveState.h"


@implementation SaveState 

@dynamic timeStamp;
@dynamic emulatorID;
@dynamic rompath;
@dynamic screenShot;
@dynamic saveData;

- (id) imageRepresentation
{
	NSImage* image = [[NSImage alloc] initWithData:[self.screenShot valueForKey:@"screenShot"]];
	return [image autorelease];
}

- (NSString *)imageRepresentationType {
    // We use this representation type because we are storing the image as binary data.
	return IKImageBrowserNSImageRepresentationType;
}

- (NSString *)imageUID {
    // This is uses the NSManagedObjectID for the entity to generate a unique string.
    return [[[self objectID] URIRepresentation] description];
}

@end