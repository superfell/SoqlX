// Copyright (c) 2009 Simon Fell
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

@class ZKUserInfo;

// <element name="metadataServerUrl" type="xsd:string" nillable="true"/>
// <element name="passwordExpired"   type="xsd:boolean" />
// <element name="sandbox"			 type="xsd:boolean"/>
// <element name="serverUrl"         type="xsd:string" nillable="true"/>
// <element name="sessionId"         type="xsd:string" nillable="true"/>
// <element name="userId"            type="tns:ID" nillable="true"/>
// <element name="userInfo"          type="tns:GetUserInfoResult" minOccurs="0"/>


@interface ZKLoginResult : ZKXmlDeserializer {
}

-(NSString *)metadataServerUrl;
-(NSString *)serverUrl;
-(NSString *)sessionId;
-(NSString *)userId;
-(ZKUserInfo *)userInfo;
-(BOOL)passwordExpired;
-(BOOL)sandbox;
@end
