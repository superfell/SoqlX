// Copyright (c) 2006-2010 Simon Fell
//
// Permission is hereby granted, free of charge, to any person obtaining a 
// copy of this software and associated documentation files (the "Software"), 
// to deal in the Software without restriction, including without limitation
// the rights to use, copy, modify, merge, publish, distribute, sublicense, 
// and/or sell copies of the Software, and to permit persons to whom the 
// Software is furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included 
// in all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS 
// OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, 
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE 
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER 
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, 
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN 
// THE SOFTWARE.
//

#import "zkQueryResult.h"

@class zkElement;

NSString * NS_URI_XSI;

@interface ZKSObject : NSObject {
	NSString 			*Id;
	NSString 			*type;
	NSMutableSet 		*fieldsToNull;
	NSMutableDictionary *fields;
	NSMutableArray		*fieldOrder;	// field names in the order they were added
}

+ (id) withType:(NSString *)type;
+ (id) withTypeAndId:(NSString *)type sfId:(NSString *)sfId;
+ (id) fromXmlNode:(zkElement *)node;

- (id) initFromXmlNode:(zkElement *)node;
- (id) initWithType:(NSString *)type;

// setters
- (void)setId:(NSString *)theId;
- (void)setType:(NSString *)type;

// setting a fieldValue to nil will automatically put it in the fieldsToNull collection
// setting a fieldValue to non nil will automatically remove it from the fieldsToNull collection
- (void)setFieldValue:(NSObject *)value field:(NSString *)field;
- (void)setFieldDateTimeValue:(NSDate *)value field:(NSString *)field;
- (void)setFieldDateValue:(NSDate *)value field:(NSString *)field;
- (void)setFieldToNull:(NSString *)field;

// basic getters
- (NSString *)id;
- (NSString *)type;
- (NSArray *)fieldsToNull;
- (NSDictionary *)fields;
- (id)fieldValue:(NSString *)field;
- (BOOL)isFieldToNull:(NSString *)field;

// typed getters
- (BOOL)boolValue:(NSString *)field;
- (NSDate *)dateTimeValue:(NSString *)field;
- (NSDate *)dateValue:(NSString *)field;
- (int)intValue:(NSString *)field;
- (double)doubleValue:(NSString *)field;
- (ZKQueryResult *)queryResultValue:(NSString *)field;

// others
- (NSArray *)orderedFieldNames;
@end
