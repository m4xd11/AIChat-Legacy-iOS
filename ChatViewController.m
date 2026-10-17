#import "ChatViewController.h"
#import <QuartzCore/QuartzCore.h>

#define COL(r,g,b) [UIColor colorWithRed:(r)/255.0 green:(g)/255.0 blue:(b)/255.0 alpha:1]
#define BUBBLE_FONT [UIFont systemFontOfSize:16]
#define ACCENT COL(79, 124, 255)
#define MAX_API_MSGS 30
#define MAX_SAVED_MSGS 80
#define SETTINGS_H 128

@interface ChatViewController () <UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, strong) UIView *header;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *subtitleLabel;
@property (nonatomic, strong) UIButton *freshBtn;
@property (nonatomic, strong) UIButton *themeBtn;
@property (nonatomic, strong) UIButton *gearBtn;
@property (nonatomic, strong) UIView *headerLine;
@property (nonatomic, strong) UIView *settings;
@property (nonatomic, strong) UITextField *keyField;
@property (nonatomic, strong) UITextField *modelField;
@property (nonatomic, strong) UITextField *sysField;
@property (nonatomic, strong) UITableView *table;
@property (nonatomic, strong) UIView *chipsView;
@property (nonatomic, strong) NSMutableArray *chips;
@property (nonatomic, strong) NSArray *chipPrompts;
@property (nonatomic, strong) UIView *inputBar;
@property (nonatomic, strong) UIView *inputLine;
@property (nonatomic, strong) UITextField *inputField;
@property (nonatomic, strong) UIButton *sendBtn;
@property (nonatomic, strong) UILabel *toast;
@property (nonatomic, strong) NSMutableArray *messages;
@property (nonatomic, assign) CGFloat kbHeight;
@property (nonatomic, assign) BOOL busy;
@property (nonatomic, assign) BOOL settingsOpen;
@property (nonatomic, assign) BOOL dark;
@property (nonatomic, assign) NSInteger animateRow;
@end

@implementation ChatViewController

#pragma mark - Theme colors

- (UIColor *)cBg       { return self.dark ? COL(13, 15, 20)    : COL(238, 240, 246); }
- (UIColor *)cSurface  { return self.dark ? COL(22, 25, 32)    : COL(255, 255, 255); }
- (UIColor *)cField    { return self.dark ? COL(34, 39, 50)    : COL(228, 231, 241); }
- (UIColor *)cBubbleAI { return self.dark ? COL(34, 39, 50)    : COL(255, 255, 255); }
- (UIColor *)cText     { return self.dark ? COL(236, 239, 246) : COL(24, 27, 38); }
- (UIColor *)cSub      { return COL(128, 134, 150); }
- (UIColor *)cLine     { return self.dark ? COL(40, 45, 57)    : COL(214, 218, 229); }

- (UIStatusBarStyle)preferredStatusBarStyle {
	return self.dark ? UIStatusBarStyleLightContent : UIStatusBarStyleDefault;
}

- (void)applyTheme {
	self.view.backgroundColor = [self cBg];
	self.header.backgroundColor = [self cSurface];
	self.titleLabel.textColor = [self cText];
	self.subtitleLabel.textColor = [self cSub];
	self.headerLine.backgroundColor = [self cLine];
	self.inputLine.backgroundColor = [self cLine];
	self.settings.backgroundColor = [self cSurface];
	self.inputBar.backgroundColor = [self cSurface];
	[self.themeBtn setTitle:(self.dark ? @"Light" : @"Dark") forState:UIControlStateNormal];
	for (UITextField *f in @[self.keyField, self.modelField, self.sysField, self.inputField]) {
		f.backgroundColor = [self cField];
		f.textColor = [self cText];
		f.keyboardAppearance = self.dark ? UIKeyboardAppearanceDark : UIKeyboardAppearanceDefault;
		NSString *p = f.attributedPlaceholder.string ?: f.placeholder ?: @"";
		f.attributedPlaceholder = [[NSAttributedString alloc] initWithString:p attributes:@{NSForegroundColorAttributeName: [self cSub]}];
	}
	for (UIButton *b in self.chips) {
		b.backgroundColor = [self cField];
		[b setTitleColor:[self cText] forState:UIControlStateNormal];
	}
	[self.table reloadData];
}

#pragma mark - Setup

- (void)viewDidLoad {
	[super viewDidLoad];
	NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
	self.dark = [d objectForKey:@"dark"] ? [d boolForKey:@"dark"] : YES;
	self.animateRow = -1;

	// Header
	self.header = [[UIView alloc] init];
	[self.view addSubview:self.header];
	self.titleLabel = [[UILabel alloc] init];
	self.titleLabel.text = @"AI Chat";
	self.titleLabel.font = [UIFont boldSystemFontOfSize:18];
	self.titleLabel.textAlignment = NSTextAlignmentCenter;
	[self.header addSubview:self.titleLabel];
	self.subtitleLabel = [[UILabel alloc] init];
	self.subtitleLabel.font = [UIFont systemFontOfSize:11];
	self.subtitleLabel.textAlignment = NSTextAlignmentCenter;
	[self.header addSubview:self.subtitleLabel];
	self.freshBtn = [self headerButton:@"New" action:@selector(resetChat)];
	self.themeBtn = [self headerButton:@"Light" action:@selector(toggleTheme)];
	self.gearBtn = [self headerButton:@"Settings" action:@selector(toggleSettings)];
	self.headerLine = [[UIView alloc] init];
	[self.view addSubview:self.headerLine];

	// Settings panel (clipped, animated height)
	self.settings = [[UIView alloc] init];
	self.settings.clipsToBounds = YES;
	[self.view addSubview:self.settings];
	self.keyField = [self darkField:@"Gemini API key"];
	self.keyField.secureTextEntry = YES;
	self.keyField.text = [d stringForKey:@"apikey"];
	self.modelField = [self darkField:@"Model"];
	self.modelField.text = [d stringForKey:@"model"] ?: @"gemini-3.8-flash";
	self.sysField = [self darkField:@"System prompt (optional, e.g. answer briefly)"];
	self.sysField.autocapitalizationType = UITextAutocapitalizationTypeSentences;
	self.sysField.text = [d stringForKey:@"sys"];
	for (UITextField *f in @[self.keyField, self.modelField, self.sysField]) [self.settings addSubview:f];
	self.settingsOpen = (self.keyField.text.length == 0);
	self.subtitleLabel.text = self.modelField.text;

	// Chat table
	self.table = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
	self.table.backgroundColor = [UIColor clearColor];
	self.table.separatorStyle = UITableViewCellSeparatorStyleNone;
	self.table.dataSource = self;
	self.table.delegate = self;
	self.table.keyboardDismissMode = UIScrollViewKeyboardDismissModeInteractive;
	self.table.contentInset = UIEdgeInsetsMake(8, 0, 8, 0);
	self.table.scrollIndicatorInsets = UIEdgeInsetsMake(8, 0, 8, 0);
	[self.view addSubview:self.table];
	[self buildChips];

	// Input bar
	self.inputBar = [[UIView alloc] init];
	[self.view addSubview:self.inputBar];
	self.inputLine = [[UIView alloc] init];
	[self.inputBar addSubview:self.inputLine];
	self.inputField = [self darkField:@"Message"];
	self.inputField.returnKeyType = UIReturnKeySend;
	self.inputField.layer.cornerRadius = 18;
	self.inputField.leftView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 14, 10)];
	[self.inputBar addSubview:self.inputField];
	self.sendBtn = [UIButton buttonWithType:UIButtonTypeCustom];
	[self.sendBtn setTitle:@"\u2191" forState:UIControlStateNormal];
	self.sendBtn.titleLabel.font = [UIFont boldSystemFontOfSize:22];
	self.sendBtn.backgroundColor = ACCENT;
	self.sendBtn.layer.cornerRadius = 18;
	[self.sendBtn addTarget:self action:@selector(sendDown) forControlEvents:UIControlEventTouchDown];
	[self.sendBtn addTarget:self action:@selector(sendUp) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside | UIControlEventTouchCancel];
	[self.sendBtn addTarget:self action:@selector(send) forControlEvents:UIControlEventTouchUpInside];
	[self.inputBar addSubview:self.sendBtn];

	// Toast
	self.toast = [[UILabel alloc] init];
	self.toast.backgroundColor = [UIColor colorWithWhite:0 alpha:0.8];
	self.toast.textColor = [UIColor whiteColor];
	self.toast.font = [UIFont systemFontOfSize:13];
	self.toast.textAlignment = NSTextAlignmentCenter;
	self.toast.layer.cornerRadius = 13;
	self.toast.clipsToBounds = YES;
	self.toast.alpha = 0;
	[self.view addSubview:self.toast];

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(kbChange:) name:UIKeyboardWillShowNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(kbChange:) name:UIKeyboardWillHideNotification object:nil];

	[self loadChat];
	[self applyTheme];
}

- (void)viewDidAppear:(BOOL)animated {
	[super viewDidAppear:animated];
	[self scrollToBottomAnimated:NO];
}

- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (UIButton *)headerButton:(NSString *)title action:(SEL)sel {
	UIButton *b = [UIButton buttonWithType:UIButtonTypeCustom];
	[b setTitle:title forState:UIControlStateNormal];
	[b setTitleColor:ACCENT forState:UIControlStateNormal];
	[b setTitleColor:[UIColor grayColor] forState:UIControlStateHighlighted];
	b.titleLabel.font = [UIFont systemFontOfSize:15];
	[b addTarget:self action:sel forControlEvents:UIControlEventTouchUpInside];
	[self.header addSubview:b];
	return b;
}

- (UITextField *)darkField:(NSString *)placeholder {
	UITextField *f = [[UITextField alloc] init];
	f.placeholder = placeholder;
	f.font = [UIFont systemFontOfSize:15];
	f.layer.cornerRadius = 9;
	f.autocorrectionType = UITextAutocorrectionTypeNo;
	f.autocapitalizationType = UITextAutocapitalizationTypeNone;
	f.delegate = self;
	f.clearButtonMode = UITextFieldViewModeWhileEditing;
	f.leftView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 10, 10)];
	f.leftViewMode = UITextFieldViewModeAlways;
	return f;
}

- (void)buildChips {
	NSArray *titles = @[@"Explain something simply", @"Help me write some code", @"Give me fun ideas"];
	self.chipPrompts = @[@"Explain a surprising science fact in simple words.",
						 @"Show me a short, useful code snippet in Python and explain it.",
						 @"Give me 5 fun things to do when I am bored."];
	CGFloat w = [UIScreen mainScreen].bounds.size.width;
	self.chipsView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, w, 8 + 3 * 46)];
	self.chips = [NSMutableArray array];
	for (int i = 0; i < 3; i++) {
		UIButton *b = [UIButton buttonWithType:UIButtonTypeCustom];
		b.frame = CGRectMake(16, 8 + i * 46, w - 32, 38);
		b.layer.cornerRadius = 19;
		b.titleLabel.font = [UIFont systemFontOfSize:15];
		[b setTitle:titles[i] forState:UIControlStateNormal];
		b.tag = i;
		[b addTarget:self action:@selector(chipTapped:) forControlEvents:UIControlEventTouchUpInside];
		[self.chipsView addSubview:b];
		[self.chips addObject:b];
	}
}

- (void)chipTapped:(UIButton *)b {
	self.inputField.text = self.chipPrompts[b.tag];
	[self send];
}

#pragma mark - Layout

- (void)viewWillLayoutSubviews {
	[super viewWillLayoutSubviews];
	CGFloat w = self.view.bounds.size.width, h = self.view.bounds.size.height;
	self.header.frame = CGRectMake(0, 0, w, 64);
	self.freshBtn.frame = CGRectMake(6, 20, 60, 44);
	self.gearBtn.frame = CGRectMake(w - 76, 20, 70, 44);
	self.themeBtn.frame = CGRectMake(w - 126, 20, 50, 44);
	CGFloat tx = 70, tw = w - 70 - 130;
	self.titleLabel.frame = CGRectMake(tx, 23, tw, 22);
	self.subtitleLabel.frame = CGRectMake(tx, 44, tw, 14);
	self.headerLine.frame = CGRectMake(0, 63.5, w, 0.5);

	CGFloat sh = self.settingsOpen ? SETTINGS_H : 0;
	self.settings.frame = CGRectMake(0, 64, w, sh);
	self.settings.alpha = self.settingsOpen ? 1 : 0;
	self.keyField.frame = CGRectMake(10, 8, w - 20, 34);
	self.modelField.frame = CGRectMake(10, 48, w - 20, 34);
	self.sysField.frame = CGRectMake(10, 88, w - 20, 34);

	CGFloat barH = 54;
	CGFloat barY = h - self.kbHeight - barH;
	self.inputBar.frame = CGRectMake(0, barY, w, barH);
	self.inputLine.frame = CGRectMake(0, 0, w, 0.5);
	self.inputField.frame = CGRectMake(10, 9, w - 20 - 44, 36);
	self.sendBtn.frame = CGRectMake(w - 46, 9, 36, 36);

	CGFloat ty = 64 + sh;
	self.table.frame = CGRectMake(0, ty, w, barY - ty);
	self.toast.frame = CGRectMake((w - 110) / 2, barY - 42, 110, 26);
}

- (void)relayoutAnimated {
	[UIView animateWithDuration:0.45 delay:0 usingSpringWithDamping:0.82 initialSpringVelocity:0
		options:UIViewAnimationOptionBeginFromCurrentState
		animations:^{ [self.view setNeedsLayout]; [self.view layoutIfNeeded]; } completion:nil];
}

- (void)toggleSettings {
	self.settingsOpen = !self.settingsOpen;
	if (!self.settingsOpen) [self.view endEditing:YES];
	[self relayoutAnimated];
}

- (void)toggleTheme {
	self.dark = !self.dark;
	[[NSUserDefaults standardUserDefaults] setBool:self.dark forKey:@"dark"];
	[UIView transitionWithView:self.view duration:0.3 options:UIViewAnimationOptionTransitionCrossDissolve
		animations:^{ [self applyTheme]; } completion:nil];
	[self setNeedsStatusBarAppearanceUpdate];
}

- (void)kbChange:(NSNotification *)n {
	NSDictionary *u = n.userInfo;
	CGRect r = [u[UIKeyboardFrameEndUserInfoKey] CGRectValue];
	BOOL show = [n.name isEqualToString:UIKeyboardWillShowNotification];
	self.kbHeight = show ? r.size.height : 0;
	double dur = [u[UIKeyboardAnimationDurationUserInfoKey] doubleValue];
	NSUInteger curve = [u[UIKeyboardAnimationCurveUserInfoKey] unsignedIntegerValue];
	[UIView animateWithDuration:dur delay:0 options:(curve << 16) | UIViewAnimationOptionBeginFromCurrentState
		animations:^{ [self.view setNeedsLayout]; [self.view layoutIfNeeded]; } completion:nil];
	if (show) dispatch_async(dispatch_get_main_queue(), ^{ [self scrollToBottomAnimated:YES]; });
}

#pragma mark - Text fields

- (BOOL)textFieldShouldReturn:(UITextField *)tf {
	if (tf == self.inputField) [self send]; else [tf resignFirstResponder];
	return YES;
}

- (void)textFieldDidEndEditing:(UITextField *)tf {
	if (tf == self.inputField) return;
	NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
	[d setObject:[self.keyField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] forKey:@"apikey"];
	[d setObject:[self.modelField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] forKey:@"model"];
	[d setObject:self.sysField.text ?: @"" forKey:@"sys"];
	[d synchronize];
	self.subtitleLabel.text = self.modelField.text;
}

#pragma mark - Send button feel

- (void)sendDown {
	[UIView animateWithDuration:0.1 animations:^{ self.sendBtn.transform = CGAffineTransformMakeScale(0.86, 0.86); }];
}

- (void)sendUp {
	[UIView animateWithDuration:0.3 delay:0 usingSpringWithDamping:0.5 initialSpringVelocity:0.8 options:0
		animations:^{ self.sendBtn.transform = CGAffineTransformIdentity; } completion:nil];
}

- (void)setSendEnabled:(BOOL)on {
	self.sendBtn.userInteractionEnabled = on;
	[UIView animateWithDuration:0.2 animations:^{ self.sendBtn.alpha = on ? 1 : 0.4; }];
}

#pragma mark - Messages

- (NSMutableDictionary *)welcomeMsg {
	return [@{@"role": @"model", @"text": @"Hi! \U0001F44B Ask me anything. Tap a message to copy it.", @"local": @YES} mutableCopy];
}

- (CGSize)textSize:(NSString *)t {
	CGFloat maxW = self.view.bounds.size.width * 0.78 - 24;
	CGRect r = [t boundingRectWithSize:CGSizeMake(maxW, CGFLOAT_MAX)
		options:NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingUsesFontLeading
		attributes:@{NSFontAttributeName: BUBBLE_FONT} context:nil];
	return CGSizeMake(ceil(r.size.width), ceil(r.size.height));
}

// Sizes are measured once per message and cached (keeps scrolling light on the CPU).
- (void)measure:(NSMutableDictionary *)m {
	if ([m[@"typing"] boolValue]) { m[@"tw"] = @46; m[@"th"] = @16; return; }
	CGSize s = [self textSize:m[@"text"]];
	m[@"tw"] = @(s.width);
	m[@"th"] = @(s.height);
}

- (void)updateChips {
	self.table.tableFooterView = ([self.messages count] <= 1) ? self.chipsView : nil;
}

- (void)appendMessage:(NSMutableDictionary *)m {
	[self measure:m];
	[self.messages addObject:m];
	NSIndexPath *ip = [NSIndexPath indexPathForRow:[self.messages count] - 1 inSection:0];
	self.animateRow = ip.row;
	[self.table insertRowsAtIndexPaths:@[ip] withRowAnimation:UITableViewRowAnimationNone];
	[self updateChips];
	[self scrollToBottomAnimated:YES];
}

- (void)scrollToBottomAnimated:(BOOL)anim {
	NSInteger n = [self.messages count];
	if (n > 0) [self.table scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:n - 1 inSection:0] atScrollPosition:UITableViewScrollPositionBottom animated:anim];
}

- (void)showToast:(NSString *)t {
	self.toast.text = t;
	[self.toast.layer removeAllAnimations];
	self.toast.alpha = 1;
	[UIView animateWithDuration:0.4 delay:1.0 options:0 animations:^{ self.toast.alpha = 0; } completion:nil];
}

- (NSString *)clean:(NSString *)s {
	s = [s stringByReplacingOccurrencesOfString:@"**" withString:@""];
	s = [s stringByReplacingOccurrencesOfString:@"`" withString:@""];
	NSRegularExpression *h = [NSRegularExpression regularExpressionWithPattern:@"^#{1,6}\\s*" options:NSRegularExpressionAnchorsMatchLines error:nil];
	s = [h stringByReplacingMatchesInString:s options:0 range:NSMakeRange(0, s.length) withTemplate:@""];
	NSRegularExpression *b = [NSRegularExpression regularExpressionWithPattern:@"^(\\s*)[\\*\\-]\\s+" options:NSRegularExpressionAnchorsMatchLines error:nil];
	s = [b stringByReplacingMatchesInString:s options:0 range:NSMakeRange(0, s.length) withTemplate:@"$1\u2022 "];
	return [s stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

#pragma mark - Persistence

- (void)loadChat {
	self.messages = [NSMutableArray arrayWithObject:[self welcomeMsg]];
	NSArray *saved = [[NSUserDefaults standardUserDefaults] arrayForKey:@"chat"];
	for (NSDictionary *s in saved) {
		if (![s[@"role"] isKindOfClass:[NSString class]] || ![s[@"text"] isKindOfClass:[NSString class]]) continue;
		[self.messages addObject:[@{@"role": s[@"role"], @"text": s[@"text"]} mutableCopy]];
	}
	for (NSMutableDictionary *m in self.messages) [self measure:m];
	[self updateChips];
	[self.table reloadData];
}

- (void)saveChat {
	NSMutableArray *a = [NSMutableArray array];
	for (NSDictionary *m in self.messages) {
		if ([m[@"local"] boolValue] || [m[@"typing"] boolValue]) continue;
		[a addObject:@{@"role": m[@"role"], @"text": m[@"text"]}];
	}
	if ([a count] > MAX_SAVED_MSGS) [a removeObjectsInRange:NSMakeRange(0, [a count] - MAX_SAVED_MSGS)];
	NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
	[d setObject:a forKey:@"chat"];
	[d synchronize];
}

- (void)resetChat {
	if (self.busy) return;
	[self.view endEditing:YES];
	self.messages = [NSMutableArray arrayWithObject:[self welcomeMsg]];
	[self measure:self.messages[0]];
	[self saveChat];
	[UIView transitionWithView:self.table duration:0.25 options:UIViewAnimationOptionTransitionCrossDissolve
		animations:^{ [self updateChips]; [self.table reloadData]; } completion:nil];
}

#pragma mark - Table

- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)s { return [self.messages count]; }

- (CGFloat)tableView:(UITableView *)tv heightForRowAtIndexPath:(NSIndexPath *)ip {
	return [self.messages[ip.row][@"th"] floatValue] + 20 + 12;
}

- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)ip {
	NSMutableDictionary *m = self.messages[ip.row];
	BOOL typing = [m[@"typing"] boolValue];
	BOOL user = [m[@"role"] isEqualToString:@"user"];
	NSString *ID = typing ? @"typing" : @"bubble";
	UITableViewCell *c = [tv dequeueReusableCellWithIdentifier:ID];
	if (!c) {
		c = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:ID];
		c.backgroundColor = [UIColor clearColor];
		c.selectionStyle = UITableViewCellSelectionStyleNone;
		UIView *bv = [[UIView alloc] init];
		bv.tag = 1;
		bv.layer.cornerRadius = 18;
		[c.contentView addSubview:bv];
		if (typing) {
			for (int i = 0; i < 3; i++) {
				UIView *dot = [[UIView alloc] initWithFrame:CGRectMake(14 + i * 18, 14, 8, 8)];
				dot.tag = 11 + i;
				dot.layer.cornerRadius = 4;
				[bv addSubview:dot];
			}
		} else {
			UILabel *l = [[UILabel alloc] init];
			l.tag = 2;
			l.numberOfLines = 0;
			l.font = BUBBLE_FONT;
			[bv addSubview:l];
		}
	}
	CGFloat tw = [m[@"tw"] floatValue], th = [m[@"th"] floatValue];
	CGFloat bw = tw + 24, bh = th + 20;
	CGFloat w = self.view.bounds.size.width;
	UIView *bv = [c.contentView viewWithTag:1];
	bv.transform = CGAffineTransformIdentity;
	bv.alpha = 1;
	bv.frame = CGRectMake(user ? w - bw - 10 : 10, 6, bw, bh);
	bv.backgroundColor = user ? ACCENT : [self cBubbleAI];
	bv.layer.borderWidth = (!self.dark && !user) ? 0.5 : 0;
	bv.layer.borderColor = [self cLine].CGColor;
	if (typing) {
		for (int i = 0; i < 3; i++) {
			UIView *dot = [bv viewWithTag:11 + i];
			dot.backgroundColor = [self cSub];
			[dot.layer removeAllAnimations];
			CABasicAnimation *a = [CABasicAnimation animationWithKeyPath:@"opacity"];
			a.fromValue = @0.25;
			a.toValue = @1.0;
			a.duration = 0.5;
			a.autoreverses = YES;
			a.repeatCount = HUGE_VALF;
			a.beginTime = CACurrentMediaTime() + i * 0.17;
			a.fillMode = kCAFillModeBackwards;
			[dot.layer addAnimation:a forKey:@"pulse"];
		}
	} else {
		UILabel *l = (UILabel *)[bv viewWithTag:2];
		l.frame = CGRectMake(12, 10, tw + 1, th);
		l.text = m[@"text"];
		l.textColor = user ? [UIColor whiteColor] : [self cText];
	}
	return c;
}

- (void)tableView:(UITableView *)tv willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)ip {
	if (ip.row != self.animateRow) return;
	self.animateRow = -1;
	UIView *bv = [cell.contentView viewWithTag:1];
	BOOL user = [self.messages[ip.row][@"role"] isEqualToString:@"user"];
	bv.alpha = 0;
	bv.transform = CGAffineTransformConcat(CGAffineTransformMakeScale(0.85, 0.85),
		CGAffineTransformMakeTranslation(user ? 26 : -26, 14));
	[UIView animateWithDuration:0.4 delay:0 usingSpringWithDamping:0.75 initialSpringVelocity:0.6
		options:UIViewAnimationOptionAllowUserInteraction
		animations:^{ bv.alpha = 1; bv.transform = CGAffineTransformIdentity; } completion:nil];
}

- (void)tableView:(UITableView *)tv didSelectRowAtIndexPath:(NSIndexPath *)ip {
	[tv deselectRowAtIndexPath:ip animated:NO];
	[self.view endEditing:YES];
	NSDictionary *m = self.messages[ip.row];
	if ([m[@"typing"] boolValue]) return;
	[UIPasteboard generalPasteboard].string = m[@"text"];
	[self showToast:@"Copied"];
}

#pragma mark - Networking

- (NSArray *)apiHistory {
	NSMutableArray *all = [NSMutableArray array];
	for (NSDictionary *m in self.messages) {
		if ([m[@"local"] boolValue] || [m[@"typing"] boolValue]) continue;
		[all addObject:m];
	}
	// Only send the most recent messages: faster, cheaper, less data on the radio.
	if ([all count] > MAX_API_MSGS) [all removeObjectsInRange:NSMakeRange(0, [all count] - MAX_API_MSGS)];
	while ([all count] && [all[0][@"role"] isEqualToString:@"model"]) [all removeObjectAtIndex:0];
	NSMutableArray *a = [NSMutableArray array];
	for (NSDictionary *m in all) [a addObject:@{@"role": m[@"role"], @"parts": @[@{@"text": m[@"text"]}]}];
	return a;
}

- (void)send {
	NSString *text = [self.inputField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	if (self.busy || text.length == 0) return;
	NSString *key = [self.keyField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	NSString *model = [self.modelField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	NSString *sys = [self.sysField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	if (key.length == 0 || model.length == 0) {
		if (!self.settingsOpen) [self toggleSettings];
		[self showToast:@"Enter API key"];
		return;
	}
	NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
	[d setObject:key forKey:@"apikey"];
	[d setObject:model forKey:@"model"];
	[d setObject:sys forKey:@"sys"];
	[d synchronize];
	self.subtitleLabel.text = model;
	if (self.settingsOpen) { self.settingsOpen = NO; [self.view endEditing:NO]; [self relayoutAnimated]; }

	self.inputField.text = @"";
	[self appendMessage:[@{@"role": @"user", @"text": text} mutableCopy]];
	[self appendMessage:[@{@"role": @"model", @"text": @"", @"typing": @YES, @"local": @YES} mutableCopy]];
	self.busy = YES;
	[self setSendEnabled:NO];

	NSString *encKey = [key stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
	NSString *urlStr = [NSString stringWithFormat:@"https://generativelanguage.googleapis.com/v1beta/models/%@:generateContent?key=%@", model, encKey];
	NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlStr]];
	req.HTTPMethod = @"POST";
	req.timeoutInterval = 60;
	[req setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
	NSMutableDictionary *body = [@{@"contents": [self apiHistory]} mutableCopy];
	if (sys.length) body[@"systemInstruction"] = @{@"parts": @[@{@"text": sys}]};
	req.HTTPBody = [NSJSONSerialization dataWithJSONObject:body options:0 error:nil];

	[[[NSURLSession sharedSession] dataTaskWithRequest:req completionHandler:^(NSData *data, NSURLResponse *resp, NSError *err) {
		NSString *reply = nil, *errMsg = nil;
		if (err) {
			errMsg = err.localizedDescription;
		} else {
			id json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
			if ([json isKindOfClass:[NSDictionary class]]) {
				NSDictionary *e = json[@"error"];
				if ([e isKindOfClass:[NSDictionary class]]) {
					errMsg = e[@"message"] ?: @"Unknown API error";
				} else {
					NSArray *c = json[@"candidates"];
					NSArray *parts = [c count] ? c[0][@"content"][@"parts"] : nil;
					NSMutableString *out = [NSMutableString string];
					for (NSDictionary *p in parts) if (p[@"text"]) [out appendString:p[@"text"]];
					if (out.length) reply = out; else errMsg = @"Empty response (maybe blocked)";
				}
			} else {
				errMsg = @"Could not parse response";
			}
		}
		dispatch_async(dispatch_get_main_queue(), ^{
			self.busy = NO;
			[self setSendEnabled:YES];
			NSInteger last = [self.messages count] - 1; // the typing bubble
			if (reply) {
				NSMutableDictionary *m = [@{@"role": @"model", @"text": [self clean:reply]} mutableCopy];
				[self measure:m];
				self.messages[last] = m;
				self.animateRow = last;
				[self.table reloadRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:last inSection:0]] withRowAnimation:UITableViewRowAnimationNone];
				[self scrollToBottomAnimated:YES];
				[self saveChat];
			} else {
				[self.messages removeLastObject]; // typing
				[self.messages removeLastObject]; // failed user message
				self.inputField.text = text;
				[self.table reloadData];
				[self appendMessage:[@{@"role": @"model", @"text": [@"\u26A0\uFE0F " stringByAppendingString:errMsg], @"local": @YES} mutableCopy]];
			}
		});
	}] resume];
}

@end
