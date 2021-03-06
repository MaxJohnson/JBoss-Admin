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

#import "JBADomainServersViewController.h"

#import "JBAOperationsManager.h"

#import "JBARefreshable.h"

#import "SubtitleCell.h"
#import "SVProgressHUD.h"
#import "UIActionSheet+BlockExtensions.h"

@interface JBADomainServersViewController()<JBARefreshable>

@end

@implementation JBADomainServersViewController {
    NSArray *_names;
    NSDictionary *_servers;    
}

@synthesize belongingHost = _belongingHost;

-(void)dealloc {
    DLog(@"JBADomainServersViewController dealloc");    
}

#pragma mark - View lifecycle
- (void)viewDidUnload {
    DLog(@"JBADomainServersViewController viewDidUnLoad");
    
    _names = nil;
    _servers = nil;

    [super viewDidUnload];
}

- (void)viewDidLoad {
    DLog(@"JBADomainServersViewController viewDidLoad");
    
    self.title = @"Select Server";

    UIRefreshControl *refreshControl = [[UIRefreshControl alloc] init];
    [refreshControl addTarget:self action:@selector(refresh) forControlEvents:UIControlEventValueChanged];
    [self setRefreshControl:refreshControl];
    
    [SVProgressHUD showWithMaskType:SVProgressHUDMaskTypeGradient networkIndicator:YES];
    [self refresh];
    
    [super viewDidLoad];
}

- (void)viewWillAppear:(BOOL)animated {
    DLog(@"JBADomainServersViewController viewWillAppear");
    
    [super viewWillAppear:animated];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return YES;
}

#pragma mark - Table Data Source Methods
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [_names count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSUInteger row = [indexPath row];
    
    SubtitleCell *cell = [SubtitleCell cellForTableView:tableView];

    UIButton *button;

    if (cell.accessoryView == nil) {
        button = [UIButton buttonWithType:UIButtonTypeCustom];
        button.frame = CGRectMake(0.0, 0.0, 70, 27);
        button.titleLabel.font = [UIFont boldSystemFontOfSize:14];
        
        cell.accessoryView = button;
    } else {
        button = (UIButton *)cell.accessoryView;
    }
    
    NSString *serverName = [_names objectAtIndex:row];
    NSMutableDictionary *serverInfo = [_servers objectForKey:serverName];
    
    if ([[serverInfo objectForKey:@"status"] isEqualToString:@"STARTED"]) {
        cell.imageView.image = [UIImage imageNamed:@"up.png"];
        
        UIImage *buttonDisableImage = [UIImage imageNamed:@"disable.png"];
        [button setBackgroundImage:buttonDisableImage forState:UIControlStateNormal];
        [button setTitle:@"Stop" forState:UIControlStateNormal];
        [button addTarget:self action:@selector(enableDisableButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
        
        cell.selectionStyle = UITableViewCellSelectionStyleBlue;
        
    } else if (  [[serverInfo objectForKey:@"status"] isEqualToString:@"DISABLED"]
              || [[serverInfo objectForKey:@"status"] isEqualToString:@"STOPPED"]
              || [[serverInfo objectForKey:@"status"] isEqualToString:@"FAILED"] ) {
        cell.imageView.image = [UIImage imageNamed:@"down.png"];   
        
        UIImage *buttonEnableImage = [UIImage imageNamed:@"enable.png"];
        [button setBackgroundImage:buttonEnableImage forState:UIControlStateNormal];
        [button setTitle:@"Start" forState:UIControlStateNormal];
        [button addTarget:self action:@selector(enableDisableButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
        
        cell.selectionStyle = UITableViewCellSelectionStyleNone;        
    } else if (  [[serverInfo objectForKey:@"status"] isEqualToString:@"STARTING"]
              || [[serverInfo objectForKey:@"status"] isEqualToString:@"STOPPING"]) {
        cell.imageView.image = [UIImage imageNamed:@"down.png"];   
        cell.accessoryView = nil;
        cell.selectionStyle = UITableViewCellSelectionStyleNone;        
    }

    cell.textLabel.text = serverName;
    cell.detailTextLabel.text = [serverInfo objectForKey:@"group"];
    
    return cell;
}

#pragma mark - Table Delegate Methods
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
     NSUInteger row = [indexPath row];

    NSString *serverName = [_names objectAtIndex:row];
    NSMutableDictionary *serverInfo = [_servers objectForKey:serverName];
    
    // TODO: better handling for this status
    if ( [[serverInfo objectForKey:@"status"] isEqualToString:@"DISABLED"]
        ||[[serverInfo objectForKey:@"status"] isEqualToString:@"STOPPED"]
        ||[[serverInfo objectForKey:@"status"] isEqualToString:@"STARTING"]
        ||[[serverInfo objectForKey:@"status"] isEqualToString:@"STOPPING"])
        return;
    
    [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    NSDictionary *server = [NSDictionary dictionaryWithObjectsAndKeys:self.belongingHost, @"host", serverName, @"server", nil ];
    
    [self dismissViewControllerAnimated:YES completion:nil];
    
    // ok inform runtime for server changed
    NSNotification *notification = [NSNotification notificationWithName:@"ServerChangedNotification" object:server];
    [[NSNotificationCenter defaultCenter] postNotification:notification];
}

#pragma mark - Action Methods
- (void)refresh {
    [[JBAOperationsManager sharedManager]
     fetchServersInfoForHostWithName:self.belongingHost
     withSuccess:^(NSDictionary *servers) {
         [SVProgressHUD dismiss];
         
         _servers = servers;
         _names = [[_servers allKeys] sortedArrayUsingSelector:@selector(compare:)];
         [self.tableView reloadData];
         
         [self.refreshControl endRefreshing];
         
     } andFailure:^(NSError *error) {
         [SVProgressHUD dismiss];
         [self.refreshControl endRefreshing];
         
         UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Oops!"
                                                         message:[error localizedDescription]
                                                        delegate:nil 
                                               cancelButtonTitle:@"Bummer"
                                               otherButtonTitles:nil];
         [alert show];
     }];
}

- (void)enableDisableButtonTapped:(id)sender {
    UIButton *senderButton = (UIButton *)sender;
    
    UITableViewCell *buttonCell = (UITableViewCell *)[senderButton superview];
    NSUInteger buttonRow = [[self.tableView indexPathForCell:buttonCell] row];
    
    BOOL start = [senderButton.currentTitle isEqualToString:@"Start"];
    
    NSString *serverName = [_names objectAtIndex:buttonRow];
    NSMutableDictionary *serverInfo = [_servers objectForKey:serverName];    
    
    UIActionSheet *yesno = [[UIActionSheet alloc]
                            initWithTitle:[NSString stringWithFormat:@"Are you sure you want to %@ \"%@\"", (start ? @"Start ": @"Stop "), serverName]
                            completionBlock:^(NSUInteger buttonIndex, UIActionSheet *actionSheet) {
                                switch (buttonIndex) {
                                    case 0: // If YES button pressed, proceed...
                                    {   
                                        [SVProgressHUD showWithMaskType:SVProgressHUDMaskTypeGradient networkIndicator:YES];
                                        
                                        [[JBAOperationsManager sharedManager]
                                         changeStatusForServerWithName:serverName
                                         belongingToHost:self.belongingHost
                                         toStatus:start 
                                         withSuccess:^(NSString *result) {
                                             
                                             BOOL anErrorHasOccured = false;
                                             
                                             if (start && ![result isEqualToString:@"STARTED"]) {
                                                 [SVProgressHUD dismissWithError:@"Server failed to start!"];
                                                 anErrorHasOccured = YES;
                                             }
                                             
                                             if (!start && ![result isEqualToString:@"STOPPED"]) {
                                                 [SVProgressHUD dismissWithError:@"Server failed to stop!"];
                                                 anErrorHasOccured = YES;                                                
                                             }
                                             
                                             if (!anErrorHasOccured)
                                                 [SVProgressHUD dismissWithSuccess:(start ? @"Started Successfully!": @"Stopped Successfully!")];
                                             
                                             // if we are here the operation was success
                                             [serverInfo setValue:result forKey:@"status"];
                                             
                                             [self.tableView reloadData];
                                             
                                         } andFailure:^(NSError *error) {
                                             [SVProgressHUD dismiss];
                                             
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
                            otherButtonTitles:nil];
    
    [yesno showInView:self.view];    
}
@end
