#import "SchemaController.h"

@implementation SchemaController

-(void)setDescribeDataSource:(DescribeListDataSource*)desc {
	[schemaView setDescribesDataSource:desc];
}

-(void)setSchemaViewToSObject:(ZKDescribeSObject *)sobject;
{
	[schemaWindow makeFirstResponder:schemaView];
	[schemaView setCentralSObject:sobject];
}

@end
