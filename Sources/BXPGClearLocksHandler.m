//
// BXPGClearLocksHandler.m
// BaseTen
//
// Copyright (C) 2006-2008 Marko Karppinen & Co. LLC.
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

#import "BXPGClearLocksHandler.h"
#import "BXDatabaseObjectIDPrivate.h"
#import "BXLogger.h"
#import "PGTSAdditions.h"
#import "PGTSHOM.h"


static void
bx_error_during_clear_notification (id self, NSError* error)
{
	BXLogWarning (@"During clear notification: %@", error);
}


@implementation BXPGClearLocksHandler
+ (NSString *) notificationName
{
	return @"baseten.ClearedLocks";
}

- (void) handleNotification: (PGTSNotification *) notification
{
	PGTSResultSet* xactRes = nil;
	NSError* error = nil;

	xactRes = [mConnection executeQuery: @"BEGIN"];
	if (! [xactRes querySucceeded]) 
	{
		error = [xactRes error];
		goto error;
	}
	
	int backendPID = [mConnection backendPID];
	NSArray* oids = [mInterface observedOids];
    
    //Which tables have pending locks?
    NSString* query = 
	@"SELECT baseten_lock_relid, "
	@"   max (baseten_lock_timestamp) AS last_date, "
	@"   baseten.locktablename (baseten_lock_relid) AS lock_table_name "
	@" FROM baseten.lock "
	@" WHERE baseten_lock_cleared = true "
	@"  AND baseten_lock_timestamp > $1 " 
	@"  AND baseten_lock_backend_pid != $2 "
	@"  AND baseten_lock_relid = ANY ($3) "
	@" GROUP BY baseten_lock_relid";
    PGTSResultSet* res = [mConnection executeQuery: query parameters: mLastCheck, [NSNumber numberWithInt: backendPID], oids];
    if (NO == [res querySucceeded])
	{
		error = [res error];
		goto error;
	}
    
	//Update the timestamp.
	while ([res advanceRow]) 
		[self setLastCheck: [res valueForKey: @"last_date"]];	
	
	//Hopefully not too many tables, because we need to get unlocked rows for each of them.
	//We can't union the queries, either, because the primary key fields differ.
	NSMutableArray* ids = [NSMutableArray array];
	BXDatabaseContext* ctx = [mInterface databaseContext];
	while ([res advanceRow])
	{
		[ids removeAllObjects];
		NSString* query = nil;
		NSNumber* relid = [res valueForKey: @"baseten_lock_relid"];
		PGTSTableDescription* table = [[mConnection databaseDescription] tableWithOid: [relid PGTSOidValue]];
		
		{
			NSString* queryFormat =
			@"SELECT DISTINCT ON (%@) l.* "
			@"FROM %@ l NATURAL INNER JOIN %@ "
			@"WHERE baseten_lock_cleared = true "
			@" AND baseten_lock_backend_pid != $1 "
			@" AND baseten_lock_timestamp > $2 ";
						
			//Primary key field names.
			NSArray* pkeyfnames = (id) [[[[[table primaryKey] fields] allObjects] PGTSCollect] BXPGEscapedName: mConnection];
			NSString* pkeystr = [pkeyfnames componentsJoinedByString: @", "];
			
			//Table names.
			NSString* lockTableName = [res valueForKey: @"lock_table_name"];
			NSString* tableName = [table BXPGQualifiedName: mConnection];
			
			query = [NSString stringWithFormat: queryFormat, pkeystr, lockTableName, tableName];
		}
		
		{
			PGTSResultSet* unlockedRows = [mConnection executeQuery: query parameters: relid, mLastCheck];
			if (! [unlockedRows querySucceeded])
			{
				error = [unlockedRows error];
				goto error;
			}

			//Get the entity.
			NSString* tableName = [table name];
			NSString* schemaName = [table schemaName];
			BXEntityDescription* entity = [ctx entityForTable: tableName inSchema: schemaName error: &error];
			if (! entity) goto error;
			
			while ([unlockedRows advanceRow])
			{
				NSDictionary* row = [unlockedRows currentRowAsDictionary];
				BXDatabaseObjectID* anID = [BXDatabaseObjectID IDWithEntity: entity primaryKeyFields: row];
				[ids addObject: anID];
			}
		}
		
		//Only one entity allowed per array.
		[[mInterface databaseContext] unlockedObjectsInDatabase: ids];
	}
	xactRes = [mConnection executeQuery: @"COMMIT"];
	if (! [xactRes querySucceeded])
	{
		error = [xactRes error];
		goto error;
	}
    
	return;
	
error:
	[mConnection executeQuery: @"ROLLBACK"];
	bx_error_during_clear_notification (self, error);
}
@end
