/*  ADSqliteDataAccessHelper.m
 *
 *  Created by Adam Duke on 2/27/12.
 *  Copyright (c) 2012 Adam Duke. All rights reserved.
 *
 */

#import "ADSqliteDataAccessHelper.h"
#import "FMDatabase.h"

@interface ADSqliteDataAccessHelper ()

@property (nonatomic, retain) NSString *databaseName;
@property (nonatomic, retain) NSString *documentsDatabasePath;

- (void)updateSchema;
- (void)executeSqlOnAllTables:(NSString *)sql;
- (NSArray *)getTableNames;
- (void)dropAllTables;

@end

@implementation ADSqliteDataAccessHelper

@synthesize databaseName, documentsDatabasePath;

/* local constants */
NSString *const CurrentSchemaVersionKey = @"CurrentSchemaVersionKey";
NSString *const SchemaVersionFormatString = @"Schema_Version_%d";

/* The default initalizer to set up the instance variables needed for database operations
 */
- (ADSqliteDataAccessHelper *)initWithDatabaseName:(NSString *)name
{
    if(self = [super init])
    {
        /* Hold on to the path to the documents directory */
        NSArray *documentPaths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSString *documentsDirectoryPath = [documentPaths objectAtIndex:0];

        /* Hold on to the paths for the SchemaVersions.plist and database files */
        self.databaseName = name ? name : @"default.sqlite";
        self.documentsDatabasePath = [documentsDirectoryPath stringByAppendingPathComponent:name];
    }
    return self;
}

#pragma mark -
#pragma mark Public Methods

/* Convenience method to get a reference to an open FMDatabase object and log any associated erros
 */
- (FMDatabase *)openApplicationDatabase
{
    FMDatabase *database = [FMDatabase databaseWithPath:self.documentsDatabasePath];
    if(![database open])
    {
        NSLog(@"Error opening database.");
        if([database hadError])
        {
            NSLog(@"Err %d: %@", [database lastErrorCode], [database lastErrorMessage]);
        }
    }
    return database;
}

/* create the default database and save it in the Documents directory */
- (BOOL)createAndValidateDatabase
{
    FMDatabase *database = [self openApplicationDatabase];

    /* update the schema */
    [self updateSchema];

    [database close];
    return YES;
}

/* delete any data that has been stored in the database */
- (void)deleteAllData
{
    [self executeSqlOnAllTables:@"DELETE FROM %@"];
    [self dropAllTables];
}

#pragma mark -
#pragma mark Private Methods

/* Determines the current state of the database schema and applies the neccesary updates
 * to match the currently expected version by the application
 */
- (void)updateSchema
{
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];

    /* get the current schema version */
    NSInteger currentVersion = [userDefaults integerForKey:CurrentSchemaVersionKey];

    /* a boolean to indicate the schema has changed */
    BOOL schemaUpdated = NO;

    NSString *fileName = [NSString stringWithFormat:SchemaVersionFormatString, currentVersion + 1];

    /* get the list of statements to make the DDL change */
    NSString *path = [[NSBundle mainBundle] pathForResource:fileName ofType:@"plist"];
    while(path)
    {
        NSArray *sqlStatements = [NSArray arrayWithContentsOfFile:path];
        schemaUpdated = YES;

        /* open the database */
        FMDatabase *database = [self openApplicationDatabase];

        /* execute the statements */
        for(NSString *statement in sqlStatements)
        {
            [database executeUpdate:statement];
            if([database hadError])
            {
                NSLog(@"Err %d: %@", [database lastErrorCode], [database lastErrorMessage]);
            }
        }
        [database close];

        /* increment version */
        currentVersion++;
        [userDefaults setInteger:currentVersion forKey:CurrentSchemaVersionKey];
        fileName = [NSString stringWithFormat:SchemaVersionFormatString, currentVersion + 1];
        path = [[NSBundle mainBundle] pathForResource:fileName ofType:@"plist"];
    }

    /* if the schemaUpdated flag has flipped, we'll want to write out the NSUserDefaults
     * because the CurrentSchemaVersion will have been updated
     */
    if(schemaUpdated)
    {
        [userDefaults synchronize];
    }
}

/* Drops all the tables currently in the database
 */
- (void)dropAllTables
{
    [self executeSqlOnAllTables:@"DROP TABLE %@"];
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults removeObjectForKey:CurrentSchemaVersionKey];
    [defaults synchronize];
}

/* gets an NSArray of NSString's containing the names of current tables
 * added to the database
 */
- (NSArray *)getTableNames
{
    FMDatabase *database = [self openApplicationDatabase];
    FMResultSet *resultSet = [database executeQuery:@"SELECT DISTINCT tbl_name FROM sqlite_master"];
    NSMutableArray *tableNames = [NSMutableArray array];
    while([resultSet next])
    {
        [tableNames addObject:[resultSet stringForColumn:@"tbl_name"]];
    }
    [resultSet close];
    [database close];
    return tableNames;
}

/* Executes the sql statement against all tables retrieved from the
 * getTableNames method. The sql statement must have a %@ string format
 * specifier in the place of the table name
 */
- (void)executeSqlOnAllTables:(NSString *)sql
{
    FMDatabase *database = [self openApplicationDatabase];
    NSArray *tableNames = [self getTableNames];
    for(NSString *tableName in tableNames)
    {
        NSString *finalSql = [NSString stringWithFormat:sql, tableName];
        [database executeUpdate:finalSql];
    }
    [database close];
}

@end
