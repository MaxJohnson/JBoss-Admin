/*
 * JBoss Admin
 * Copyright 2012, Christos Vasilakis, and individual contributors.
 * See the copyright.txt file in the distribution for a full
 * listing of individual contributors.
 *
 * This is free software; you can redistribute it and/or modify it
 * under the terms of the GNU Lesser General Public License as
 * published by the Free Software Foundation; either version 2.1 of
 * the License, or (at your option) any later version.
 *
 * This software is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with this software; if not, write to the Free
 * Software Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA
 * 02110-1301 USA, or see the FSF site: http://www.fsf.org.
 */

#import "JBAAddDeploymentViewController.h"
#import "JBADeploymentDetailsViewController.h"

#import "JBAOperationsManager.h"

#import "DefaultCell.h"
#import "SVProgressHUD.h"
#import "TKProgressAlertView.h"
#import "UIActionSheet+BlockExtensions.h"
#import "NSFileManager+DirectoryLocations.h"

@implementation JBAAddDeploymentViewController {
    NSMutableArray *_files;
    
    NSString *_documentsDirectory;
    
    NSIndexPath *_lastIndexPath;
}

-(void)dealloc {
    DLog(@"JBAAddDeploymentViewController dealloc");    
}

#pragma mark - View lifecycle
- (void)viewDidUnload {
    DLog(@"JBAAddDeploymentViewController viewDidUnLoad");
    
    _files = nil;
    _documentsDirectory = nil;
    _lastIndexPath = nil;

    [super viewDidUnload];
}

- (void)viewDidLoad {
    DLog(@"JBAAddDeploymentViewController viewDidLoad");
    
    // Configure the navigation bar
    self.title = @"Step1/2: Upload";
    
    UIBarButtonItem *cancelButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Cancel" style:UIBarButtonItemStyleBordered target:self action:@selector(cancel)];
    self.navigationItem.leftBarButtonItem = cancelButtonItem;
    
    UIBarButtonItem *nextButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Next" style:UIBarButtonItemStyleDone target:self action:@selector(upload)];

    self.navigationItem.rightBarButtonItem = nextButtonItem;
    self.navigationItem.rightBarButtonItem.enabled = NO; // initially disable it cause nothing is checked
    
    _documentsDirectory = [[NSFileManager defaultManager] documentsDirectory];
    
    NSError *error;
    NSArray *files = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:_documentsDirectory error:&error];

    if (error) { // an error occured reading directory contents
        UIAlertView *oops = [[UIAlertView alloc] initWithTitle:@"Oops!"
                                                       message:[error localizedDescription]
                                                      delegate:nil 
                                             cancelButtonTitle:@"Bummer"
                                             otherButtonTitles:nil];
        [oops show];
    }
    
    _files = [NSMutableArray arrayWithArray:files];
    
    // sort by filename
    [_files sortUsingSelector:@selector(compare:)];

    [super viewDidLoad];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return YES;
}

#pragma mark - Table Data Source Methods
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [_files count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSUInteger row = [indexPath row];
    NSUInteger oldRow = [_lastIndexPath row];
    
    DefaultCell *cell = [DefaultCell cellForTableView:tableView];
    
    cell.textLabel.text = [_files objectAtIndex:row];
    cell.accessoryType = (row == oldRow && _lastIndexPath != nil) ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
    
    return cell;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return YES;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    NSUInteger row = [indexPath row];
    
    NSString *file = [_files objectAtIndex:row];
    
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        
        UIActionSheet *yesno = 
            [[UIActionSheet alloc]
                initWithTitle:[NSString stringWithFormat:@"Are you sure you want to delete file \"%@\"", file]
                completionBlock:^(NSUInteger buttonIndex, UIActionSheet *actionSheet) {
                    switch (buttonIndex) {
                        case 0: // If YES button pressed, proceed...
                        {
                            NSError *error;
                            [[NSFileManager defaultManager] removeItemAtPath:[_documentsDirectory stringByAppendingPathComponent:file]
                                                                       error:&error];
                            
                            if (error) {
                                UIAlertView *oops = [[UIAlertView alloc] initWithTitle:@"Oops!"
                                                                               message:[error localizedDescription]
                                                                              delegate:nil 
                                                                     cancelButtonTitle:@"Bummer"
                                                                     otherButtonTitles:nil];
                                [oops show];
                            } else {
                                [_files removeObjectAtIndex:row];
                            
                                [tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] 
                                                 withRowAnimation:UITableViewRowAnimationFade];
                                
                                // if the item was already checkmarked
                                // disable the upload button
                                NSUInteger oldRow = [_lastIndexPath row];
                                if (row == oldRow && _lastIndexPath != nil)
                                    self.navigationItem.rightBarButtonItem.enabled = NO;

                            }
                        }  
                            break;
                    }
                }
                
                cancelButtonTitle:@"No"
                destructiveButtonTitle: @"Yes"
                otherButtonTitles:nil
             ];
        
        [yesno showInView:self.view];
    }   
}
    
#pragma mark - Table Delegate Methods
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    int newRow = [indexPath row];
    int oldRow = (_lastIndexPath != nil) ? [_lastIndexPath row] : -1;
    
    if (newRow != oldRow) {
        UITableViewCell *newCell = [tableView cellForRowAtIndexPath:indexPath];
        
        newCell.accessoryType = UITableViewCellAccessoryCheckmark;
        
        UITableViewCell *oldCell = [tableView cellForRowAtIndexPath:_lastIndexPath];
        oldCell.accessoryType = UITableViewCellAccessoryNone;
        
        _lastIndexPath = indexPath;
    }
    
    self.navigationItem.rightBarButtonItem.enabled = YES;
    
    [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
}

#pragma mark - Action Methods
-(void)cancel {
     [self dismissViewControllerAnimated:YES completion:nil];
}

-(void)upload {
    NSString *name = [_files objectAtIndex:[_lastIndexPath row]];

    NSString *filename = [[[NSFileManager defaultManager] documentsDirectory] stringByAppendingPathComponent:name];

    // TODO: this is HACK, for some reason totalBytesExpectedToWrite is doubled during the upload
    // which messes the progress bar indicator
    NSDictionary *fileAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:filename error:nil];
    long long fileSize = 2 * [[fileAttributes objectForKey:NSFileSize] longLongValue];

    UIActionSheet *yesno = 
        [[UIActionSheet alloc]
            initWithTitle:[NSString stringWithFormat:@"Are you sure you want to upload \"%@\"", name]
            completionBlock:^(NSUInteger buttonIndex, UIActionSheet *actionSheet) {
                switch (buttonIndex) {
                    case 0: // If YES button pressed, proceed...
                    {
                        TKProgressAlertView *alertView = [[TKProgressAlertView alloc]
                                                          initWithProgressTitle:@"uploading, please wait..."];
                        
                        alertView.progressBar.progress = 0;
                        
                        [alertView show];

                        [[JBAOperationsManager sharedManager]
                         uploadFileWithName:filename
                            withUploadProgress:^(NSInteger bytesWritten, NSInteger totalBytesWritten, NSInteger totalBytesExpectedToWrite) {
                                double progress = totalBytesWritten / (double) fileSize;
                                //DLog(@"Sent bytesWritten=%d totalBytesWritten=%d of totalBytesExpectedToWrite=%qi bytes (%f)", bytesWritten, totalBytesWritten, fileSize, progress);
                                [alertView.progressBar setProgress:progress animated:YES];
                            } 
                            withSuccess:^(NSString *deploymentHash) {
                                [alertView hide];
                                
                                JBADeploymentDetailsViewController *detailsController = [[JBADeploymentDetailsViewController alloc] initWithStyle:UITableViewStyleGrouped];
                                
                                detailsController.deploymentHash = deploymentHash;
                                detailsController.deploymentName = name;
                                detailsController.deploymentRuntimeName = name;
                                
                                [self.navigationController pushViewController:detailsController animated:YES];
                                
                            } andFailure:^(NSError *error) {
                                [alertView hide];
                             
                                UIAlertView *oops = [[UIAlertView alloc] initWithTitle:@"Oops!"
                                                                               message:[error localizedDescription]
                                                                              delegate:nil 
                                                                     cancelButtonTitle:@"Bummer"
                                                                     otherButtonTitles:nil];
                                [oops show];
                            }];
                        }  
                        break;
                    }
                }
            
            cancelButtonTitle:@"No"
            destructiveButtonTitle: @"Yes"
            otherButtonTitles:nil
         ];

    [yesno showInView:self.view];
}


@end
