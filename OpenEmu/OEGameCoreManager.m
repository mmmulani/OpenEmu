/*
 Copyright (c) 2010, OpenEmu Team
 
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

#import "OEGameCoreManager.h"
#import "OECorePlugin.h"
#import "OEGameCoreHelper.h"
#import "OEGameCoreController.h"
#import "NSString+UUID.h"
#import "OpenEmuHelperApp.h"

NSString *const OEGameDocumentErrorDomain = @"OEGameDocumentErrorDomain";

#import "OETaskWrapper.h"

@implementation OEGameCoreManager
@synthesize romPath, plugin, owner;

- (id)initWithROMAtPath:(NSString *)theRomPath corePlugin:(OECorePlugin *)thePlugin owner:(OEGameCoreController *)theOwner error:(NSError **)outError
{
    self = [super init];
    
    if(self != nil)
    {
        plugin  = thePlugin;
        owner   = theOwner;
        romPath = [theRomPath copy];
        
        if(![self startHelperProcessError:outError])
        {
            [self release];
            return nil;
        }
        
        if(![self loadROMError:outError])
        {
            [self endHelperProcess];
            [self release];
            return nil;
        }
    }
    return self;
}

- (void)stop
{
    [self endHelperProcess];
}

- (void)dealloc
{
    [self stop];
    [romPath release];
    [super dealloc];
}

- (BOOL)startHelperProcessError:(NSError **)outError
{
    if(outError != NULL) *outError = [NSError errorWithDomain:NSOSStatusErrorDomain code:unimpErr userInfo:NULL];
    
    return NO;
}

- (void)endHelperProcess
{
    
}

- (id<OEGameCoreHelper>)rootProxy
{
    return nil;
}

- (BOOL)loadROMError:(NSError **)outError
{
    BOOL ret = [[self rootProxy] loadRomAtPath:romPath withCorePluginAtPath:[[plugin bundle] bundlePath] owner:owner];
    
    if(!ret && outError != NULL)
        *outError = [NSError errorWithDomain:@"OEHelperProcessErrorDomain"
                                        code:-10 // FIXME: whatever
                                    userInfo:[NSDictionary dictionaryWithObject:NSLocalizedString(@"The ROM couldn't be loaded.", @"OEGameCoreManager loadROMError: error reason.") forKey:NSLocalizedFailureReasonErrorKey]];
    
    return ret;
}

@end

#pragma mark -
#pragma mark Manager using a background process

@implementation OEGameCoreProcessManager

- (id<OEGameCoreHelper>)rootProxy
{
    return rootProxy;
}

- (OETaskWrapper*)helper
{
    return helper;
}

- (BOOL)startHelperProcessError:(NSError **)outError
{
    // run our background task. Get our IOSurface ids from its standard out.
    NSString *cliPath = [[NSBundle bundleForClass:[self class]] pathForResource:@"OpenEmuHelperApp" ofType: @""];
    
    // generate a UUID string so we can have multiple screen capture background tasks running.
    taskUUIDForDOServer = [[NSString stringWithUUID] retain];
    // NSLog(@"helper tool UUID should be %@", taskUUIDForDOServer);
    
    NSArray *args = [NSArray arrayWithObjects:cliPath, taskUUIDForDOServer, nil];
    
    helper = [[OETaskWrapper alloc] initWithController:self arguments:args userInfo:nil];
    [helper startProcess];
    
    if(![helper isRunning])
    {
        [helper release];
        if(outError != NULL)
            *outError = [NSError errorWithDomain:OEGameDocumentErrorDomain
                                            code:OEHelperAppNotRunningError
                                        userInfo:[NSDictionary dictionaryWithObject:NSLocalizedString(@"The background process couldn't be launched", @"Not running background process error") forKey:NSLocalizedFailureReasonErrorKey]];
        return NO;
    }
    
    // now that we launched the helper, start up our NSConnection for DO object vending and configure it
    // this is however a race condition if our helper process is not fully launched yet. 
    // we hack it out here. Normally this while loop is not noticable, its very fast
    
    NSDate *start = [NSDate date];
    
    taskConnection = nil;
    while(taskConnection == nil)
    {
        taskConnection = [NSConnection connectionWithRegisteredName:[NSString stringWithFormat:@"com.openemu.OpenEmuHelper-%@", taskUUIDForDOServer, nil] host:nil];
        
        if(-[start timeIntervalSinceNow] > 3.0)
        {
            [self endHelperProcess];
            if(outError != NULL)
            {
                *outError = [NSError errorWithDomain:OEGameDocumentErrorDomain
                                                code:OEConnectionTimedOutError
                                            userInfo:[NSDictionary dictionaryWithObject:NSLocalizedString(@"Couldn't connect to the background process.", @"Timed out error reason.") forKey:NSLocalizedFailureReasonErrorKey]];
            }
            return NO;
        }
    }
    
    [taskConnection retain];
    
    if(![taskConnection isValid])
    {
        [self endHelperProcess];
        if(outError != NULL)
        {
            *outError = [NSError errorWithDomain:OEGameDocumentErrorDomain
                                            code:OEInvalidHelperConnectionError
                                        userInfo:[NSDictionary dictionaryWithObject:NSLocalizedString(@"The background process connection couldn't be established", @"Invalid helper connection error reason.") forKey:NSLocalizedFailureReasonErrorKey]];
        }
        return NO;
    }
    
    // now that we have a valid connection...
    rootProxy = [[taskConnection rootProxy] retain];
    if(rootProxy == nil)
    {
        NSLog(@"nil root proxy object?");
        [self endHelperProcess];
        if(outError != NULL)
        {
            *outError = [NSError errorWithDomain:OEGameDocumentErrorDomain
                                            code:OENilRootProxyObjectError
                                        userInfo:[NSDictionary dictionaryWithObject:NSLocalizedString(@"The root proxy object is nil.", @"Nil root proxy object error reason.") forKey:NSLocalizedFailureReasonErrorKey]];
        }
        return NO;
    }
    
    [(NSDistantObject *)rootProxy setProtocolForProxy:@protocol(OEGameCoreHelper)];
    
    return YES;
}

- (void)endHelperProcess
{
    // kill our background friend
    [helper stopProcess];
    helper = nil;
    
    [rootProxy release];
    rootProxy = nil;
    
    [taskConnection release];
    taskConnection = nil;
}

#pragma mark -
#pragma mark TaskWrapper delegate methods
- (void)appendOutput:(NSString *)output fromProcess:(OETaskWrapper *)aTask
{
    printf("%s", [output UTF8String]);
}    

- (void)processStarted:(OETaskWrapper *)aTask
{
}

- (void)processFinished:(OETaskWrapper *)aTask withStatus:(NSInteger)statusCode
{
}

@end

#pragma mark -
#pragma mark Manager using a background thread

@implementation OEGameCoreThreadManager

- (void)executionThread:(id)object
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    
    taskUUIDForDOServer = [[NSString stringWithUUID] retain];
    
    [[NSThread currentThread] setName:[OEHelperServerNamePrefix stringByAppendingString:taskUUIDForDOServer]];
    
    helperObject = [[[OpenEmuHelperApp alloc] init] autorelease];
    
    if([helperObject launchConnectionWithIdentifierSuffix:taskUUIDForDOServer error:&error])
        CFRunLoopRun();
    else
        [error retain];
    
    [pool drain];
}

- (void)dumpUpperLoop
{
    CFRunLoopStop(CFRunLoopGetCurrent());
}

- (void)stopRunLoop
{
    [helperObject stopEmulation];
    CFRunLoopStop(CFRunLoopGetCurrent());
    
    [self performSelector:@selector(dumpUpperLoop) onThread:[NSThread currentThread] withObject:nil waitUntilDone:NO];
}

- (id<OEGameCoreHelper>)rootProxy
{
    return rootProxy;
}

- (BOOL)startHelperProcessError:(NSError **)outError
{
    helper = [[NSThread alloc] initWithTarget:self selector:@selector(executionThread:) object:nil];
    [helper start];
    
    if(![helper isExecuting])
    {
        [helper release];
        if(outError != NULL)
            *outError = [NSError errorWithDomain:OEGameDocumentErrorDomain
                                            code:OEHelperAppNotRunningError
                                        userInfo:
                         [NSDictionary dictionaryWithObjectsAndKeys:
                          NSLocalizedString(@"The background process couldn't be launched", @"Not running background process error"), NSLocalizedFailureReasonErrorKey,
                          [error autorelease], NSUnderlyingErrorKey,
                          nil]];
        return NO;
    }
    
    // now that we launched the helper, start up our NSConnection for DO object vending and configure it
    // this is however a race condition if our helper process is not fully launched yet. 
    // we hack it out here. Normally this while loop is not noticable, its very fast
    
    NSDate *start = [NSDate date];
    
    taskConnection = nil;
    while(taskConnection == nil)
    {
        taskConnection = [NSConnection connectionWithRegisteredName:[NSString stringWithFormat:@"com.openemu.OpenEmuHelper-%@", taskUUIDForDOServer, nil] host:nil];
        
        if(error != nil && ![helper isExecuting])
        {
            if (outError) *outError = [error autorelease];
            return NO;
        }
        
        if(-[start timeIntervalSinceNow] > 3.0)
        {
            [self endHelperProcess];
            if(outError != NULL)
            {
                *outError = [NSError errorWithDomain:OEGameDocumentErrorDomain
                                                code:OEConnectionTimedOutError
                                            userInfo:[NSDictionary dictionaryWithObject:NSLocalizedString(@"Couldn't connect to the background process.", @"Timed out error reason.") forKey:NSLocalizedFailureReasonErrorKey]];
            }
            return NO;
        }
    }
    
    [taskConnection retain];
    
    if(![taskConnection isValid])
    {
        [self endHelperProcess];
        if(outError != NULL)
        {
            *outError = [NSError errorWithDomain:OEGameDocumentErrorDomain
                                            code:OEInvalidHelperConnectionError
                                        userInfo:[NSDictionary dictionaryWithObject:NSLocalizedString(@"The background process connection couldn't be established", @"Invalid helper connection error reason.") forKey:NSLocalizedFailureReasonErrorKey]];
        }
        return NO;
    }
    
    // now that we have a valid connection...
    rootProxy = [[taskConnection rootProxy] retain];
    if(rootProxy == nil)
    {
        NSLog(@"nil root proxy object?");
        [self endHelperProcess];
        if(outError != NULL)
        {
            *outError = [NSError errorWithDomain:OEGameDocumentErrorDomain
                                            code:OENilRootProxyObjectError
                                        userInfo:[NSDictionary dictionaryWithObject:NSLocalizedString(@"The root proxy object is nil.", @"Nil root proxy object error reason.") forKey:NSLocalizedFailureReasonErrorKey]];
        }
        return NO;
    }
    
    [(NSDistantObject *)rootProxy setProtocolForProxy:@protocol(OEGameCoreHelper)];
    
    return YES;
}

- (void)endHelperProcess
{
    // kill our background friend
    [self performSelector:@selector(stopRunLoop) onThread:helper withObject:nil waitUntilDone:NO];
    
    // Runs the runloop until the helper is actually done to prevent deadlocks if the game core wants the main thread to do stuff...
    while([helperObject isRunning]) CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.1, YES);
    
    [helper release];
    helper = nil;
    
    [rootProxy release];
    rootProxy = nil;
    
    [taskConnection release];
    taskConnection = nil;
}

@end
