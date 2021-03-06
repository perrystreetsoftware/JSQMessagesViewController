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

#import "JSQMessagesInputToolbar.h"

#import "JSQMessagesComposerTextView.h"

#import "JSQMessagesToolbarButtonFactory.h"

#import "UIColor+JSQMessages.h"
#import "UIImage+JSQMessages.h"
#import "UIView+JSQMessages.h"

static void * kJSQMessagesInputToolbarKeyValueObservingContext = &kJSQMessagesInputToolbarKeyValueObservingContext;


@interface JSQMessagesInputToolbar ()

@property (assign, nonatomic) BOOL jsq_isObserving;
@property (nonatomic) NSLayoutConstraint *leadingContentConstraint;
@property (nonatomic) NSLayoutConstraint *trailingContentConstraint;

@end



@implementation JSQMessagesInputToolbar

@dynamic delegate;

#pragma mark - Initialization

- (void)awakeFromNib
{
    [super awakeFromNib];
    [self setTranslatesAutoresizingMaskIntoConstraints:NO];

    self.jsq_isObserving = NO;
    self.sendButtonOnRight = YES;

    JSQMessagesToolbarContentView *toolbarContentView = [self loadToolbarContentView];
    [toolbarContentView.textView sizeToFit];
    self.preferredDefaultHeight = toolbarContentView.textView.frame.size.height + 16;
    self.maximumHeight = NSNotFound;

    toolbarContentView.frame = self.frame;
    [self addSubview:toolbarContentView];

    [toolbarContentView.topAnchor constraintEqualToAnchor:self.topAnchor].active = YES;
    [toolbarContentView.bottomAnchor constraintEqualToAnchor:self.bottomAnchor].active = YES;

    self.leadingContentConstraint = [toolbarContentView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor];
    self.trailingContentConstraint = [toolbarContentView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor];

    self.leadingContentConstraint.active = YES;
    self.trailingContentConstraint.active = YES;

    [self setNeedsUpdateConstraints];
    _contentView = toolbarContentView;

    [self jsq_addObservers];

    self.contentView.leftBarButtonItem = [JSQMessagesToolbarButtonFactory defaultAccessoryButtonItem];
    self.contentView.rightBarButtonItem = [JSQMessagesToolbarButtonFactory defaultSendButtonItem];

    [self toggleSendButtonEnabled];
}

- (JSQMessagesToolbarContentView *)loadToolbarContentView
{
    NSArray *nibViews = [[NSBundle bundleForClass:[JSQMessagesInputToolbar class]] loadNibNamed:NSStringFromClass([JSQMessagesToolbarContentView class])
                                                                                          owner:nil
                                                                                        options:nil];
    return nibViews.firstObject;
}

- (void)dealloc
{
    [self jsq_removeObservers];
}

#pragma mark - Setters

- (void)setPreferredDefaultHeight:(CGFloat)preferredDefaultHeight
{
    NSParameterAssert(preferredDefaultHeight > 0.0f);
    _preferredDefaultHeight = preferredDefaultHeight;
}

#pragma mark - Actions

- (void)jsq_leftBarButtonPressed:(UIButton *)sender
{
    [self.delegate messagesInputToolbar:self didPressLeftBarButton:sender];
}

- (void)jsq_rightBarButtonPressed:(UIButton *)sender
{
    [self.delegate messagesInputToolbar:self didPressRightBarButton:sender];
}

#pragma mark - Input toolbar

- (void)toggleSendButtonEnabled {
    [self toggleSendButtonEnabled:(self.contentView.searchResultsContainerView.frame.size.height > 0)];
}

- (void)toggleSendButtonEnabled:(BOOL)searchResultsContainerVisible
{
    BOOL hasText = [self.contentView.textView hasText];

    if (self.sendButtonOnRight) {
        BOOL searchResultsBlockingSend = searchResultsContainerVisible && self.searchResultsShouldBlockSendButton;
        // Show/hide the send button instead of dimming it
        self.contentView.isRightBarButtonItemHidden = (!hasText || searchResultsBlockingSend || self.disableSendButton);
    }
    else {
        self.contentView.leftBarButtonItem.enabled = hasText;
    }
}

#pragma mark - Key-value observing

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (context == kJSQMessagesInputToolbarKeyValueObservingContext) {
        if (object == self.contentView) {

            if ([keyPath isEqualToString:NSStringFromSelector(@selector(leftBarButtonItem))]) {

                [self.contentView.leftBarButtonItem removeTarget:self
                                                          action:NULL
                                                forControlEvents:UIControlEventTouchUpInside];

                [self.contentView.leftBarButtonItem addTarget:self
                                                       action:@selector(jsq_leftBarButtonPressed:)
                                             forControlEvents:UIControlEventTouchUpInside];
            }
            else if ([keyPath isEqualToString:NSStringFromSelector(@selector(rightBarButtonItem))]) {

                [self.contentView.rightBarButtonItem removeTarget:self
                                                           action:NULL
                                                 forControlEvents:UIControlEventTouchUpInside];

                [self.contentView.rightBarButtonItem addTarget:self
                                                        action:@selector(jsq_rightBarButtonPressed:)
                                              forControlEvents:UIControlEventTouchUpInside];
            }

            [self toggleSendButtonEnabled];
        }
    }
}

- (void)jsq_addObservers
{
    if (self.jsq_isObserving) {
        return;
    }

    [self.contentView addObserver:self
                       forKeyPath:NSStringFromSelector(@selector(leftBarButtonItem))
                          options:0
                          context:kJSQMessagesInputToolbarKeyValueObservingContext];

    [self.contentView addObserver:self
                       forKeyPath:NSStringFromSelector(@selector(rightBarButtonItem))
                          options:0
                          context:kJSQMessagesInputToolbarKeyValueObservingContext];

    self.jsq_isObserving = YES;
}

- (void)jsq_removeObservers
{
    if (!_jsq_isObserving) {
        return;
    }

    @try {
        [_contentView removeObserver:self
                          forKeyPath:NSStringFromSelector(@selector(leftBarButtonItem))
                             context:kJSQMessagesInputToolbarKeyValueObservingContext];

        [_contentView removeObserver:self
                          forKeyPath:NSStringFromSelector(@selector(rightBarButtonItem))
                             context:kJSQMessagesInputToolbarKeyValueObservingContext];
    }
    @catch (NSException *__unused exception) { }

    _jsq_isObserving = NO;
}

#pragma mark: - SCRUFF additions

- (void)setLeadingConstant:(CGFloat)constant {
    self.leadingContentConstraint.constant = constant;
}

- (void)setTrailingConstant:(CGFloat)constant {
    self.trailingContentConstraint.constant = constant;
}

@end
