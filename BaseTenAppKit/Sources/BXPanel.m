//
// BXPanel.m
// BaseTen
//
// Copyright (C) 2007 Marko Karppinen & Co. LLC.
//
// Before using this software, please review the available licensing options
// by visiting http://www.karppinen.fi/baseten/licensing/ or by contacting
// us at sales@karppinen.fi. Without an additional license, this software
// may be distributed only in compliance with the GNU General Public License.
//
//
// This program is free software; you can redistribute it and/or modify
// it under the terms of the GNU General Public License, version 2.0,
// as published by the Free Software Foundation.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program; if not, write to the Free Software
// Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
//
// $Id$
//

#import "BXPanel.h"


@implementation BXPanel

- (void) beginSheetModalForWindow: (NSWindow *) docWindow modalDelegate: (id) modalDelegate 
				   didEndSelector: (SEL) didEndSelector contextInfo: (void *) contextInfo
{	
	mPanelDidEndSelector = didEndSelector;
	mPanelDelegate = modalDelegate;
	mPanelContextInfo = contextInfo;
	[NSApp beginSheet: self modalForWindow: docWindow modalDelegate: self 
	   didEndSelector: @selector (sheetDidEnd:returnCode:contextInfo:) 
		  contextInfo: NULL];
}

- (void) setLeftOpenOnContinue: (BOOL) aBool
{
    mLeftOpenOnContinue = aBool;
}

- (IBAction) continue: (id) sender
{
    [self continueWithReturnCode: [sender tag]];
}

- (void) sheetDidEnd: (BXPanel *) panel returnCode: (int) returnCode contextInfo: (void *) contextInfo
{
    if (NO == mLeftOpenOnContinue)
        [self continueWithReturnCode: returnCode];
}

- (void) continueWithReturnCode: (int) returnCode;
{
    if (NULL != mPanelDidEndSelector)
	{
		NSMethodSignature* signature = [mPanelDelegate methodSignatureForSelector: mPanelDidEndSelector];
		NSInvocation* invocation = [NSInvocation invocationWithMethodSignature: signature];
		[invocation setSelector: mPanelDidEndSelector];
		[invocation setTarget: mPanelDelegate];
		[invocation setArgument: &self atIndex: 2];
		[invocation setArgument: &returnCode atIndex: 3];
		[invocation setArgument: &mPanelContextInfo atIndex: 4];
		[invocation invoke];
	}
    
    if (NO == mLeftOpenOnContinue)
        [self end];
}

- (void) end
{
    [NSApp endSheet: self];
    //Try to be cautious since we might get released when closed
    [[self retain] autorelease];
    [self close];    
}
@end