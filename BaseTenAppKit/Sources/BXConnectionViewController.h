//
// BXConnectionViewController.h
// BaseTen
//
// Copyright (C) 2009 Marko Karppinen & Co. LLC.
//
// Before using this software, please review the available licensing options
// by visiting http://basetenframework.org/licensing/ or by contacting
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

@protocol BXConnectionViewControllerDelegate <NSObject>
- (void) connectionViewControllerOtherButtonClicked: (id) controller;
- (void) connectionViewControllerCancelButtonClicked: (id) controller;
- (void) connectionViewControllerConnectButtonClicked: (id) controller;
@end


@interface BXConnectionViewController : NSObject
{
	id <BXConnectionViewControllerDelegate> mDelegate; //Weak
	IBOutlet NSView* mView;
	IBOutlet NSButton* mOtherButton;
	IBOutlet NSButtonCell* mCancelButton;
	IBOutlet NSButtonCell* mConnectButton;
	IBOutlet NSProgressIndicator* mProgressIndicator;
	IBOutlet NSResponder* mInitialFirstResponder;
	NSSize mViewSize;
	BOOL mConnecting;
	BOOL mCanCancel;
}
- (NSView *) view;
- (NSSize) viewSize;
- (NSResponder *) initialFirstResponder;

- (NSString *) host;
- (NSInteger) port;

- (void) setDelegate: (id <BXConnectionViewControllerDelegate>) object;
- (void) setCanCancel: (BOOL) aBool;
- (BOOL) canCancel;
- (void) setConnecting: (BOOL) aBool;
- (BOOL) isConnecting;

- (IBAction) otherButtonClicked: (id) sender;
- (IBAction) cancelButtonClicked: (id) sender;
- (IBAction) connectButtonClicked: (id) sender;
@end
