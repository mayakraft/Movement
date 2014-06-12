//
//  Motion.h
//  Movement
//
//  Created by Robby on 6/12/14.
//  Copyright (c) 2014 Robby Kraft. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreMotion/CoreMotion.h>
#import <GLKit/GLKit.h>

@protocol MotionDelegate <NSObject>
@optional
-(void) didFinishRecording;
@end

@interface Motion : NSObject

@property id <MotionDelegate> delegate;

@property CMMotionManager *motionManager;

@property GLKQuaternion attitude;
@property GLKVector3 rotationRate;
@property GLKVector3 acceleration;
@property GLKVector3 gravity;
@property GLKVector3 magneticField;

// stored data
@property NSMutableArray *attitudeMatrixArray;
@property NSMutableArray *rotationRateArray;
@property NSMutableArray *userAccelerationArray;
@property NSMutableArray *attitudeQuaternionArray;
@property int numDataPoints;

-(void) recordDuration:(NSTimeInterval)duration Acceleration:(BOOL)a Orientation:(BOOL)o Rotation:(BOOL)r;
-(void) stop;

@property BOOL isRecording;

@end
