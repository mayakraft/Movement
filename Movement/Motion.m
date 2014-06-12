//
//  Motion.m
//  Movement
//
//  Created by Robby on 6/12/14.
//  Copyright (c) 2014 Robby Kraft. All rights reserved.
//

#import "Motion.h"

@interface Motion (){    
    NSTimer *recordTimer;
}

@end

@implementation Motion

-(id) init{
    self = [super init];
    if(self){
        _motionManager = [[CMMotionManager alloc] init];
        _motionManager.deviceMotionUpdateInterval = 1.0/60.0;
    }
    return self;
}

-(void) recordDuration:(NSTimeInterval)duration Acceleration:(BOOL)acc Orientation:(BOOL)ori Rotation:(BOOL)rot{
    _isRecording = true;
    if([recordTimer isValid] || (!acc && !ori && !rot) )
        return;  // will not record over a recording, will not record if nothing is chosen
    
    recordTimer = [NSTimer scheduledTimerWithTimeInterval:duration target:self selector:@selector(stop) userInfo:nil repeats:NO];
    
    if(_motionManager.isDeviceMotionAvailable){
        [_motionManager startDeviceMotionUpdatesToQueue:[NSOperationQueue currentQueue] withHandler: ^(CMDeviceMotion *deviceMotion, NSError *error){
           
            _acceleration = GLKVector3Make(deviceMotion.userAcceleration.x, deviceMotion.userAcceleration.y, deviceMotion.userAcceleration.z);
            _rotationRate = GLKVector3Make(deviceMotion.rotationRate.x, deviceMotion.rotationRate.y, deviceMotion.rotationRate.z);
            _attitude = GLKQuaternionMake(deviceMotion.attitude.quaternion.x, deviceMotion.attitude.quaternion.y, deviceMotion.attitude.quaternion.z, deviceMotion.attitude.quaternion.w);
            _gravity = GLKVector3Make(deviceMotion.gravity.x, deviceMotion.gravity.y, deviceMotion.gravity.z);
            _magneticField = GLKVector3Make(deviceMotion.magneticField.field.x, deviceMotion.magneticField.field.y, deviceMotion.magneticField.field.z);

            if(rot) [self recordRotationRate:deviceMotion.rotationRate];
            if(acc) [self recordUserAcceleration:deviceMotion.userAcceleration];
            if(ori) [self recordAttitudeQuaternion:deviceMotion.attitude.quaternion];
            _numDataPoints++;
        }];
    }
}

-(void)recordAttitudeQuaternion:(CMQuaternion) q{
    [_attitudeQuaternionArray addObject:[NSNumber numberWithFloat:q.x]];
    [_attitudeQuaternionArray addObject:[NSNumber numberWithFloat:q.y]];
    [_attitudeQuaternionArray addObject:[NSNumber numberWithFloat:q.z]];
}

-(void)recordUserAcceleration:(CMAcceleration) a{
    [_userAccelerationArray addObject:[NSNumber numberWithFloat:a.x]];
    [_userAccelerationArray addObject:[NSNumber numberWithFloat:a.y]];
    [_userAccelerationArray addObject:[NSNumber numberWithFloat:a.z]];
}

-(void) recordRotationRate:(CMRotationRate) r{
    [_rotationRateArray addObject:[NSNumber numberWithFloat:r.x]];
    [_rotationRateArray addObject:[NSNumber numberWithFloat:r.y]];
    [_rotationRateArray addObject:[NSNumber numberWithFloat:r.z]];
}

-(void)stop{
    if([recordTimer isValid]){
        [recordTimer invalidate];
        [_delegate didFinishRecording];
    }
    [_motionManager stopDeviceMotionUpdates];
    _isRecording = false;
}

//-(void)logOrientation{
//    NSLog(@"\n%.3f, %.3f, %.3f\n%.3f, %.3f, %.3f\n%.3f, %.3f, %.3f",
//          _attitudeMatrix.m00, _attitudeMatrix.m01, _attitudeMatrix.m02,
//          _attitudeMatrix.m10, _attitudeMatrix.m11, _attitudeMatrix.m12,
//          _attitudeMatrix.m20, _attitudeMatrix.m21, _attitudeMatrix.m22);
//    NSLog(@"(%.4f, %.4f, %.4f) (%.4f, %.4f, %.4f)",_userAcceleration.x, _userAcceleration.y, _userAcceleration.z, _rotationRate.x,_rotationRate.y,_rotationRate.z );
//}
//

@end
