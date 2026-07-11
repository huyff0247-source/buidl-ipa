#import "esp.h"
#import "mahoa.h"
#import "../lib/Offsets.h"
#import <QuartzCore/QuartzCore.h>
#import <UIKit/UIKit.h> 
#include <sys/mman.h>
#include <string>
#include <vector>
#include <cmath>
#include <cstdio>

uint64_t Moudule_Base = -1;

// --- Debug status hien thi tren man hinh ---
static char g_debugStatus[256] = "ESP: khoi dong...";
static int g_playerCount = 0;

// --- ESP Config ---
static bool isBox = YES;
static bool isBone = YES;
static bool isHealth = YES;
static bool isName = YES;
static bool isDis = YES;
static bool isPlayerCount = YES; // Dem so player song xung quanh (hien giua-tren man hinh)

// --- Aimbot Config ---
static bool isAimbot = NO;
static float aimFov = 150.0f;      // Ban kinh vong tron FOV (px)
static float aimDistance = 200.0f; // Khoang cach aim toi da (m)
static int   aimBone = 0;          // 0 = Head, 1 = Neck, 2 = Hip
static float aimSpeed = 0.5f;      // Toc do aim (0.05 muot cham -> 1.0 tuc thi)
static bool  aimOnlyFire = YES;    // Chi aim khi dang ban

@interface CustomSwitch : UIControl
@property (nonatomic, assign, getter=isOn) BOOL on;
@end

@implementation CustomSwitch { UIView *_thumb; }
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
        _thumb = [[UIView alloc] initWithFrame:CGRectMake(2, 2, 22, 22)];
        _thumb.backgroundColor = [UIColor colorWithWhite:0.75 alpha:1.0];
        _thumb.layer.cornerRadius = 11;
        [self addSubview:_thumb];
        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(toggle)];
        [self addGestureRecognizer:tap];
    }
    return self;
}
- (void)drawRect:(CGRect)rect {
    CGContextRef context = UIGraphicsGetCurrentContext();
    UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:self.bounds cornerRadius:self.bounds.size.height/2];
    CGContextSetFillColorWithColor(context, (self.isOn ? [UIColor colorWithRed:0.0 green:0.8 blue:0.0 alpha:1.0] : [UIColor colorWithWhite:0.15 alpha:1.0]).CGColor);
    [path fill];
}
- (void)setOn:(BOOL)on {
    if (_on != on) { _on = on; [self setNeedsDisplay]; [self updateThumbPosition]; }
}
- (void)toggle {
    self.on = !self.on;
    [self sendActionsForControlEvents:UIControlEventValueChanged];
}
- (void)updateThumbPosition {
    [UIView animateWithDuration:0.2 animations:^{
        CGRect frame = self->_thumb.frame;
        frame.origin.x = self.isOn ? self.bounds.size.width - frame.size.width - 2 : 2;
        self->_thumb.frame = frame;
        self->_thumb.backgroundColor = self.isOn ? UIColor.whiteColor : [UIColor colorWithWhite:0.75 alpha:1.0];
    }];
}
@end

@interface MenuView ()
@property (nonatomic, strong) CADisplayLink *displayLink;
@property (nonatomic, strong) NSMutableArray<CALayer *> *drawingLayers;
- (void)renderESPToLayers:(NSMutableArray<CALayer *> *)layers;
@end

@implementation MenuView {
    UIView *menuContainer;
    UIView *floatingButton;
    CGPoint _initialTouchPoint;
    
    // Tab Views
    UIView *mainTabContainer;
    UIView *aimTabContainer;
    UIView *settingTabContainer;

    UIView *previewView;
    UIView *previewContentContainer;
    
    UILabel *previewNameLabel;
    UILabel *previewDistLabel;
    UIView *healthBarContainer;
    UIView *boxContainer;
    UIView *skeletonContainer;
    
    float previewScale;

    UILabel *fovValueLabel;
    UILabel *distValueLabel;
    UILabel *speedValueLabel;
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        ESPLog("MenuView initWithFrame: DA KHOI TAO - ESP dang chay");
        self.userInteractionEnabled = YES;
        self.backgroundColor = [UIColor clearColor];
        self.drawingLayers = [NSMutableArray array];
        
        [self SetUpBase];
        self.displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(updateFrame)];
        [self.displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];

        [self setupFloatingButton];
        [self setupMenuUI];
        [self layoutSubviews];
    }
    return self;
}

- (void)setupFloatingButton {
    floatingButton = [[UIView alloc] initWithFrame:CGRectMake(50, 50, 50, 50)];
    floatingButton.backgroundColor = [UIColor colorWithRed:0.0 green:0.8 blue:0.0 alpha:1.0];
    floatingButton.layer.cornerRadius = 25;
    floatingButton.layer.borderWidth = 2;
    floatingButton.layer.borderColor = [UIColor whiteColor].CGColor;
    floatingButton.clipsToBounds = YES;
    
    UILabel *iconLabel = [[UILabel alloc] initWithFrame:floatingButton.bounds];
    iconLabel.text = @"M";
    iconLabel.textColor = [UIColor whiteColor];
    iconLabel.textAlignment = NSTextAlignmentCenter;
    iconLabel.font = [UIFont boldSystemFontOfSize:20];
    [floatingButton addSubview:iconLabel];
    
    UITapGestureRecognizer *openTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(showMenu)];
    [floatingButton addGestureRecognizer:openTap];
    
    UIPanGestureRecognizer *iconPan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
    [floatingButton addGestureRecognizer:iconPan];
    
    [self addSubview:floatingButton];
}

- (void)addFeatureToView:(UIView *)view withTitle:(NSString *)title atY:(CGFloat)y initialValue:(BOOL)isOn andAction:(SEL)action {
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(15, y, 150, 26)];
    label.text = title;
    label.textColor = [UIColor whiteColor];
    label.font = [UIFont systemFontOfSize:13];
    [view addSubview:label];
    
    CustomSwitch *customSwitch = [[CustomSwitch alloc] initWithFrame:CGRectMake(240, y, 52, 26)];
    customSwitch.on = isOn;
    [customSwitch addTarget:self action:action forControlEvents:UIControlEventValueChanged];
    [view addSubview:customSwitch];
}

- (void)setupMenuUI {
    CGFloat menuWidth = 550;
    CGFloat menuHeight = 320;
    
    menuContainer = [[UIView alloc] initWithFrame:CGRectMake(0, 0, menuWidth, menuHeight)];
    menuContainer.backgroundColor = [UIColor colorWithRed:0.05 green:0.05 blue:0.05 alpha:0.95];
    menuContainer.layer.cornerRadius = 15;
    menuContainer.layer.borderColor = [UIColor colorWithRed:0.2 green:0.2 blue:0.2 alpha:1.0].CGColor;
    menuContainer.layer.borderWidth = 2;
    menuContainer.clipsToBounds = YES;
    menuContainer.hidden = YES;
    [self addSubview:menuContainer];
    
    // Header
    UIView *headerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, menuWidth, 40)];
    headerView.backgroundColor = [UIColor clearColor];
    [menuContainer addSubview:headerView];
    
    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(160, 5, 200, 30)];
    titleLabel.text = @"MENU TIPA";
    titleLabel.textColor = [UIColor whiteColor];
    titleLabel.font = [UIFont fontWithName:@"HelveticaNeue-Bold" size:22];
    [headerView addSubview:titleLabel];
    
    UILabel *subTitle = [[UILabel alloc] initWithFrame:CGRectMake(350, 12, 150, 20)];
    subTitle.text = @"Cheat by TGHUY";
    subTitle.textColor = [UIColor lightGrayColor];
    subTitle.font = [UIFont systemFontOfSize:10];
    [headerView addSubview:subTitle];
    
    NSArray *colors = @[[UIColor greenColor], [UIColor yellowColor], [UIColor redColor]];
    for (int i = 0; i < 3; i++) {
        UIView *circle = [[UIView alloc] initWithFrame:CGRectMake(menuWidth - 80 + (i * 25), 10, 18, 18)];
        circle.backgroundColor = colors[i];
        circle.layer.cornerRadius = 9;
        
        UILabel *btnIcon = [[UILabel alloc] initWithFrame:circle.bounds];
        btnIcon.textAlignment = NSTextAlignmentCenter;
        btnIcon.font = [UIFont boldSystemFontOfSize:12];
        btnIcon.textColor = [UIColor blackColor];
        
        if (i == 0) btnIcon.text = @"□";
        if (i == 1) btnIcon.text = @"-";
        if (i == 2) {
            btnIcon.text = @"X";
            UITapGestureRecognizer *closeTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(hideMenu)];
            [circle addGestureRecognizer:closeTap];
        }
        [circle addSubview:btnIcon];
        [headerView addSubview:circle];
    }
    
    UIPanGestureRecognizer *menuPan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
    [headerView addGestureRecognizer:menuPan];
    
    // Sidebar Buttons
    UIView *sidebar = [[UIView alloc] initWithFrame:CGRectMake(465, 50, 75, 250)];
    sidebar.backgroundColor = [UIColor colorWithWhite:0.8 alpha:1.0];
    sidebar.layer.cornerRadius = 10;
    [menuContainer addSubview:sidebar];
    
    NSArray *tabs = @[@"Main", @"AIM", @"Setting"];
    for (int i = 0; i < tabs.count; i++) {
        UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
        btn.frame = CGRectMake(5, 10 + (i * 50), 65, 35);
        btn.backgroundColor = (i == 0) ? [UIColor colorWithRed:0.2 green:0.2 blue:0.2 alpha:1.0] : [UIColor colorWithRed:0.3 green:0.3 blue:0.3 alpha:1.0];
        [btn setTitle:tabs[i] forState:UIControlStateNormal];
        [btn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        btn.layer.cornerRadius = 17.5;
        btn.titleLabel.font = [UIFont boldSystemFontOfSize:11];
        btn.tag = i;
        [btn addTarget:self action:@selector(tabChanged:) forControlEvents:UIControlEventTouchUpInside];
        [sidebar addSubview:btn];
    }

    // --- MAIN TAB (ESP) ---
    mainTabContainer = [[UIView alloc] initWithFrame:CGRectMake(15, 50, 440, 250)];
    mainTabContainer.backgroundColor = [UIColor clearColor];
    [menuContainer addSubview:mainTabContainer];

    // Preview Section (Left)
    UIView *previewBorder = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 130, 250)];
    previewBorder.layer.borderColor = [UIColor whiteColor].CGColor;
    previewBorder.layer.borderWidth = 1;
    previewBorder.layer.cornerRadius = 10;
    [mainTabContainer addSubview:previewBorder];
    
    UILabel *pvTitle = [[UILabel alloc] initWithFrame:CGRectMake(0, 5, 130, 20)];
    pvTitle.text = @"Preview";
    pvTitle.textColor = [UIColor whiteColor];
    pvTitle.textAlignment = NSTextAlignmentCenter;
    pvTitle.font = [UIFont boldSystemFontOfSize:14];
    [previewBorder addSubview:pvTitle];
    
    UIView *line = [[UIView alloc] initWithFrame:CGRectMake(10, 28, 110, 1)];
    line.backgroundColor = [UIColor whiteColor];
    [previewBorder addSubview:line];
    
    previewView = [[UIView alloc] initWithFrame:CGRectMake(0, 30, 130, 220)];
    previewView.backgroundColor = [UIColor blackColor];
    previewView.clipsToBounds = YES;
    [previewBorder addSubview:previewView];
    
    previewContentContainer = [[UIView alloc] initWithFrame:previewView.bounds];
    [previewView addSubview:previewContentContainer];
    
    [self drawPreviewElements];
    [self updatePreviewVisibility];

    // Feature Box (Right)
    UIView *featureBox = [[UIView alloc] initWithFrame:CGRectMake(140, 0, 300, 250)];
    featureBox.layer.borderColor = [UIColor whiteColor].CGColor;
    featureBox.layer.borderWidth = 1;
    featureBox.layer.cornerRadius = 10;
    featureBox.backgroundColor = [UIColor blackColor];
    [mainTabContainer addSubview:featureBox];
    
    UILabel *ftTitle = [[UILabel alloc] initWithFrame:CGRectMake(15, 10, 200, 20)];
    ftTitle.text = @"ESP Feature";
    ftTitle.textColor = [UIColor whiteColor];
    ftTitle.font = [UIFont boldSystemFontOfSize:16];
    [featureBox addSubview:ftTitle];
    
    UIView *ftLine = [[UIView alloc] initWithFrame:CGRectMake(15, 35, 270, 1)];
    ftLine.backgroundColor = [UIColor whiteColor];
    [featureBox addSubview:ftLine];
    
    [self addFeatureToView:featureBox withTitle:@"Box" atY:45 initialValue:isBox andAction:@selector(toggleBox:)];
    [self addFeatureToView:featureBox withTitle:@"Bone" atY:80 initialValue:isBone andAction:@selector(toggleBone:)];
    [self addFeatureToView:featureBox withTitle:@"Health" atY:115 initialValue:isHealth andAction:@selector(toggleHealth:)];
    [self addFeatureToView:featureBox withTitle:@"Name" atY:150 initialValue:isName andAction:@selector(toggleName:)];
    [self addFeatureToView:featureBox withTitle:@"Distance" atY:185 initialValue:isDis andAction:@selector(toggleDist:)];

    UILabel *sliderLabel = [[UILabel alloc] initWithFrame:CGRectMake(15, 220, 40, 20)];
    sliderLabel.text = @"Size:";
    sliderLabel.textColor = [UIColor whiteColor];
    sliderLabel.font = [UIFont systemFontOfSize:12];
    [featureBox addSubview:sliderLabel];
    
    UISlider *slider = [[UISlider alloc] initWithFrame:CGRectMake(55, 220, 225, 20)];
    slider.minimumValue = 0.5;
    slider.maximumValue = 1.3;
    slider.value = 1.0;
    slider.thumbTintColor = [UIColor whiteColor];
    slider.minimumTrackTintColor = [UIColor greenColor];
    slider.transform = CGAffineTransformMakeScale(0.8, 0.8);
    [slider addTarget:self action:@selector(sliderValueChanged:) forControlEvents:UIControlEventValueChanged];
    [featureBox addSubview:slider];

    // --- AIM TAB ---
    aimTabContainer = [[UIView alloc] initWithFrame:CGRectMake(15, 50, 440, 250)];
    aimTabContainer.backgroundColor = [UIColor blackColor];
    aimTabContainer.layer.borderColor = [UIColor whiteColor].CGColor;
    aimTabContainer.layer.borderWidth = 1;
    aimTabContainer.layer.cornerRadius = 10;
    aimTabContainer.clipsToBounds = YES; // khong cho control tran ra ngoai vien
    aimTabContainer.hidden = YES; // An mac dinh
    [menuContainer addSubview:aimTabContainer];

    UILabel *aimTitle = [[UILabel alloc] initWithFrame:CGRectMake(15, 6, 200, 20)];
    aimTitle.text = @"Aimbot Logic";
    aimTitle.textColor = [UIColor whiteColor];
    aimTitle.font = [UIFont boldSystemFontOfSize:15];
    [aimTabContainer addSubview:aimTitle];

    UIView *aimLine = [[UIView alloc] initWithFrame:CGRectMake(15, 27, 410, 1)];
    aimLine.backgroundColor = [UIColor whiteColor];
    [aimTabContainer addSubview:aimLine];

    [self addFeatureToView:aimTabContainer withTitle:@"Enable Aimbot" atY:34 initialValue:isAimbot andAction:@selector(toggleAimbot:)];
    [self addFeatureToView:aimTabContainer withTitle:@"Only When Firing" atY:64 initialValue:aimOnlyFire andAction:@selector(toggleAimOnlyFire:)];

    // Aim Bone selector (Head / Neck / Hip)
    UILabel *boneLabel = [[UILabel alloc] initWithFrame:CGRectMake(15, 96, 85, 24)];
    boneLabel.text = @"Aim Bone:";
    boneLabel.textColor = [UIColor whiteColor];
    boneLabel.font = [UIFont systemFontOfSize:13];
    [aimTabContainer addSubview:boneLabel];

    UISegmentedControl *boneSeg = [[UISegmentedControl alloc] initWithItems:@[@"Head", @"Neck", @"Hip"]];
    boneSeg.frame = CGRectMake(105, 94, 315, 28);
    boneSeg.selectedSegmentIndex = aimBone;
    boneSeg.tintColor = [UIColor whiteColor];
    if (@available(iOS 13.0, *)) {
        boneSeg.selectedSegmentTintColor = [UIColor colorWithRed:0.0 green:0.7 blue:0.0 alpha:1.0];
        [boneSeg setTitleTextAttributes:@{NSForegroundColorAttributeName:[UIColor whiteColor]} forState:UIControlStateNormal];
    }
    [boneSeg addTarget:self action:@selector(boneChanged:) forControlEvents:UIControlEventValueChanged];
    [aimTabContainer addSubview:boneSeg];

    // FOV Slider (co hien gia tri)
    UILabel *fovLabel = [[UILabel alloc] initWithFrame:CGRectMake(15, 126, 300, 16)];
    fovLabel.text = @"FOV Radius (px):";
    fovLabel.textColor = [UIColor whiteColor];
    fovLabel.font = [UIFont systemFontOfSize:12];
    [aimTabContainer addSubview:fovLabel];

    fovValueLabel = [[UILabel alloc] initWithFrame:CGRectMake(320, 126, 100, 16)];
    fovValueLabel.text = [NSString stringWithFormat:@"%.0f", aimFov];
    fovValueLabel.textColor = [UIColor redColor];
    fovValueLabel.textAlignment = NSTextAlignmentRight;
    fovValueLabel.font = [UIFont boldSystemFontOfSize:12];
    [aimTabContainer addSubview:fovValueLabel];

    UISlider *fovSlider = [[UISlider alloc] initWithFrame:CGRectMake(15, 143, 405, 18)];
    fovSlider.minimumValue = 10.0;
    fovSlider.maximumValue = 400.0;
    fovSlider.value = aimFov;
    fovSlider.thumbTintColor = [UIColor whiteColor];
    fovSlider.minimumTrackTintColor = [UIColor redColor];
    [fovSlider addTarget:self action:@selector(fovChanged:) forControlEvents:UIControlEventValueChanged];
    [aimTabContainer addSubview:fovSlider];

    // Distance Slider (co hien gia tri)
    UILabel *distLabel = [[UILabel alloc] initWithFrame:CGRectMake(15, 167, 300, 16)];
    distLabel.text = @"Aim Distance (m):";
    distLabel.textColor = [UIColor whiteColor];
    distLabel.font = [UIFont systemFontOfSize:12];
    [aimTabContainer addSubview:distLabel];

    distValueLabel = [[UILabel alloc] initWithFrame:CGRectMake(320, 167, 100, 16)];
    distValueLabel.text = [NSString stringWithFormat:@"%.0f", aimDistance];
    distValueLabel.textColor = [UIColor cyanColor];
    distValueLabel.textAlignment = NSTextAlignmentRight;
    distValueLabel.font = [UIFont boldSystemFontOfSize:12];
    [aimTabContainer addSubview:distValueLabel];

    UISlider *distSlider = [[UISlider alloc] initWithFrame:CGRectMake(15, 184, 405, 18)];
    distSlider.minimumValue = 10.0;
    distSlider.maximumValue = 500.0;
    distSlider.value = aimDistance;
    distSlider.thumbTintColor = [UIColor whiteColor];
    distSlider.minimumTrackTintColor = [UIColor blueColor];
    [distSlider addTarget:self action:@selector(distChanged:) forControlEvents:UIControlEventValueChanged];
    [aimTabContainer addSubview:distSlider];

    // Aim Speed Slider (co hien gia tri)
    UILabel *speedLabel = [[UILabel alloc] initWithFrame:CGRectMake(15, 208, 300, 16)];
    speedLabel.text = @"Aim Speed:";
    speedLabel.textColor = [UIColor whiteColor];
    speedLabel.font = [UIFont systemFontOfSize:12];
    [aimTabContainer addSubview:speedLabel];

    speedValueLabel = [[UILabel alloc] initWithFrame:CGRectMake(320, 208, 100, 16)];
    speedValueLabel.text = [NSString stringWithFormat:@"%.2f", aimSpeed];
    speedValueLabel.textColor = [UIColor greenColor];
    speedValueLabel.textAlignment = NSTextAlignmentRight;
    speedValueLabel.font = [UIFont boldSystemFontOfSize:12];
    [aimTabContainer addSubview:speedValueLabel];

    UISlider *speedSlider = [[UISlider alloc] initWithFrame:CGRectMake(15, 225, 405, 18)];
    speedSlider.minimumValue = 0.05;
    speedSlider.maximumValue = 1.0;
    speedSlider.value = aimSpeed;
    speedSlider.thumbTintColor = [UIColor whiteColor];
    speedSlider.minimumTrackTintColor = [UIColor greenColor];
    [speedSlider addTarget:self action:@selector(speedChanged:) forControlEvents:UIControlEventValueChanged];
    [aimTabContainer addSubview:speedSlider];


    // --- SETTING TAB (Empty for now) ---
    settingTabContainer = [[UIView alloc] initWithFrame:CGRectMake(15, 50, 440, 250)];
    settingTabContainer.backgroundColor = [UIColor blackColor];
    settingTabContainer.layer.borderColor = [UIColor whiteColor].CGColor;
    settingTabContainer.layer.borderWidth = 1;
    settingTabContainer.layer.cornerRadius = 10;
    settingTabContainer.hidden = YES;
    [menuContainer addSubview:settingTabContainer];
    
    UILabel *stTitle = [[UILabel alloc] initWithFrame:CGRectMake(15, 10, 200, 20)];
    stTitle.text = @"Settings";
    stTitle.textColor = [UIColor whiteColor];
    stTitle.font = [UIFont boldSystemFontOfSize:16];
    [settingTabContainer addSubview:stTitle];

    UIView *stLine = [[UIView alloc] initWithFrame:CGRectMake(15, 35, 410, 1)];
    stLine.backgroundColor = [UIColor whiteColor];
    [settingTabContainer addSubview:stLine];
    [self addFeatureToView:settingTabContainer withTitle:@"Enemy Count (top)" atY:45 initialValue:isPlayerCount andAction:@selector(togglePlayerCount:)];
}

- (void)tabChanged:(UIButton *)sender {
    mainTabContainer.hidden = YES;
    aimTabContainer.hidden = YES;
    settingTabContainer.hidden = YES;
    
    // Reset buttons color
    for (UIView *sub in sender.superview.subviews) {
        if ([sub isKindOfClass:[UIButton class]]) {
            UIButton *btn = (UIButton *)sub;
            btn.backgroundColor = [UIColor colorWithRed:0.3 green:0.3 blue:0.3 alpha:1.0];
        }
    }
    // Highlight active button
    sender.backgroundColor = [UIColor colorWithRed:0.2 green:0.2 blue:0.2 alpha:1.0];
    
    if (sender.tag == 0) mainTabContainer.hidden = NO;
    if (sender.tag == 1) aimTabContainer.hidden = NO;
    if (sender.tag == 2) settingTabContainer.hidden = NO;
}

- (void)drawPreviewElements {
    CGFloat w = previewView.frame.size.width;  
    CGFloat h = previewView.frame.size.height; 
    CGFloat cx = w / 2;
    CGFloat startY = 45; 
    
    previewNameLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 20, w, 15)];
    previewNameLabel.text = @"ID PlayerName";
    previewNameLabel.textColor = [UIColor greenColor];
    previewNameLabel.textAlignment = NSTextAlignmentCenter;
    previewNameLabel.font = [UIFont boldSystemFontOfSize:11];
    [previewContentContainer addSubview:previewNameLabel];
    
    CGFloat barW = 70;
    healthBarContainer = [[UIView alloc] initWithFrame:CGRectMake(cx - barW/2, 38, barW, 2)];
    healthBarContainer.backgroundColor = [UIColor greenColor];
    [previewContentContainer addSubview:healthBarContainer];
    
    CGFloat boxW = 70;
    CGFloat boxH = 130;
    CGFloat bx = cx - boxW/2;
    CGFloat by = startY;
    
    boxContainer = [[UIView alloc] initWithFrame:previewView.bounds];
    [previewContentContainer addSubview:boxContainer];
    
    CGFloat lineLen = 15;
    UIColor *boxColor = [UIColor whiteColor];
    [self addLineRect:CGRectMake(bx, by, lineLen, 1) color:boxColor parent:boxContainer];
    [self addLineRect:CGRectMake(bx, by, 1, lineLen) color:boxColor parent:boxContainer];
    [self addLineRect:CGRectMake(bx + boxW - lineLen, by, lineLen, 1) color:boxColor parent:boxContainer];
    [self addLineRect:CGRectMake(bx + boxW, by, 1, lineLen) color:boxColor parent:boxContainer];
    [self addLineRect:CGRectMake(bx, by + boxH, lineLen, 1) color:boxColor parent:boxContainer];
    [self addLineRect:CGRectMake(bx, by + boxH - lineLen, 1, lineLen) color:boxColor parent:boxContainer];
    [self addLineRect:CGRectMake(bx + boxW - lineLen, by + boxH, lineLen, 1) color:boxColor parent:boxContainer];
    [self addLineRect:CGRectMake(bx + boxW, by + boxH - lineLen, 1, lineLen) color:boxColor parent:boxContainer];

    skeletonContainer = [[UIView alloc] initWithFrame:previewView.bounds];
    [previewContentContainer addSubview:skeletonContainer];
    
    UIColor *skelColor = [UIColor whiteColor];
    CGFloat skelThick = 1.0;
    
    CGFloat headRad = 7;
    CGFloat headY = by + 15;
    UIView *head = [[UIView alloc] initWithFrame:CGRectMake(cx - headRad, headY - headRad, headRad*2, headRad*2)];
    head.layer.borderColor = skelColor.CGColor;
    head.layer.borderWidth = skelThick;
    head.layer.cornerRadius = headRad;
    [skeletonContainer addSubview:head];
    
    CGPoint pNeck = CGPointMake(cx, headY + headRad);
    CGPoint pPelvis = CGPointMake(cx, by + 65);
    CGPoint pShoulderL = CGPointMake(cx - 15, by + 30);
    CGPoint pShoulderR = CGPointMake(cx + 15, by + 30);
    CGPoint pElbowL = CGPointMake(cx - 20, by + 50);
    CGPoint pElbowR = CGPointMake(cx + 20, by + 50);
    CGPoint pHandL = CGPointMake(cx - 20, by + 70);
    CGPoint pHandR = CGPointMake(cx + 20, by + 70);
    CGPoint pKneeL = CGPointMake(cx - 12, by + 95);
    CGPoint pKneeR = CGPointMake(cx + 12, by + 95);
    CGPoint pFootL = CGPointMake(cx - 15, by + 125);
    CGPoint pFootR = CGPointMake(cx + 15, by + 125);
    
    [self addLineFrom:pNeck to:pPelvis color:skelColor width:skelThick inView:skeletonContainer];
    [self addLineFrom:pShoulderL to:pShoulderR color:skelColor width:skelThick inView:skeletonContainer];
    [self addLineFrom:CGPointMake(cx, by+30) to:pShoulderL color:skelColor width:skelThick inView:skeletonContainer];
    [self addLineFrom:pShoulderL to:pElbowL color:skelColor width:skelThick inView:skeletonContainer];
    [self addLineFrom:pElbowL to:pHandL color:skelColor width:skelThick inView:skeletonContainer];
    [self addLineFrom:CGPointMake(cx, by+30) to:pShoulderR color:skelColor width:skelThick inView:skeletonContainer];
    [self addLineFrom:pShoulderR to:pElbowR color:skelColor width:skelThick inView:skeletonContainer];
    [self addLineFrom:pElbowR to:pHandR color:skelColor width:skelThick inView:skeletonContainer];
    [self addLineFrom:pPelvis to:pKneeL color:skelColor width:skelThick inView:skeletonContainer];
    [self addLineFrom:pKneeL to:pFootL color:skelColor width:skelThick inView:skeletonContainer];
    [self addLineFrom:pPelvis to:pKneeR color:skelColor width:skelThick inView:skeletonContainer];
    [self addLineFrom:pKneeR to:pFootR color:skelColor width:skelThick inView:skeletonContainer];
    
    previewDistLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, by + boxH + 5, w, 15)];
    previewDistLabel.text = @"Distance";
    previewDistLabel.textColor = [UIColor whiteColor];
    previewDistLabel.textAlignment = NSTextAlignmentCenter;
    previewDistLabel.font = [UIFont systemFontOfSize:10];
    [previewContentContainer addSubview:previewDistLabel];
}

- (void)updatePreviewVisibility {
    boxContainer.hidden = !isBox;
    skeletonContainer.hidden = !isBone;
    healthBarContainer.hidden = !isHealth;
    previewNameLabel.hidden = !isName;
    previewDistLabel.hidden = !isDis;
    
    if (isBox && isBone) {
        [previewContentContainer bringSubviewToFront:boxContainer];
    }
}

// --- Toggle Handlers ---
- (void)toggleBox:(CustomSwitch *)sender { isBox = sender.isOn; boxContainer.hidden = !isBox; }
- (void)toggleBone:(CustomSwitch *)sender { isBone = sender.isOn; skeletonContainer.hidden = !isBone; }
- (void)toggleHealth:(CustomSwitch *)sender { isHealth = sender.isOn; healthBarContainer.hidden = !isHealth; }
- (void)toggleName:(CustomSwitch *)sender { isName = sender.isOn; previewNameLabel.hidden = !isName; }
- (void)toggleDist:(CustomSwitch *)sender { isDis = sender.isOn; previewDistLabel.hidden = !isDis; }
- (void)togglePlayerCount:(CustomSwitch *)sender { isPlayerCount = sender.isOn; }
- (void)toggleAimbot:(CustomSwitch *)sender { isAimbot = sender.isOn; }
- (void)toggleAimOnlyFire:(CustomSwitch *)sender { aimOnlyFire = sender.isOn; }

- (void)boneChanged:(UISegmentedControl *)sender { aimBone = (int)sender.selectedSegmentIndex; }

- (void)fovChanged:(UISlider *)sender {
    aimFov = sender.value;
    fovValueLabel.text = [NSString stringWithFormat:@"%.0f", aimFov];
}
- (void)distChanged:(UISlider *)sender {
    aimDistance = sender.value;
    distValueLabel.text = [NSString stringWithFormat:@"%.0f", aimDistance];
}
- (void)speedChanged:(UISlider *)sender {
    aimSpeed = sender.value;
    speedValueLabel.text = [NSString stringWithFormat:@"%.2f", aimSpeed];
}

- (void)addLineRect:(CGRect)frame color:(UIColor *)color parent:(UIView *)parent {
    UIView *v = [[UIView alloc] initWithFrame:frame];
    v.backgroundColor = color;
    [parent addSubview:v];
}
- (void)addLineFrom:(CGPoint)p1 to:(CGPoint)p2 color:(UIColor *)color width:(CGFloat)width inView:(UIView *)view {
    UIView *line = [[UIView alloc] init];
    line.backgroundColor = color;
    CGFloat dx = p2.x - p1.x;
    CGFloat dy = p2.y - p1.y;
    CGFloat len = sqrt(dx*dx + dy*dy);
    CGFloat angle = atan2(dy, dx);
    line.frame = CGRectMake(p1.x, p1.y, len, width);
    line.layer.anchorPoint = CGPointMake(0, 0.5);
    line.center = p1;
    line.transform = CGAffineTransformMakeRotation(angle);
    [view addSubview:line];
}

- (void)sliderValueChanged:(UISlider *)sender {
    previewScale = sender.value;
    [UIView animateWithDuration:0.1 animations:^{
        self->previewContentContainer.transform = CGAffineTransformMakeScale(self->previewScale, self->previewScale);
    }];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    if (self.superview) self.frame = self.superview.bounds;
    CGRect screenBounds = self.bounds;
    CGPoint btnCenter = floatingButton.center;
    CGFloat halfW = floatingButton.bounds.size.width / 2;
    CGFloat halfH = floatingButton.bounds.size.height / 2;
    if (btnCenter.x < halfW) btnCenter.x = halfW;
    if (btnCenter.x > screenBounds.size.width - halfW) btnCenter.x = screenBounds.size.width - halfW;
    if (btnCenter.y < halfH) btnCenter.y = halfH;
    if (btnCenter.y > screenBounds.size.height - halfH) btnCenter.y = screenBounds.size.height - halfH;
    floatingButton.center = btnCenter;
}

- (void)showMenu {
    menuContainer.hidden = NO;
    floatingButton.hidden = YES;
    menuContainer.transform = CGAffineTransformMakeScale(0.1, 0.1);
    [self centerMenu];
    [UIView animateWithDuration:0.3 animations:^{
        self->menuContainer.transform = CGAffineTransformIdentity;
    }];
    [self updatePreviewVisibility];
}

- (void)hideMenu {
    [UIView animateWithDuration:0.3 animations:^{
        self->menuContainer.transform = CGAffineTransformMakeScale(0.1, 0.1);
    } completion:^(BOOL finished) {
        self->menuContainer.hidden = YES;
        self->floatingButton.hidden = NO;
        self->menuContainer.transform = CGAffineTransformIdentity;
    }];
}

- (void)centerMenu {
    menuContainer.center = CGPointMake(self.bounds.size.width / 2, self.bounds.size.height / 2);
}
- (void)handlePan:(UIPanGestureRecognizer *)gesture {
    CGPoint touchPoint = [gesture locationInView:self];
    if (gesture.state == UIGestureRecognizerStateBegan) {
        _initialTouchPoint = touchPoint;
    } else if (gesture.state == UIGestureRecognizerStateChanged) {
        CGFloat deltaX = touchPoint.x - _initialTouchPoint.x;
        CGFloat deltaY = touchPoint.y - _initialTouchPoint.y;
        UIView *viewToMove = (gesture.view == floatingButton) ? floatingButton : menuContainer;
        viewToMove.center = CGPointMake(viewToMove.center.x + deltaX, viewToMove.center.y + deltaY);
        _initialTouchPoint = touchPoint;
    }
}

- (void)SetUpBase {
    // KHONG dung dispatch_once: neu lan dau chua lay duoc base (game chua san sang)
    // thi phai thu lai o cac frame sau, khong cache so 0 vinh vien.
    if (Moudule_Base == (uint64_t)-1 || Moudule_Base == 0) {
        Moudule_Base = (uint64_t)GetGameModule_Base((char*)"freefireth");
        ESPLog("SetUpBase: Moudule_Base = 0x%llx", Moudule_Base);
    }
}

- (void)updateFrame {
    if (!self.window) return;
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    for (CALayer *layer in self.drawingLayers) {
        [layer removeFromSuperlayer];
    }
    [self.drawingLayers removeAllObjects];
    
    // Draw FOV Circle + hien thi so (FOV / khoang cach aim)
    if (isAimbot) {
        float screenX = self.bounds.size.width / 2;
        float screenY = self.bounds.size.height / 2;
        
        CAShapeLayer *circleLayer = [CAShapeLayer layer];
        UIBezierPath *path = [UIBezierPath bezierPathWithArcCenter:CGPointMake(screenX, screenY) radius:aimFov startAngle:0 endAngle:2 * M_PI clockwise:YES];
        circleLayer.path = path.CGPath;
        circleLayer.fillColor = [UIColor clearColor].CGColor;
        circleLayer.strokeColor = [UIColor colorWithRed:1.0 green:1.0 blue:1.0 alpha:0.5].CGColor;
        circleLayer.lineWidth = 1.0;
        [self.drawingLayers addObject:circleLayer];
    }
    
    [self renderESPToLayers:self.drawingLayers];
    
    for (CALayer *layer in self.drawingLayers) {
        [self.layer addSublayer:layer];
    }
    [CATransaction commit];
    [self setNeedsDisplay];
}

- (void)dealloc {
    [self.displayLink invalidate];
    self.displayLink = nil;
}

static inline void DrawBoneLine(
    NSMutableArray<CALayer *> *layers,
    CGPoint p1,
    CGPoint p2,
    UIColor *color,
    CGFloat width
) {
    CGFloat dx = p2.x - p1.x;
    CGFloat dy = p2.y - p1.y;
    CGFloat len = sqrt(dx*dx + dy*dy);
    if (len < 2.0f) return;

    CALayer *line = [CALayer layer];
    line.backgroundColor = color.CGColor;
    line.bounds = CGRectMake(0, 0, len, width);
    line.position = p1;
    line.anchorPoint = CGPointMake(0, 0.5);
    line.transform = CATransform3DMakeRotation(atan2(dy, dx), 0, 0, 1);
    [layers addObject:line];
}


Quaternion GetRotationToLocation(Vector3 targetLocation, float y_bias, Vector3 myLoc){
    return Quaternion::LookRotation((targetLocation + Vector3(0, y_bias, 0)) - myLoc, Vector3(0, 1, 0));
}

// Lay toa do bone can aim theo lua chon (0=Head, 1=Neck, 2=Hip)
static Vector3 getAimBonePos(uint64_t player, int bone) {
    if (bone == 2) {
        return getPositionExt(getHip(player));
    }
    Vector3 head = getPositionExt(getHead(player));
    if (bone == 1) {
        // Neck ~ diem giua head va hip, thien ve head
        Vector3 hip = getPositionExt(getHip(player));
        return head * 0.8f + hip * 0.2f;
    }
    return head; // Head
}

// Ghi aim rotation, lam muot theo speed (Slerp tu huong hien tai -> huong dich).
void set_aim(uint64_t player, Quaternion rotation, float speed) {
    if (!isVaildPtr(player)) return;

    if (speed >= 0.999f) {
        WriteAddr<Quaternion>(player + Off::AimRotation, rotation);
        return;
    }
    if (speed < 0.02f) speed = 0.02f;

    Quaternion current = ReadAddr<Quaternion>(player + Off::AimRotation);
    float mag = current.x*current.x + current.y*current.y + current.z*current.z + current.w*current.w;
    if (!isfinite(mag) || mag < 0.001f) {
        WriteAddr<Quaternion>(player + Off::AimRotation, rotation);
        return;
    }
    Quaternion smooth = Quaternion::Slerp(current, rotation, speed);
    WriteAddr<Quaternion>(player + Off::AimRotation, smooth);
}

bool get_IsFiring(uint64_t player) {
    if (!isVaildPtr(player)) return false;
    bool fireState = ReadAddr<bool>(player + Off::IsFiring);
    return fireState;
}


bool get_IsVisible(uint64_t player) {
    if (!isVaildPtr(player)) return false;
    
    int visibleFlags = ReadAddr<int>(player + Off::IsVisible);
    return (visibleFlags & 0x1) == 1;
}


// Them pawn vao mang neu hop le VA chua ton tai (tranh box trung khi player
// xuat hien o nhieu List/Dictionary khac nhau).
static inline void AddPawnUnique(uint64_t *pawns, int *pawnCount, int maxCount, uint64_t po) {
    if (!isVaildPtr(po)) return;
    for (int i = 0; i < *pawnCount; i++) {
        if (pawns[i] == po) return;
    }
    if (*pawnCount < maxCount) pawns[(*pawnCount)++] = po;
}

- (void)renderESPToLayers:(NSMutableArray<CALayer *> *)layers {
    if (Moudule_Base == (uint64_t)-1 || Moudule_Base == 0) {
        // Thu lay lai base moi frame (game co the vua moi mo)
        [self SetUpBase];
    }
    if (Moudule_Base == (uint64_t)-1 || Moudule_Base == 0) {
        snprintf(g_debugStatus, sizeof(g_debugStatus), "LOI base: %s", g_baseErr[0] ? g_baseErr : "chua ro (xem esp_log.txt)");
        return;
    }

    uint64_t matchGame = getMatchGame(Moudule_Base);
    if (!isVaildPtr(matchGame)) {
        snprintf(g_debugStatus, sizeof(g_debugStatus), "LOI matchGame: %s", g_matchDiag[0] ? g_matchDiag : "(chua ro)");
        return;
    }
    
    uint64_t camera = CameraMain(matchGame);
    if (!isVaildPtr(camera)) {
        snprintf(g_debugStatus, sizeof(g_debugStatus), "LOI: camera=0x%llx (offset CameraManager sai)", camera);
        return;
    }

    uint64_t match = getMatch(matchGame);
    if (!isVaildPtr(match)) {
        snprintf(g_debugStatus, sizeof(g_debugStatus), "LOI: match=0x%llx (offset 0x90 sai)", match);
        return;
    }

    uint64_t myPawnObject = getLocalPlayer(match);
    if (!isVaildPtr(myPawnObject)) {
        snprintf(g_debugStatus, sizeof(g_debugStatus), "LOI: myPawn=0x%llx (offset 0xD8 sai / chua vao tran)", myPawnObject);
        return;
    }
    
    uint64_t mainCameraTransform = ReadAddr<uint64_t>(myPawnObject + Off::Pawn_MainCameraTransform);
    Vector3 myLocation = getPositionExt(mainCameraTransform);
    
    ESPLog("render: myPawn=0x%llx camTransform=0x%llx myLoc=(%.1f,%.1f,%.1f)", myPawnObject, mainCameraTransform, myLocation.x, myLocation.y, myLocation.z);

    // === Thu thap con tro Player tu List<Player> VA Dictionary<K,Player> ===
    // 3 List (0x158/0x160/0x578) thuong RONG (size=0, items tro ve empty array
    // dung chung). Player song nam trong cac Dictionary<K,Player> cua match.
    static const int kPawnsMax = 256;
    uint64_t pawns[256];
    int pawnCount = 0;

    // Nguon 1: List<Player>. Layout: _items(Player[])=+0x10, _size(int)=+0x18, data=+0x20.
    for (int li = 0; li < Off::MatchListCands_N; ++li) {
        uint64_t lp = ReadAddr<uint64_t>(match + Off::MatchListCands[li]);
        if (!isVaildPtr(lp)) { ESPLog("render: list off=0x%llx ptr=0x%llx INVALID", (unsigned long long)Off::MatchListCands[li], lp); continue; }
        int sz = ReadAddr<int>(lp + Off::List_Size);
        uint64_t items = ReadAddr<uint64_t>(lp + Off::List_Items);
        ESPLog("render: list off=0x%llx ptr=0x%llx size=%d items=0x%llx", (unsigned long long)Off::MatchListCands[li], lp, sz, items);
        if (sz > 0 && sz <= 100 && isVaildPtr(items)) {
            for (int i = 0; i < sz && pawnCount < kPawnsMax; i++) {
                uint64_t po = ReadAddr<uint64_t>(items + Off::Array_DataStart + 8 * i);
                AddPawnUnique(pawns, &pawnCount, kPawnsMax, po);
            }
        }
    }

    // Nguon 2: Dictionary<K,Player>. Layout il2cpp: entries(Entry[])=+0x18, count(int)=+0x20.
    // Entry = { int hash; int next; TKey key; TValue value; }, data mang entries bat dau +0x20.
    // Key BHGGAEEHJCO (0x18 byte): value @ entry+0x20, stride 0x28.
    // Key byte (0x148):            value @ entry+0x10, stride 0x18.
    struct DictCand { uint64_t off; uint64_t valOff; uint64_t stride; };
    DictCand kDictCands[Off::MatchDictObjCands_N + Off::MatchDictByteCands_N];
    int nDict = 0;
    for (int k = 0; k < Off::MatchDictObjCands_N; ++k)
        kDictCands[nDict++] = { Off::MatchDictObjCands[k], Off::DictKeyObj_ValOff, Off::DictKeyObj_Stride };
    for (int k = 0; k < Off::MatchDictByteCands_N; ++k)
        kDictCands[nDict++] = { Off::MatchDictByteCands[k], Off::DictKeyByte_ValOff, Off::DictKeyByte_Stride };
    for (int di = 0; di < nDict; ++di) {
        uint64_t dp = ReadAddr<uint64_t>(match + kDictCands[di].off);
        if (!isVaildPtr(dp)) { ESPLog("render: dict off=0x%llx ptr=0x%llx INVALID", (unsigned long long)kDictCands[di].off, dp); continue; }
        int cnt = ReadAddr<int>(dp + Off::Dict_Count);
        uint64_t entries = ReadAddr<uint64_t>(dp + Off::Dict_Entries);
        ESPLog("render: dict off=0x%llx ptr=0x%llx count=%d entries=0x%llx", (unsigned long long)kDictCands[di].off, dp, cnt, entries);
        if (cnt > 0 && cnt <= 100 && isVaildPtr(entries)) {
            for (int i = 0; i < cnt && pawnCount < kPawnsMax; i++) {
                uint64_t entry = entries + Off::Array_DataStart + (uint64_t)i * kDictCands[di].stride;
                uint64_t po = ReadAddr<uint64_t>(entry + kDictCands[di].valOff);
                AddPawnUnique(pawns, &pawnCount, kPawnsMax, po);
            }
        }
    }

    ESPLog("render: tong pawnCount=%d", pawnCount);
    if (pawnCount <= 0) {
        snprintf(g_debugStatus, sizeof(g_debugStatus), "LOI: khong tim thay player (list+dict rong)");
        return;
    }
    int coutValue = pawnCount;
    
    float *matrix = GetViewMatrix(camera);
    if (matrix) {
        ESPLog("render: VM row0=[%.3f %.3f %.3f %.3f]", matrix[0], matrix[1], matrix[2], matrix[3]);
        ESPLog("render: VM row1=[%.3f %.3f %.3f %.3f]", matrix[4], matrix[5], matrix[6], matrix[7]);
        ESPLog("render: VM row2=[%.3f %.3f %.3f %.3f]", matrix[8], matrix[9], matrix[10], matrix[11]);
        ESPLog("render: VM row3=[%.3f %.3f %.3f %.3f]", matrix[12], matrix[13], matrix[14], matrix[15]);
    } else {
        ESPLog("render: viewMatrix=NULL");
    }
    if (matrix == NULL) {
        snprintf(g_debugStatus, sizeof(g_debugStatus), "LOI: view matrix NULL");
        return;
    }

    // === TU DONG DO + AP DUNG OFFSET VIEW MATRIX ===
    // Van de: doc tu offset 0xD8 ra ma tran rac (row0=[0 0 0 0]) -> W2S sai vi tri.
    // Giai phap: quet cac offset tren camera & v1, cham diem theo so dich chieu
    // dung + do phan tan (loai ma tran rac chum ve 1 diem). Tim duoc thi LUU lai
    // va AP DUNG ngay cho matrix (khong can build lai). Chay lai moi frame den khi
    // tim duoc (can >=3 dich de dang tin cay).
    static bool     s_vmFound = false;
    static int      s_vmSrc   = 0;   // 0 = camera, 1 = v1
    static uint64_t s_vmOff   = 0;
    static int      s_vmMode  = 0;   // 0 = row, 1 = transpose
    {
        float W = self.bounds.size.width, H = self.bounds.size.height;
        if (!s_vmFound && W > 300 && pawnCount > 0) {
            Vector3 heads[32];
            int nHeads = 0;
            for (int i = 0; i < pawnCount && nHeads < 32; i++) {
                if (!isVaildPtr(pawns[i])) continue;
                if (isLocalTeamMate(myPawnObject, pawns[i])) continue; // bo dong doi
                Vector3 hp = getPositionExt(getHead(pawns[i]));
                if (!isfinite(hp.x) || !isfinite(hp.y) || !isfinite(hp.z)) continue;
                heads[nHeads++] = hp;
            }

            if (nHeads >= 3) {
                uint64_t v1 = ReadAddr<uint64_t>(camera + Off::Camera_ViewMatrixPtr);
                uint64_t srcs[2] = { camera, v1 };
                const char* srcName[2] = { "camera", "v1" };

                int      bScore = 0;
                float    bSpread = 0.0f;
                uint64_t bOff = 0; int bSrc = 0, bMode = 0;

                for (int sIdx = 0; sIdx < 2; sIdx++) {
                    uint64_t base = srcs[sIdx];
                    if (!isVaildPtr(base)) continue;
                    for (uint64_t off = 0x0; off <= 0x600; off += 0x4) {
                        float m[16];
                        bool ok = true;
                        for (int k = 0; k < 16; k++) {
                            m[k] = ReadAddr<float>(base + off + k * 0x4);
                            if (!isfinite(m[k]) || fabsf(m[k]) > 1e6f) { ok = false; break; }
                        }
                        if (!ok) continue;

                        for (int mode = 0; mode < 2; mode++) {
                            int score = 0;
                            float minx=1e9f,maxx=-1e9f,miny=1e9f,maxy=-1e9f;
                            for (int h = 0; h < nHeads; h++) {
                                Vector3 p = heads[h];
                                float w, xn, yn;
                                if (mode == 0) {
                                    w  = m[3]*p.x + m[7]*p.y + m[11]*p.z + m[15];
                                    xn = m[0]*p.x + m[4]*p.y + m[8]*p.z + m[12];
                                    yn = m[1]*p.x + m[5]*p.y + m[9]*p.z + m[13];
                                } else {
                                    w  = m[12]*p.x + m[13]*p.y + m[14]*p.z + m[15];
                                    xn = m[0]*p.x + m[1]*p.y + m[2]*p.z + m[3];
                                    yn = m[4]*p.x + m[5]*p.y + m[6]*p.z + m[7];
                                }
                                if (w < 1.0f || w > 100000.0f) continue;
                                float sx = W/2 + xn/w*(W/2);
                                float sy = H/2 - yn/w*(H/2);
                                if (sx >= 0 && sx <= W && sy >= 0 && sy <= H) {
                                    score++;
                                    if (sx<minx)minx=sx; if (sx>maxx)maxx=sx;
                                    if (sy<miny)miny=sy; if (sy>maxy)maxy=sy;
                                }
                            }
                            // do phan tan cua cac diem chieu duoc
                            float spread = 0.0f;
                            if (score >= 2) spread = (maxx-minx) + (maxy-miny);
                            // Yeu cau: chieu dung TAT CA dich + phan tan du lon
                            // (ma tran rac chum ve tam -> spread ~0 -> bi loai).
                            bool good = (score == nHeads) && (spread > (W*0.15f));
                            if (good && (score > bScore || (score==bScore && spread>bSpread))) {
                                bScore = score; bSpread = spread;
                                bOff = off; bSrc = sIdx; bMode = mode;
                            }
                        }
                    }
                }

                if (bScore >= 3) {
                    s_vmFound = true; s_vmSrc = bSrc; s_vmOff = bOff; s_vmMode = bMode;
                    ESPLog("MTXSCAN OK: %s+0x%llx mode=%s score=%d/%d spread=%.0f -> DA AP DUNG",
                           srcName[bSrc], (unsigned long long)bOff,
                           bMode==0?"row":"transpose", bScore, nHeads, bSpread);
                } else {
                    ESPLog("MTXSCAN: chua tim duoc (nHeads=%d, bScore=%d). Thu lai frame sau.", nHeads, bScore);
                }
            }
        }

        // AP DUNG offset da tim: nap lai 16 float tu dung nguon+offset vao matrix.
        // Neu mode=transpose thi chuyen ve layout row de WorldToScreen dung nhu cu.
        if (s_vmFound) {
            uint64_t base = (s_vmSrc == 0) ? camera : ReadAddr<uint64_t>(camera + Off::Camera_ViewMatrixPtr);
            if (isVaildPtr(base) || s_vmSrc == 0) {
                float m[16];
                for (int k = 0; k < 16; k++) m[k] = ReadAddr<float>(base + s_vmOff + k * 0x4);
                if (s_vmMode == 0) {
                    for (int k = 0; k < 16; k++) matrix[k] = m[k];
                } else {
                    // transpose -> row
                    matrix[0]=m[0];  matrix[1]=m[4];  matrix[2]=m[8];   matrix[3]=m[12];
                    matrix[4]=m[1];  matrix[5]=m[5];  matrix[6]=m[9];   matrix[7]=m[13];
                    matrix[8]=m[2];  matrix[9]=m[6];  matrix[10]=m[10]; matrix[11]=m[14];
                    matrix[12]=m[3]; matrix[13]=m[7]; matrix[14]=m[11]; matrix[15]=m[15];
                }
            }
        }
    }
    
    g_playerCount = coutValue;
    snprintf(g_debugStatus, sizeof(g_debugStatus), "OK: doc memory thanh cong! mBase=0x%llx", Moudule_Base);
    
    float viewWidth = self.bounds.size.width;
    float viewHeight = self.bounds.size.height;
    CGPoint screenCenter = CGPointMake(viewWidth / 2, viewHeight / 2);

    // So player (dich con song) xung quanh
    int playersAround = 0;

    // Variables for Aimbot
    uint64_t bestTarget = 0;
    float bestScore = 1e18f;   // score cang nho cang tot (px toi tam FOV, hoac m)
    bool isVis = false;
    bool isFire = get_IsFiring(myPawnObject);

    // Ma tran view co hop le khong? (neu hong thi W2S/FOV filter khong dung duoc,
    // fallback chon dich gan nhat theo khoang cach 3D).
    bool matrixValid = (fabsf(matrix[0]) > 1e-6f || fabsf(matrix[1]) > 1e-6f || fabsf(matrix[2]) > 1e-6f);

    bool w2sLoggedThisFrame = false;
    for (int i = 0; i < coutValue; i++) {
        uint64_t PawnObject = pawns[i];
        if (!isVaildPtr(PawnObject)) continue;

        bool isLocalTeam = isLocalTeamMate(myPawnObject, PawnObject);
        if (isLocalTeam) continue;
        
        int CurHP = get_CurHP(PawnObject);
        if (CurHP <= 0) continue; 

        playersAround++; // dich con song hop le -> tinh vao so xung quanh

        Vector3 HeadPos     = getPositionExt(getHead(PawnObject));

        float dis = Vector3::Distance(myLocation, HeadPos);
        if (dis > 400.0f) continue;

        // === Chon target aimbot ===
        if (isAimbot && dis <= aimDistance) {
            if (matrixValid) {
                // Ma tran OK -> chon dich gan tam ngam nhat trong vong FOV.
                Vector3 aimW = getAimBonePos(PawnObject, aimBone);
                Vector3 w2sAim = WorldToScreen(aimW, matrix, viewWidth, viewHeight);
                float deltaX = w2sAim.x - screenCenter.x;
                float deltaY = w2sAim.y - screenCenter.y;
                float distanceFromCenter = sqrtf(deltaX * deltaX + deltaY * deltaY);
                if (distanceFromCenter <= aimFov && distanceFromCenter < bestScore) {
                    bestScore = distanceFromCenter;
                    isVis = get_IsVisible(PawnObject);
                    bestTarget = PawnObject;
                }
            } else {
                // Ma tran hong -> fallback: chon dich gan nhat theo khoang cach 3D.
                if (dis < bestScore) {
                    bestScore = dis;
                    isVis = get_IsVisible(PawnObject);
                    bestTarget = PawnObject;
                }
            }
        }

        if (dis > 220.0f) continue; 

        Vector3 RightToePos = getPositionExt(getRightToeNode(PawnObject));
        Vector3 HipPos      = getPositionExt(getHip(PawnObject));
        Vector3 L_Ankle     = getPositionExt(getLeftAnkle(PawnObject));
        Vector3 R_Ankle     = getPositionExt(getRightAnkle(PawnObject));
        
        Vector3 L_Shoulder  = getPositionExt(getLeftShoulder(PawnObject));
        Vector3 R_Shoulder  = getPositionExt(getRightShoulder(PawnObject));
        Vector3 L_Elbow     = getPositionExt(getLeftElbow(PawnObject));
        Vector3 R_Elbow     = getPositionExt(getRightElbow(PawnObject));
        Vector3 L_Hand      = getPositionExt(getLeftHand(PawnObject));
        Vector3 R_Hand      = getPositionExt(getRightHand(PawnObject));

        Vector3 HeadTop     = HeadPos; HeadTop.y += 0.2f;
        Vector3 w2sHead     = WorldToScreen(HeadTop, matrix, viewWidth, viewHeight);
        Vector3 w2sToe      = WorldToScreen(RightToePos, matrix, viewWidth, viewHeight);
        if (!w2sLoggedThisFrame) {
            w2sLoggedThisFrame = true;
            ESPLog("render: W2S dich headWorld=(%.2f,%.2f,%.2f) -> screen=(%.1f,%.1f) toe=(%.1f,%.1f) view=(%.0fx%.0f) dis=%.1f myLoc=(%.2f,%.2f,%.2f)",
                   HeadPos.x, HeadPos.y, HeadPos.z, w2sHead.x, w2sHead.y, w2sToe.x, w2sToe.y, viewWidth, viewHeight, dis,
                   myLocation.x, myLocation.y, myLocation.z);
        }

        Vector3 wHead       = WorldToScreen(HeadPos, matrix, viewWidth, viewHeight);
        Vector3 wHip        = WorldToScreen(HipPos, matrix, viewWidth, viewHeight);

        if (isBone) {
             Vector3 wLS = WorldToScreen(L_Shoulder, matrix, viewWidth, viewHeight);
             Vector3 wRS = WorldToScreen(R_Shoulder, matrix, viewWidth, viewHeight);
             Vector3 wLE = WorldToScreen(L_Elbow, matrix, viewWidth, viewHeight);
             Vector3 wRE = WorldToScreen(R_Elbow, matrix, viewWidth, viewHeight);
             Vector3 wLH = WorldToScreen(L_Hand, matrix, viewWidth, viewHeight);
             Vector3 wRH = WorldToScreen(R_Hand, matrix, viewWidth, viewHeight);
             Vector3 wLA = WorldToScreen(L_Ankle, matrix, viewWidth, viewHeight);
             Vector3 wRA = WorldToScreen(R_Ankle, matrix, viewWidth, viewHeight);

            UIColor *boneColor = [UIColor whiteColor];
            CGFloat boneWidth = 1.0f;

            DrawBoneLine(layers, CGPointMake(wHead.x, wHead.y), CGPointMake(wHip.x, wHip.y), boneColor, boneWidth);
            DrawBoneLine(layers, CGPointMake(wLS.x, wLS.y), CGPointMake(wRS.x, wRS.y), boneColor, boneWidth);
            DrawBoneLine(layers, CGPointMake(wLS.x, wLS.y), CGPointMake(wLE.x, wLE.y), boneColor, boneWidth);
            DrawBoneLine(layers, CGPointMake(wLE.x, wLE.y), CGPointMake(wLH.x, wLH.y), boneColor, boneWidth);
            DrawBoneLine(layers, CGPointMake(wRS.x, wRS.y), CGPointMake(wRE.x, wRE.y), boneColor, boneWidth);
            DrawBoneLine(layers, CGPointMake(wRE.x, wRE.y), CGPointMake(wRH.x, wRH.y), boneColor, boneWidth);
            DrawBoneLine(layers, CGPointMake(wHip.x, wHip.y), CGPointMake(wLA.x, wLA.y), boneColor, boneWidth);
            DrawBoneLine(layers, CGPointMake(wHip.x, wHip.y), CGPointMake(wRA.x, wRA.y), boneColor, boneWidth);
        }

        float boxHeight = abs(w2sHead.y - w2sToe.y);
        float boxWidth = boxHeight * 0.5f;
        float x = w2sHead.x - boxWidth * 0.5f;
        float y = w2sHead.y;
        
        if (isBox) {
            CALayer *boxLayer = [CALayer layer];
            boxLayer.frame = CGRectMake(x, y, boxWidth, boxHeight);
            boxLayer.borderColor = [UIColor redColor].CGColor;
            boxLayer.borderWidth = 1.0;
            boxLayer.cornerRadius = 3.0;
            [layers addObject:boxLayer];
        }
        
        if (isName) {
            NSString *Name = GetNickName(PawnObject);
            if (Name.length > 0) {
                CATextLayer *nameLayer = [CATextLayer layer];
                nameLayer.string = Name;
                nameLayer.fontSize = 10;
                nameLayer.frame = CGRectMake(x - 20, y - 15, boxWidth + 40, 15);
                nameLayer.alignmentMode = kCAAlignmentCenter;
                nameLayer.foregroundColor = [UIColor greenColor].CGColor;
                [layers addObject:nameLayer];
            }
        }
        
        if (isHealth) {
            int MaxHP = get_MaxHP(PawnObject);
            if (MaxHP > 0) {
                float hpRatio = (float)CurHP / (float)MaxHP;
                if (hpRatio < 0) hpRatio = 0; if (hpRatio > 1) hpRatio = 1;
                
                float barWidth = 4.0;
                float barHeight = boxHeight;
                float filledHeight = barHeight * hpRatio;
                
                CALayer *bgBar = [CALayer layer];
                bgBar.frame = CGRectMake(x - barWidth - 2, y, barWidth, barHeight);
                bgBar.backgroundColor = [UIColor redColor].CGColor;
                [layers addObject:bgBar];
                
                CALayer *hpBar = [CALayer layer];
                hpBar.frame = CGRectMake(x - barWidth - 2, y + (barHeight - filledHeight), barWidth, filledHeight);
                hpBar.backgroundColor = [UIColor greenColor].CGColor;
                [layers addObject:hpBar];
            }
        }
        
        if (isDis) {
            CATextLayer *distLayer = [CATextLayer layer];
            distLayer.string = [NSString stringWithFormat:@"[%.0fm]", dis];
            distLayer.fontSize = 9;
            distLayer.frame = CGRectMake(x - 10, y + boxHeight + 2, boxWidth + 20, 12);
            distLayer.alignmentMode = kCAAlignmentCenter;
            distLayer.foregroundColor = [UIColor whiteColor].CGColor;
            [layers addObject:distLayer];
        }
    }

    // Hien so player song xung quanh o GIUA-TREN man hinh (gan vien tren)
    g_playerCount = playersAround;
    if (isPlayerCount) {
        CATextLayer *cntLayer = [CATextLayer layer];
        cntLayer.string = [NSString stringWithFormat:@"%d", playersAround];
        cntLayer.fontSize = 24;
        cntLayer.alignmentMode = kCAAlignmentCenter;
        cntLayer.frame = CGRectMake(viewWidth / 2 - 50, 40, 100, 30);
        cntLayer.foregroundColor = [UIColor whiteColor].CGColor;
        cntLayer.contentsScale = [UIScreen mainScreen].scale;
        [layers addObject:cntLayer];
    }

    if (isAimbot) {
        ESPLog("AIM: target=0x%llx onlyFire=%d isFire=%d bone=%d speed=%.2f matrixValid=%d",
               (unsigned long long)bestTarget, aimOnlyFire, isFire, aimBone, aimSpeed, matrixValid);
    }
    if (isAimbot && isVaildPtr(bestTarget) && (!aimOnlyFire || isFire)) {
        Vector3 aimTarget = getAimBonePos(bestTarget, aimBone);

        // Head can chinh len 1 chut cho khop tam; Neck/Hip ban thang.
        float yBias = (aimBone == 0) ? 0.1f : 0.0f;
        Quaternion targetLook = GetRotationToLocation(aimTarget, yBias, myLocation);

        set_aim(myPawnObject, targetLook, aimSpeed);
        ESPLog("AIM: da ghi rotation (%.3f,%.3f,%.3f,%.3f) toi player 0x%llx",
               targetLook.x, targetLook.y, targetLook.z, targetLook.w, (unsigned long long)myPawnObject);
    }
}

@end
