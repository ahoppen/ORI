#import "PathViewController.h"

#import "PathCell.h"
#import "FileCell.h"

#import "PlistViewController.h"
#import "ImageViewController.h"
#import "BinaryFileViewController.h"
#import "NibViewController.h"

#import "UIViewController+FileViewController.h"

@interface PathViewController () <UIDocumentInteractionControllerDelegate>

@property (nonatomic, retain) NSArray* files;
@property (nonatomic, retain) NSMutableArray* filesFiltered;

@property (nonatomic, retain) UIDocumentInteractionController* interactionController;

@end


@implementation PathViewController

@synthesize path = _path;
@synthesize files = _files;

@synthesize interactionController = _interactionController;

- (void)setup {
	if([self.path isEqualToString:@"/"]) {
		self.title = @"/";
	} else {
		self.title = [self.path lastPathComponent];
	}
	
	NSError* error = nil;
	self.files = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:self.path error:&error];
	self.filesFiltered = [[self.files mutableCopy]autorelease];
	
	if(error) {
		NSLog(@"%@", error);
	}
}

- (id)initWithPath:(NSString*)path {
	self = [super init];
	if(self != nil) {
		self.path = path;
		
		[self setup];
	}
	return self;
}

- (id)initWithCoder:(NSCoder*)coder {
	self = [super initWithCoder:coder];
	if(self != nil) {
		self.path = @"/";
		
		[self setup];
	}
	return self;
}

- (void)dealloc {
	self.path = nil;
	self.files = nil;
	self.filesFiltered = nil;
	
	self.interactionController = nil;
	
	[super dealloc];
}

- (void)viewDidLoad {
	[super viewDidLoad];
}

- (void)viewDidUnload {
	self.interactionController = nil;
	
	[super viewDidUnload];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation {
	return YES;
}

#pragma mark -
#pragma mark UITableViewDataSource / UITableViewDelegate

- (NSInteger)numberOfSectionsInTableView:(UITableView*)tableView {
	return 1;
}

- (NSInteger)tableView:(UITableView*)tableView numberOfRowsInSection:(NSInteger)section {
	return self.filesFiltered.count;
}

- (UITableViewCell*)tableView:(UITableView*)tableView cellForRowAtIndexPath:(NSIndexPath*)indexPath {
	NSString* name = [self.filesFiltered objectAtIndex:indexPath.row];
	NSString* fullPath = [self.path stringByAppendingPathComponent:name];
	NSDictionary* attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:fullPath error:nil];
	
	//	NSLog(@"%@ %@", name, attributes);
	
	if([[attributes fileType] isEqual:NSFileTypeDirectory]) {
		PathCell* cell = (PathCell*)[tableView dequeueReusableCellWithIdentifier:[PathCell reuseIdentifier]];
		if(cell == nil) {
			cell = [PathCell cell];
		}
		
		cell.nameView.text = name;
		
		return cell;
	} else {
		FileCell* cell = (FileCell*)[tableView dequeueReusableCellWithIdentifier:[FileCell reuseIdentifier]];
		if(cell == nil) {
			cell = [FileCell cell];
			
			UILongPressGestureRecognizer* gestureRecognizer = [[[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(tableViewCellLongPress:)] autorelease];
			gestureRecognizer.minimumPressDuration = 0.5;
			gestureRecognizer.cancelsTouchesInView = NO;
			[cell addGestureRecognizer:gestureRecognizer];
		}
		
		cell.nameView.text = name;
		
		unsigned long long fileSize = attributes.fileSize;
		if(fileSize == 0) {
			cell.sizeView.text = @"Zero Bytes";
		} else if(fileSize < 1024) {
			cell.sizeView.text = [NSString stringWithFormat:@"%llu B", fileSize];
		} else if(fileSize < 1024 * 1024) {
			cell.sizeView.text = [NSString stringWithFormat:@"%.1f kB", fileSize / 1024.0f];
		} else {
			cell.sizeView.text = [NSString stringWithFormat:@"%.1f MB", fileSize / (1024.0f * 1024.0f)];
		}
		
		return cell;
	}
}

- (void)tableView:(UITableView*)tableView didSelectRowAtIndexPath:(NSIndexPath*)indexPath {
	if(self.interactionController) {
		return;
	}
	
	NSString* name = [self.filesFiltered objectAtIndex:indexPath.row];
	NSString* fullPath = [self.path stringByAppendingPathComponent:name];
	
	if ([[NSFileManager defaultManager]fileExistsAtPath:fullPath]) {
		if ([[NSFileManager defaultManager]isReadableFileAtPath:fullPath]) {
			UIViewController* viewController = [UIViewController viewControllerForPath:fullPath];
			if(viewController) {
				[self.navigationController pushViewController:viewController animated:YES];
			} else {
			}
			[self.searchDisplayController setActive:NO animated:YES];
		} else {
			[[[[UIAlertView alloc]initWithTitle:@"No permission" message:@"No rights to read the file" delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil]autorelease]show];
			[tableView deselectRowAtIndexPath:indexPath animated:YES];
		}
	} else {
		[[[[UIAlertView alloc]initWithTitle:@"No file" message:@"The file does no longer exist" delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil]autorelease]show];
		[tableView deselectRowAtIndexPath:indexPath animated:YES];
	}
}

- (void)tableViewCellLongPress:(id)sender {
	UILongPressGestureRecognizer* gestureRecognizer = sender;
	if(gestureRecognizer.state == UIGestureRecognizerStateBegan)
	{
		UITableViewCell* cell = (UITableViewCell*)gestureRecognizer.view;
		
		UITableView* tableView = (UITableView*)cell.superview;
		
		NSIndexPath* indexPath = [tableView indexPathForCell:cell];
		
		NSString* name = [self.filesFiltered objectAtIndex:indexPath.row];
		NSString* fullPath = [self.path stringByAppendingPathComponent:name];
		
		NSURL* URL = [NSURL fileURLWithPath:fullPath];
		
		self.interactionController = [UIDocumentInteractionController interactionControllerWithURL:URL];
		self.interactionController.delegate = self;
		[self.interactionController presentOptionsMenuFromRect:cell.frame inView:tableView animated:YES];
	}
}

#pragma mark - UISearchDisplayDelegate

- (void)searchDisplayControllerDidBeginSearch:(UISearchDisplayController *)controller {
}

- (BOOL)searchDisplayController:(UISearchDisplayController *)controller shouldReloadTableForSearchString:(NSString *)searchString {
	self.filesFiltered = [[self.files mutableCopy]autorelease];
	[self.filesFiltered filterUsingPredicate:[NSPredicate predicateWithFormat:@"self CONTAINS[c] %@", searchString]];
	return YES;
}

- (void)searchDisplayControllerWillEndSearch:(UISearchDisplayController *)controller {
	self.filesFiltered = [[self.files mutableCopy]autorelease];
}


#pragma mark - UIDocumentInteractionControllerDelegate

- (void)documentInteractionControllerDidDismissOptionsMenu:(UIDocumentInteractionController*)controller {
	[self.tableView deselectRowAtIndexPath:self.tableView.indexPathForSelectedRow animated:NO];
	
	self.interactionController = nil;
}

@end

