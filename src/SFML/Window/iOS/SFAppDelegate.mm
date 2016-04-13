////////////////////////////////////////////////////////////
//
// SFML - Simple and Fast Multimedia Library
// Copyright (C) 2007-2015 Laurent Gomila (laurent@sfml-dev.org)
//
// This software is provided 'as-is', without any express or implied warranty.
// In no event will the authors be held liable for any damages arising from the use of this software.
//
// Permission is granted to anyone to use this software for any purpose,
// including commercial applications, and to alter it and redistribute it freely,
// subject to the following restrictions:
//
// 1. The origin of this software must not be misrepresented;
//    you must not claim that you wrote the original software.
//    If you use this software in a product, an acknowledgment
//    in the product documentation would be appreciated but is not required.
//
// 2. Altered source versions must be plainly marked as such,
//    and must not be misrepresented as being the original software.
//
// 3. This notice may not be removed or altered from any source distribution.
//
////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////
// Headers
////////////////////////////////////////////////////////////
#include <SFML/Window/iOS/SFAppDelegate.hpp>
#include <SFML/Window/iOS/SFMain.hpp>
#include <vector>


namespace
{
    // Save the global instance of the delegate
    SFAppDelegate* delegateInstance = NULL;

    // Current touches positions
    std::vector<sf::Vector2i> touchPositions;
	
	sf::Event::OrientationChangedEvent::BasicDeviceOrientation toBasicDeviceOrientation(UIDeviceOrientation orientation)
	{
		switch (orientation)
		{
			case UIDeviceOrientationFaceDown:
				return sf::Event::OrientationChangedEvent::FaceDownOrientation;
			case UIDeviceOrientationFaceUp:
				return sf::Event::OrientationChangedEvent::FaceUpOrientation;
			case UIDeviceOrientationLandscapeLeft:
				return sf::Event::OrientationChangedEvent::LandscapeLeftOrientation;
			case UIDeviceOrientationLandscapeRight:
				return sf::Event::OrientationChangedEvent::LandscapeRightOrientation;
			case UIDeviceOrientationPortrait:
				return sf::Event::OrientationChangedEvent::PortraitRightsideUpOrientation;
			case UIDeviceOrientationPortraitUpsideDown:
				return sf::Event::OrientationChangedEvent::PortraitUpsideDownOrientation;
			case UIDeviceOrientationUnknown:
			default:
				return sf::Event::OrientationChangedEvent::UnknownOrientation;
		}
	}
}


@implementation SFAppDelegate

@synthesize sfWindow;
@synthesize motionManager;
@synthesize backingScaleFactor;


////////////////////////////////////////////////////////////
+ (SFAppDelegate*)getInstance
{
    return delegateInstance;
}


////////////////////////////////////////////////////////////
- (void)runUserMain
{
    // Arguments intentionally dropped, see comments in main in sfml-main
    sfmlMain(0, NULL);
}


////////////////////////////////////////////////////////////
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    // Save the delegate instance
    delegateInstance = [self initBackingScale];

    // Register orientation changes notifications
    [[UIDevice currentDevice] beginGeneratingDeviceOrientationNotifications];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(deviceOrientationDidChange:) name:UIDeviceOrientationDidChangeNotification object: nil];

    // Change the working directory to the resources directory
    [[NSFileManager defaultManager] changeCurrentDirectoryPath: [[NSBundle mainBundle] resourcePath]];

    // Schedule an indirect call to the user main, so that this call (and the whole
    // init sequence) can end, and the default splashscreen can be destroyed
    [self performSelector:@selector(runUserMain) withObject:nil afterDelay:0.0];

	application.statusBarHidden = YES;
    return true;
}

- (id)initBackingScale
{
    if (self = [super init])
    {
        // Instantiate the motion manager
		motionManager = [[CMMotionManager alloc] init];

        id data = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"NSHighResolutionCapable"];
        if(data && [data boolValue])
            backingScaleFactor = [[UIScreen mainScreen] scale];
        else
            backingScaleFactor = 1;
  
        return self;
    }
    return nil;
}

////////////////////////////////////////////////////////////
- (void)applicationWillResignActive:(UIApplication *)application
{
    // Called when:
    // - the application is sent to background
    // - the application is interrupted by a call or message

    // Generate a LostFocus event
    if (self.sfWindow)
    {
        sf::Event event;
        event.type = sf::Event::LostFocus;
        sfWindow->forwardEvent(event);
    }
}


////////////////////////////////////////////////////////////
- (void)applicationDidEnterBackground:(UIApplication *)application
{
    // Called when the application is sent to background (home button pressed)
}


////////////////////////////////////////////////////////////
- (void)applicationDidBecomeActive:(UIApplication *)application
{
    // Called when:
    // - the application is sent to foreground
    // - the application was interrupted by a call or message

    // Generate a GainedFocus event
    if (self.sfWindow)
    {
        sf::Event event;
        event.type = sf::Event::GainedFocus;
        sfWindow->forwardEvent(event);
    }
	else
	{
		NSLog(@"no self window yet");
	}
}


////////////////////////////////////////////////////////////
- (void)applicationWillEnterForeground:(UIApplication *)application
{
    // Called when the application is sent to foreground (app icon pressed)
}


////////////////////////////////////////////////////////////
- (void)applicationWillTerminate:(UIApplication *)application
{
    // Generate a Closed event
    if (self.sfWindow)
    {
        sf::Event event;
        event.type = sf::Event::Closed;
        sfWindow->forwardEvent(event);
    }
}

- (bool)supportsOrientation:(UIDeviceOrientation)orientation
{
    if (!self.sfWindow)
        return false;

    UIViewController* rootViewController = [((__bridge UIWindow*)(self.sfWindow->getSystemHandle())) rootViewController];
    if (!rootViewController || ![rootViewController shouldAutorotate])
        return false;

    NSArray *supportedOrientations = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"UISupportedInterfaceOrientations"];
    if (!supportedOrientations)
        return false;

    int appFlags = 0;
    if ([supportedOrientations containsObject:@"UIInterfaceOrientationPortrait"])
        appFlags += UIInterfaceOrientationMaskPortrait;
    if ([supportedOrientations containsObject:@"UIInterfaceOrientationPortraitUpsideDown"])
        appFlags += UIInterfaceOrientationMaskPortraitUpsideDown;
    if ([supportedOrientations containsObject:@"UIInterfaceOrientationLandscapeLeft"])
        appFlags += UIInterfaceOrientationMaskLandscapeLeft;
    if ([supportedOrientations containsObject:@"UIInterfaceOrientationLandscapeRight"])
        appFlags += UIInterfaceOrientationMaskLandscapeRight;

    return (1 << orientation) & [rootViewController supportedInterfaceOrientations] & appFlags;
}

- (bool)needsToFlipFrameForOrientation:(UIDeviceOrientation)orientation
{
    sf::Vector2u size = self.sfWindow->getSize();
    return ((!UIDeviceOrientationIsLandscape(orientation) && size.x > size.y)
            || (UIDeviceOrientationIsLandscape(orientation) && size.y > size.x));
}

////////////////////////////////////////////////////////////
- (void)deviceOrientationDidChange:(NSNotification *)notification
{
    if (self.sfWindow)
    {
        // Get the new orientation
        UIDeviceOrientation orientation = [[UIDevice currentDevice] orientation];
        // Filter interesting orientations
        if (UIDeviceOrientationIsValidInterfaceOrientation(orientation))
        {
            // Check if the app can switch to this orientation and if so if the window's size must be adjusted
            if ([self supportsOrientation:orientation])
			{
				// Send a OrientationChanged event to the current window
				sf::Event event;
				event.type = sf::Event::OrientationChanged;
				event.orientation.id = toBasicDeviceOrientation(orientation);
				sfWindow->forwardEvent(event);
			}
        }
    }
}

////////////////////////////////////////////////////////////
- (void)setVirtualKeyboardVisible:(bool)visible
{
    if (self.sfWindow)
        self.sfWindow->setVirtualKeyboardVisible(visible);
}


////////////////////////////////////////////////////////////
- (sf::Vector2i)getTouchPosition:(unsigned int)index
{
    if (index < touchPositions.size())
        return touchPositions[index];
    else
        return sf::Vector2i(-1, -1);
}


////////////////////////////////////////////////////////////
- (void)notifyTouchBegin:(unsigned int)index withTapCount:(unsigned int)tapCount atPosition:(sf::Vector2i)position;
{
    position.x *= backingScaleFactor;
    position.y *= backingScaleFactor;
    
    // save the touch position
    if (index >= touchPositions.size())
        touchPositions.resize(index + 1, sf::Vector2i(-1, -1));
    touchPositions[index] = position;

    // notify the event to the application window
    if (self.sfWindow)
    {
        sf::Event event;
        event.type = sf::Event::TouchBegan;
        event.touch.finger = index;
		event.touch.tapCount = tapCount;
        event.touch.x = position.x;
        event.touch.y = position.y;
        sfWindow->forwardEvent(event);
    }
}


////////////////////////////////////////////////////////////
- (void)notifyTouchMove:(unsigned int)index withTapCount:(unsigned int)tapCount atPosition:(sf::Vector2i)position;
{
    position.x *= backingScaleFactor;
    position.y *= backingScaleFactor;
    
    // save the touch position
    if (index >= touchPositions.size())
        touchPositions.resize(index + 1, sf::Vector2i(-1, -1));
    touchPositions[index] = position;

    // notify the event to the application window
    if (self.sfWindow)
    {
        sf::Event event;
        event.type = sf::Event::TouchMoved;
        event.touch.finger = index;
		event.touch.tapCount = tapCount;
        event.touch.x = position.x;
        event.touch.y = position.y;
        sfWindow->forwardEvent(event);
    }
}


////////////////////////////////////////////////////////////
- (void)notifyTouchEnd:(unsigned int)index withTapCount:(unsigned int)tapCount atPosition:(sf::Vector2i)position;
{
    // clear the touch position
    if (index < touchPositions.size())
        touchPositions[index] = sf::Vector2i(-1, -1);

    // notify the event to the application window
    if (self.sfWindow)
    {
        sf::Event event;
        event.type = sf::Event::TouchEnded;
        event.touch.finger = index;
		event.touch.tapCount = tapCount;
        event.touch.x = position.x * backingScaleFactor;
        event.touch.y = position.y * backingScaleFactor;
        sfWindow->forwardEvent(event);
    }
}


////////////////////////////////////////////////////////////
- (void)notifyShakeMotion;
{
    if (self.sfWindow)
    {
        sf::Event event;
        event.type = sf::Event::ShakeMotion;
        sfWindow->forwardEvent(event);
    }
}

////////////////////////////////////////////////////////////
- (void)notifyCharacter:(sf::Uint32)character
{
    if (self.sfWindow)
    {
        sf::Event event;
        event.type = sf::Event::TextEntered;
        event.text.unicode = character;
        sfWindow->forwardEvent(event);
    }
}


@end
