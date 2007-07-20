//
// BXDatabaseObjectID.m
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

#import "BXDatabaseObjectID.h"
#import "BXDatabaseObjectIDPrivate.h"
#import "BXDatabaseAdditions.h"
#import "BXEntityDescription.h"
#import "BXEntityDescriptionPrivate.h"
#import "BXDatabaseContext.h"
#import "BXInterface.h"
#import "BXAttributeDescription.h"
#import "BXDatabaseObject.h"
#import "BXDatabaseObjectPrivate.h"
#import "BXAttributeDescriptionPrivate.h"

#import <Log4Cocoa/Log4Cocoa.h>
#import <TSDataTypes/TSDataTypes.h>


static TSNonRetainedObjectSet* gObjectIDs;


/**
 * A unique identifier for a database object.
 * This class is not thread-safe, i.e. 
 * if methods of a BXDatabaseObjectID instance will be called from 
 * different threads the result is undefined.
 */
@implementation BXDatabaseObjectID

+ (void) initialize
{
    static BOOL tooLate = NO;
    if (NO == tooLate)
    {
        tooLate = YES;
        gObjectIDs = [[TSNonRetainedObjectSet alloc] init];
    }
}

/** 
 * Create an object identifier from an NSURL
 * \note This is not the designated initializer.
 */
- (id) initWithURI: (NSURL *) anURI context: (BXDatabaseContext *) context error: (NSError **) error
{
    id rval = nil;
    NSError* localError = nil;
    NSString* absoluteURI = [anURI absoluteString];
    NSString* query = [anURI query];
    NSString* path = [anURI path];
    
    NSArray* pathComponents = [path pathComponents];
    unsigned int count = [pathComponents count];
    NSString* tableName = [pathComponents objectAtIndex: count - 1];
    NSString* schemaName = [pathComponents objectAtIndex: count - 2];
    NSString* dbAddress = [absoluteURI substringToIndex: [absoluteURI length] - ([tableName length] + 1 + [query length])];
    //FIXME: object address and context address should be compared.
    dbAddress = nil; //Suppress a warning

    BXEntityDescription* entityDesc = [context entityForTable: tableName inSchema: schemaName error: &localError];
    if (nil != localError) goto bail;
	if (NO == [entityDesc isValidated])
	{
		[context connectIfNeeded: &localError];
		if (nil != localError) goto bail;
	}
    
	NSMutableDictionary* pkeyDict = [NSMutableDictionary dictionary];
	NSScanner* queryScanner = [NSScanner scannerWithString: query];
	while (NO == [queryScanner isAtEnd])
	{
		NSString* key = nil;
		NSString* type = nil;
		id value = nil;
		
		[queryScanner scanUpToString: @"," intoString: &key];
		[queryScanner scanString: @"," intoString: NULL];
		[queryScanner scanUpToString: @"=" intoString: &type];
		[queryScanner scanString: @"=" intoString: NULL];
		
		unichar c = [type characterAtIndex: 0];
		switch (c)
		{
			case 's':
				[queryScanner scanUpToString: @"&" intoString: &value];
				break;
			case 'n':
			{
				NSDecimal dec;
				[queryScanner scanDecimal: &dec];
				value = [NSDecimalNumber decimalNumberWithDecimal: dec];
				break;
			}
			case 'd':
			default:
			{
				NSString* encodedString = nil;
				[queryScanner scanUpToString: @"&" intoString: &encodedString];
				NSData* archivedData = [encodedString BXURLDecodedData];
				value = [NSUnarchiver unarchiveObjectWithData: archivedData];
				break;
			}
		}	
		log4AssertValueReturn ([entityDesc isValidated], nil, @"Expected entity %@ to have been validated earlier.", entityDesc);
		[pkeyDict setObject: value forKey: key];
		
		[queryScanner scanUpToString: @"&" intoString: NULL];
		[queryScanner scanString: @"&" intoString: NULL];
	}
	rval = [self initWithEntity: entityDesc primaryKeyFields: pkeyDict];
	return rval;
	
bail:
	{
		BXHandleError (error, localError);
		return nil;
	}
}

- (NSString *) description
{
    NSString* rval = nil;
    @synchronized (mPkeyFValues)
    {
        rval = [NSString stringWithFormat: @"%@ (%p) e: %@ pkeyFV: %@", [self class], self, mEntity, mPkeyFValues];
    }
    return rval;
}

- (void) dealloc
{
    if (YES == mRegistered)
    {
        [gObjectIDs removeObject: self];
        [mEntity unregisterObjectID: self];
    }
    
    [mURIRepresentation release];
    [mEntity release];
    @synchronized (mPkeyFValues)
    {
        [mPkeyFValues release];
    }
    [super dealloc];
}

/** The entity of the receiver. */
- (BXEntityDescription *) entity
{
    return mEntity;
}

/** URI representation of the receiver. */
- (NSURL *) URIRepresentation
{
    if (nil == mURIRepresentation)
    {
        NSURL* databaseURI = [mEntity databaseURI];
        NSMutableArray* parts = nil;
        @synchronized (mPkeyFValues)
        {
            parts = [NSMutableArray arrayWithCapacity: [mPkeyFValues count]];
            NSArray* keys = [mPkeyFValues keysSortedByValueUsingSelector: @selector (compare:)];
            TSEnumerate (currentKey, e, [keys objectEnumerator])
            {
                id currentValue = [mPkeyFValues objectForKey: currentKey];
                NSString* valueForURL = @"";
                char argtype = 'd';
                //NSStrings and NSNumbers get a special treatment
                if ([currentValue isKindOfClass: [NSString class]])
                {
                    valueForURL = currentValue;
                    argtype = 's';
                }
                else if ([currentValue isKindOfClass: [NSNumber class]])
                {
                    valueForURL = [currentValue stringValue];
                    argtype = 'n';
                }
                else
                {
                    //Just use NSData
                    valueForURL = [NSString BXURLEncodedData: [NSArchiver archivedDataWithRootObject: currentValue]];            
                }
                
                [parts addObject: [NSString stringWithFormat: @"%@,%c=%@", 
                    [currentKey stringByAddingPercentEscapesUsingEncoding: NSUTF8StringEncoding],
                    argtype, valueForURL]];
            }
        }
        NSString* absolutePath = [[NSString stringWithFormat: @"/%@/%@/%@?",
            [databaseURI path],
            [[mEntity schemaName] stringByAddingPercentEscapesUsingEncoding: NSUTF8StringEncoding],
            [[mEntity name] stringByAddingPercentEscapesUsingEncoding: NSUTF8StringEncoding]] stringByStandardizingPath];
        absolutePath = [absolutePath stringByAppendingString: [parts componentsJoinedByString: @"&"]];
            
        mURIRepresentation = [[[NSURL URLWithString: absolutePath relativeToURL: databaseURI] 
            absoluteURL] retain];
    }
    return mURIRepresentation;
}

- (unsigned int) hash
{
    if (0 == mHash)
    {
        mHash = [mEntity hash];
        @synchronized (mPkeyFValues)
        {
            TSEnumerate (currentValue, e, [mPkeyFValues objectEnumerator])
                mHash ^= [currentValue hash];
        }
    }
    return mHash;
}

/** 
 * An NSPredicate for this object ID.
 * The predicate can be used to fetch the object from the database, for example.
 */
- (NSPredicate *) predicate
{
    NSPredicate* predicate = nil;
    NSMutableArray* predicates = nil;
	NSDictionary* attributes = [mEntity attributesByName];
    @synchronized (mPkeyFValues)
    {
        predicates = [NSMutableArray arrayWithCapacity: [mPkeyFValues count]];
        TSEnumerate (currentKey, e, [mPkeyFValues keyEnumerator])
        {
            NSExpression* rhs = [NSExpression expressionForConstantValue: [mPkeyFValues objectForKey: currentKey]];
            NSExpression* lhs = [NSExpression expressionForConstantValue: [attributes objectForKey: currentKey]];
            NSPredicate* predicate = 
                [NSComparisonPredicate predicateWithLeftExpression: lhs
                                                   rightExpression: rhs
                                                          modifier: NSDirectPredicateModifier
                                                              type: NSEqualToPredicateOperatorType
                                                           options: 0];
            [predicates addObject: predicate];
        }
    }
    if (0 < [predicates count])
        predicate = [NSCompoundPredicate andPredicateWithSubpredicates: predicates];
    return predicate;
}

- (BOOL) isEqual: (id) anObject
{
    BOOL rval = NO;
    if (NO == [anObject isKindOfClass: [BXDatabaseObjectID class]])
        rval = [super isEqual: anObject];
    else
    {
        BXDatabaseObjectID* anId = (BXDatabaseObjectID *) anObject;
        if (0 == anId->mHash || 0 == mHash || anId->mHash == mHash)
        {
            @synchronized (mPkeyFValues)
            {
                rval = ([mEntity isEqual: anId->mEntity] && 
                        [mPkeyFValues isEqualToDictionary: anId->mPkeyFValues]);
            }
        }
    }
    return rval;
}

/**
 * Primary key field names.
 * This method is thread-safe.
 * \return      An NSArray of NSStrings
 */
- (NSArray *) primaryKeyFieldNames;
{
    id rval = nil;
    @synchronized (mPkeyFValues)
    {
        rval = [mPkeyFValues allKeys];
    }
    return rval;
}

/**
 * Values for the primary key fields.
 * This method is thread-safe.
 * \return      An NSDictionary with NSStrings as keys.
 */
- (NSDictionary *) primaryKeyFieldValues;
{
    id rval = nil;
    @synchronized (mPkeyFValues)
    {
        rval = [[mPkeyFValues copy] autorelease];
    }
    return rval;
}

- (id) valueForUndefinedKey: (NSString *) aKey
{
    //Don't call super's implementation since it raises an exception and
    //we don't want that even if nil gets returned
    
    id rval = nil;
    @synchronized (mPkeyFValues)
    {
        rval = [mPkeyFValues objectForKey: aKey];
    }
    return rval;
}

/**
 * Primary key field value for the given key.
 * This method is thread-safe.
 * \param       aKey        A BXPropertyDescription
 */
- (id) objectForKey: (id) aKey
{
    id retval = nil;
	//FIXME: lock for entity as well?
	if (mEntity == [aKey entity])
	{
		@synchronized (mPkeyFValues)
		{
			retval = [mPkeyFValues objectForKey: [aKey name]];
		}
	}
    return retval;
}

- (NSDictionary *) allObjects
{
	NSMutableDictionary* retval = nil;
	NSDictionary* attributes = [mEntity attributesByName];
	@synchronized (mPkeyFValues)
	{
		retval = [NSMutableDictionary dictionaryWithCapacity: [mPkeyFValues count]];
		TSEnumerate (currentKey, e, [mPkeyFValues keyEnumerator])
			[retval setObject: [mPkeyFValues objectForKey: currentKey] forKey: [attributes objectForKey: currentKey]];
	}
	
	return retval;
}

@end


@implementation BXDatabaseObjectID (NSCopying)
/** Retain on copy. */
- (id) copyWithZone: (NSZone *) zone
{
    return [self retain];
}
@end


@implementation BXDatabaseObjectID (PrivateMethods)
/** 
 * \internal
 * \name Creating object IDs */
//@{
/** A convenience method */
+ (id) IDWithEntity: (BXEntityDescription *) aDesc primaryKeyFields: (NSDictionary *) aDict
{
    return [[[self class] alloc] initWithEntity: aDesc primaryKeyFields: aDict];
}

/** 
 * \internal
 * The designated initializer.
 * \param   aDesc   The entity.
 * \param   aDict   An NSDictionary in which the keys are NSStrings.
 * \throw   NSException named NSInternalInconsistencyException in case some of the required 
 *          parameters were missing or invalid.
 */
- (id) initWithEntity: (BXEntityDescription *) aDesc primaryKeyFields: (NSDictionary *) aDict
{
    if ((self = [super init]))
    {
		NSString* reason = nil;
        if (nil == aDesc)
			reason = @"Entity was nil.";
		else if (0 == [aDict count])
			reason = @"Primary key values were not set.";
		
		TSEnumerate (currentDesc, e, [aDict keyEnumerator])
		{
			if (NO == [currentDesc isKindOfClass: [NSString class]])
			{
				reason = @"Expected to receive only NSStrings as keys.";
				break;
			}
		}
		
		if (nil != reason)
        {
            NSDictionary* userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
                self,   kBXObjectIDKey,
                aDesc,  kBXEntityDescriptionKey,
                aDict,  kBXPrimaryKeyFieldsKey,
                nil];
            NSException* exception = [NSException exceptionWithName: NSInternalInconsistencyException
                                                             reason: reason
                                                           userInfo: userInfo];
            [exception raise];
        }
        
        mRegistered = NO;
        mHash = 0;
        mEntity = [aDesc copy];
        mPkeyFValues = [aDict mutableCopy];
        mLastModificationType = kBXNoModification;
        
        //Only single instance allowed
        id anID = [gObjectIDs member: self];
        log4AssertValueReturn ([gObjectIDs containsObject: self] ? nil != anID : YES, nil,
							   @"gObjectIDs contains the current objectID but it could not be found."
							   " \n\tself: \t%@ \n\tgObjectIDs: \t%@",
							   self, gObjectIDs);
        if (nil == anID)
        {
            [gObjectIDs addObject: self];
            mRegistered = YES;
            [mEntity registerObjectID: self];
        }
        else
        {
            [self release];
            self = [anID retain];
        }
    }
    return self;
}
//@}

- (id) init
{
    //We need either an URI or an entity and primary key fields
    [self release];
    return nil;
}

- (void) replaceValuesWith: (NSDictionary *) aDict
{
    @synchronized (mPkeyFValues)
    {
        [mPkeyFValues addEntriesFromDictionary: aDict];
    }
}

- (void) setLastModificationType: (enum BXModificationType) aType
{
    mLastModificationType = aType;
}

- (enum BXModificationType) lastModificationType
{
    return mLastModificationType;
}

#if 0
- (BXDatabaseObjectID *) partialKeyForView: (BXEntityDescription *) view
{
    log4AssertValueReturn ([view isView], nil, @"Expected given entity (%@) to be a view.", view);
    
    NSArray* keys = [view primaryKeyFields];
    NSArray* myKeys = [[self entity] correspondingProperties: keys];
    NSArray* values = [self objectsForKeys: myKeys];
    return [[self class] IDWithEntity: view primaryKeyFields: [NSDictionary dictionaryWithObjects: values forKeys: keys]];
}
#endif

- (void) setStatus: (enum BXObjectDeletionStatus) status forObjectRegisteredInContext: (BXDatabaseContext *) context
{
	[[context registeredObjectWithID: self] setDeleted: status];
}
@end
