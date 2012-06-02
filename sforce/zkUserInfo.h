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


#import "zkXmlDeserializer.h"

@interface ZKUserInfo : ZKXmlDeserializer  {
}

// API v7.0
-(BOOL)accessibilityMode;
-(NSString *)currencySymbol;
-(NSString *)organizationId;
-(NSString *)organizationName;
-(BOOL)organizationIsMultiCurrency;
-(NSString *)defaultCurrencyIsoCode;
-(NSString *)email;
-(NSString *)fullName;
-(NSString *)userId;
-(NSString *)language;
-(NSString *)locale;
-(NSString *)timeZone;
-(NSString *)skin;
// API v8.0
-(NSString *)licenseType;
-(NSString *)profileId;
-(NSString *)roleId;
-(NSString *)userName;
-(NSString *)userType;
// v20.0
-(BOOL)disallowHtmlAttachments;
-(BOOL)hasPersonAccounts;
// v21.0
-(int)orgAttachmentFileSizeLimit;
-(int)sessionSecondsValid;
@end
