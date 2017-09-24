//
//  Created by Jesse Squires
//  http://www.jessesquires.com
//
//
//  Documentation
//  http://cocoadocs.org/docsets/JSQMessagesViewController
//
//
//  GitHub
//  https://github.com/jessesquires/JSQMessagesViewController
//
//
//  License
//  Copyright (c) 2014 Jesse Squires
//  Released under an MIT license: http://opensource.org/licenses/MIT
//

#import "JSQMessagesViewController.h"

#import "JSQMessagesCollectionViewFlowLayoutInvalidationContext.h"

#import "JSQMessageData.h"
#import "JSQMessageBubbleImageDataSource.h"
#import "JSQMessageAvatarImageDataSource.h"

#import "JSQMessagesCollectionViewCellIncoming.h"
#import "JSQMessagesCollectionViewCellOutgoing.h"

#import "JSQMessagesTypingIndicatorFooterView.h"
#import "JSQMessagesLoadEarlierHeaderView.h"

#import "JSQMessagesToolbarContentView.h"
#import "JSQMessagesInputToolbar.h"
#import "JSQMessagesComposerTextView.h"

#import "NSString+JSQMessages.h"
#import "UIColor+JSQMessages.h"
#import "UIDevice+JSQMessages.h"
#import "NSBundle+JSQMessages.h"

#import <objc/runtime.h>
#import <pop/POP.h>

static void * kJSQMessagesKeyValueObservingContext = &kJSQMessagesKeyValueObservingContext;

const CGFloat kSearchBarAnimationDuration = 0.2;

@interface JSQMessagesViewController () <JSQMessagesInputToolbarDelegate,
JSQMessagesKeyboardControllerDelegate>

@property (weak, nonatomic) IBOutlet JSQMessagesCollectionView *collectionView;
@property (weak, nonatomic) IBOutlet JSQMessagesInputToolbar *inputToolbar;
@property (weak, nonatomic) IBOutlet UIView *pickerToolbar;
@property (weak, nonatomic) IBOutlet UIView *adContainerView;

@property (weak, nonatomic) IBOutlet NSLayoutConstraint *toolbarHeightConstraint;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *toolbarBottomLayoutGuide;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *pickerToolbarHeightConstraint;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *pickerViewHeightConstraint;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *adContainerHeightConstraint;

@property (assign, nonatomic) BOOL isAdVisible;

@property (weak, nonatomic) UIView *snapshotView;

@property (assign, nonatomic) BOOL jsq_isObserving;

@property (strong, nonatomic) NSIndexPath *selectedIndexPathForMenu;

@property (weak, nonatomic) UIGestureRecognizer *currentInteractivePopGestureRecognizer;

@property (assign, nonatomic) BOOL textViewWasFirstResponderDuringInteractivePop;

@property (nonatomic) BOOL transitioningSize;

@end



@implementation JSQMessagesViewController

#pragma mark - Class methods

+ (UINib *)nib
{
    return [UINib nibWithNibName:NSStringFromClass([JSQMessagesViewController class])
                          bundle:[NSBundle bundleForClass:[JSQMessagesViewController class]]];
}

+ (instancetype)messagesViewController
{
    return [[[self class] alloc] initWithNibName:NSStringFromClass([JSQMessagesViewController class])
                                          bundle:[NSBundle bundleForClass:[JSQMessagesViewController class]]];
}

+ (void)initialize {
    [super initialize];
    if (self == [JSQMessagesViewController self]) {

    }
}

#pragma mark - Initialization

- (void)jsq_configureMessagesViewController
{
    self.view.backgroundColor = [UIColor whiteColor];

    self.jsq_isObserving = NO;

    self.toolbarHeightConstraint.constant = self.inputToolbar.preferredDefaultHeight;

    self.collectionView.dataSource = self;
    self.collectionView.delegate = self;

    self.inputToolbar.delegate = self;
    self.inputToolbar.contentView.textView.placeHolder = [NSBundle jsq_localizedStringForKey:@"new_message"];

    self.inputToolbar.contentView.textView.accessibilityLabel = [NSBundle jsq_localizedStringForKey:@"new_message"];

    self.inputToolbar.contentView.textView.delegate = self;

    self.automaticallyScrollsToMostRecentMessage = YES;

    self.outgoingCellIdentifier = [JSQMessagesCollectionViewCellOutgoing cellReuseIdentifier];
    self.outgoingMediaCellIdentifier = [JSQMessagesCollectionViewCellOutgoing mediaCellReuseIdentifier];

    self.incomingCellIdentifier = [JSQMessagesCollectionViewCellIncoming cellReuseIdentifier];
    self.incomingMediaCellIdentifier = [JSQMessagesCollectionViewCellIncoming mediaCellReuseIdentifier];

    // NOTE: let this behavior be opt-in for now
    // [JSQMessagesCollectionViewCell registerMenuAction:@selector(delete:)];

    self.showTypingIndicator = NO;

    self.showLoadEarlierMessagesHeader = NO;

    self.topContentAdditionalInset = 0.0f;

    self.bottomContentAdditionalInset = [self targetAdHeight];

    self.isAdVisible = YES;

    self.adContainerView.clipsToBounds = YES;
    self.adContainerView.accessibilityLabel = @"Ad Container";

    self.pickerView = [UIView new];

    [self jsq_updateCollectionViewInsetsAnimated:NO];

    // Don't set keyboardController if client creates custom content view via -loadToolbarContentView
    if (self.inputToolbar.contentView.textView != nil) {
        self.keyboardController = [[JSQMessagesKeyboardController alloc] initWithTextView:self.inputToolbar.contentView.textView
                                                                              contextView:self.view
                                                                     panGestureRecognizer:self.collectionView.panGestureRecognizer
                                                                                 delegate:self];
    }
}

- (void)dealloc
{
    [self jsq_registerForNotifications:NO];
    [self jsq_removeObservers];

    _collectionView.dataSource = nil;
    _collectionView.delegate = nil;

    _inputToolbar.contentView.textView.delegate = nil;
    _inputToolbar.delegate = nil;

    [_keyboardController endListeningForKeyboard];
    _keyboardController = nil;
}

#pragma mark - Setters

- (void)setShowTypingIndicator:(BOOL)showTypingIndicator
{
    if (_showTypingIndicator == showTypingIndicator) {
        return;
    }

    _showTypingIndicator = showTypingIndicator;
    [self.collectionView.collectionViewLayout invalidateLayoutWithContext:[JSQMessagesCollectionViewFlowLayoutInvalidationContext context]];
    [self.collectionView.collectionViewLayout invalidateLayout];
}

- (void)setShowLoadEarlierMessagesHeader:(BOOL)showLoadEarlierMessagesHeader
{
    if (_showLoadEarlierMessagesHeader == showLoadEarlierMessagesHeader) {
        return;
    }

    _showLoadEarlierMessagesHeader = showLoadEarlierMessagesHeader;
    [self.collectionView.collectionViewLayout invalidateLayoutWithContext:[JSQMessagesCollectionViewFlowLayoutInvalidationContext context]];
    [self.collectionView.collectionViewLayout invalidateLayout];
    [self.collectionView reloadData];
}

- (void)setTopContentAdditionalInset:(CGFloat)topContentAdditionalInset
                            animated:(BOOL)animated
{
    _topContentAdditionalInset = topContentAdditionalInset;
    [self jsq_updateCollectionViewInsetsAnimated:animated];
}

#pragma mark - View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];

    [[[self class] nib] instantiateWithOwner:self options:nil];

    [self jsq_configureMessagesViewController];
    [self jsq_registerForNotifications:YES];

    self.toolbarHeightConstraint.constant = self.inputToolbar.preferredDefaultHeight;
}

- (void)viewWillAppear:(BOOL)animated
{
    NSParameterAssert(self.senderId != nil);
    NSParameterAssert(self.senderDisplayName != nil);

    [super viewWillAppear:animated];
    [self.view layoutIfNeeded];
    [self.collectionView.collectionViewLayout invalidateLayout];

    if (self.automaticallyScrollsToMostRecentMessage) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self scrollToBottomAnimated:NO];
            [self.collectionView.collectionViewLayout invalidateLayoutWithContext:[JSQMessagesCollectionViewFlowLayoutInvalidationContext context]];
        });
    }

    [self jsq_updateKeyboardTriggerPoint];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [self jsq_addObservers];
    [self jsq_addActionToInteractivePopGestureRecognizer:YES];
    [self.keyboardController beginListeningForKeyboard];

    if ([UIDevice jsq_isCurrentDeviceBeforeiOS8]) {
        [self.snapshotView removeFromSuperview];
    }
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    self.collectionView.collectionViewLayout.springinessEnabled = NO;

    self.isPickerViewVisible = NO;

    [self.inputToolbar.contentView.textView resignFirstResponder];
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    [self jsq_addActionToInteractivePopGestureRecognizer:NO];
    [self jsq_removeObservers];
    [self.keyboardController endListeningForKeyboard];
}


#pragma mark - View rotation

- (BOOL)shouldAutorotate
{
    return YES;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations
{
    if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPhone) {
        return UIInterfaceOrientationMaskAllButUpsideDown;
    }
    return UIInterfaceOrientationMaskAll;
}

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
    [super willRotateToInterfaceOrientation:toInterfaceOrientation duration:duration];
    [self.collectionView.collectionViewLayout invalidateLayoutWithContext:[JSQMessagesCollectionViewFlowLayoutInvalidationContext context]];
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation
{
    [super didRotateFromInterfaceOrientation:fromInterfaceOrientation];
    if (self.showTypingIndicator) {
        self.showTypingIndicator = NO;
        self.showTypingIndicator = YES;
        [self.collectionView reloadData];
    }
}

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator {
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
    [self jsq_resetLayoutAndCaches];

    self.transitioningSize = YES;

    [coordinator animateAlongsideTransition:^(id<UIViewControllerTransitionCoordinatorContext>  _Nonnull context) {
    } completion:^(id<UIViewControllerTransitionCoordinatorContext>  _Nonnull context) {
        self.transitioningSize = NO;
    }];
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [super traitCollectionDidChange:previousTraitCollection];
    [self jsq_resetLayoutAndCaches];
}

- (void)jsq_resetLayoutAndCaches
{
    JSQMessagesCollectionViewFlowLayoutInvalidationContext *context = [JSQMessagesCollectionViewFlowLayoutInvalidationContext context];
    context.invalidateFlowLayoutMessagesCache = YES;
    [self.collectionView.collectionViewLayout invalidateLayoutWithContext:context];
}

#pragma mark - Messages view controller

- (void)didPressSendButton:(UIButton *)button
           withMessageText:(NSString *)text
                  senderId:(NSString *)senderId
         senderDisplayName:(NSString *)senderDisplayName
                      date:(NSDate *)date
{
    NSAssert(NO, @"Error! required method not implemented in subclass. Need to implement %s", __PRETTY_FUNCTION__);
}

- (void)didPressAccessoryButton:(UIButton *)sender
{
    NSAssert(NO, @"Error! required method not implemented in subclass. Need to implement %s", __PRETTY_FUNCTION__);
}

- (void)finishSendingMessage
{
    [self finishSendingMessageAnimated:YES];
}

- (void)finishSendingMessageAnimated:(BOOL)animated {

    UITextView *textView = self.inputToolbar.contentView.textView;
    textView.text = nil;
    [textView.undoManager removeAllActions];

    [self deliverTextViewChangedEventsToSearchResultsView:textView];
    [self.inputToolbar toggleSendButtonEnabled];

    [[NSNotificationCenter defaultCenter] postNotificationName:UITextViewTextDidChangeNotification object:textView];

    [self.collectionView.collectionViewLayout invalidateLayoutWithContext:[JSQMessagesCollectionViewFlowLayoutInvalidationContext context]];
    [self.collectionView reloadData];

    if (self.automaticallyScrollsToMostRecentMessage) {
        [self scrollToBottomAnimated:animated];
    }
}

- (void)finishReceivingMessage
{
    [self finishReceivingMessageAnimated:YES];
}

- (void)finishReceivingMessageAnimated:(BOOL)animated {

    self.showTypingIndicator = NO;

    [self.collectionView.collectionViewLayout invalidateLayoutWithContext:[JSQMessagesCollectionViewFlowLayoutInvalidationContext context]];
    [self.collectionView reloadData];

    if (self.automaticallyScrollsToMostRecentMessage && ![self jsq_isMenuVisible]) {
        [self scrollToBottomAnimated:animated];
    }

    UIAccessibilityPostNotification(UIAccessibilityAnnouncementNotification, [NSBundle jsq_localizedStringForKey:@"new_message_received_accessibility_announcement"]);
}

- (void)scrollToBottomAnimated:(BOOL)animated
{
    if ([self.collectionView numberOfSections] == 0) {
        return;
    }

    NSIndexPath *lastCell = [NSIndexPath indexPathForItem:([self.collectionView numberOfItemsInSection:0] - 1) inSection:0];
    [self scrollToIndexPath:lastCell animated:animated];
}

- (void)scrollToIndexPath:(NSIndexPath *)indexPath animated:(BOOL)animated
{
    if ([self.collectionView numberOfSections] <= indexPath.section) {
        return;
    }

    NSInteger numberOfItems = [self.collectionView numberOfItemsInSection:indexPath.section];
    if (numberOfItems == 0) {
        return;
    }

    CGFloat collectionViewContentHeight = [self.collectionView.collectionViewLayout collectionViewContentSize].height;
    BOOL isContentTooSmall = (collectionViewContentHeight < CGRectGetHeight(self.collectionView.bounds));

    if (isContentTooSmall) {
        //  workaround for the first few messages not scrolling
        //  when the collection view content size is too small, `scrollToItemAtIndexPath:` doesn't work properly
        //  this seems to be a UIKit bug, see #256 on GitHub
        [self.collectionView scrollRectToVisible:CGRectMake(0.0, collectionViewContentHeight - 1.0f, 1.0f, 1.0f)
                                        animated:animated];
        return;
    }

    NSInteger item = MAX(MIN(indexPath.item, numberOfItems - 1), 0);
    indexPath = [NSIndexPath indexPathForItem:item inSection:0];

    //  workaround for really long messages not scrolling
    //  if last message is too long, use scroll position bottom for better appearance, else use top
    //  possibly a UIKit bug, see #480 on GitHub
    CGSize cellSize = [self.collectionView.collectionViewLayout sizeForItemAtIndexPath:indexPath];
    CGFloat maxHeightForVisibleMessage = CGRectGetHeight(self.collectionView.bounds)
                                         - self.collectionView.contentInset.top
                                         - self.collectionView.contentInset.bottom
                                         ;
                                         // - CGRectGetHeight(self.inputToolbar.bounds);
    UICollectionViewScrollPosition scrollPosition = (cellSize.height > maxHeightForVisibleMessage) ? UICollectionViewScrollPositionBottom : UICollectionViewScrollPositionTop;


    // Check for current animations and allow them to override
    POPBasicAnimation *a1 = [self.collectionView pop_animationForKey:@"collectionView kPOPScrollViewContentOffset"];

    if (a1) {
        // Ignore any kind of scroll operation requests if we are already
        // in the middle of a scroll operation -- we are probably
        // already animating to the bottom
        // which is where this guy undoubtedly wants to go too
        // so just let our animation continue
    } else {
        [self.collectionView scrollToItemAtIndexPath:indexPath
                                    atScrollPosition:scrollPosition
                                            animated:animated];
    }
}

- (BOOL)isOutgoingMessage:(id<JSQMessageData>)messageItem
{
    NSString *messageSenderId = [messageItem senderId];
    NSParameterAssert(messageSenderId != nil);

    return [messageSenderId isEqualToString:self.senderId];
}

#pragma mark - JSQMessages collection view data source

- (id<JSQMessageData>)collectionView:(JSQMessagesCollectionView *)collectionView messageDataForItemAtIndexPath:(NSIndexPath *)indexPath
{
    NSAssert(NO, @"ERROR: required method not implemented: %s", __PRETTY_FUNCTION__);
    return nil;
}

- (void)collectionView:(JSQMessagesCollectionView *)collectionView didDeleteMessageAtIndexPath:(NSIndexPath *)indexPath
{
    NSAssert(NO, @"ERROR: required method not implemented: %s", __PRETTY_FUNCTION__);
}

- (id<JSQMessageBubbleImageDataSource>)collectionView:(JSQMessagesCollectionView *)collectionView messageBubbleImageDataForItemAtIndexPath:(NSIndexPath *)indexPath
{
    NSAssert(NO, @"ERROR: required method not implemented: %s", __PRETTY_FUNCTION__);
    return nil;
}

- (id<JSQMessageAvatarImageDataSource>)collectionView:(JSQMessagesCollectionView *)collectionView avatarImageDataForItemAtIndexPath:(NSIndexPath *)indexPath
{
    NSAssert(NO, @"ERROR: required method not implemented: %s", __PRETTY_FUNCTION__);
    return nil;
}

- (NSAttributedString *)collectionView:(JSQMessagesCollectionView *)collectionView attributedTextForCellTopLabelAtIndexPath:(NSIndexPath *)indexPath
{
    return nil;
}

- (NSAttributedString *)collectionView:(JSQMessagesCollectionView *)collectionView attributedTextForMessageBubbleTopLabelAtIndexPath:(NSIndexPath *)indexPath
{
    return nil;
}

- (NSAttributedString *)collectionView:(JSQMessagesCollectionView *)collectionView attributedTextForCellBottomLabelAtIndexPath:(NSIndexPath *)indexPath
{
    return nil;
}

#pragma mark - Collection view data source

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
    return 0;
}

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView
{
    return 1;
}

- (UICollectionViewCell *)collectionView:(JSQMessagesCollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    id<JSQMessageData> messageItem = [collectionView.dataSource collectionView:collectionView messageDataForItemAtIndexPath:indexPath];
    NSParameterAssert(messageItem != nil);

    BOOL isOutgoingMessage = [self isOutgoingMessage:messageItem];
    BOOL isMediaMessage = [messageItem isMediaMessage];

    NSString *cellIdentifier = nil;
    if (isMediaMessage) {
        cellIdentifier = isOutgoingMessage ? self.outgoingMediaCellIdentifier : self.incomingMediaCellIdentifier;
    }
    else {
        cellIdentifier = isOutgoingMessage ? self.outgoingCellIdentifier : self.incomingCellIdentifier;
    }

    JSQMessagesCollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:cellIdentifier forIndexPath:indexPath];
    cell.delegate = collectionView;

    if (!isMediaMessage) {
        cell.textView.text = [messageItem text];

        if ([UIDevice jsq_isCurrentDeviceBeforeiOS8]) {
            //  workaround for iOS 7 textView data detectors bug
            cell.textView.text = nil;
            cell.textView.attributedText = [[NSAttributedString alloc] initWithString:[messageItem text]
                                                                           attributes:@{ NSFontAttributeName : [collectionView.collectionViewLayout messageBubbleFontForItemAtIndexPath:indexPath] }];
        }

        NSParameterAssert(cell.textView.text != nil);

        id<JSQMessageBubbleImageDataSource> bubbleImageDataSource = [collectionView.dataSource collectionView:collectionView messageBubbleImageDataForItemAtIndexPath:indexPath];
        cell.messageBubbleImageView.image = [bubbleImageDataSource messageBubbleImage];
        cell.messageBubbleImageView.highlightedImage = [bubbleImageDataSource messageBubbleHighlightedImage];
    }
    else {
        id<JSQMessageMediaData> messageMedia = [messageItem media];
        cell.mediaView = [messageMedia mediaView] ?: [messageMedia mediaPlaceholderView];
        NSParameterAssert(cell.mediaView != nil);
    }

    BOOL needsAvatar = YES;
    if (isOutgoingMessage && CGSizeEqualToSize(collectionView.collectionViewLayout.outgoingAvatarViewSize, CGSizeZero)) {
        needsAvatar = NO;
    }
    else if (!isOutgoingMessage && CGSizeEqualToSize(collectionView.collectionViewLayout.incomingAvatarViewSize, CGSizeZero)) {
        needsAvatar = NO;
    }

    id<JSQMessageAvatarImageDataSource> avatarImageDataSource = nil;
    if (needsAvatar) {
        avatarImageDataSource = [collectionView.dataSource collectionView:collectionView avatarImageDataForItemAtIndexPath:indexPath];
        if (avatarImageDataSource != nil) {

            UIImage *avatarImage = [avatarImageDataSource avatarImage];
            if (avatarImage == nil) {
                cell.avatarImageView.image = [avatarImageDataSource avatarPlaceholderImage];
                cell.avatarImageView.highlightedImage = nil;
            }
            else {
                cell.avatarImageView.image = avatarImage;
                cell.avatarImageView.highlightedImage = [avatarImageDataSource avatarHighlightedImage];
            }
        }
    }

    cell.cellTopLabel.attributedText = [collectionView.dataSource collectionView:collectionView attributedTextForCellTopLabelAtIndexPath:indexPath];
    cell.messageBubbleTopLabel.attributedText = [collectionView.dataSource collectionView:collectionView attributedTextForMessageBubbleTopLabelAtIndexPath:indexPath];
    cell.cellBottomLabel.attributedText = [collectionView.dataSource collectionView:collectionView attributedTextForCellBottomLabelAtIndexPath:indexPath];

    CGFloat bubbleTopLabelInset = (avatarImageDataSource != nil) ? 60.0f : 15.0f;

    if (isOutgoingMessage) {
        cell.messageBubbleTopLabel.textInsets = UIEdgeInsetsMake(0.0f, 0.0f, 0.0f, bubbleTopLabelInset);
    }
    else {
        cell.messageBubbleTopLabel.textInsets = UIEdgeInsetsMake(0.0f, bubbleTopLabelInset, 0.0f, 0.0f);
    }

    cell.textView.dataDetectorTypes = UIDataDetectorTypeAll;

    cell.backgroundColor = [UIColor clearColor];
    cell.layer.rasterizationScale = [UIScreen mainScreen].scale;
    cell.layer.shouldRasterize = YES;
    [self collectionView:collectionView accessibilityForCell:cell indexPath:indexPath message:messageItem];

    return cell;
}

- (void)collectionView:(JSQMessagesCollectionView *)collectionView
  accessibilityForCell:(JSQMessagesCollectionViewCell*)cell
             indexPath:(NSIndexPath *)indexPath
               message:(id<JSQMessageData>)messageItem
{
    const BOOL isMediaMessage = [messageItem isMediaMessage];
    cell.isAccessibilityElement = YES;
    if (!isMediaMessage) {
        cell.accessibilityLabel = [NSString stringWithFormat:[NSBundle jsq_localizedStringForKey:@"text_message_accessibility_label"],
                                   [messageItem senderDisplayName],
                                   [messageItem text]];
    }
    else {
        cell.accessibilityLabel = [NSString stringWithFormat:[NSBundle jsq_localizedStringForKey:@"media_message_accessibility_label"],
                                   [messageItem senderDisplayName]];
    }
}

- (UICollectionReusableView *)collectionView:(JSQMessagesCollectionView *)collectionView
           viewForSupplementaryElementOfKind:(NSString *)kind
                                 atIndexPath:(NSIndexPath *)indexPath
{
    if (self.showTypingIndicator && [kind isEqualToString:UICollectionElementKindSectionFooter]) {
        return [collectionView dequeueTypingIndicatorFooterViewForIndexPath:indexPath];
    }
    else if (self.showLoadEarlierMessagesHeader && [kind isEqualToString:UICollectionElementKindSectionHeader]) {
        return [collectionView dequeueLoadEarlierMessagesViewHeaderForIndexPath:indexPath];
    }

    return nil;
}

- (CGSize)collectionView:(UICollectionView *)collectionView
                  layout:(JSQMessagesCollectionViewFlowLayout *)collectionViewLayout referenceSizeForFooterInSection:(NSInteger)section
{
    if (!self.showTypingIndicator) {
        return CGSizeZero;
    }

    return CGSizeMake([collectionViewLayout itemWidth], kJSQMessagesTypingIndicatorFooterViewHeight);
}

- (CGSize)collectionView:(UICollectionView *)collectionView
                  layout:(JSQMessagesCollectionViewFlowLayout *)collectionViewLayout referenceSizeForHeaderInSection:(NSInteger)section
{
    if (!self.showLoadEarlierMessagesHeader) {
        return CGSizeZero;
    }

    return CGSizeMake([collectionViewLayout itemWidth], kJSQMessagesLoadEarlierHeaderViewHeight);
}

#pragma mark - Collection view delegate

- (BOOL)collectionView:(JSQMessagesCollectionView *)collectionView shouldShowMenuForItemAtIndexPath:(NSIndexPath *)indexPath
{
    //  disable menu for media messages
    id<JSQMessageData> messageItem = [collectionView.dataSource collectionView:collectionView messageDataForItemAtIndexPath:indexPath];
    if ([messageItem isMediaMessage]) {
        return NO;
    }

    self.selectedIndexPathForMenu = indexPath;

    //  textviews are selectable to allow data detectors
    //  however, this allows the 'copy, define, select' UIMenuController to show
    //  which conflicts with the collection view's UIMenuController
    //  temporarily disable 'selectable' to prevent this issue
    JSQMessagesCollectionViewCell *selectedCell = (JSQMessagesCollectionViewCell *)[collectionView cellForItemAtIndexPath:indexPath];
    selectedCell.textView.selectable = NO;

    return YES;
}

- (BOOL)collectionView:(UICollectionView *)collectionView canPerformAction:(SEL)action forItemAtIndexPath:(NSIndexPath *)indexPath withSender:(id)sender
{
    if (action == @selector(copy:) || action == @selector(delete:)) {
        return YES;
    }

    return NO;
}

- (void)collectionView:(JSQMessagesCollectionView *)collectionView performAction:(SEL)action forItemAtIndexPath:(NSIndexPath *)indexPath withSender:(id)sender
{
    if (action == @selector(copy:)) {
        id<JSQMessageData> messageData = [collectionView.dataSource collectionView:collectionView messageDataForItemAtIndexPath:indexPath];
        [[UIPasteboard generalPasteboard] setString:[messageData text]];
    }
    else if (action == @selector(delete:)) {
        [collectionView.dataSource collectionView:collectionView didDeleteMessageAtIndexPath:indexPath];

        [collectionView deleteItemsAtIndexPaths:@[indexPath]];
        [collectionView.collectionViewLayout invalidateLayout];
    }
}

#pragma mark - Collection view delegate flow layout

- (CGSize)collectionView:(JSQMessagesCollectionView *)collectionView
                  layout:(JSQMessagesCollectionViewFlowLayout *)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath
{
    return [collectionViewLayout sizeForItemAtIndexPath:indexPath];
}

- (CGFloat)collectionView:(JSQMessagesCollectionView *)collectionView
                   layout:(JSQMessagesCollectionViewFlowLayout *)collectionViewLayout heightForCellTopLabelAtIndexPath:(NSIndexPath *)indexPath
{
    return 0.0f;
}

- (CGFloat)collectionView:(JSQMessagesCollectionView *)collectionView
                   layout:(JSQMessagesCollectionViewFlowLayout *)collectionViewLayout heightForMessageBubbleTopLabelAtIndexPath:(NSIndexPath *)indexPath
{
    return 0.0f;
}

- (CGFloat)collectionView:(JSQMessagesCollectionView *)collectionView
                   layout:(JSQMessagesCollectionViewFlowLayout *)collectionViewLayout heightForCellBottomLabelAtIndexPath:(NSIndexPath *)indexPath
{
    return 0.0f;
}

- (void)collectionView:(JSQMessagesCollectionView *)collectionView
 didTapAvatarImageView:(UIImageView *)avatarImageView
           atIndexPath:(NSIndexPath *)indexPath { }

- (void)collectionView:(JSQMessagesCollectionView *)collectionView didTapMessageBubbleAtIndexPath:(NSIndexPath *)indexPath { }

- (void)collectionView:(JSQMessagesCollectionView *)collectionView
 didTapCellAtIndexPath:(NSIndexPath *)indexPath
         touchLocation:(CGPoint)touchLocation { }

#pragma mark - Input toolbar delegate

- (void)messagesInputToolbar:(JSQMessagesInputToolbar *)toolbar didPressLeftBarButton:(UIButton *)sender
{
    if (toolbar.sendButtonOnRight) {
        [self didPressAccessoryButton:sender];
    }
    else {
        [self didPressSendButton:sender
                 withMessageText:[self jsq_currentlyComposedMessageText]
                        senderId:self.senderId
               senderDisplayName:self.senderDisplayName
                            date:[NSDate date]];
    }
}

- (void)messagesInputToolbar:(JSQMessagesInputToolbar *)toolbar didPressRightBarButton:(UIButton *)sender
{
    if (toolbar.sendButtonOnRight) {
        [self didPressSendButton:sender
                 withMessageText:[self jsq_currentlyComposedMessageText]
                        senderId:self.senderId
               senderDisplayName:self.senderDisplayName
                            date:[NSDate date]];
    }
    else {
        [self didPressAccessoryButton:sender];
    }
}

- (NSAttributedString *)jsq_currentlyComposedMessageAttributedText {
    [self jsq_currentlyComposedMessageText];

    return self.inputToolbar.contentView.textView.attributedText;
}

- (NSString *)jsq_currentlyComposedMessageText
{
    //  auto-accept any auto-correct suggestions
    [self.inputToolbar.contentView.textView.inputDelegate selectionWillChange:self.inputToolbar.contentView.textView];
    [self.inputToolbar.contentView.textView.inputDelegate selectionDidChange:self.inputToolbar.contentView.textView];

    return [self.inputToolbar.contentView.textView.text jsq_stringByTrimingWhitespace];
}

#pragma mark - Text view delegate

- (void)textViewDidBeginEditing:(UITextView *)textView
{
    if (textView != self.inputToolbar.contentView.textView) {
        return;
    }

    [textView becomeFirstResponder];

    if (self.automaticallyScrollsToMostRecentMessage) {
        [self scrollToBottomAnimated:YES];
    }

    [self deliverTextViewBeginEditingEventsToSearchResultsView:textView];
}

- (void)textViewDidChange:(UITextView *)textView
{
    if (textView != self.inputToolbar.contentView.textView) {
        return;
    }

    [self.inputToolbar toggleSendButtonEnabled];
    [self deliverTextViewChangedEventsToSearchResultsView:textView];
}

- (void)textViewDidEndEditing:(UITextView *)textView
{
    if (textView != self.inputToolbar.contentView.textView) {
        return;
    }

    [textView resignFirstResponder];
}

#pragma mark - Notifications

- (void)jsq_handleDidChangeStatusBarFrameNotification:(NSNotification *)notification
{
    // In sample project, we receive the keyboard hide/show notifications BEFORE
    // the status bar frame notifications, which causes keyboardIsVisible to be NO
    // during a rotation
    //
    // In other project, we receive the keyboard hide/show notification AFTER
    // the status bar frame notification, which causes layout constraint violations
    // during a rotation
    //
    // So, we cache when we are rotating because we never want to be updating
    // these constraints in the middle of a rotation
    if (self.keyboardController.keyboardIsVisible && !self.transitioningSize) {
        [self jsq_setToolbarBottomLayoutGuideConstant:CGRectGetHeight(self.keyboardController.currentKeyboardFrame)];
    }
}

- (void)didReceiveMenuWillShowNotification:(NSNotification *)notification
{
    if (!self.selectedIndexPathForMenu) {
        return;
    }

    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UIMenuControllerWillShowMenuNotification
                                                  object:nil];

    UIMenuController *menu = [notification object];
    [menu setMenuVisible:NO animated:NO];

    JSQMessagesCollectionViewCell *selectedCell = (JSQMessagesCollectionViewCell *)[self.collectionView cellForItemAtIndexPath:self.selectedIndexPathForMenu];
    CGRect selectedCellMessageBubbleFrame = [selectedCell convertRect:selectedCell.messageBubbleContainerView.frame toView:self.view];

    [menu setTargetRect:selectedCellMessageBubbleFrame inView:self.view];
    [menu setMenuVisible:YES animated:YES];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(didReceiveMenuWillShowNotification:)
                                                 name:UIMenuControllerWillShowMenuNotification
                                               object:nil];
}

- (void)didReceiveMenuWillHideNotification:(NSNotification *)notification
{
    if (!self.selectedIndexPathForMenu) {
        return;
    }

    //  per comment above in 'shouldShowMenuForItemAtIndexPath:'
    //  re-enable 'selectable', thus re-enabling data detectors if present
    JSQMessagesCollectionViewCell *selectedCell = (JSQMessagesCollectionViewCell *)[self.collectionView cellForItemAtIndexPath:self.selectedIndexPathForMenu];
    selectedCell.textView.selectable = YES;
    self.selectedIndexPathForMenu = nil;
}

// SCRUFF Added
- (void)didReceiveContentSizeCategoryDidChange:(NSNotification *)notification {
    [self.collectionView reloadData];
}

#pragma mark - Key-value observing

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (context == kJSQMessagesKeyValueObservingContext) {

        if (object == self.inputToolbar.contentView.textView
            && [keyPath isEqualToString:NSStringFromSelector(@selector(contentSize))]) {

            CGSize oldContentSize = [[change objectForKey:NSKeyValueChangeOldKey] CGSizeValue];
            CGSize newContentSize = [[change objectForKey:NSKeyValueChangeNewKey] CGSizeValue];

            CGFloat dy = newContentSize.height - oldContentSize.height;

            // We only care about changes in y; changes in x (triggered by presence or absene of frequent phrases icon) are irrelevant
            if (dy != 0) {
                [self jsq_adjustInputToolbarForComposerTextViewContentSizeChange:dy];
                [self jsq_updateCollectionViewInsetsAnimated:NO];
                if (self.automaticallyScrollsToMostRecentMessage) {
                    [self scrollToBottomAnimated:NO];
                }
            }
        }
    }
}

#pragma mark - Keyboard controller delegate

- (void)keyboardController:(JSQMessagesKeyboardController *)keyboardController keyboardDidChangeFrame:(CGRect)keyboardFrame
{
    if (![self.inputToolbar.contentView.textView isFirstResponder] && self.toolbarBottomLayoutGuide.constant == 0.0) {
        return;
    }

    CGFloat heightFromBottom = CGRectGetMaxY(self.collectionView.frame) - CGRectGetMinY(keyboardFrame);

    heightFromBottom = MAX(0.0, heightFromBottom);

    // Show/hide the ad container view
    self.isAdVisible = heightFromBottom == 0.0;

    [self jsq_setToolbarBottomLayoutGuideConstant:heightFromBottom];
}

- (void)keyboardDidHideAfterPan:(JSQMessagesKeyboardController *)keyboardController  {
    // Overridden in subclasses in case they want to adjust their
    // input toolbars, etc
}

- (void)jsq_setToolbarBottomLayoutGuideConstant:(CGFloat)constant
{
    BOOL toolbarBottomLayoutGuideChanged = constant != self.toolbarBottomLayoutGuide.constant;

    self.toolbarBottomLayoutGuide.constant = constant;
    [self.view setNeedsUpdateConstraints];
    [self.view layoutIfNeeded];

    [self jsq_updateCollectionViewInsetsAnimated:NO];

    // If the bottom layout guide constant has changed, this means we probably
    // have received a new keyboard dimension (it takes a sec or two to get the
    // dimensions for Gboard and we get a number of callbacks where the constant
    // is 0 before it finally becomes 200px+).
    // When we get a new keyboard dimension, if we have previously started a
    // contentOffset animation (because we are showing the searchResultsContainerView for example)
    // we must prematurely end that animation
    // We then rely on a call to scrollToBottomAnimated to properly position the contentOffset
    // at the bottom of our collectionView
    if (toolbarBottomLayoutGuideChanged) {
        POPBasicAnimation *a1 = [self.collectionView pop_animationForKey:@"collectionView kPOPScrollViewContentOffset"];

        if (a1) {
            [self.collectionView pop_removeAnimationForKey:@"collectionView kPOPScrollViewContentOffset"];
        }
    }

    // This will now serve to animate our contentOffset, if we had previously removed the animation
    [self scrollToBottomAnimated:NO];
}

- (void)jsq_updateKeyboardTriggerPoint
{
    self.keyboardController.keyboardTriggerPoint = CGPointMake(0.0f, CGRectGetHeight(self.inputToolbar.bounds));
}

#pragma mark - Gesture recognizers

- (void)jsq_handleInteractivePopGestureRecognizer:(UIGestureRecognizer *)gestureRecognizer
{
    switch (gestureRecognizer.state) {
        case UIGestureRecognizerStateBegan:
        {
            if ([UIDevice jsq_isCurrentDeviceBeforeiOS8]) {
                [self.snapshotView removeFromSuperview];
            }

            self.textViewWasFirstResponderDuringInteractivePop = [self.inputToolbar.contentView.textView isFirstResponder];

            [self.keyboardController endListeningForKeyboard];

            if ([UIDevice jsq_isCurrentDeviceBeforeiOS8]) {
                [self.inputToolbar.contentView.textView resignFirstResponder];
                [UIView animateWithDuration:0.0
                                 animations:^{
                                     [self jsq_setToolbarBottomLayoutGuideConstant:0.0];
                                 }];

                UIView *snapshot = [self.view snapshotViewAfterScreenUpdates:YES];
                [self.view addSubview:snapshot];
                self.snapshotView = snapshot;
            }
        }
            break;
        case UIGestureRecognizerStateChanged:
            break;
        case UIGestureRecognizerStateCancelled:
        case UIGestureRecognizerStateEnded:
        case UIGestureRecognizerStateFailed:
            [self.keyboardController beginListeningForKeyboard];
            if (self.textViewWasFirstResponderDuringInteractivePop) {
                [self.inputToolbar.contentView.textView becomeFirstResponder];
            }

            if ([UIDevice jsq_isCurrentDeviceBeforeiOS8]) {
                [self.snapshotView removeFromSuperview];
            }
            break;
        default:
            break;
    }
}

#pragma mark - Input toolbar utilities

- (BOOL)jsq_inputToolbarHasReachedMaximumHeight
{
    return CGRectGetMinY(self.inputToolbar.frame) == (self.topLayoutGuide.length + self.topContentAdditionalInset);
}

- (void)jsq_adjustInputToolbarForComposerTextViewContentSizeChange:(CGFloat)dy
{
    BOOL contentSizeIsIncreasing = (dy > 0);

    if ([self jsq_inputToolbarHasReachedMaximumHeight]) {
        BOOL contentOffsetIsPositive = (self.inputToolbar.contentView.textView.contentOffset.y > 0);

        if (contentSizeIsIncreasing || contentOffsetIsPositive) {
            [self jsq_scrollComposerTextViewToBottomAnimated:YES];
            return;
        }
    }

    CGFloat toolbarOriginY = CGRectGetMinY(self.inputToolbar.frame);
    CGFloat newToolbarOriginY = toolbarOriginY - dy;

    //  attempted to increase origin.Y above topLayoutGuide
    if (newToolbarOriginY <= self.topLayoutGuide.length + self.topContentAdditionalInset) {
        dy = toolbarOriginY - (self.topLayoutGuide.length + self.topContentAdditionalInset);
        [self jsq_scrollComposerTextViewToBottomAnimated:YES];
    }

    [self jsq_adjustInputToolbarHeightConstraintByDelta:dy];

    [self jsq_updateKeyboardTriggerPoint];

    if (dy < 0) {
        [self jsq_scrollComposerTextViewToBottomAnimated:NO];
    }
}

- (void)jsq_adjustInputToolbarHeightConstraintByDelta:(CGFloat)dy
{
    CGFloat toolbarHeightConstraintValue = self.toolbarHeightConstraint.constant;

    POPBasicAnimation *a1 = [self.toolbarHeightConstraint pop_animationForKey:@"self.toolbarHeightConstraint"];
    if (a1) {
        toolbarHeightConstraintValue = [a1.toValue floatValue];
    }

    CGFloat proposedHeight = toolbarHeightConstraintValue + dy;

    CGFloat finalHeight = MAX(proposedHeight, self.inputToolbar.preferredDefaultHeight);

    if (self.inputToolbar.maximumHeight != NSNotFound) {
        finalHeight = MIN(finalHeight, self.inputToolbar.maximumHeight);
    }

    if (toolbarHeightConstraintValue != finalHeight) {
        if (a1) {
            [self.toolbarHeightConstraint pop_removeAnimationForKey:@"self.toolbarHeightConstraint"];
            a1.toValue = @(finalHeight);
            [self.toolbarHeightConstraint pop_addAnimation:a1 forKey:@"self.toolbarHeightConstraint"];
        } else {
            self.toolbarHeightConstraint.constant = finalHeight;
        }
        [self.view setNeedsUpdateConstraints];
        [self.view layoutIfNeeded];
    }
}

- (void)jsq_scrollComposerTextViewToBottomAnimated:(BOOL)animated
{
    UITextView *textView = self.inputToolbar.contentView.textView;
    CGPoint contentOffsetToShowLastLine = CGPointMake(0.0f, textView.contentSize.height - CGRectGetHeight(textView.bounds));

    if (!animated) {
        textView.contentOffset = contentOffsetToShowLastLine;
        return;
    }

    [UIView animateWithDuration:0.01
                          delay:0.01
                        options:UIViewAnimationOptionCurveLinear
                     animations:^{
                         textView.contentOffset = contentOffsetToShowLastLine;
                     }
                     completion:nil];
}

#pragma mark - Collection view utilities

// If we have an active animation on the height of our inputToolbar, this method
// will use that as the truth about the height; otherwise we will use our standard constraint
// This is helpful for methods that want to make calculations while we're in the middle
// of an animation
- (CGFloat)inputToolbarPostAnimationHeight {
    CGFloat postAnimationHeight = self.toolbarHeightConstraint.constant;
    POPBasicAnimation *a1 = [self.toolbarHeightConstraint pop_animationForKey:@"self.toolbarHeightConstraint"];

    if (a1) {
        postAnimationHeight = [a1.toValue floatValue];
    }

    return postAnimationHeight;
}

- (void)jsq_updateCollectionViewInsetsAnimated:(BOOL)animated
{
    // Input toolbar animates, so isHidden may not yet be updated
    // when we are attempting to calculate insets

    // isPickerViewVisible is updated immediately so we use that instead
    CGFloat topEdgeOfBottomWidget = 0;
    CGFloat actualInputToolbarHeight = [self inputToolbarPostAnimationHeight];

    if (self.isPickerViewVisible) {
        topEdgeOfBottomWidget = CGRectGetMinY(self.pickerToolbar.frame);
    } else {
        topEdgeOfBottomWidget = CGRectGetMaxY(self.inputToolbar.frame) - actualInputToolbarHeight - self.inputToolbar.transform.ty;
    }

    CGFloat defaultBottomInset = CGRectGetMaxY(self.collectionView.frame) - topEdgeOfBottomWidget;
    CGFloat adContainerInset = self.isAdVisible ? [self targetAdHeight] : 0.0;

    self.adContainerHeightConstraint.constant = adContainerInset;

    [self jsq_setCollectionViewInsetsTopValue:self.topLayoutGuide.length + self.topContentAdditionalInset
                                  bottomValue:defaultBottomInset + adContainerInset
                                     animated:animated];


}

- (void)jsq_setCollectionViewInsetsTopValue:(CGFloat)top
                                bottomValue:(CGFloat)bottom
                                   animated:(BOOL)animated
{
    UIEdgeInsets insets = UIEdgeInsetsMake(top, 0.0f, bottom, 0.0f);

    if (animated) {
        POPBasicAnimation *a0 = [POPBasicAnimation easeOutAnimation];
        a0.property = [POPAnimatableProperty propertyWithName:kPOPScrollViewContentInset];
        a0.toValue = [NSValue valueWithUIEdgeInsets:insets];
        a0.duration = kSearchBarAnimationDuration;

        // KEY is important to ensure no collisions with other animations in this file
        [self.collectionView pop_addAnimation:a0 forKey:@"collectionView kPOPScrollViewContentInset"];
    } else {
        [self.collectionView pop_removeAnimationForKey:@"collectionView kPOPScrollViewContentInset"];
        self.collectionView.contentInset = insets;
    }

    // No one really sees these so no need to animate
    self.collectionView.scrollIndicatorInsets = insets;
}

- (BOOL)jsq_isMenuVisible
{
    //  check if cell copy menu is showing
    //  it is only our menu if `selectedIndexPathForMenu` is not `nil`
    return self.selectedIndexPathForMenu != nil && [[UIMenuController sharedMenuController] isMenuVisible];
}

#pragma mark - Utilities

- (void)jsq_addObservers
{
    if (self.jsq_isObserving) {
        return;
    }

    [self.inputToolbar.contentView.textView addObserver:self
                                             forKeyPath:NSStringFromSelector(@selector(contentSize))
                                                options:NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew
                                                context:kJSQMessagesKeyValueObservingContext];

    self.jsq_isObserving = YES;
}

- (void)jsq_removeObservers
{
    if (!_jsq_isObserving) {
        return;
    }

    @try {
        [_inputToolbar.contentView.textView removeObserver:self
                                                forKeyPath:NSStringFromSelector(@selector(contentSize))
                                                   context:kJSQMessagesKeyValueObservingContext];
    }
    @catch (NSException * __unused exception) { }

    _jsq_isObserving = NO;
}

- (void)jsq_registerForNotifications:(BOOL)registerForNotifications
{
    if (registerForNotifications) {
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(jsq_handleDidChangeStatusBarFrameNotification:)
                                                     name:UIApplicationDidChangeStatusBarFrameNotification
                                                   object:nil];

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(didReceiveMenuWillShowNotification:)
                                                     name:UIMenuControllerWillShowMenuNotification
                                                   object:nil];

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(didReceiveMenuWillHideNotification:)
                                                     name:UIMenuControllerWillHideMenuNotification
                                                   object:nil];

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(didReceiveContentSizeCategoryDidChange:)
                                                     name:UIContentSizeCategoryDidChangeNotification
                                                   object:nil];
    }
    else {
        [[NSNotificationCenter defaultCenter] removeObserver:self
                                                        name:UIApplicationDidChangeStatusBarFrameNotification
                                                      object:nil];

        [[NSNotificationCenter defaultCenter] removeObserver:self
                                                        name:UIMenuControllerWillShowMenuNotification
                                                      object:nil];

        [[NSNotificationCenter defaultCenter] removeObserver:self
                                                        name:UIMenuControllerWillHideMenuNotification
                                                      object:nil];

        [[NSNotificationCenter defaultCenter] removeObserver:self
                                                        name:UIContentSizeCategoryDidChangeNotification
                                                      object:nil];
    }
}

- (void)jsq_addActionToInteractivePopGestureRecognizer:(BOOL)addAction
{
    if (self.currentInteractivePopGestureRecognizer != nil) {
        [self.currentInteractivePopGestureRecognizer removeTarget:nil
                                                           action:@selector(jsq_handleInteractivePopGestureRecognizer:)];
        self.currentInteractivePopGestureRecognizer = nil;
    }

    if (addAction) {
        [self.navigationController.interactivePopGestureRecognizer addTarget:self
                                                                      action:@selector(jsq_handleInteractivePopGestureRecognizer:)];
        self.currentInteractivePopGestureRecognizer = self.navigationController.interactivePopGestureRecognizer;
    }
}

#pragma mark - Scruff Additions

- (void)showPickerView {
    self.isPickerViewVisible = YES;

    // Hide the input toolbar
    [self setInputToolbarHidden:YES];

    // Set the custom input view of the input toolbar's textView to
    // the pickerView, which replaces the keyboard.
    self.inputToolbar.contentView.textView.inputView = self.pickerView;

    [self.inputToolbar.contentView.textView reloadInputViews];

    // Make sure the textView is first responder so the keyboard - or in
    // this case the pickerView - becomes visible
    [self.inputToolbar.contentView.textView becomeFirstResponder];

    // We don't want the keyboard's shortcut bar to display above the
    // pickerView since it's unnecessary, so we need to clear it out
    UITextInputAssistantItem *item = self.inputToolbar.contentView.textView.inputAssistantItem;

    item.leadingBarButtonGroups = @[];
    item.trailingBarButtonGroups = @[];
}

- (void)hidePickerViewShowingKeyboard:(BOOL)showKeyboard {
    self.isPickerViewVisible = NO;

    if (!showKeyboard) {
        // First, hide the pickerView
        [self.inputToolbar.contentView.textView resignFirstResponder];
    }

    // Set the custom inputView to nil to restore the keyboard
    self.inputToolbar.contentView.textView.inputView = nil;

    // Show the input toolbar again
    [self setInputToolbarHidden:NO];

    [self.inputToolbar.contentView.textView reloadInputViews];

    if (showKeyboard) {
        [self.inputToolbar.contentView.textView becomeFirstResponder];
        [self jsq_updateCollectionViewInsetsAnimated:NO];
        [self scrollToBottomAnimated:NO];
    }
}

- (void)setInputToolbarHidden:(BOOL)hidden {
    CGFloat transformY = self.toolbarHeightConstraint.constant;

    if (!hidden) {
        [self.inputToolbar setHidden:NO];
    }

    [UIView animateWithDuration:kSearchBarAnimationDuration animations:^{
        if (hidden) {
            self.inputToolbar.transform = CGAffineTransformMakeTranslation(0.0, transformY);
        } else {
            self.inputToolbar.transform = CGAffineTransformIdentity;
        }
    } completion:^(BOOL finished) {
        if (hidden) {
            [self.inputToolbar setHidden:YES];
        }
    }];
}

// Override in subclass to change the ad height
- (CGFloat)targetAdHeight {
    return 44.0;
}

#pragma mark - SCRUFF Additions for searchResultsContainerView

- (void)searchResultsContainerViewVisible:(BOOL)visible animated:(BOOL)animated {
    CGFloat hiddenHeight = self.inputToolbar.contentView.hiddenTopOffsetConstraintValue;

    // When this method is called, we have already swapped out the subview
    // but have not necessarily resized the container
    // targetVisibleHeight uses sizeFitting method to calculate optimal size for subview
    // currentVisibleHeight looks at what the frame actually is right now
    CGFloat targetVisibleHeight = self.inputToolbar.contentView.visibleTopOffsetConstraintValue;
    CGFloat currentVisibleHeight = self.inputToolbar.contentView.searchResultsContainerView.frame.size.height;

    CGFloat oldOffset = self.isSearchResultsContainerViewVisible ? currentVisibleHeight : hiddenHeight;
    CGFloat newOffset = visible ? targetVisibleHeight : hiddenHeight;

    CGFloat dy = newOffset - oldOffset;

    // We need to adjust search container view before all else
    POPBasicAnimation *a0 = [POPBasicAnimation easeOutAnimation];
    a0.property = [POPAnimatableProperty propertyWithName:kPOPLayoutConstraintConstant];
    a0.toValue = visible ? @(self.inputToolbar.contentView.searchResultsContainerViewContentHeight) : @(0);
    a0.duration = kSearchBarAnimationDuration;

    // Because this constraint could be in the middle of changing, we cannot trust
    // its current value if we are in the middle of an animation
    // Instead, we have to go to the animation to obtain what it's true value is
    CGFloat postAnimationHeight = self.toolbarHeightConstraint.constant;
    POPBasicAnimation *a1 = [self.toolbarHeightConstraint pop_animationForKey:@"self.toolbarHeightConstraint"];

    if (a1) {
        postAnimationHeight = [a1.toValue floatValue];
    }

    a1 = [POPBasicAnimation easeOutAnimation];
    a1.property = [POPAnimatableProperty propertyWithName:kPOPLayoutConstraintConstant];
    a1.toValue = @([self jsq_computeInputToolbarHeightConstraintByDelta:dy
                                                    postAnimationHeight:postAnimationHeight]);

    a1.duration = kSearchBarAnimationDuration;
    [a1 setCompletionBlock:^(POPAnimation *a, BOOL done) {
        if (done) {
            [self jsq_updateKeyboardTriggerPoint];
            [self searchResultsContainerViewChanged];
        }
    }];

    if (animated) {
        [self.toolbarHeightConstraint pop_addAnimation:a1 forKey:@"self.toolbarHeightConstraint"];
        [self.inputToolbar.contentView.searchResultsContainerViewHeightConstraint pop_addAnimation:a0 forKey:@"searchResultsContainerViewHeightConstraint"];
    } else {
        self.inputToolbar.contentView.searchResultsContainerViewHeightConstraint.constant = [a0.toValue floatValue];
        self.toolbarHeightConstraint.constant = [a1.toValue floatValue];
    }

    UIEdgeInsets finalEdgeInsetsAfterCurrentAnimation = [self jsq_computeCollectionViewInsets:dy];
    POPBasicAnimation *a2 = [POPBasicAnimation easeOutAnimation];
    a2.property = [POPAnimatableProperty propertyWithName:kPOPScrollViewContentInset];
    a2.toValue = [NSValue valueWithUIEdgeInsets:finalEdgeInsetsAfterCurrentAnimation];
    a2.duration = kSearchBarAnimationDuration;

    [self.collectionView pop_addAnimation:a2 forKey:@"collectionView kPOPScrollViewContentInset"];

    POPBasicAnimation *a3 = [POPBasicAnimation easeOutAnimation];
    a3.property = [POPAnimatableProperty propertyWithName:kPOPScrollViewScrollIndicatorInsets];
    a3.toValue = [NSValue valueWithUIEdgeInsets:finalEdgeInsetsAfterCurrentAnimation];
    a3.duration = kSearchBarAnimationDuration;

    [self.collectionView pop_addAnimation:a3 forKey:@"collectionView kPOPScrollViewScrollIndicatorInsets"];

    CGFloat availableContentDisplayHeight = self.collectionView.frame.size.height -
    finalEdgeInsetsAfterCurrentAnimation.bottom - finalEdgeInsetsAfterCurrentAnimation.top;

    if (self.collectionView.contentSize.height > availableContentDisplayHeight) {
        POPBasicAnimation *a4 = [POPBasicAnimation easeOutAnimation];
        a4.property = [POPAnimatableProperty propertyWithName:kPOPScrollViewContentOffset];
        a4.toValue = [NSValue valueWithCGPoint:CGPointMake(0, [self requiredScrollOffsetToBeAtBottom:dy
                                                                                         finalInsets:finalEdgeInsetsAfterCurrentAnimation])];
        a4.duration = kSearchBarAnimationDuration;

        [self.collectionView pop_addAnimation:a4 forKey:@"collectionView kPOPScrollViewContentOffset"];
    }

    [self.inputToolbar toggleSendButtonEnabled:visible];
    self.isSearchResultsContainerViewVisible = visible;
}

- (void)cancelContentSpecificAnimations {
    // If the content in our dataSource changes, we need to stop whatever
    // contentOffset animations we are doing because they could be wrong
    for (NSString *anim in @[@"collectionView kPOPScrollViewContentOffset"]) {
        [self.collectionView pop_removeAnimationForKey:anim];
    }
}

- (void)searchResultsContainerViewChanged {
    if (self.automaticallyScrollsToMostRecentMessage) {
        [self scrollToBottomAnimated:NO];
    }
}

- (CGFloat)computeTopYOffsetOfInputToolbar:(CGFloat)dy {
    CGFloat topYOffset = 0;

    CGRect frameOfSearchResultsContainer =
    [self.view convertRect:self.inputToolbar.contentView.searchResultsContainerView.frame
                  fromView:self.inputToolbar.contentView];
    CGFloat bottomYOffsetOfSearchResultsContainer = CGRectGetMaxY(frameOfSearchResultsContainer);

    if (self.isPickerViewVisible) {
        topYOffset = CGRectGetMinY(self.pickerToolbar.frame) + dy;
    } else if (self.isSearchResultsContainerViewVisible) {
//        CGFloat targetHeightOfSearchResultsContainerContent = [self.inputToolbar.contentView.searchResultsContainerView.subviews[0] systemLayoutSizeFittingSize:UILayoutFittingCompressedSize].height;
        CGFloat currentHeightOfSearchResultsContainerContent = self.inputToolbar.contentView.searchResultsContainerView.frame.size.height;

        topYOffset = bottomYOffsetOfSearchResultsContainer - currentHeightOfSearchResultsContainerContent;
    } else {
        topYOffset = bottomYOffsetOfSearchResultsContainer;
    }

    return topYOffset;
}

- (UIEdgeInsets)jsq_computeCollectionViewInsets:(CGFloat)dy
{
    CGFloat defaultBottomInset = CGRectGetMaxY(self.collectionView.frame) - [self computeTopYOffsetOfInputToolbar:dy];
    CGFloat adContainerInset = self.isAdVisible ? [self targetAdHeight] : 0.0;

    self.adContainerHeightConstraint.constant = adContainerInset;

    UIEdgeInsets insets = UIEdgeInsetsMake(self.topLayoutGuide.length + self.topContentAdditionalInset, 0.0f, defaultBottomInset + adContainerInset + dy, 0.0f);

    return insets;
}

- (CGFloat)jsq_computeInputToolbarHeightConstraintByDelta:(CGFloat)dy
                                      postAnimationHeight:(CGFloat)postAnimationHeight {

    CGFloat proposedHeight = postAnimationHeight + dy;

    CGFloat finalHeight = MAX(proposedHeight, self.inputToolbar.preferredDefaultHeight);

    if (self.inputToolbar.maximumHeight != NSNotFound) {
        finalHeight = MIN(finalHeight, self.inputToolbar.maximumHeight);
    }

    if (postAnimationHeight != finalHeight) {
        return finalHeight;

    }

    return 0;
}

- (CGFloat)requiredScrollOffsetToBeAtBottom:(CGFloat)dy finalInsets:(UIEdgeInsets)finalEdgeInsetsAfterCurrentAnimation {
    float scrollViewHeight = self.collectionView.frame.size.height;
    float scrollContentSizeHeight = self.collectionView.contentSize.height;
    //    float scrollOffset = self.collectionView.contentOffset.y;
    float scrollInset = finalEdgeInsetsAfterCurrentAnimation.bottom;

    return scrollContentSizeHeight + scrollInset - scrollViewHeight;
}

- (void)deliverTextViewChangedEventsToSearchResultsView:(UITextView *)textView {
    if (self.isSearchResultsContainerViewVisible) {
        if (self.inputToolbar.contentView.searchResultsContainerView.subviews.count > 0) {
            UIView *subview = self.inputToolbar.contentView.searchResultsContainerView.subviews[0];

            if (subview &&
                [subview respondsToSelector:@selector(textViewDidChange:)]) {
                [subview performSelectorOnMainThread:@selector(textViewDidChange:) withObject:textView waitUntilDone:NO];
            }
        }
    }
}

- (void)deliverTextViewBeginEditingEventsToSearchResultsView:(UITextView *)textView {
    if (self.isSearchResultsContainerViewVisible) {
        if (self.inputToolbar.contentView.searchResultsContainerView.subviews.count > 0) {
            UIView *subview = self.inputToolbar.contentView.searchResultsContainerView.subviews[0];

            if (subview &&
                [subview respondsToSelector:@selector(textViewDidBeginEditing:)]) {
                [subview performSelectorOnMainThread:@selector(textViewDidBeginEditing:) withObject:textView waitUntilDone:NO];
            }
        }
    }
}

@end
