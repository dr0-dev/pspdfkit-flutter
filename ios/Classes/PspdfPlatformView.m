//
//  Copyright © 2018-2022 PSPDFKit GmbH. All rights reserved.
//
//  THIS SOURCE CODE AND ANY ACCOMPANYING DOCUMENTATION ARE PROTECTED BY INTERNATIONAL COPYRIGHT LAW
//  AND MAY NOT BE RESOLD OR REDISTRIBUTED. USAGE IS BOUND TO THE PSPDFKIT LICENSE AGREEMENT.
//  UNAUTHORIZED REPRODUCTION OR DISTRIBUTION IS SUBJECT TO CIVIL AND CRIMINAL PENALTIES.
//  This notice may not be removed from this file.
//
#import "PspdfPlatformView.h"
#import "PspdfkitFlutterHelper.h"
#import "PspdfkitFlutterConverter.h"

@import PSPDFKit;
@import PSPDFKitUI;

@interface PspdfPlatformView() <PSPDFViewControllerDelegate>

@property int64_t platformViewId;
@property (nonatomic) FlutterMethodChannel *channel;
@property (nonatomic) FlutterEventChannel *eventchannel;
@property (nonatomic, weak) UIViewController *flutterViewController;
@property (nonatomic) PSPDFViewController *pdfViewController;
@property (nonatomic) PSPDFNavigationController *navigationController;
@end

@implementation PspdfPlatformView

- (nonnull UIView *)view {
    return self.navigationController.view ?: [UIView new];
}

- (instancetype)initWithFrame:(CGRect)frame viewIdentifier:(int64_t)viewId arguments:(id)args messenger:(NSObject<FlutterBinaryMessenger> *)messenger {
    NSString *name = [NSString stringWithFormat:@"com.pspdfkit.widget.%lld",viewId];
    _platformViewId = viewId;
    _channel = [FlutterMethodChannel methodChannelWithName:name binaryMessenger:messenger];

   /* let eventChannel = FlutterEventChannel(name: "your.channel.id", binaryMessenger: messenger!)
            eventChannel.setStreamHandler(SwiftStreamHandler())*/
    
    _eventchannel = [FlutterEventChannel eventChannelWithName:@"com.pspdfkit.widget/enter_annotation" binaryMessenger:messenger];
    //[_eventchannel setStreamHandler:<#(NSObject<FlutterStreamHandler> * _Nullable)#>
    
    _navigationController = [PSPDFNavigationController new];
    _navigationController.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;

    // View controller containment
    _flutterViewController = [UIApplication sharedApplication].delegate.window.rootViewController;
    if (_flutterViewController == nil) {
        NSLog(@"Warning: FlutterViewController is nil. This may lead to view container containment problems with PSPDFViewController since we no longer receive UIKit lifecycle events.");
    }
    
    
    [_flutterViewController addChildViewController:_navigationController];
    [_navigationController didMoveToParentViewController:_flutterViewController];

    NSString *documentPath = args[@"document"];
    if (documentPath != nil && [documentPath  isKindOfClass:[NSString class]] && [documentPath length] > 0) {
        NSDictionary *configurationDictionary = [PspdfkitFlutterConverter processConfigurationOptionsDictionaryForPrefix:args[@"configuration"]];

        PSPDFDocument *document = [PspdfkitFlutterHelper documentFromPath:documentPath];

        [PspdfkitFlutterHelper unlockWithPasswordIfNeeded:document dictionary:configurationDictionary];

        BOOL isImageDocument = [PspdfkitFlutterHelper isImageDocument:documentPath];
        PSPDFConfiguration *configuration = [PspdfkitFlutterConverter configuration:configurationDictionary isImageDocument:isImageDocument];

        _pdfViewController = [[PSPDFViewController alloc] initWithDocument:document configuration:configuration];
        _pdfViewController.appearanceModeManager.appearanceMode = [PspdfkitFlutterConverter appearanceMode:configurationDictionary];
        _pdfViewController.pageIndex = [PspdfkitFlutterConverter pageIndex:configurationDictionary];

        _pdfViewController.documentInfoCoordinator.availableControllerOptions = @[PSPDFDocumentInfoOptionOutline, PSPDFDocumentInfoOptionAnnotations];

        
       

        
    
        
        _pdfViewController.delegate = self;

            

        PSPDFAnnotationToolbarConfiguration *toolbarConfiguration = [[PSPDFAnnotationToolbarConfiguration alloc] initWithAnnotationGroups:@[
            [PSPDFAnnotationGroup groupWithItems:@[
                [PSPDFAnnotationGroupItem itemWithType:PSPDFAnnotationStringHighlight],
                [PSPDFAnnotationGroupItem itemWithType:PSPDFAnnotationStringUnderline],
                [PSPDFAnnotationGroupItem itemWithType:PSPDFAnnotationStringSquiggly],
                [PSPDFAnnotationGroupItem itemWithType:PSPDFAnnotationStringStrikeOut],
                
            ]],
            [PSPDFAnnotationGroup groupWithItems:@[
                [PSPDFAnnotationGroupItem itemWithType:PSPDFAnnotationStringNote],
                [PSPDFAnnotationGroupItem itemWithType:PSPDFAnnotationStringFreeText]
            ]],
            [PSPDFAnnotationGroup groupWithItems:@[
                [PSPDFAnnotationGroupItem itemWithType:PSPDFAnnotationStringInk variant:PSPDFAnnotationVariantStringInkPen configurationBlock:[PSPDFAnnotationGroupItem inkConfigurationBlock]],
            ]],
            [PSPDFAnnotationGroup groupWithItems:@[
                [PSPDFAnnotationGroupItem itemWithType:PSPDFAnnotationStringInk variant:PSPDFAnnotationVariantStringInkHighlighter ],
            ]],
                
            [PSPDFAnnotationGroup groupWithItems:@[
                [PSPDFAnnotationGroupItem itemWithType:PSPDFAnnotationStringLine],
                [PSPDFAnnotationGroupItem itemWithType:PSPDFAnnotationStringSquare],
                [PSPDFAnnotationGroupItem itemWithType:PSPDFAnnotationStringCircle],
                [PSPDFAnnotationGroupItem itemWithType:PSPDFAnnotationStringPolygon],
                [PSPDFAnnotationGroupItem itemWithType:PSPDFAnnotationStringPolyLine],
                /*[PSPDFAnnotationGroupItem itemWithType:PSPDFAnnotationStringLine variant:PSPDFAnnotationVariantStringLineArrow configurationBlock:[PSPDFAnnotationGroupItem inkConfigurationBlock]],*/
                [PSPDFAnnotationGroupItem itemWithType:PSPDFAnnotationStringStamp]
            ]],
            /*[PSPDFAnnotationGroup groupWithItems:@[
                [PSPDFAnnotationGroupItem itemWithType:PSPDFAnnotationStringStamp]
            ]],*/
            [PSPDFAnnotationGroup groupWithItems:@[
                [PSPDFAnnotationGroupItem itemWithType:PSPDFAnnotationStringEraser]
            ]],
        ]];

        _pdfViewController.annotationToolbarController.annotationToolbar.configurations = @[toolbarConfiguration];


        if ((id)configurationDictionary != NSNull.null) {
            NSString *key;

            key = @"leftBarButtonItems";
            if (configurationDictionary[key]) {
                [PspdfkitFlutterHelper setLeftBarButtonItems:configurationDictionary[key] forViewController:_pdfViewController];
            }
            key = @"rightBarButtonItems";
            if (configurationDictionary[key]) {
                [PspdfkitFlutterHelper setRightBarButtonItems:configurationDictionary[key] forViewController:_pdfViewController];
            }
            key = @"invertColors";
            if (configurationDictionary[key]) {
                _pdfViewController.appearanceModeManager.appearanceMode = [configurationDictionary[key] boolValue] ? PSPDFAppearanceModeNight : PSPDFAppearanceModeDefault;
            }
            key = @"toolbarTitle";
            if (configurationDictionary[key]) {
                [PspdfkitFlutterHelper setToolbarTitle:configurationDictionary[key] forViewController:_pdfViewController];
            }
             if ( [configurationDictionary objectForKey:@"fullname"]!= [NSNull null]) {
                PSPDFUsernameHelper.defaultAnnotationUsername = [configurationDictionary objectForKey:@"fullname"];
                document.defaultAnnotationUsername = [configurationDictionary objectForKey:@"fullname"];
            }

            key = @"mainColor";
            if ( [configurationDictionary objectForKey:key]!= [NSNull null]) {
                
                NSString* mainColor = [configurationDictionary objectForKey:key];
                
                
                
                unsigned int c;
                if ([mainColor characterAtIndex:0] == '#') {
                    [[NSScanner scannerWithString:[mainColor substringFromIndex:1]] scanHexInt:&c];
                } else {
                    [[NSScanner scannerWithString:mainColor] scanHexInt:&c];
                }
                UIColor *mainUIColor = [UIColor colorWithRed:((c & 0xff0000) >> 16) / 255.0
                                                          green:((c & 0xff00) >> 8) / 255.0
                                                           blue:(c & 0xff) / 255.0 alpha:1.0];
                
                UINavigationBar *navBarProxy = [UINavigationBar appearanceWhenContainedInInstancesOfClasses:@[PSPDFNavigationController.class]];
                PSPDFAnnotationToolbar *annotationToolbarProxy = [PSPDFAnnotationToolbar appearance];
                
                navBarProxy.tintColor = mainUIColor;
                
                annotationToolbarProxy.tintColor = mainUIColor;
            }

            PSPDFRenderDrawBlock renderBlock = ^(CGContextRef context, PSPDFPageIndex pageIndex, CGRect cropBox, PSPDFRenderOptions *options) {
                       bool watermarkEnabled = [[configurationDictionary valueForKey:@"watermarkEnabled"] boolValue];

                           if (watermarkEnabled) {
                               NSString *text = [configurationDictionary valueForKey:@"fullname"];
                               NSString *opacity = [configurationDictionary valueForKey:@"watermarkOpacity"];
                               NSString *color = [configurationDictionary valueForKey:@"watermarkColor"];
                               NSString *fontSize = [configurationDictionary valueForKey:@"watermarkFontSize"];


                               CGContextSaveGState(context);

                               for (int i = 1; i <= 10; i++)
                               {

                                   text= [text stringByAppendingString:[NSString stringWithFormat:@"%@%@",@"   ",text]];
                               }

                               // CGContextSaveGState(context);

                               unsigned int c;
                               if ([color characterAtIndex:0] == '#') {
                                   [[NSScanner scannerWithString:[color substringFromIndex:1]] scanHexInt:&c];
                               } else {
                                   [[NSScanner scannerWithString:color] scanHexInt:&c];
                               }
                               UIColor *watermarkColor = [UIColor colorWithRed:((c & 0xff0000) >> 16) / 255.0
                                                                         green:((c & 0xff00) >> 8) / 255.0
                                                                          blue:(c & 0xff) / 255.0 alpha:1.0];


                               CGFloat watermarkColorAlpha = (CGFloat) [opacity floatValue] ;
                               NSStringDrawingContext *stringDrawingContext = [NSStringDrawingContext new];
                               stringDrawingContext.minimumScaleFactor = 0.1f;
                               //calcolo di quanta rotazione bisogna applicare per averlo diagonale alla pagina
                               CGFloat xDiff = cropBox.size.width;
                               CGFloat yDiff = cropBox.size.height;
                               CGFloat rads = atan2(yDiff, xDiff);
                               CGContextRotateCTM(context, rads);

                               NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc] init];
                               paragraphStyle.lineBreakMode = NSLineBreakByClipping;
                               cropBox.size.width = cropBox.size.width * 2;

                               [text drawWithRect:cropBox
                                          options:NSStringDrawingUsesLineFragmentOrigin
                                       attributes:@{NSFontAttributeName: [UIFont boldSystemFontOfSize:[fontSize floatValue]],
                                               NSForegroundColorAttributeName: [watermarkColor colorWithAlphaComponent:watermarkColorAlpha],
                                               NSParagraphStyleAttributeName: paragraphStyle
                                       }
                                          context:stringDrawingContext];
                               CGContextRestoreGState(context);
                           }
                       };


        if ([configurationDictionary[@"watermarkEnabled"] boolValue]) [document updateRenderOptionsForType:PSPDFRenderTypePage withBlock:^(PSPDFRenderOptions * options){
                               options.drawBlock = renderBlock;
                           }];



        }
    } else {
        _pdfViewController = [[PSPDFViewController alloc] init];
    }
    [_navigationController setViewControllers:@[_pdfViewController] animated:NO];

    self = [super init];

    __weak id weakSelf = self;
    [_channel setMethodCallHandler:^(FlutterMethodCall * _Nonnull call, FlutterResult  _Nonnull result) {
        [weakSelf handleMethodCall:call result:result];
    }];

    return self;
}

- (void)dealloc {
    [self cleanup];
}

- (UIColor*)colorFromHexString:(NSString *)color {
    unsigned int c;
    if ([color characterAtIndex:0] == '#') {
        [[NSScanner scannerWithString:[color substringFromIndex:1]] scanHexInt:&c];
    } else {
        [[NSScanner scannerWithString:color] scanHexInt:&c];
    }
    UIColor *uicolor = [UIColor colorWithRed:((c & 0xff0000) >> 16) / 255.0
                                              green:((c & 0xff00) >> 8) / 255.0
                                               blue:(c & 0xff) / 255.0 alpha:1.0];
    
    return uicolor;
}

 
- (void)cleanup {
    self.pdfViewController.document = nil;
    [self.pdfViewController.view removeFromSuperview];
    [self.pdfViewController removeFromParentViewController];
    [self.navigationController.navigationBar removeFromSuperview];
    [self.navigationController.view removeFromSuperview];
    [self.navigationController removeFromParentViewController];
}

- (void)handleMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result {
    [PspdfkitFlutterHelper processMethodCall:call result:result forViewController:self.pdfViewController];
}

/*- (void)viewWillLayoutSubviews {
    [super viewWillLayoutSubviews];
    
    CGRect userInterfaceFrame = _pdfViewController.view.bounds;
    userInterfaceFrame.size.height -= 300;
    
    _pdfViewController.userInterfaceView.frame =userInterfaceFrame;
}*/

# pragma mark - PSPDFViewControllerDelegate

- (void)pdfViewControllerDidDismiss:(PSPDFViewController *)pdfController {
    // Don't hold on to the view controller object after dismissal.
    [self cleanup];
}

// viewWillLayoutSubviews

@end
