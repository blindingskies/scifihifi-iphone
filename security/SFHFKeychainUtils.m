//
//  SFHFKeychainUtils.m
//
//  Created by Buzz Andersen on 10/20/08.
//  Based partly on code by Jonathan Wight, Jon Crosby, and Mike Malone.
//  Copyright 2008 Sci-Fi Hi-Fi. All rights reserved.
//
//  Permission is hereby granted, free of charge, to any person
//  obtaining a copy of this software and associated documentation
//  files (the "Software"), to deal in the Software without
//  restriction, including without limitation the rights to use,
//  copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the
//  Software is furnished to do so, subject to the following
//  conditions:
//
//  The above copyright notice and this permission notice shall be
//  included in all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
//  EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
//  OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
//  NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
//  HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
//  WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
//  FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
//  OTHER DEALINGS IN THE SOFTWARE.
//

#import "SFHFKeychainUtils.h"
#import <Security/Security.h>

#if TARGET_OS_MAC == 1
//
// Security.framework on 10.6 has two issues compared to the iPhone version
// 1. Security.h doesn't include SecItem.h
// 2. kSecClassGenericPassword is not declared in SecItem.h
//

#import <Security/SecItem.h>

//extern const CFTypeRef kSecClassGenericPassword;
extern CFTypeRef kSecClassGenericPassword
    __OSX_AVAILABLE_STARTING(__MAC_NA, __IPHONE_2_0);

#endif // TARGET_OS_MAC

static NSString *SFHFKeychainUtilsErrorDomain = @"SFHFKeychainUtilsErrorDomain";

#if __IPHONE_OS_VERSION_MIN_REQUIRED < 30000 && TARGET_IPHONE_SIMULATOR
@interface SFHFKeychainUtils (PrivateMethods)
+ (SecKeychainItemRef)getKeychainItemReferenceForUsername: (NSString *)username andServiceName: (NSString *)serviceName error: (NSError **)error;
@end
#endif

@implementation SFHFKeychainUtils

#if __IPHONE_OS_VERSION_MIN_REQUIRED < 30000 && TARGET_IPHONE_SIMULATOR

#pragma mark iOS Simulator methods
  //////////////////////////////////////////////////////////////////////
  //
  // Simulator methods
  //
  //////////////////////////////////////////////////////////////////////

+ (NSString *)getPasswordForUsername: (NSString *)username
					  andServiceName: (NSString *)serviceName
						 accessGroup: (NSString *)accessGroupName
							   error: (NSError **)error
{
	if (!username || !serviceName)
	{
		if (nil != error)
		{
			*error = [NSError errorWithDomain: SFHFKeychainUtilsErrorDomain code: -2000 userInfo: nil];
		}
		return nil;
	}
	
	SecKeychainItemRef item = [SFHFKeychainUtils getKeychainItemReferenceForUsername: username andServiceName: serviceName error: error];
	
	if (((error != nil) && (*error != nil)) || !item)
	{
		return nil;
	}
	
	// Ignore the shared keychain access group name. When I have more time I might look into supporting this.
	if (accessGroupName)
	{
		NSLog(@"Warning: accessGroupName is ignored while running in the simulator. Please test on device. Patches welcome.");
	}
	
	// from Advanced Mac OS X Programming, ch. 16
  UInt32 length;
  char *password;
  SecKeychainAttribute attributes[8];
  SecKeychainAttributeList list;
	
  attributes[0].tag = kSecAccountItemAttr;
  attributes[1].tag = kSecDescriptionItemAttr;
  attributes[2].tag = kSecLabelItemAttr;
  attributes[3].tag = kSecModDateItemAttr;
  
  list.count = 4;
  list.attr = attributes;
  
  OSStatus status = SecKeychainItemCopyContent(item, NULL, &list, &length, (void **)&password);
	
	if (status != noErr)
	{
		if (error != nil)
		{
			*error = [NSError errorWithDomain: SFHFKeychainUtilsErrorDomain code: status userInfo: nil];
		}
		return nil;
  }
  
	NSString *passwordString = nil;
	
	if (password != NULL) {
		char passwordBuffer[1024];
		
		if (length > 1023) {
			length = 1023;
		}
		strncpy(passwordBuffer, password, length);
		
		passwordBuffer[length] = '\0';
		passwordString = [NSString stringWithCString: passwordBuffer encoding: NSASCIIStringEncoding];
	}
	
	SecKeychainItemFreeContent(&list, password);
  
  CFRelease(item);
  
  return passwordString;
}


+ (BOOL)storeUsername: (NSString *)username
		  andPassword: (NSString *)password
	   forServiceName: (NSString *)serviceName
		  accessGroup: (NSString *)accessGroupName
	   updateExisting: (BOOL)updateExisting
				error: (NSError **)error
{
	if (!username || !password || !serviceName)
	{
		if (error != nil)
		{
			*error = [NSError errorWithDomain: SFHFKeychainUtilsErrorDomain code: -2000 userInfo: nil];
		}
		return NO;
	}
	
	OSStatus status = noErr;
	
	SecKeychainItemRef item = [SFHFKeychainUtils getKeychainItemReferenceForUsername: username andServiceName: serviceName error: error];
	
	if ((error != nil) && (*error != nil) && ([*error code] != noErr))
	{
		return NO;
	}

	// Ignore the shared keychain access group name. When I have more time I might look into supporting this.
	if (accessGroupName)
	{
		NSLog(@"Warning: accessGroupName is ignored while running in the simulator. Please test on device. Patches welcome.");
	}	

	if (error != nil)
	{
		*error = nil;
	}

	if (item)
	{
		status = SecKeychainItemModifyAttributesAndData(item,
                                                    NULL,
                                                    strlen([password UTF8String]),
                                                    [password UTF8String]);
		
		CFRelease(item);
	}
	else
	{
		status = SecKeychainAddGenericPassword(NULL,                                     
                                           strlen([serviceName UTF8String]), 
                                           [serviceName UTF8String],
                                           strlen([username UTF8String]),                        
                                           [username UTF8String],
                                           strlen([password UTF8String]),
                                           [password UTF8String],
                                           NULL);
	}
	
	if (status != noErr)
	{
		if (error != nil)
		{
			*error = [NSError errorWithDomain: SFHFKeychainUtilsErrorDomain code: status userInfo: nil];
		}
		return NO;
	}
	return YES;
}


+ (BOOL)deleteItemForUsername: (NSString *)username
			   andServiceName: (NSString *)serviceName
				  accessGroup: (NSString *)accessGroupName
						error: (NSError **)error
{
	if (!username || !serviceName)
	{
		if (error != nil)
		{
			*error = [NSError errorWithDomain: SFHFKeychainUtilsErrorDomain code: 2000 userInfo: nil];
		}
		return NO;
	}

	if (error != nil)
	{
		*error = nil;
	}

	SecKeychainItemRef item = [SFHFKeychainUtils getKeychainItemReferenceForUsername: username andServiceName: serviceName error: error];
	
	if ((error != nil) && (*error != nil) && ([*error code] != noErr))
	{
		return NO;
	}

	// Ignore the shared keychain access group name. When I have more time I might look into supporting this.
	if (accessGroupName)
	{
		NSLog(@"Warning: accessGroupName is ignored while running in the simulator. Please test on device. Patches welcome.");
	}		

	if (item)
	{
		OSStatus status = SecKeychainItemDelete(item);
		CFRelease(item);

		if (status != noErr)
		{
			if (error != nil)
			{
				*error = [NSError errorWithDomain: SFHFKeychainUtilsErrorDomain code: status userInfo: nil];            
				return NO;
			}
		}
	}
	return YES;
}


+ (SecKeychainItemRef)getKeychainItemReferenceForUsername: (NSString *)username andServiceName: (NSString *)serviceName error: (NSError **)error
{
	if (!username || !serviceName)
	{
		if (error != nil)
		{
			*error = [NSError errorWithDomain: SFHFKeychainUtilsErrorDomain code: -2000 userInfo: nil];
		}
		return nil;
	}

	if (error != nil)
	{
		*error = nil;
	}

	SecKeychainItemRef item;
	
	OSStatus status = SecKeychainFindGenericPassword(NULL,
                                                   strlen([serviceName UTF8String]),
                                                   [serviceName UTF8String],
                                                   strlen([username UTF8String]),
                                                   [username UTF8String],
                                                   NULL,
                                                   NULL,
                                                   &item);
	
	if (status != noErr)
	{
		if (status != errSecItemNotFound)
		{
			if (error != nil)
			{
				*error = [NSError errorWithDomain: SFHFKeychainUtilsErrorDomain code: status userInfo: nil];
			}
		}
		return nil;		
	}
	return item;
}

#else

#pragma mark iOS Real Device Methods
  //////////////////////////////////////////////////////////////////////
  //
  // iOS Device methods
  //
  //////////////////////////////////////////////////////////////////////

+ (NSString *)getPasswordForUsername: (NSString *)username
					  andServiceName: (NSString *)serviceName
						 accessGroup: (NSString *)accessGroupName
							   error: (NSError **)error
{
	if (!username || !serviceName)
	{
		if (error != nil)
		{
			*error = [NSError errorWithDomain: SFHFKeychainUtilsErrorDomain code: -2000 userInfo: nil];
		}
		return nil;
	}
	
	if (error != nil)
	{
		*error = nil;
	}
  
	// Set up a query dictionary with the base query attributes: item type (generic), username, and service
	NSArray *keys = [[[NSArray alloc] initWithObjects: (NSString *) kSecClass, kSecAttrAccount, kSecAttrService, nil] autorelease];
	NSArray *objects = [[[NSArray alloc] initWithObjects: (NSString *) kSecClassGenericPassword, username, serviceName, nil] autorelease];
	
	NSDictionary *query = [[[NSDictionary alloc] initWithObjects: objects forKeys: keys] autorelease];
	
	// First do a query for attributes, in case we already have a Keychain item with no password data set.
	// One likely way such an incorrect item could have come about is due to the previous (incorrect)
	// version of this code (which set the password as a generic attribute instead of password data).
	
	NSDictionary *attributeResult = NULL;
	NSMutableDictionary *attributeQuery = [query mutableCopy];
	[attributeQuery setObject: (id)kCFBooleanTrue forKey: (id)kSecReturnAttributes];

	// Check if there's a shared keychain access group name provided and set it appropriately.
	if (accessGroupName)
	{
//		NSLog(@"Adding access group.");
		[attributeQuery setObject: (id)accessGroupName forKey: (id)kSecAttrAccessGroup];
	}

	OSStatus status = SecItemCopyMatching((CFDictionaryRef)attributeQuery, (CFTypeRef *)&attributeResult);
	
	[attributeResult release];
	[attributeQuery release];
	
	if (status != noErr)
	{
		// No existing item found--simply return nil for the password
		if (error != nil && status != errSecItemNotFound)
		{
			//Only return an error if a real exception happened--not simply for "not found."
			*error = [NSError errorWithDomain: SFHFKeychainUtilsErrorDomain code: status userInfo: nil];
		}
		return nil;
	}
	
	// We have an existing item, now query for the password data associated with it.
	
	NSData *resultData = nil;
	NSMutableDictionary *passwordQuery = [query mutableCopy];
	[passwordQuery setObject: (id) kCFBooleanTrue forKey: (id) kSecReturnData];

	status = SecItemCopyMatching((CFDictionaryRef)passwordQuery, (CFTypeRef *)&resultData);

	[resultData autorelease];
	[passwordQuery release];
	
	if (status != noErr)
	{
		if (status == errSecItemNotFound)
		{
			// We found attributes for the item previously, but no password now, so return a special error.
			// Users of this API will probably want to detect this error and prompt the user to
			// re-enter their credentials.  When you attempt to store the re-entered credentials
			// using storeUsername:andPassword:forServiceName:updateExisting:error
			// the old, incorrect entry will be deleted and a new one with a properly encrypted
			// password will be added.
			if (error != nil)
			{
				*error = [NSError errorWithDomain: SFHFKeychainUtilsErrorDomain code: -1999 userInfo: nil];
			}
		}
		else
		{
			// Something else went wrong. Simply return the normal Keychain API error code.
			if (error != nil)
			{
				*error = [NSError errorWithDomain: SFHFKeychainUtilsErrorDomain code: status userInfo: nil];
			}
		}
		
		return nil;
	}
  
	NSString *password = nil;	
  
	if (resultData)
	{
		password = [[NSString alloc] initWithData: resultData encoding: NSUTF8StringEncoding];
	}
	else
	{
		// There is an existing item, but we weren't able to get password data for it for some reason,
		// Possibly as a result of an item being incorrectly entered by the previous code.
		// Set the -1999 error so the code above us can prompt the user again.
		if (error != nil)
		{
			*error = [NSError errorWithDomain: SFHFKeychainUtilsErrorDomain code: -1999 userInfo: nil];
		}
	}
	return [password autorelease];
}


+ (BOOL)storeUsername: (NSString *)username
		  andPassword: (NSString *)password
	   forServiceName: (NSString *)serviceName
		  accessGroup: (NSString *)accessGroupName
	   updateExisting: (BOOL)updateExisting
				error: (NSError **)error 
{
	NSError				*getError = nil;
	NSString			*existingPassword;

	if (!username || !password || !serviceName) 
	{
		if (error != nil) 
		{
			*error = [NSError errorWithDomain: SFHFKeychainUtilsErrorDomain code: -2000 userInfo: nil];
		}
		return NO;
	}
	
	// See if we already have a password entered for these credentials.
	existingPassword = [SFHFKeychainUtils getPasswordForUsername: username
												  andServiceName: serviceName
													 accessGroup: accessGroupName
														   error: &getError];
	if ([getError code] == -1999) 
	{
		// There is an existing entry without a password properly stored (possibly as a result of the previous incorrect version of this code.
		// Delete the existing item before moving on entering a correct one.
		getError = nil;
		[self deleteItemForUsername: username andServiceName: serviceName accessGroup: accessGroupName error: &getError];
		if ([getError code] != noErr) 
		{
			if (error != nil) 
			{
				*error = getError;
			}
			return NO;
		}
	}
	else if ([getError code] != noErr) 
	{
		if (error != nil) 
		{
			*error = getError;
		}
		return NO;
	}

	if (error != nil) 
	{
		*error = nil;
	}

	OSStatus status = noErr;
  
	if (existingPassword) 
	{
		// We have an existing, properly entered item with a password.
		// Update the existing item.
		
		if (![existingPassword isEqualToString:password] && updateExisting) 
		{
			//Only update if we're allowed to update existing.  If not, simply do nothing.
			
			NSArray *keys = [[[NSArray alloc] initWithObjects: (NSString *) kSecClass, 
                        kSecAttrService, 
                        kSecAttrLabel, 
                        kSecAttrAccount, 
                        nil] autorelease];
			
			NSArray *objects = [[[NSArray alloc] initWithObjects: (NSString *) kSecClassGenericPassword, 
                           serviceName,
                           serviceName,
                           username,
                           nil] autorelease];
			
			NSDictionary *query = [[[NSDictionary alloc] initWithObjects: objects forKeys: keys] autorelease];			

			NSMutableDictionary *mutableQuery = [query mutableCopy];

			// Check if there's a shared keychain access group name provided and set it appropriately.
			if (accessGroupName)
			{
//				NSLog(@"Adding access group.");
				
				[mutableQuery setObject:(id)accessGroupName forKey:(id)kSecAttrAccessGroup];
			}
			
			status = SecItemUpdate((CFDictionaryRef)mutableQuery, (CFDictionaryRef)[NSDictionary dictionaryWithObject: [password dataUsingEncoding: NSUTF8StringEncoding] forKey: (NSString *)kSecValueData]);
            
            [mutableQuery release];
		}
	}
	else 
	{
		// No existing entry (or an existing, improperly entered, and therefore now
		// deleted, entry).  Create a new entry.
		NSArray *keys = [[[NSArray alloc] initWithObjects: (NSString *) kSecClass, 
                      kSecAttrService, 
                      kSecAttrLabel, 
                      kSecAttrAccount, 
                      kSecValueData, 
                      nil] autorelease];
		
		NSArray *objects = [[[NSArray alloc] initWithObjects: (NSString *) kSecClassGenericPassword, 
                         serviceName,
                         serviceName,
                         username,
                         [password dataUsingEncoding: NSUTF8StringEncoding],
                         nil] autorelease];
		
		NSDictionary *query = [[[NSDictionary alloc] initWithObjects: objects forKeys: keys] autorelease];			

		NSMutableDictionary *mutableQuery = [query mutableCopy];

		// Check if there's a shared keychain access group name provided and set it appropriately.
		if (accessGroupName)
		{
//			NSLog(@"getPasswordForUsername: adding access group.");
			[mutableQuery setObject:accessGroupName forKey:(id)kSecAttrAccessGroup];
		}

		status = SecItemAdd((CFDictionaryRef) mutableQuery, NULL);
        
        [mutableQuery release];
	}
	
	if (error != nil && status != noErr) 
	{
		// Something went wrong with adding the new item. Return the Keychain error code.
		*error = [NSError errorWithDomain: SFHFKeychainUtilsErrorDomain code: status userInfo: nil];
		return NO;
	}
	return YES;
}


+ (BOOL)deleteItemForUsername: (NSString *)username
			   andServiceName: (NSString *)serviceName
				  accessGroup: (NSString *)accessGroupName
						error: (NSError **)error 
{
	if (!username || !serviceName) 
	{
		if (error != nil) 
		{
			*error = [NSError errorWithDomain: SFHFKeychainUtilsErrorDomain code: -2000 userInfo: nil];
		}
		return NO;
	}
	
	if (error != nil) 
	{
		*error = nil;
	}
  
	NSArray *keys = [[[NSArray alloc] initWithObjects: (NSString *) kSecClass, kSecAttrAccount, kSecAttrService, kSecReturnAttributes, nil] autorelease];
	NSArray *objects = [[[NSArray alloc] initWithObjects: (NSString *) kSecClassGenericPassword, username, serviceName, kCFBooleanTrue, nil] autorelease];
	
	NSDictionary *query = [[[NSDictionary alloc] initWithObjects: objects forKeys: keys] autorelease];
	
	NSMutableDictionary *mutableQuery = [query mutableCopy];
	
	// Check if there's a shared keychain access group name provided and set it appropriately.
	if (accessGroupName)
	{
		NSLog(@"getPasswordForUsername: adding access group.");
		[mutableQuery setObject:accessGroupName forKey:(id)kSecAttrAccessGroup];
	}	
	
	OSStatus status = SecItemDelete((CFDictionaryRef) mutableQuery);
	
    [mutableQuery release];
    
	if (error != nil && status != noErr) 
	{
		*error = [NSError errorWithDomain: SFHFKeychainUtilsErrorDomain code: status userInfo: nil];		
		return NO;
	}
	return YES;
}

#endif

@end