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

#import "JBAAttributeGenericTypeEditor.h"
#import "JBAOperationsManager.h"
#import "JBAServerReplyViewController.h"
#import "JBossValue.h"
#import "JBAListEditor.h"

#import "JBAAppDelegate.h"

#import "CommonUtil.h"
#import "JSONKit.h"

#import "EditCell.h"
#import "LabelButtonCell.h"
#import "ToggleSwitchCell.h"
#import "TextViewCell.h"

#import "SVProgressHUD.h"

// Table Sections
enum JBAGenericAttributeEditorTableSections {
    JBATableEditorSection = 0,
    JBATableHelpSection,
    JBATableGenericNumSections
};

// Table Rows
enum JBAEditorRows {
    JBAEditorRow = 0,
    JBAEditorTableSecNumRows
};

enum JBAHelpRows {
    JBAHelpRow = 0,
    JBAHelpTableSecNumRows
};

@implementation JBAAttributeGenericTypeEditor {
    // this will hold temporary the items hold by ListEditor    
    NSMutableArray *_tempList; 
}

-(void)dealloc {
    DLog(@"JBAAttributeGenericTypeEditor dealloc");    
}

#pragma mark - View lifecycle
- (void)viewDidUnload {
    DLog(@"JBAAttributeGenericTypeEditor viewDidUnLoad");
    
    [super viewDidUnload];
}

- (void)viewDidLoad {
    DLog(@"JBAAttributeGenericTypeEditor viewDidLoad");
    
    UIBarButtonItem *saveButton = [[UIBarButtonItem alloc]
                                   initWithTitle:NSLocalizedString(@"Save",
                                                                   @"Save - for button to save changes")
                                   style:UIBarButtonItemStyleDone
                                   target:self
                                   action:@selector(save)];
    
    self.navigationItem.rightBarButtonItem = saveButton;
    
    // disable save if the attribute is read-only
    self.navigationItem.rightBarButtonItem.enabled = !self.node.isReadOnly;
    
    self.title = @"Edit Attribute";
    
    // cater for LIST types
    if (self.node.type == LIST) {
        if ([self.node.value isKindOfClass:[NSNull class]]) // if "undefined"
            _tempList = [[NSMutableArray alloc] init];  // create a new list
        else
            _tempList = [NSMutableArray arrayWithArray:self.node.value];  // else copy the items from the original LIST
    }
    
    [super viewDidLoad];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return YES;
}

#pragma mark - Table Data Source Methods
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return JBATableGenericNumSections;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    switch (section) {
        case JBATableHelpSection:
            return @"Description";
        default:
            return nil;        
    }
}

- (CGFloat) tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath{
	if(indexPath.section == JBATableHelpSection) return 240.0;
	return 44.0;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    switch (section) {
        case JBATableEditorSection:
            return JBAEditorTableSecNumRows;
        case JBATableHelpSection:
            return JBAHelpTableSecNumRows;
        default:
            return 0;
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSUInteger section = [indexPath section];
    NSUInteger row = [indexPath row];
    
    id cell;
    
    switch (section) {
        case JBATableEditorSection:
        {
            switch (row) {
                case JBAEditorRow:
                    if (self.node.type == BOOLEAN) {
                        ToggleSwitchCell *toggleCell = [ToggleSwitchCell cellForTableView:tableView];
                        toggleCell.label.text = self.node.name;
                        
                        // if "undefined" default to false
                        if ([self.node.value isKindOfClass:[NSNull class]])
                            toggleCell.toggler.on = NO;
                        else 
                            toggleCell.toggler.on = [self.node.value boolValue];

                        cell = toggleCell;

                    } else if (self.node.type == LIST) {
                        LabelButtonCell *listCell = [LabelButtonCell cellForTableView:tableView];
                        listCell.label.text = self.node.name;
                        
                        listCell.button.titleLabel.font = [UIFont italicSystemFontOfSize:15];
                        [listCell.button setTitle:(self.node.isReadOnly? @"Click to View": @"Click To Edit") forState:UIControlStateNormal];
                        [listCell.button addTarget:self action:@selector(displayListEditor:) forControlEvents:UIControlEventTouchUpInside];                    

                        cell = listCell;
                        
                    } else {
                        EditCell *editCell = [EditCell cellForTableView:tableView];                
                        editCell.label.text = self.node.name; 

                        // if "undefined" set an empty text
                        if ([self.node.value isKindOfClass:[NSNull class]])
                            editCell.txtField.text = @"";
                        else
                            editCell.txtField.text = [self.node.value cellDisplay];
                        
                        if (   self.node.type == INT
                            || self.node.type == LONG
                            || self.node.type == DOUBLE
                            || self.node.type == BIG_DECIMAL
                            || self.node.type == BIG_INTEGER)
                            editCell.txtField.keyboardType = UIKeyboardTypeDecimalPad;
                        else
                            editCell.txtField.keyboardType = UIKeyboardTypeDefault;
                        
                        editCell.txtField.placeholder = [self.node typeAsString];
                        [editCell.txtField addTarget:self action:@selector(textFieldDone:) forControlEvents:UIControlEventEditingDidEndOnExit];
                        
                        cell = editCell;
                    }

                    break;
            }   
            break;
        }

        case JBATableHelpSection:
        {
            switch (row) {
                case JBAHelpRow:
                {
                    TextViewCell *description = [TextViewCell cellForTableView:tableView];
                    description.textView.text = self.node.descr;
                    description.textView.editable = NO;                    
                    
                    cell = description;
                }
            }
            break;            
        }
            
    }
    
    return cell;
}

#pragma mark - Actions
-(void)save {
    NSUInteger editorRow[] = {JBATableEditorSection, JBAEditorRow};
    NSIndexPath *onlyRowPath = [NSIndexPath indexPathWithIndexes:editorRow length:2];
    
    id cell = [self.tableView cellForRowAtIndexPath:onlyRowPath];
    id value;
    
    if ([cell isKindOfClass:[EditCell class]]) {
        EditCell *editCell = (EditCell *)cell;
        
        // need to convert numbers
        NSString *textFieldValue = editCell.txtField.text;
        
        // if the textfield is not empty, update value
        // otherwise will be nil and it won't be submitted 
        // to the server see [super updateWithValue]
        if (![textFieldValue isEqualToString:@""]) {
            // TODO couldn't find value to test, need more checks
            if (self.node.type == INT)
                value = [NSNumber numberWithInt:[textFieldValue integerValue]];
            else if (self.node.type == LONG || self.node.type == BIG_INTEGER)
                value = [NSNumber numberWithLongLong:[textFieldValue longLongValue]];
            else if (self.node.type== DOUBLE || self.node.type == BIG_DECIMAL)
                value = [NSNumber numberWithDouble:[textFieldValue doubleValue]];
            else if (self.node.type == OBJECT) { // TODO: better handling
                value = [textFieldValue objectFromJSONString];
                
                if (value == nil) {
                    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Oops!"
                                                                    message:@"Invalid JSON string that represents an Object type!"
                                                                   delegate:nil 
                                                          cancelButtonTitle:@"Bummer"
                                                          otherButtonTitles:nil];
                    [alert show];
                    return;
                }
            }
            else // string
                value = textFieldValue;
        } 
        
        // delay a bit if the keyboard is open so that the progress bar
        // is displayed correctly on the center
        // during the keyboard dismissing from screen
        if ([editCell.txtField isFirstResponder]) {
            [editCell.txtField resignFirstResponder];
        } else {
            value = editCell.txtField.text;
        }
        
    } else if ([cell isKindOfClass:[ToggleSwitchCell class]]) {
        ToggleSwitchCell *toggleCell = (ToggleSwitchCell *)cell;
        value = [NSNumber numberWithBool:toggleCell.toggler.on];

    } else if ([cell isKindOfClass:[LabelButtonCell class]]) {
        value = _tempList;
    }
    
    [SVProgressHUD showWithMaskType:SVProgressHUDMaskTypeGradient networkIndicator:YES];
    
    NSDictionary *params =
    [NSDictionary dictionaryWithObjectsAndKeys:
     @"write-attribute", @"operation",
     (self.node.path == nil?[NSArray arrayWithObject:@"/"]: self.node.path), @"address",
     self.node.name, @"name",
     value /* if nil it will act as a sentinel for dictionaryWithObjectsAndKeys */, @"value", nil];
    
    [[JBAOperationsManager sharedManager]
     postJBossRequestWithParams:params
     success:^(NSMutableDictionary *JSON) {
         [SVProgressHUD dismiss];
         
         // if success, update this node value
         if ([[JSON objectForKey:@"outcome"] isEqualToString:@"success"]) {
             // if type LIST do a copy so subsequent edits do
             // not affect the original LIST
             if (self.node.type == LIST) {
                 self.node.value = [NSMutableArray arrayWithArray:value];
             } else {
                 self.node.value = value;
             }
         }
         // display server reply
         JBAServerReplyViewController *replyController = [[JBAServerReplyViewController alloc] initWithStyle:UITableViewStyleGrouped];
         replyController.operationName = self.node.name;
         
         replyController.reply = [JSON JSONStringWithOptions:JKSerializeOptionPretty error:nil];
         
         UINavigationController *navigationController = [CommonUtil customizedNavigationController];
         [navigationController pushViewController:replyController animated:NO];
         
         JBAAppDelegate *delegate = (JBAAppDelegate *)[UIApplication sharedApplication].delegate;
         [delegate.navController presentViewController:navigationController animated:YES completion:nil];
         
     } failure:^(NSError *error) {
         [SVProgressHUD dismiss];
         
         UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Oops!"
                                                         message:[error localizedDescription]
                                                        delegate:nil
                                               cancelButtonTitle:@"Bummer"
                                               otherButtonTitles:nil];
         [alert show];
     } process:NO
     ];
}

- (void)displayListEditor:(id)sender {
    JBAListEditor *listEditorController = [[JBAListEditor alloc] initWithStyle:UITableViewStyleGrouped];
    listEditorController.title = self.node.name;
    
    listEditorController.items = _tempList;
    listEditorController.valueType = self.node.valueType;
    listEditorController.isReadOnlyMode = self.node.isReadOnly;
    
    UINavigationController *navigationController = [CommonUtil customizedNavigationController];
    [navigationController pushViewController:listEditorController animated:NO];

    JBAAppDelegate *delegate = (JBAAppDelegate *)[UIApplication sharedApplication].delegate;
    [delegate.navController presentViewController:navigationController animated:YES completion:nil];
}

#pragma mark - TextField methods
- (void)textFieldDone:(UITextField *)sender {
    [sender resignFirstResponder];
}

@end
