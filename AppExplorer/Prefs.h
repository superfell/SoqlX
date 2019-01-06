// Copyright (c) 2014,2015 Simon Fell
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

#import <Foundation/Foundation.h>

// Are the field names in the object/field list on the left sorted by field name ?
extern NSString *PREF_SORTED_FIELD_LIST;

// When we build a query, do we sort the fields by name ?
extern NSString *PREF_QUERY_SORT_FIELDS;

// If true we'll skip address fields from the generated query, and just select the component fields
// If false (default) we'll skip the component fields and just select the compound field (short resulting query text, slightly cleaner results table, but not editable)
extern NSString *PREF_SKIP_ADDRESS_FIELDS;

// What font size do we want for text ? migrated to NSFont userFixedPitchFont in 3.1
extern NSString *PREF_TEXT_SIZE;

// Should we exit the app if the last window is closed, or stay running ?
extern NSString *PREF_QUIT_ON_LAST_WINDOW_CLOSE;
