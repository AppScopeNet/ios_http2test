// 
// Copyright (c) 2016 AppScope.net
// 
// See LICENSE

@import QuartzCore;

#import "ASViewController.h"


#define kRowsCount              10
#define kColumnsCount           20
#define kCellsCount             (kRowsCount * kColumnsCount)
#define kHttp1EndpointUrlTpl    @"https://dprxmob557h5a.cloudfront.net/demo/tile-%d.png"
#define kHttp2EndpointUrlTpl    @"https://http2demo.cloudflare.com/demo/tile-%d.png"
#define kLabelTextTpl           @"HTTP/%d: Load time: %.02fs."


@interface ASViewController()<UICollectionViewDataSource, UICollectionViewDelegate, NSURLSessionDelegate> {
    
    UILabel *activeLabel;
    UICollectionView *activeCollectionView;
    
    NSMutableDictionary *taskIdentifiers;
    NSMutableDictionary *imagesData;
    NSDate *startTime;
    NSURLSession *session;
    
    BOOL isTestRunning;
    BOOL http2Test;
    
    NSTimeInterval http1Time;
}

@property (nonatomic, retain) IBOutlet UIButton *runTestButton;
@property (nonatomic, retain) IBOutlet UIButton *resetCacheButton;
@property (nonatomic, retain) IBOutlet UISwitch *useCacheSwitch;
@property (nonatomic, retain) IBOutlet UILabel *http1Label;
@property (nonatomic, retain) IBOutlet UILabel *http2Label;
@property (nonatomic, retain) IBOutlet UILabel *resultLabel;
@property (nonatomic, retain) IBOutlet UILabel *useCacheLabel;
@property (nonatomic, retain) IBOutlet UICollectionView *http1CollectionView;
@property (nonatomic, retain) IBOutlet UICollectionView *http2CollectionView;
@property (nonatomic, retain) IBOutlet UIScrollView *scrollView;

@end


@implementation ASViewController


@synthesize runTestButton;
@synthesize resetCacheButton;
@synthesize useCacheSwitch;
@synthesize http1Label;
@synthesize http2Label;
@synthesize resultLabel;
@synthesize useCacheLabel;
@synthesize http1CollectionView;
@synthesize http2CollectionView;
@synthesize scrollView;


#pragma mark - Initialization

- (void)viewDidLoad {
    
    [super viewDidLoad];
    
    taskIdentifiers = [NSMutableDictionary dictionaryWithCapacity:kCellsCount];
    imagesData = [NSMutableDictionary dictionaryWithCapacity:kCellsCount];
    
    resetCacheButton.enabled = NO;
    useCacheSwitch.on = NO;
    
    [http1CollectionView registerClass:[UICollectionViewCell class] forCellWithReuseIdentifier:NSStringFromClass([UICollectionViewCell class])];
    [http2CollectionView registerClass:[UICollectionViewCell class] forCellWithReuseIdentifier:NSStringFromClass([UICollectionViewCell class])];
    
    CGRect frame = http1CollectionView.frame;
    CGFloat height = kRowsCount * frame.size.width / kColumnsCount;
    CGFloat offset = height - frame.size.height;
    frame.size.height = height;
    http1CollectionView.frame = frame;
    
    frame = http2CollectionView.frame;
    frame.origin.y += offset;
    frame.size.height = height;
    http2CollectionView.frame = frame;
    
    [self moveView:http2Label atOffset:offset];
    
    offset *= 2;
    
    [self moveView:resultLabel atOffset:offset];
    [self moveView:resetCacheButton atOffset:offset];
    [self moveView:useCacheSwitch atOffset:offset];
    [self moveView:useCacheLabel atOffset:offset];
    [self moveView:runTestButton atOffset:offset];
    
    CGSize size = scrollView.contentSize;
    frame = runTestButton.frame;
    height = frame.origin.y + frame.size.height + 20;
    
    if (size.height < height) {
        
        size.height = height;
        scrollView.contentSize = size;
    }
}


#pragma mark - Actions

- (IBAction)runTest:(UIButton *)sender {
    
    if (isTestRunning) {
        
        isTestRunning = NO;
        runTestButton.enabled = NO;
        
        [session getAllTasksWithCompletionHandler:^(NSArray<__kindof NSURLSessionTask *> * _Nonnull tasks) {
            
            for (NSURLSessionTask *task in tasks) {
                
                [task cancel];
            }
            
            [taskIdentifiers removeAllObjects];
            [imagesData removeAllObjects];
            
            [self enableControls:YES];
            
            runTestButton.enabled = YES;
        }];
    }
    else {
        
        NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
        config.networkServiceType = NSURLNetworkServiceTypeDefault;
        config.requestCachePolicy = useCacheSwitch.on ?
            NSURLRequestUseProtocolCachePolicy : NSURLRequestReloadIgnoringLocalCacheData;
        session = [NSURLSession sessionWithConfiguration:config delegate:self delegateQueue:[NSOperationQueue mainQueue]];
        
        isTestRunning = YES;
        http2Test = NO;
        
        http1Label.text = [NSString stringWithFormat:kLabelTextTpl, 1, 0.0];
        http2Label.text = [NSString stringWithFormat:kLabelTextTpl, 2, 0.0];
        resultLabel.text = @"";
        
        [http1CollectionView reloadData];
        [http2CollectionView reloadData];
        
        [self enableControls:NO];
        [self runTestForEndpoint:kHttp1EndpointUrlTpl withView:http1CollectionView label:http1Label];
    }
}

- (IBAction)resetCache:(UIButton *)sender {
    
    [[NSURLCache sharedURLCache] removeAllCachedResponses];
}

- (IBAction)useCache:(UISwitch *)sender {
    
    resetCacheButton.enabled = sender.on;
}


#pragma mark - Helper methods

- (void)moveView:(UIView *)view atOffset:(CGFloat)offset {
    
    CGRect frame = view.frame;
    frame.origin.y += offset;
    view.frame = frame;
}

- (void)enableControls:(BOOL)enable {

    useCacheSwitch.enabled = enable;
    resetCacheButton.enabled = useCacheSwitch.on && enable;
    runTestButton.selected = !enable;
}

- (void)runTestForEndpoint:(NSString *)endpoint withView:(UICollectionView *)view label:(UILabel *)label {
    
    [taskIdentifiers removeAllObjects];
    [imagesData removeAllObjects];
    
    startTime = [NSDate new];
    activeLabel = label;
    activeCollectionView = view;
    int counter = 0;
    
    for (int i = 0; i < kRowsCount; i++) {
        
        for (int j = 0; j < kColumnsCount; j++) {
            
            NSString *url = [NSString stringWithFormat:endpoint, counter];
            NSURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:url]];
            NSURLSessionDataTask *task = [session dataTaskWithRequest:request];
            task.priority = counter >= (kCellsCount / 2) ? NSURLSessionTaskPriorityHigh : NSURLSessionTaskPriorityLow;
            [task resume];
            
            NSNumber *key = @(task.taskIdentifier);
            [imagesData setObject:[NSMutableData new] forKey:key];
            [taskIdentifiers setObject:@(counter) forKey:key];
            
            counter++;
        }
    }
}


#pragma mark - UICollectionViewDelegate methods

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath
{
    CGFloat width = collectionView.frame.size.width / kColumnsCount;
    CGFloat height = collectionView.frame.size.height / kRowsCount;
    return CGSizeMake(width, height);
}


#pragma mark - UICollectionViewDataSource methods

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView {
    
    return 1;
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    
    return kCellsCount;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    
    UICollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:NSStringFromClass([UICollectionViewCell class]) forIndexPath:indexPath];
    cell.layer.contentsGravity = kCAGravityResize;
    cell.layer.contents = nil;
    
    return cell;
}


#pragma mark - NSURLSessionDataDelegate delegate

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask
                                     didReceiveData:(NSData *)data {
    
    if (!isTestRunning) {
        
        return;
    }
    
    NSNumber *key = @(dataTask.taskIdentifier);
    NSMutableData *imageData = [imagesData objectForKey:key];
    
    if (imageData) {
        
        [imageData appendData:data];
    }
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task
                           didCompleteWithError:(nullable NSError *)error {
    
    if (!isTestRunning) {
        
        return;
    }
    
    NSNumber *key = @(task.taskIdentifier);
    
    if (!error) {
        
        NSNumber *identifier = [taskIdentifiers objectForKey:key];
        
        if (identifier) {
            
            UICollectionViewCell *cell = [activeCollectionView cellForItemAtIndexPath:[NSIndexPath indexPathForRow:[identifier integerValue] inSection:0]];
            
            if (cell) {
                
                NSMutableData *imageData = [imagesData objectForKey:key];
                
                if (imageData) {
                    
                    UIImage *image = [UIImage imageWithData:imageData];
                    
                    if (image) {
                        
                        cell.layer.contents = (__bridge id)image.CGImage;
                    }
                }
            }
        }
    }
    else {
        
        NSLog(@"Connection error: %@", [error localizedDescription]);
    }
    
    [taskIdentifiers removeObjectForKey:key];
    
    NSUInteger count = taskIdentifiers.count;
    NSDate *now = [NSDate new];
    
    if (count == 0 || count % 5 == 0) {
        
        NSTimeInterval interval = [now timeIntervalSinceDate:startTime];
        activeLabel.text = [NSString stringWithFormat:kLabelTextTpl, (http2Test ? 2 : 1), interval];
    }
    
    if (count == 0) {
        
        if (http2Test) {
            
            isTestRunning = NO;
            
            [self enableControls:YES];
            
            NSTimeInterval http2Time = [now timeIntervalSinceDate:startTime];
            resultLabel.text = [NSString stringWithFormat:@"HTTP/2 was %.1fx faster than HTTP/1.1", http1Time / http2Time];
        }
        else {
            
            http1Time = [now timeIntervalSinceDate:startTime];
            http2Test = YES;
            
            [self runTestForEndpoint:kHttp2EndpointUrlTpl withView:http2CollectionView label:http2Label];
        }
    }
}


@end
