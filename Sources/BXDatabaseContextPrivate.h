//
// BXDatabaseContextPrivate.h
// BaseTen
//
// Copyright (C) 2006 Marko Karppinen & Co. LLC.
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

#import <BaseTen/BaseTen.h>


extern void BXInit ();


@interface BXDatabaseContext (PrivateMethods)
/* Moved from the context. */
- (BOOL) executeUpdateObject: (BXDatabaseObject *) anObject key: (id) aKey value: (id) aValue error: (NSError **) error;
- (BOOL) executeUpdateObject: (BXDatabaseObject *) anObject withDictionary: (NSDictionary *) aDict error: (NSError **) error;
- (NSArray *) executeUpdateEntity: (BXEntityDescription *) anEntity withDictionary: (NSDictionary *) aDict 
                        predicate: (NSPredicate *) predicate error: (NSError **) error;
- (BOOL) executeDeleteFromEntity: (BXEntityDescription *) anEntity withPredicate: (NSPredicate *) predicate 
                           error: (NSError **) error;

/* Especially these need some attention before moving to a public header. */
- (void) lockObject: (BXDatabaseObject *) object key: (id) key status: (enum BXObjectStatus) status
             sender: (id <BXObjectAsynchronousLocking>) sender;
- (void) unlockObject: (BXDatabaseObject *) anObject key: (id) aKey;

/* Really internal. */
- (id) executeFetchForEntity: (BXEntityDescription *) entity 
               withPredicate: (NSPredicate *) predicate 
             returningFaults: (BOOL) returnFaults 
             excludingFields: (NSArray *) excludedFields 
               returnedClass: (Class) returnedClass 
                       error: (NSError **) error;
- (NSArray *) executeUpdateObject: (BXDatabaseObject *) anObject entity: (BXEntityDescription *) anEntity 
                        predicate: (NSPredicate *) predicate withDictionary: (NSDictionary *) aDict 
                            error: (NSError **) error;
- (NSArray *) executeDeleteObject: (BXDatabaseObject *) anObject 
                           entity: (BXEntityDescription *) entity
                        predicate: (NSPredicate *) predicate
                            error: (NSError **) error;
- (void) validateEntity: (BXEntityDescription *) anEntity;
@end
