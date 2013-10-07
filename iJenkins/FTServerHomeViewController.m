//
//  FTServerHomeViewController.m
//  iJenkins
//
//  Created by Ondrej Rafaj on 29/08/2013.
//  Copyright (c) 2013 Fuerte Innovations. All rights reserved.
//

#import "FTServerHomeViewController.h"
#import "FTJobDetailViewController.h"
#import "FTManageViewController.h"
#import "FTBuildQueueViewController.h"
#import "FTBasicCell.h"
#import "FTLoadingCell.h"
#import "FTJobCell.h"
#import "FTNoJobCell.h"
#import "FTIconCell.h"


@interface FTServerHomeViewController ()

@property (nonatomic, strong) UISearchBar *searchBar;
@property (nonatomic, strong) FTAccountOverviewCell *overviewCell;
@property (nonatomic, strong) UIRefreshControl *refreshControl;

@property (nonatomic, strong) NSArray *views;

@property (nonatomic, strong) FTAPIServerViewDataObject *selectedView;

@property (nonatomic, strong) FTAPIServerDataObject *serverObject;
@property (nonatomic, strong) NSMutableArray *jobs;

@property (nonatomic) BOOL isDataAvailable;

@property (nonatomic, assign) BOOL isSearching;

@end


@implementation FTServerHomeViewController


#pragma mark Data

- (void)alertView:(UIAlertView *)alertView willDismissWithButtonIndex:(NSInteger)buttonIndex {
    [self.navigationController popViewControllerAnimated:YES];
}

- (void)loadData {
    if (!_serverObject) {
        _isDataAvailable = NO;
        _isSearching = NO;
        self.searchBar.text = @"";
        
        _serverObject = [[FTAPIServerDataObject alloc] init];
        if (_selectedView) {
            [_serverObject setViewToLoad:_selectedView];
        }
        [FTAPIConnector connectWithObject:_serverObject andOnCompleteBlock:^(id<FTAPIDataAbstractObject> dataObject, NSError *error) {
            if (error) {
                if (error.code != -999) {
                    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:FTLangGet(@"Connection error") message:error.localizedDescription delegate:self cancelButtonTitle:FTLangGet(@"Ok") otherButtonTitles:nil];
                    [alert show];
                }
            }
            else {
                [_overviewCell setJobsStats:_serverObject.jobsStats];
                if (_serverObject.jobs.count > 0) {
                    _isDataAvailable = YES;
                }
                else {
                    _isDataAvailable = NO;
                }
                if (_serverObject.views && (_serverObject.views.count > 0)) {
                    _views = _serverObject.views;
                }
                
                self.jobs = [NSMutableArray arrayWithArray:_serverObject.jobs];
                [super.tableView reloadData];
                [self setTitle:kAccountsManager.selectedAccount.name];
                
                if (_serverObject.views.count > 1) {
                    if (!_selectedView) {
                        _selectedView = [_views objectAtIndex:0];
                    }
                }
                
                [NSTimer scheduledTimerWithTimeInterval:0.3 target:self selector:@selector(createTopButtons) userInfo:nil repeats:NO];
                [_refreshControl endRefreshing];
            }
        }];
    }
    else {
        _isDataAvailable = YES;
        [self.tableView reloadData];
    }
}

#pragma mark Search bar delegate

- (BOOL)searchBarShouldBeginEditing:(UISearchBar *)searchBar {
    [searchBar setShowsCancelButton:YES animated:YES];
    return YES;
}

- (BOOL)searchBarShouldEndEditing:(UISearchBar *)searchBar {
    [searchBar setShowsCancelButton:NO animated:YES];
    return YES;
}

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
    [self performSearchWithSearchText:searchBar.text force:NO];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
    [self performSearchWithSearchText:searchBar.text force:YES];
    [searchBar resignFirstResponder];
}

- (void)searchBarCancelButtonClicked:(UISearchBar *)searchBar {
    _isSearching = NO;
    self.jobs = [NSMutableArray arrayWithArray:_serverObject.jobs];
    [searchBar setText:@""];
    [searchBar resignFirstResponder];
    [super.tableView reloadData];
}

/**
 *  Performs search of given search term in jobs
 *
 *  @param searchText Text from search field
 *  @param force      If YES, minimum search term length is ignored. If NO, there is some length trashold before the search is performed. Usefull on realtime search
 */
- (void)performSearchWithSearchText:(NSString *)searchText force:(BOOL)force {
    if ([searchText length] > 1 || force) {
        _isSearching = YES;
        NSMutableArray *arr = [NSMutableArray array];
        
        for (FTAPIJobDataObject *job in _serverObject.jobs) {
            NSRange isRange = [job.name rangeOfString:searchText options:NSCaseInsensitiveSearch];
            if (isRange.location != NSNotFound) {
                [arr addObject:job];
            }
        }
        self.jobs = arr;
    }
    else {
        _isSearching = NO;
        self.jobs = [NSMutableArray arrayWithArray:_serverObject.jobs];
    }
    [self.tableView reloadData];
}

#pragma mark Creating elements

- (void)createTableView {
    [super createTableView];
    
    _searchBar = [[UISearchBar alloc] initWithFrame:CGRectMake(0, 0, super.tableView.width, 44)];
    [_searchBar setDelegate:self];
    [_searchBar setShowsCancelButton:NO];
    [_searchBar setAutoresizingWidth];
    [super.tableView setTableHeaderView:_searchBar];
     
    _refreshControl = [[UIRefreshControl alloc] init];
    [_refreshControl addTarget:self action:@selector(refreshActionCalled:) forControlEvents:UIControlEventValueChanged];
    [self.tableView addSubview:_refreshControl];
    [_refreshControl centerHorizontally];
    [_refreshControl setYOrigin:-60];
}

- (void)createTopButtons {
    UIBarButtonItem *filter = [[UIBarButtonItem alloc] initWithTitle:_selectedView.name style:UIBarButtonItemStyleBordered target:self action:@selector(showViewSelector:)];
    [self.navigationItem setRightBarButtonItem:filter animated:YES];
}

- (void)createAllElements {
    [super createAllElements];
    
    [self createTableView];
}

#pragma mark View lifecycle

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    [self loadData];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [super.tableView setContentOffset:CGPointMake(0, _searchBar.height)];
}

#pragma mark Actions

- (void)refreshActionCalled:(UIRefreshControl *)sender {
    _isSearching = NO;
    _serverObject = nil;
    [self loadData];
}

- (void)showViewSelector:(UIBarButtonItem *)sender {
    FTViewSelectorViewController *c = [[FTViewSelectorViewController alloc] init];
    [c setSelectedView:_selectedView];
    [c setViews:_views];
    [c setDelegate:self];
    UINavigationController *nc = [[UINavigationController alloc] initWithRootViewController:c];
    [self presentViewController:nc animated:YES completion:NULL];
}

#pragma mark Table view delegate and data source methods

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return (_isSearching ? 1 : 2);
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if ([self isJobsSection:section] && [self.jobs count] > 0) {
        return [self.jobs count];
    }
    else return 3;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (!_isDataAvailable) {
        return (indexPath.section == 0 ? ((indexPath.row == 0) ? 218 : 54) : 54);
    }
    if ([self isOverviewSection:indexPath.section]) {
        if (indexPath.row == 0) return 218;
        else return 54;
    }
    else if([self isJobsSection:indexPath.section]) {
        return 54;
    }
    else {
        return 100;
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if ([self isOverviewSection:section]) {
        return FTLangGet(@"Overview");
    }
    else {
        return FTLangGet(@"Jobs");
    }
}

- (UITableViewCell *)cellForJobAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *identifier = @"jobCellIdentifier";
    FTJobCell *cell = [super.tableView dequeueReusableCellWithIdentifier:identifier];
    if (!cell) {
        cell = [[FTJobCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:identifier];
        [cell setLayoutType:FTBasicCellLayoutTypeDefault];
    }
    [cell reset];

    FTAPIJobDataObject *job = [self jobAtIndexPath:indexPath];
    [cell setJob:job];
    [cell.textLabel setText:job.name];
    [cell setDescriptionText:(job.jobDetail.healthReport.description ? job.jobDetail.healthReport.description : FTLangGet(@"Loading ..."))];
    return cell;
}

- (UITableViewCell *)cellForOverview {
    if (_overviewCell) return _overviewCell;
    static NSString *identifier = @"cellForOverviewIdentifier";
    _overviewCell = [super.tableView dequeueReusableCellWithIdentifier:identifier];
    if (!_overviewCell) {
        _overviewCell = [[FTAccountOverviewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:identifier];
    }
    [_overviewCell setDelegate:self];
    [_overviewCell setJobsStats:_serverObject.jobsStats];
    return _overviewCell;
}

- (UITableViewCell *)cellForNoJob {
    UITableViewCell *cell;
    
    if(_isSearching)
    {
        static NSString *CellIdentifier = @"noSearchResultsCell";
        FTBasicCell *basicCell = (FTBasicCell *)[super.tableView dequeueReusableCellWithIdentifier:CellIdentifier];
        if (!basicCell) {
            basicCell = [[FTBasicCell alloc] initWithStyle:UITableViewCellStyleValue2 reuseIdentifier:CellIdentifier];
            basicCell.layoutType = FTBasicCellLayoutTypeDefault;
            basicCell.textLabel.textColor = [UIColor grayColor];
            basicCell.selectionStyle = UITableViewCellSelectionStyleNone;
        }
        cell = basicCell;
        cell.textLabel.text = FTLangGet(@"No search results");
    }
    else
    {
        static NSString *CellIdentifier = @"cellForNoJobIdentifier";
        cell = [super.tableView dequeueReusableCellWithIdentifier:CellIdentifier];
        if (!cell) {
            cell = [[FTNoJobCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellIdentifier];
        }
    }
    
    return cell;
}

- (FTIconCell *)iconCellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellIdentifier = @"cellForSettingsIdentifier";
    FTIconCell *cell = [super.tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (!cell) {
        cell = [[FTIconCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellIdentifier];
    }
    if (indexPath.row == 1) {
        [cell setAccessoryType:UITableViewCellAccessoryDisclosureIndicator];
        [cell.iconView setDefaultIconIdentifier:@"icon-road"];
        [cell.textLabel setText:FTLangGet(@"Build queue")];
        [cell.detailTextLabel setText:FTLangGet(@"And build executor status")];
    }
    else {
        [cell.iconView setDefaultIconIdentifier:@"icon-cogs"];
        [cell.textLabel setText:FTLangGet(@"Manage Jenkins")];
        if (kAccountsManager.selectedAccount.username && kAccountsManager.selectedAccount.username.length > 0) {
            [cell setAccessoryType:UITableViewCellAccessoryDisclosureIndicator];
            [cell setSelectionStyle:UITableViewCellSelectionStyleDefault];
            [cell.iconView setAlpha:1];
            [cell.textLabel setAlpha:1];
            [cell.detailTextLabel setAlpha:1];
            [cell.detailTextLabel setText:FTLangGet(@"Basic Jenkins configuration")];
        }
        else {
            [cell setAccessoryType:UITableViewCellAccessoryNone];
            [cell setSelectionStyle:UITableViewCellSelectionStyleNone];
            [cell.iconView setAlpha:0.4];
            [cell.textLabel setAlpha:0.4];
            [cell.detailTextLabel setAlpha:0.4];
            [cell.detailTextLabel setText:FTLangGet(@"Security needs to be enabled to access this section")];
        }
    }
    return cell;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (_isDataAvailable)
    {
        if ([self isOverviewSection:indexPath.section]) {
            if (indexPath.row == 0) return [self cellForOverview];
            else {
                return [self iconCellForRowAtIndexPath:indexPath];
            }
        }
        else if ([self.jobs count] == 0) {
            return [self cellForNoJob];
        }
        else {
            return [self cellForJobAtIndexPath:indexPath];
        }
    }
    else {
        return [FTLoadingCell cellForTable:tableView];
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:indexPath];
    
    if ([cell isKindOfClass:[FTNoJobCell class]]) {
        [self showViewSelector:nil];
        return;
    }
    else if ([cell isKindOfClass:[FTIconCell class]]) {
        if (indexPath.row == 1) {
            FTBuildQueueViewController *c = [[FTBuildQueueViewController alloc] init];
            [self.navigationController pushViewController:c animated:YES];
        }
        else {
            FTManageViewController *c = [[FTManageViewController alloc] init];
            [self.navigationController pushViewController:c animated:YES];
        }
        return;
    }
    
    FTAPIJobDataObject *job = [self jobAtIndexPath:indexPath];

    if (job.jobDetail) {
        FTJobDetailViewController *c = [[FTJobDetailViewController alloc] init];
        [c setTitle:job.name];
        [c setJob:job];
        [self.navigationController pushViewController:c animated:YES];
    }
}

#pragma mark Overview cell delegate methods

- (void)accountOverviewCell:(FTAccountOverviewCell *)cell requiresFilterForStat:(FTAPIServerStatsDataObject *)stat {
    //UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Selected filter" message:stat.color delegate:Nil cancelButtonTitle:@"Ok" otherButtonTitles:nil];
    //[alert show];
}

#pragma mark View selector delegate methods

- (void)viewSelectorController:(FTViewSelectorViewController *)controller didSelect:(FTAPIServerViewDataObject *)view {
    _selectedView = view;
    _serverObject = nil;
    [self loadData];
    self.navigationItem.rightBarButtonItem = nil;
    [controller dismissViewControllerAnimated:YES completion:^{
        
    }];
}

#pragma mark Private methods

- (BOOL)isOverviewSection:(NSInteger)section
{
    if (!_isDataAvailable || _isSearching) {
        return NO;
    }
    
    return (section == 0);
}

- (BOOL)isJobsSection:(NSInteger)section
{
    if (!_isDataAvailable) {
        return NO;
    }
    
    if (_isSearching) {
        return YES;
    }
    
    return (section == 1);
}

- (FTAPIJobDataObject *)jobAtIndexPath:(NSIndexPath *)indexPath
{
    if (!_isDataAvailable) {
        return nil;
    }
    
    NSUInteger dataCount = [self.jobs count];
    
    if (dataCount > 0 && indexPath.row < dataCount && [self isJobsSection:indexPath.section]) {
        return self.jobs[indexPath.row];
    }
    
    return nil;
}

@end
