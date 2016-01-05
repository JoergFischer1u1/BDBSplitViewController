//
//  BDBSplitViewController.m
//
//  Copyright (c) 2013-2014 Bradley David Bergeron
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy of
//  this software and associated documentation files (the "Software"), to deal in
//  the Software without restriction, including without limitation the rights to
//  use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
//  the Software, and to permit persons to whom the Software is furnished to do so,
//  subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
//  FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
//  COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
//  IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
//  CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

@import QuartzCore;

#import "BDBSplitViewController.h"


typedef NS_ENUM(NSInteger, BDBMasterViewState) {
    BDBMasterViewStateHidden,
    BDBMasterViewStateVisible
};


static void     * const kBDBSplitViewControllerKVOContext = (void *)&kBDBSplitViewControllerKVOContext;
static NSString * const kBDBSplitViewControllerKVOKeyPath = @"view.frame";


#pragma mark -
@interface BDBSplitViewController ()

@property (nonatomic) UIView *detailDimmingView;
@property (nonatomic) UITapGestureRecognizer *detailTapGesture;

@property (nonatomic, readwrite) UIBarButtonItem *showHideMasterViewButtonItem;
@property (nonatomic, readwrite) UIBarButtonItem *closeMasterViewButtonItem;

@property (nonatomic, readwrite) BDBMasterViewState masterViewState;

- (void)setupWithViewControllers:(NSArray *)viewControllers;

- (void)initialize;
- (void)configureMasterView;

- (void)toggleMasterView:(UIBarButtonItem *)sender;
- (void)closeMasterView:(UIBarButtonItem *)sender;

- (CGRect)masterViewFrameForState:(BDBMasterViewState)state;
- (CGRect)detailViewFrameForState:(BDBMasterViewState)state;

@end


#pragma mark -
@implementation BDBSplitViewController

#pragma mark Initialization
+ (instancetype)splitViewWithMasterViewController:(UIViewController *)mvc
                             detailViewController:(UIViewController *)dvc
{
    return [[[self class] alloc] initWithMasterViewController:mvc
                                         detailViewController:dvc];
}

+ (instancetype)splitViewWithMasterViewController:(UIViewController *)mvc
                             detailViewController:(UIViewController *)dvc
                                            style:(BDBSplitViewControllerMasterDisplayStyle)style
{
    return [[[self class] alloc] initWithMasterViewController:mvc
                                         detailViewController:dvc
                                                        style:style];
}

- (instancetype)initWithMasterViewController:(UIViewController *)mvc
                        detailViewController:(UIViewController *)dvc
{
    NSParameterAssert(mvc);
    NSParameterAssert(dvc);

    self = [super init];

    if (self) {
        [self setupWithViewControllers:@[mvc, dvc]];
    }

    return self;
}

- (instancetype)initWithMasterViewController:(UIViewController *)mvc
                        detailViewController:(UIViewController *)dvc
                                       style:(BDBSplitViewControllerMasterDisplayStyle)style
{
    self = [self initWithMasterViewController:mvc detailViewController:dvc];

    if (self) {
        _masterViewDisplayStyle = style;
    }

    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];

    if (self) {
        [self setupWithViewControllers:self.viewControllers];
    }

    return self;
}

- (void)setupWithViewControllers:(NSArray *)viewControllers
{
    NSParameterAssert(viewControllers);
    NSAssert(viewControllers.count == 2, @"viewControllers array must conatin both a master view controller and a detail view controller.");

    self.viewControllers = viewControllers;

    _masterViewDisplayStyle = BDBSplitViewControllerMasterDisplayStyleNormal;

    if (UIInterfaceOrientationIsPortrait([[UIApplication sharedApplication] statusBarOrientation])) {
        _masterViewState = BDBMasterViewStateHidden;
    } else {
        _masterViewState = BDBMasterViewStateVisible;
    }
}

#pragma mark View Lifecycle
- (void)dealloc
{
    [self.detailViewController removeObserver:self
                                   forKeyPath:kBDBSplitViewControllerKVOKeyPath
                                      context:kBDBSplitViewControllerKVOContext];
}

- (void)awakeFromNib
{
    [super awakeFromNib];

    [self initialize];
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    [self initialize];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];

    [self willRotateToInterfaceOrientation:[[UIApplication sharedApplication] statusBarOrientation] duration:0.f];
}

- (BOOL)prefersStatusBarHidden
{
    return self.statusBarHidden;
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];

    self.masterViewController.view.frame = [self masterViewFrameForState:self.masterViewState];
    self.detailViewController.view.frame = [self detailViewFrameForState:self.masterViewState];
}

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation
                                duration:(NSTimeInterval)duration
{
    [super willRotateToInterfaceOrientation:toInterfaceOrientation duration:duration];

    if (self.masterViewDisplayStyle == BDBSplitViewControllerMasterDisplayStyleNormal) {
        if (UIInterfaceOrientationIsLandscape(toInterfaceOrientation)) {
            if (self.masterViewIsHidden) {
                [self showMasterViewControllerAnimated:YES completion:nil];
            }
        } else {
            [self hideMasterViewControllerAnimated:YES completion:nil];
        }
    }
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation
{
    [super didRotateFromInterfaceOrientation:fromInterfaceOrientation];

    if (self.masterViewState == BDBMasterViewStateHidden) {
        self.masterViewController.view.hidden = YES;
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context
{
    if (context == kBDBSplitViewControllerKVOContext) {
        if ([object isEqual:self.detailViewController] && [keyPath isEqualToString:kBDBSplitViewControllerKVOKeyPath]) {
            UIView *view = self.detailViewController.view;

            CGRect currentFrame = [change[@"new"] CGRectValue];
            CGRect properFrame = [self detailViewFrameForState:self.masterViewState];

            if (!CGRectEqualToRect(currentFrame, properFrame)) {
                view.frame = [self detailViewFrameForState:self.masterViewState];
            }
        }
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

- (void)initialize
{
    self.detailDimmingView = [[UIView alloc] initWithFrame:self.view.frame];
    self.detailDimmingView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.detailDimmingView.backgroundColor = [UIColor colorWithWhite:0.f alpha:self.detailDimmingOpacity];
    self.detailDimmingView.alpha = 0.f;
    self.detailDimmingView.hidden = YES;
    [self.view insertSubview:self.detailDimmingView aboveSubview:self.detailViewController.view];

    self.detailTapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(detailViewTapped:)];
    self.detailTapGesture.numberOfTapsRequired = 1;
    self.detailTapGesture.numberOfTouchesRequired = 1;
    [self.detailDimmingView addGestureRecognizer:self.detailTapGesture];

    self.masterViewAnimationDuration = 0.3f;

    [self configureMasterView];
}

- (void)configureMasterView
{
    if (self.masterViewState == BDBMasterViewStateHidden) {
        self.masterViewController.view.hidden = YES;
    } else {
        self.masterViewController.view.hidden = NO;
    }

    if (self.masterViewDisplayStyle == BDBSplitViewControllerMasterDisplayStyleDrawer) {
        self.masterViewController.view.clipsToBounds = NO;
        self.masterViewController.view.layer.shadowColor = [UIColor blackColor].CGColor;
        self.masterViewController.view.layer.shadowOffset = (CGSize){0.f, 0.f};
        self.masterViewController.view.layer.shadowRadius = 10.f;
        self.masterViewController.view.layer.shadowOpacity = 0.8f;
    } else {
        self.masterViewController.view.clipsToBounds = YES;
        self.masterViewController.view.layer.shadowColor = nil;
        self.masterViewController.view.layer.shadowRadius = 0.f;
        self.masterViewController.view.layer.shadowOpacity = 0.f;
    }
}

#pragma mark UIBarButtonItems
- (UIBarButtonItem *)showHideMasterViewButtonItem
{
    if (!_showHideMasterViewButtonItem) {
        NSString *buttonTitle = (self.masterViewIsHidden) ?
            NSLocalizedStringWithDefaultValue(@"BDBSplitViewControllerShowButtonTitle",
                                              @"BDBSplitViewController",
                                              [NSBundle mainBundle],
                                              @"Show",
                                              @"Show/Hide button title when master view is hidden.") :
            NSLocalizedStringWithDefaultValue(@"BDBSplitViewControllerHideButtonTitle",
                                              @"BDBSplitViewController",
                                              [NSBundle mainBundle],
                                              @"Hide",
                                              @"Show/Hide button title when master view is visible.");

        _showHideMasterViewButtonItem = [[UIBarButtonItem alloc] initWithTitle:buttonTitle
                                                                         style:UIBarButtonItemStylePlain
                                                                        target:self
                                                                        action:@selector(toggleMasterView:)];
    }

    return _showHideMasterViewButtonItem;
}

- (UIBarButtonItem *)closeMasterViewButtonItem
{
    if (!_closeMasterViewButtonItem) {
        _closeMasterViewButtonItem =
            [[UIBarButtonItem alloc] initWithTitle:NSLocalizedStringWithDefaultValue(@"BDBSplitViewControllerCloseButtonTitle",
                                                                                     @"BDBSplitViewController",
                                                                                     [NSBundle mainBundle],
                                                                                     @"Close",
                                                                                     @"Close button title.")
                                             style:UIBarButtonItemStylePlain
                                            target:self
                                            action:@selector(closeMasterView:)];
    }

    return _closeMasterViewButtonItem;
}

- (void)toggleMasterView:(UIBarButtonItem *)sender
{
    if (self.masterViewIsHidden) {
        [self showMasterViewControllerAnimated:YES completion:nil];
    } else {
        [self hideMasterViewControllerAnimated:YES completion:nil];
    }
}

- (void)closeMasterView:(UIBarButtonItem *)sender
{
    if (!self.masterViewIsHidden) {
        [self hideMasterViewControllerAnimated:YES completion:nil];
    }
}

#pragma mark UIViewController Overrides
- (void)setViewControllers:(NSArray *)viewControllers
{
    NSParameterAssert(viewControllers);
    NSAssert(viewControllers.count == 2, @"viewControllers array must conatin both a master view controller and a detail view controller.");

    UIViewController *newDetailVC = viewControllers[1];

    if (self.detailViewController && ![self.detailViewController isEqual:newDetailVC]) {
        [self.detailViewController removeObserver:self
                                       forKeyPath:kBDBSplitViewControllerKVOKeyPath
                                          context:kBDBSplitViewControllerKVOContext];
    }

    [super setViewControllers:viewControllers];

    [newDetailVC addObserver:self
                  forKeyPath:kBDBSplitViewControllerKVOKeyPath
                     options:NSKeyValueObservingOptionNew|NSKeyValueObservingOptionOld
                     context:kBDBSplitViewControllerKVOContext];

    [self configureMasterView];
}

#pragma mark Master / Detail Accessors
- (UIViewController *)masterViewController
{
    NSAssert(self.viewControllers.count > 0, @"self.viewControllers does not conatin a master view controller.");

    return self.viewControllers[0];
}

- (UIViewController *)detailViewController
{
    return (self.viewControllers.count < 2) ? nil : self.viewControllers[1];
}

- (void)setDetailViewController:(UIViewController *)dvc
{
    NSParameterAssert(dvc);

    self.viewControllers = @[self.masterViewController, dvc];
}

#pragma mark Master View
- (void)setMasterViewDisplayStyle:(BDBSplitViewControllerMasterDisplayStyle)style
{
    [self setMasterViewDisplayStyle:style animated:NO];
}

- (void)setMasterViewDisplayStyle:(BDBSplitViewControllerMasterDisplayStyle)style
                         animated:(BOOL)animated
{
    _masterViewDisplayStyle = style;

    switch (style) {
        case BDBSplitViewControllerMasterDisplayStyleSticky: {
            self.detailViewShouldDim = NO;
            self.masterViewShouldDismissOnTap = NO;

            break;
        }
        case BDBSplitViewControllerMasterDisplayStyleDrawer: {
            self.detailViewShouldDim = YES;
            self.masterViewShouldDismissOnTap = YES;
            self.masterViewState = BDBMasterViewStateHidden;

            break;
        }
        case BDBSplitViewControllerMasterDisplayStyleNormal:
        default: {
            self.detailViewShouldDim = NO;
            self.masterViewShouldDismissOnTap = NO;

            if (UIInterfaceOrientationIsLandscape([[UIApplication sharedApplication] statusBarOrientation])) {
                [self showMasterViewControllerAnimated:animated completion:nil];
            } else {
                [self hideMasterViewControllerAnimated:animated completion:nil];
            }

            break;
        }
    }

    [self configureMasterView];
}

- (BOOL)masterViewIsHidden
{
    return (self.masterViewState == BDBMasterViewStateHidden);
}

- (CGRect)masterViewFrameForState:(BDBMasterViewState)state
{
    CGRect masterViewFrame = self.masterViewController.view.frame;

    switch (state) {
        case BDBMasterViewStateHidden: {
            masterViewFrame = (CGRect){{-masterViewFrame.size.width, 0.f}, masterViewFrame.size};

            break;
        }
        case BDBMasterViewStateVisible:
        default: {
            masterViewFrame = (CGRect){CGPointZero, masterViewFrame.size};

            break;
        }
    }

    return masterViewFrame;
}

#pragma mark Detail View
- (CGFloat)detailDimmingOpacity
{
    if (!_detailViewDimmingOpacity) {
        _detailViewDimmingOpacity = 0.4f;
    }

    return _detailViewDimmingOpacity;
}

- (void)setDetailDimmingOpacity:(CGFloat)opacity
{
    NSAssert(opacity >= 0.f && opacity <= 1.f, @"Opacity must be between 0 and 1.");

    _detailViewDimmingOpacity = opacity;
    self.detailDimmingView.backgroundColor = [UIColor colorWithWhite:0.f alpha:opacity];
}

- (void)detailViewTapped:(UITapGestureRecognizer *)recognizer
{
    [self hideMasterViewControllerAnimated:YES completion:nil];
}

- (CGRect)detailViewFrameForState:(BDBMasterViewState)state
{
    if (self.masterViewDisplayStyle == BDBSplitViewControllerMasterDisplayStyleDrawer) {
        return self.view.bounds;
    }

    CGRect masterViewFrame = self.masterViewController.view.frame;
    CGRect detailViewFrame = self.detailViewController.view.frame;

    CGRect frame;

    switch (state) {
        case BDBMasterViewStateHidden: {
            frame = self.view.bounds;

            break;
        }
        case BDBMasterViewStateVisible:
        default: {
            frame = (CGRect){{masterViewFrame.size.width + 1.f, 0.f}, {self.view.bounds.size.width - masterViewFrame.size.width - 1.f, detailViewFrame.size.height}};

            break;
        }
    }

    return frame;
}

#pragma mark Show / Hide Master View
- (void)showMasterViewControllerAnimated:(BOOL)animated
                              completion:(void (^)(void))completion
{
    if (!self.masterViewIsHidden) {
        return;
    }

    if (self.detailViewShouldDim) {
        self.detailDimmingView.frame = self.view.bounds;
        self.detailDimmingView.hidden = NO;
    }

    if (self.masterViewShouldDismissOnTap) {
        self.detailTapGesture.enabled = YES;
    }

    if ([self.svcDelegate respondsToSelector:@selector(splitViewControllerWillShowMasterViewController:)]) {
        [self.svcDelegate splitViewControllerWillShowMasterViewController:self];
    }

    [self.masterViewController viewWillAppear:animated];

    self.masterViewState = BDBMasterViewStateVisible;
    self.masterViewController.view.hidden = NO;

    if (animated) {
        [UIView animateWithDuration:self.masterViewAnimationDuration
                              delay:0.f
                            options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState
                         animations:^{
                             self.detailDimmingView.alpha = 1.f;

                             self.masterViewController.view.frame = [self masterViewFrameForState:BDBMasterViewStateVisible];
                             self.detailViewController.view.frame = [self detailViewFrameForState:BDBMasterViewStateVisible];

                             [self.masterViewController.view layoutIfNeeded];
                             [self.detailViewController.view layoutIfNeeded];
                         }
                         completion:^(BOOL finished) {
                             [self didShowMasterViewController:animated completion:completion];
                         }];
    } else {
        [self didShowMasterViewController:animated completion:completion];
    }
}

- (void)didShowMasterViewController:(BOOL)animated
                         completion:(void (^)(void))completion
{
    self.showHideMasterViewButtonItem.title = NSLocalizedStringWithDefaultValue(@"BDBSplitViewControllerHideButtonTitle",
                                                                                @"BDBSplitViewController",
                                                                                [NSBundle mainBundle],
                                                                                @"Hide",
                                                                                @"Show/Hide button title when master view is visible.");

    [self.masterViewController viewDidAppear:animated];
    [self.view setNeedsLayout];

    if ([self.svcDelegate respondsToSelector:@selector(splitViewControllerDidShowMasterViewController:)]) {
        [self.svcDelegate splitViewControllerDidShowMasterViewController:self];
    }

    if (completion) {
        completion();
    }
}

- (void)hideMasterViewControllerAnimated:(BOOL)animated
                              completion:(void (^)(void))completion
{
    if (self.masterViewIsHidden) {
        return;
    }

    if ([self.svcDelegate respondsToSelector:@selector(splitViewControllerWillHideMasterViewController:)]) {
        [self.svcDelegate splitViewControllerWillHideMasterViewController:self];
    }

    [self.masterViewController viewWillDisappear:animated];

    self.masterViewState = BDBMasterViewStateHidden;

    if (animated) {
        [UIView animateWithDuration:self.masterViewAnimationDuration
                              delay:0.f
                            options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState
                         animations:^{
                             self.detailDimmingView.alpha = 0.f;

                             self.masterViewController.view.frame = [self masterViewFrameForState:BDBMasterViewStateHidden];
                             self.detailViewController.view.frame = [self detailViewFrameForState:BDBMasterViewStateHidden];

                             [self.masterViewController.view layoutIfNeeded];
                             [self.detailViewController.view layoutIfNeeded];
                         }
                         completion:^(BOOL finished) {
                             [self didHideMasterViewController:animated completion:completion];
                         }];
    } else {
        [self didHideMasterViewController:animated completion:completion];
    }
}

- (void)didHideMasterViewController:(BOOL)animated
                         completion:(void (^)(void))completion
{
    self.masterViewController.view.hidden = YES;

    self.detailDimmingView.hidden = YES;
    self.detailTapGesture.enabled = NO;

    self.showHideMasterViewButtonItem.title = NSLocalizedStringWithDefaultValue(@"BDBSplitViewControllerShowButtonTitle",
                                                                                @"BDBSplitViewController",
                                                                                [NSBundle mainBundle],
                                                                                @"Show",
                                                                                @"Show/Hide button title when master view is hidden.");

    [self.masterViewController viewDidDisappear:animated];
    [self.view setNeedsLayout];

    if ([self.svcDelegate respondsToSelector:@selector(splitViewControllerDidHideMasterViewController:)]) {
        [self.svcDelegate splitViewControllerDidHideMasterViewController:self];
    }

    if (completion) {
        completion();
    }
}

@end


#pragma mark -
@implementation UIViewController (BDBSplitViewController)

- (BDBSplitViewController *)bdb_splitViewController
{
    UIViewController *parentViewController = self;

    while (parentViewController) {
        if ([parentViewController isKindOfClass:[BDBSplitViewController class]]) {
            return (BDBSplitViewController *)parentViewController;
        }

        parentViewController = parentViewController.parentViewController;
    }

    return nil;
}

@end


#pragma mark -
@implementation BDBDetailViewController

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.bdb_splitViewController.delegate = self;
}

- (BOOL)splitViewController:(BDBSplitViewController *)svc
   shouldHideViewController:(UIViewController *)vc
              inOrientation:(UIInterfaceOrientation)orientation
{
    switch (svc.masterViewDisplayStyle) {
        case BDBSplitViewControllerMasterDisplayStyleSticky: {
            return NO;
        }
        case BDBSplitViewControllerMasterDisplayStyleDrawer: {
            return svc.masterViewIsHidden;
        }
        case BDBSplitViewControllerMasterDisplayStyleNormal:
        default: {
            if (svc.masterViewIsHidden) {
                return UIInterfaceOrientationIsPortrait(orientation);
            } else {
                return NO;
            }
        }
    }
}

@end
