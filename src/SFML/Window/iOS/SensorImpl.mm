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
#include <SFML/Window/SensorImpl.hpp>
#include <SFML/Window/iOS/SFAppDelegate.hpp>


namespace
{
    unsigned int deviceMotionEnabledCount = 0;

    float toDegrees(float radians)
    {
        return radians * 180.f / 3.141592654f;
    }
}


namespace sf
{
namespace priv
{
////////////////////////////////////////////////////////////
void SensorImpl::initialize()
{
    // Nothing to do
}


////////////////////////////////////////////////////////////
void SensorImpl::cleanup()
{
    // Nothing to do
}


////////////////////////////////////////////////////////////
bool SensorImpl::isAvailable(Sensor::Type sensor)
{
    switch (sensor)
    {
        case Sensor::Accelerometer:
            return [SFAppDelegate getInstance].motionManager.accelerometerAvailable;

        case Sensor::Gyroscope:
            return [SFAppDelegate getInstance].motionManager.gyroAvailable;

        case Sensor::Magnetometer:
            return [SFAppDelegate getInstance].motionManager.magnetometerAvailable;

        case Sensor::Gravity:
        case Sensor::UserAcceleration:
        case Sensor::Orientation:
            return [SFAppDelegate getInstance].motionManager.deviceMotionAvailable;

        default:
            return false;
    }
}


////////////////////////////////////////////////////////////
bool SensorImpl::open(Sensor::Type sensor)
{
    // Store the sensor type
    m_sensor = sensor;

    // The sensor is disabled by default
    m_enabled = false;

    // Set the refresh rate (use the maximum allowed)
    static const NSTimeInterval updateInterval = 1. / 60.;
    switch (sensor)
    {
        case Sensor::Accelerometer:
            [SFAppDelegate getInstance].motionManager.accelerometerUpdateInterval = updateInterval;
            break;

        case Sensor::Gyroscope:
            [SFAppDelegate getInstance].motionManager.gyroUpdateInterval = updateInterval;
            break;

        case Sensor::Magnetometer:
            [SFAppDelegate getInstance].motionManager.magnetometerUpdateInterval = updateInterval;
            break;

        case Sensor::Gravity:
        case Sensor::UserAcceleration:
        case Sensor::Orientation:
            [SFAppDelegate getInstance].motionManager.deviceMotionUpdateInterval = updateInterval;
            break;

        default:
            break;
    }

    return true;
}


////////////////////////////////////////////////////////////
void SensorImpl::close()
{
    // Nothing to do
}


////////////////////////////////////////////////////////////
Vector3f SensorImpl::update()
{
    Vector3f value;
    CMMotionManager* manager = [SFAppDelegate getInstance].motionManager;

    switch (m_sensor)
    {
        case Sensor::Accelerometer:
		@autoreleasepool {
			CMAccelerometerData *accelerometerData = manager.accelerometerData;
			if (accelerometerData)
			{
				// Acceleration is given in G, convert to m/s^2
				value.x = accelerometerData.acceleration.x * 9.81f;
				value.y = accelerometerData.acceleration.y * 9.81f;
				value.z = accelerometerData.acceleration.z * 9.81f;
			}
            break;
		}

        case Sensor::Gyroscope:
		@autoreleasepool {
			CMGyroData *gyroData = manager.gyroData;
			if (gyroData)
			{
				// Rotation rates are given in rad/s, convert to deg/s
				value.x = toDegrees(gyroData.rotationRate.x);
				value.y = toDegrees(gyroData.rotationRate.y);
				value.z = toDegrees(gyroData.rotationRate.z);
			}
            break;
		}

        case Sensor::Magnetometer:
		@autoreleasepool {
			CMMagnetometerData *magnetometerData = manager.magnetometerData;
			if (magnetometerData)
			{
				// Magnetic field is given in microteslas
				value.x = magnetometerData.magneticField.x;
				value.y = magnetometerData.magneticField.y;
				value.z = magnetometerData.magneticField.z;
			}
            break;
		}

        case Sensor::UserAcceleration:
        @autoreleasepool {
			CMDeviceMotion *deviceMotion = manager.deviceMotion;
			if (deviceMotion)
			{
				CMAcceleration userAcceleration = deviceMotion.userAcceleration;
				// User acceleration is given in G, convert to m/s^2
				value.x = userAcceleration.x * 9.81f;
				value.y = userAcceleration.y * 9.81f;
				value.z = userAcceleration.z * 9.81f;
			}
            break;
        }

        case Sensor::Orientation:
        @autoreleasepool {
			CMDeviceMotion *deviceMotion = manager.deviceMotion;
			if (deviceMotion)
			{
				CMAttitude *attitude = deviceMotion.attitude;
				// Absolute rotation (Euler) angles are given in radians, convert to degrees
				value.x = toDegrees(attitude.yaw);
				value.y = toDegrees(attitude.pitch);
				value.z = toDegrees(attitude.roll);
			}
            break;
        }

        case Sensor::Gravity:
		@autoreleasepool {
			CMDeviceMotion *deviceMotion = manager.deviceMotion;
			if (deviceMotion)
			{
				CMAcceleration gravity = deviceMotion.gravity;
				// Gravity is given in G, convert to m/s^2
				value.x = gravity.x * 9.81f;
				value.y = gravity.y * 9.81f;
				value.z = gravity.z * 9.81f;
			}
            break;
        }

		default:
            break;
    }

    return value;
}


////////////////////////////////////////////////////////////
void SensorImpl::setEnabled(bool enabled)
{
    // Don't do anything if the state is the same
    if (enabled == m_enabled)
        return;

    switch (m_sensor)
    {
        case Sensor::Accelerometer:
            if (enabled)
                [[SFAppDelegate getInstance].motionManager startAccelerometerUpdates];
            else
                [[SFAppDelegate getInstance].motionManager stopAccelerometerUpdates];
            break;

        case Sensor::Gyroscope:
            if (enabled)
                [[SFAppDelegate getInstance].motionManager startGyroUpdates];
            else
                [[SFAppDelegate getInstance].motionManager stopGyroUpdates];
            break;

        case Sensor::Magnetometer:
            if (enabled)
                [[SFAppDelegate getInstance].motionManager startMagnetometerUpdates];
            else
                [[SFAppDelegate getInstance].motionManager stopMagnetometerUpdates];
            break;

        case Sensor::Gravity:
        case Sensor::UserAcceleration:
        case Sensor::Orientation:
            // these 3 sensors all share the same implementation, so we must disable
            // it only if the three sensors are disabled
            if (enabled)
            {
                if (deviceMotionEnabledCount == 0)
                    [[SFAppDelegate getInstance].motionManager startDeviceMotionUpdates];
                deviceMotionEnabledCount++;
            }
            else
            {
                deviceMotionEnabledCount--;
                if (deviceMotionEnabledCount == 0)
                    [[SFAppDelegate getInstance].motionManager stopDeviceMotionUpdates];
            }
            break;

        default:
            break;
    }

    // Update the enable state
    m_enabled = enabled;
}

} // namespace priv

} // namespace sf
