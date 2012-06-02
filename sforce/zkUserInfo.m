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


#import "zkUserInfo.h"

@implementation ZKUserInfo

/*
                    <element name="accessibilityMode"          type="xsd:boolean"/>
                    <element name="currencySymbol"             type="xsd:string" nillable="true"/>
                    <element name="orgDefaultCurrencyIsoCode"  type="xsd:string" nillable="true"/>
                    <element name="orgDisallowHtmlAttachments" type="xsd:boolean"/>
                    <element name="orgHasPersonAccounts"       type="xsd:boolean"/>
                    <element name="organizationId"             type="tns:ID"/>
                    <element name="organizationMultiCurrency"  type="xsd:boolean"/>
                    <element name="organizationName"           type="xsd:string"/>
                    <element name="profileId"                  type="tns:ID"/>
                    <element name="roleId"                     type="tns:ID" nillable="true"/>
                    <element name="userDefaultCurrencyIsoCode" type="xsd:string" nillable="true"/>
                    <element name="userEmail"                  type="xsd:string"/>
                    <element name="userFullName"               type="xsd:string"/>
                    <element name="userId"                     type="tns:ID"/>
                    <element name="userLanguage"               type="xsd:string"/>
                    <element name="userLocale"                 type="xsd:string"/>
                    <element name="userName"                   type="xsd:string"/>
                    <element name="userTimeZone"               type="xsd:string"/>
                    <element name="userType"                   type="xsd:string"/>
                    <element name="userUiSkin"                 type="xsd:string"/>
*/

					
-(BOOL)accessibilityMode {
	return [self boolean:@"accessibilityMode"];
}
-(NSString *)currencySymbol {
	return [self string:@"currencySymbol"];
}
-(NSString *)organizationId {
	return [self string:@"organizationId"];
}
-(BOOL)organizationIsMultiCurrency {
	return [self boolean:@"organizationMultiCurrency"];
}
-(NSString *)organizationName {
	return [self string:@"organizationName"];
}
-(NSString *)defaultCurrencyIsoCode {
	return [self string:@"userDefaultCurrencyIsoCode"];
}
-(NSString *)email {
	return [self string:@"userEmail"];
}
-(NSString *)fullName {
	return [self string:@"userFullName"];
}
-(NSString *)userId {
	return [self string:@"userId"];
}
-(NSString *)language {
	return [self string:@"userLanguage"];
}
-(NSString *)locale {
	return [self string:@"userLocale"];
}
-(NSString *)timeZone {
	return [self string:@"userTimeZone"];
}
-(NSString *)skin {
	return [self string:@"userUiSkin"];
}
-(NSString *)licenseType {
	return [self string:@"licenseType"];
}
-(NSString *)profileId {
	return [self string:@"profileId"];
}
-(NSString *)roleId {
	return [self string:@"roleId"];
}
-(NSString *)userName {
	return [self string:@"userName"];
}
-(NSString *)userType {
	return [self string:@"userType"];
}
-(BOOL)disallowHtmlAttachments {
	return [self boolean:@"orgDisallowHtmlAttachments"];
}
-(BOOL)hasPersonAccounts {
	return [self boolean:@"orgHasPersonAccounts"];
}
-(int)orgAttachmentFileSizeLimit {
	return [self integer:@"orgAttachmentFileSizeLimit"];
}

-(int)sessionSecondsValid {
	return [self integer:@"sessionSecondsValid"];
}

@end
