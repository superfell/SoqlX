/* SchemaController */

#import <Cocoa/Cocoa.h>
#import "SchemaView.h"
#import "DataSources.h"

@interface SchemaController : NSObject
{
    IBOutlet SchemaView		*schemaView;
    IBOutlet NSWindow		*schemaWindow;
}

-(void)setDescribeDataSource:(DescribeListDataSource *)dataSource;
-(void)setSchemaViewToSObject:(ZKDescribeSObject *)sobject;

@end
