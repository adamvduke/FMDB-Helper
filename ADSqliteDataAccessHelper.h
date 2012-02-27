/*  ADSqliteDataAccessHelper.h
 *
 *  Created by Adam Duke on 2/27/12.
 *  Copyright (c) 2012 Adam Duke. All rights reserved.
 *
 */

#import <Foundation/Foundation.h>

@class FMDatabase;

@interface ADSqliteDataAccessHelper : NSObject
{
    @private
    NSString *databaseName;
    NSString *documentsDatabasePath;
}

- (ADSqliteDataAccessHelper *)initWithDatabaseName:(NSString *)name;

/* get a reference to an open database instance */
- (FMDatabase *)openApplicationDatabase;

/* copy the default database to the file system */
- (BOOL)createAndValidateDatabase;

/* Delete all information in the database */
- (void)deleteAllData;

@end
