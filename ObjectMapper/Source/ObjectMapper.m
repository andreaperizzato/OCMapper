//
//  ObjectMapper.m
//  iFollow
//
//  Created by Aryan Gh on 4/14/13.
//  Copyright (c) 2013 Aryan Gh. All rights reserved.
//

#import "ObjectMapper.h"

#define KEY_FOR_ARRAY_OF_OBJECT_MAPPING_INFOS @"objectMappingInfos"

@interface ObjectMapper()
@property (nonatomic, strong) NSMutableDictionary *mappingDictionary;
@end

@implementation ObjectMapper
@synthesize mappingDictionary;

#pragma mark - initialization -

+ (ObjectMapper *)sharedInstance
{
	static ObjectMapper *singleton;
	static dispatch_once_t onceToken;
	
	dispatch_once(&onceToken, ^{
		singleton = [[ObjectMapper alloc] init];
	});
	
	return singleton;
}

- (id)init
{
	if (self = [super init])
	{
		self.mappingDictionary = [NSMutableDictionary dictionary];
	}
	
	return self;
}

#pragma mark - Public Methods -

- (void)mapFromDictionaryKey:(NSString *)dictionaryKey toPropertyKey:(NSString *)propertyKey withObjectType:(Class)objectType forClass:(Class)class
{
	NSMutableDictionary *mappingForClass = [self.mappingDictionary objectForKey:NSStringFromClass(class)];
	
	if (!mappingForClass)
	{
		mappingForClass = [NSMutableDictionary dictionary];
		[mappingForClass setObject:[NSMutableArray array] forKey:KEY_FOR_ARRAY_OF_OBJECT_MAPPING_INFOS];
	}
	
	NSMutableArray *objectMappingInfos = [mappingForClass objectForKey:KEY_FOR_ARRAY_OF_OBJECT_MAPPING_INFOS];
	ObjectMappingInfo *info = [[ObjectMappingInfo alloc] initWithDictionaryKey:dictionaryKey propertyKey:propertyKey andObjectType:objectType];
	[objectMappingInfos addObject:info];
	
	[self.mappingDictionary setObject:mappingForClass forKey:NSStringFromClass(class)];
}

- (void)mapFromDictionaryKey:(NSString *)dictionaryKey toPropertyKey:(NSString *)propertyKey forClass:(Class)class
{
	[self mapFromDictionaryKey:dictionaryKey toPropertyKey:propertyKey withObjectType:nil forClass:class];
}

- (id)objectFromSource:(id)source toInstanceOfClass:(Class)class
{
	if ([source isKindOfClass:[NSDictionary class]])
	{
		return [self processDictionary:source forClass:class];
	}
	else if ([source isKindOfClass:[NSArray class]])
	{
		return [self processArray:source forClass:class];
	}
	else
	{
		return source;
	}
}

- (id)processDictionary:(NSDictionary *)source forClass:(Class)class
{
	id object = [[class alloc] init];
	
	for (NSString *key in source)
	{
		ObjectMappingInfo *mappingInfo = [self mappingInfoByDictionaryKey:key forClass:class];
		id value = [source objectForKey:(NSString *)key];
		NSString *propertyName;
		Class objectType;
		id nestedObject;
		
		if (mappingInfo)
		{
			propertyName = mappingInfo.propertyKey;
			objectType = mappingInfo.objectType;
		}
		else
		{
			propertyName = key;
			objectType = [self classFromString:key];
			
			if (!objectType && key.length && [[key substringFromIndex:key.length-1] isEqual:@"s"])
				objectType = [self classFromString:[key substringToIndex:key.length-1]];
		}
		
		if ([value isKindOfClass:[NSDictionary class]])
		{
			nestedObject = [self processDictionary:value forClass:objectType];
		}
		else if ([value isKindOfClass:[NSArray class]])
		{
			nestedObject = [self processArray:value forClass:objectType];
		}
		else
		{
			nestedObject = value;
		}
		
		if ([object respondsToSelector:NSSelectorFromString(propertyName)])
		{
			[object setValue:nestedObject forKey:propertyName];
		}
	}
	
	return object;
}

- (id)processArray:(NSArray *)value forClass:(Class)class
{
	NSMutableArray *nestedArray = [NSMutableArray array];
	
	for (id objectInArray in value)
	{
		id nestedObject = [self objectFromSource:objectInArray toInstanceOfClass:class];
		
		if (nestedObject)
			[nestedArray addObject:nestedObject];
	}

	return nestedArray;
}

#pragma mark - Private Methods -

- (Class)classFromString:(NSString *)className
{
	if (NSClassFromString(className))
		return NSClassFromString(className);
	
	if (NSClassFromString([className capitalizedString]))
		return NSClassFromString([className capitalizedString]);
	
	int numClasses;
	Class *classes = NULL;
	
	classes = NULL;
	numClasses = objc_getClassList(NULL, 0);
	
	if (numClasses > 0)
	{
		classes = (__unsafe_unretained Class *)malloc(sizeof(Class) * numClasses);
		numClasses = objc_getClassList(classes, numClasses);
		
		for (int i = 0; i < numClasses; i++)
		{
			Class class = classes[i];
			
			if ([[NSStringFromClass(class) lowercaseString] isEqual:[className lowercaseString]])
				return class;
		}
	}
	
	return nil;
}

- (ObjectMappingInfo *)mappingInfoByDictionaryKey:(NSString *)dictionaryKey forClass:(Class)class
{
	NSMutableArray *mappingInfos = [[self.mappingDictionary objectForKey:NSStringFromClass(class)] objectForKey:KEY_FOR_ARRAY_OF_OBJECT_MAPPING_INFOS];
	
	for (ObjectMappingInfo *info in mappingInfos)
	{
		if ([info.dictionaryKey isEqual:dictionaryKey])
			return info;
	}
	
	return nil;
}

@end
