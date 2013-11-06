//
//  ViewController.m
//  Movement
//
//  Created by Robby Kraft on 11/1/13.
//  Copyright (c) 2013 Robby Kraft. All rights reserved.
//

#import "ViewController.h"
#import <CoreMotion/CoreMotion.h>

#define RECORD_LENGTH 5.0f // seconds

@interface ViewController () {
    GLfloat _fieldOfView;
    GLfloat _aspectRatio;
    BOOL _orientToDevice;
    CMMotionManager *motionManager;

    GLKMatrix4 _attitudeMatrix;
    GLKVector3 _rotationRate;
    GLKVector3 _userAcceleration;
    GLKVector3 _attitudeQuaternion;
    
    NSMutableArray *attitudeMatrixArray;
    NSMutableArray *rotationRateArray;
    NSMutableArray *userAccelerationArray;
    NSMutableArray *attitudeQuaternionArray;
    
    float *rotationRates;
    float *userAccelerations;
    float *attitudeQuaternions;
    
    //recording
    GLfloat backgroundColor;
    BOOL recordMode;
    int recordIndex;
    NSTimer *recordTimer;
    int count;
}
@property (strong, nonatomic) EAGLContext *context;
@property (strong, nonatomic) GLKBaseEffect *effect;

- (void)initGL;
- (void)tearDownGL;
- (void)setOrientToDevice:(BOOL)orientToDevice;

@end

@implementation ViewController

- (void)viewDidLoad{
    [super viewDidLoad];
    motionManager = [[CMMotionManager alloc] init];
    motionManager.deviceMotionUpdateInterval = 1.0/45.0; // this will exhaust the battery!
    [self setOrientToDevice:YES];
    [self initGL];
    GLKView *view = (GLKView *)self.view;
    view.context = self.context;
    backgroundColor = 0.0;
}

-(void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event{
    backgroundColor = 1.0;
}
-(void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event{
    backgroundColor = 0.0;
    if(![recordTimer isValid])
        [self beginRecording];
}

-(void)beginRecording{
    NSLog(@"begin recording");
    recordMode = YES;
    recordIndex = 0;
    attitudeMatrixArray = [NSMutableArray array];
    rotationRateArray = [NSMutableArray array];
    userAccelerationArray = [NSMutableArray array];
    attitudeQuaternionArray = [NSMutableArray array];
    recordTimer = [NSTimer scheduledTimerWithTimeInterval:RECORD_LENGTH target:self selector:@selector(endRecording) userInfo:Nil repeats:NO];
}

-(void)endRecording{
    NSLog(@"end recording");
    
    free(rotationRates);
    free(userAccelerations);
    free(attitudeQuaternions);
    
    rotationRates = malloc(sizeof(float)*rotationRateArray.count);
    userAccelerations = malloc(sizeof(float)*userAccelerationArray.count);
    attitudeQuaternions = malloc(sizeof(float)*attitudeQuaternionArray.count);
    for(int i = 0; i < rotationRateArray.count; i++)
        rotationRates[i] = [rotationRateArray[i] floatValue];
    for(int i = 0; i < userAccelerationArray.count; i++)
        userAccelerations[i] = [userAccelerationArray[i] floatValue];
    for(int i = 0; i < attitudeQuaternionArray.count; i++)
        attitudeQuaternions[i] = [attitudeQuaternionArray[i] floatValue];
    
    recordMode = NO;
    [recordTimer invalidate];
}

-(void)recordAttitudeQuaternion:(CMQuaternion) q{
    [attitudeQuaternionArray addObject:[NSNumber numberWithFloat:q.x]];
    [attitudeQuaternionArray addObject:[NSNumber numberWithFloat:q.y]];
    [attitudeQuaternionArray addObject:[NSNumber numberWithFloat:q.z]];
}

-(void)recordUserAcceleration:(CMAcceleration) a{
    [userAccelerationArray addObject:[NSNumber numberWithFloat:a.x]];
    [userAccelerationArray addObject:[NSNumber numberWithFloat:a.y]];
    [userAccelerationArray addObject:[NSNumber numberWithFloat:a.z]];
}

-(void) recordRotationRate:(CMRotationRate) r{
    [rotationRateArray addObject:[NSNumber numberWithFloat:r.x]];
    [rotationRateArray addObject:[NSNumber numberWithFloat:r.y]];
    [rotationRateArray addObject:[NSNumber numberWithFloat:r.z]];
}

-(void)recordAttitudeMatrix{
    [attitudeMatrixArray addObject:[NSNumber numberWithFloat:_attitudeMatrix.m00]];
    [attitudeMatrixArray addObject:[NSNumber numberWithFloat:_attitudeMatrix.m01]];
    [attitudeMatrixArray addObject:[NSNumber numberWithFloat:_attitudeMatrix.m02]];
    [attitudeMatrixArray addObject:[NSNumber numberWithFloat:_attitudeMatrix.m10]];
    [attitudeMatrixArray addObject:[NSNumber numberWithFloat:_attitudeMatrix.m11]];
    [attitudeMatrixArray addObject:[NSNumber numberWithFloat:_attitudeMatrix.m12]];
    [attitudeMatrixArray addObject:[NSNumber numberWithFloat:_attitudeMatrix.m20]];
    [attitudeMatrixArray addObject:[NSNumber numberWithFloat:_attitudeMatrix.m21]];
    [attitudeMatrixArray addObject:[NSNumber numberWithFloat:_attitudeMatrix.m22]];
}

-(void) setOrientToDevice:(BOOL)orientToDevice{
    _orientToDevice = orientToDevice;
    if(orientToDevice){
        if(motionManager.isDeviceMotionAvailable){
            [motionManager startDeviceMotionUpdatesToQueue:[NSOperationQueue currentQueue] withHandler: ^(CMDeviceMotion *deviceMotion, NSError *error){
                if(recordMode){
                    CMAcceleration a = deviceMotion.userAcceleration;
                    CMRotationRate r = deviceMotion.rotationRate;
                    CMQuaternion q = deviceMotion.attitude.quaternion;
                    CMRotationMatrix m = deviceMotion.attitude.rotationMatrix;
                    _userAcceleration = GLKVector3Make(a.x, a.y, a.z);
                    _rotationRate = GLKVector3Make(r.x, r.y, r.z);
                    _attitudeQuaternion = GLKVector3Make(q.x, q.y, q.z);
                    _attitudeMatrix= GLKMatrix4Make(m.m11, m.m21, m.m31, 0.0f,
                                                    m.m12, m.m22, m.m32, 0.0f,
                                                    m.m13, m.m23, m.m33, 0.0f,
                                                    0.0f , 0.0f , 0.0f , 1.0f);
                    //if(count%5==0){
                    //   [self recordAttitudeMatrix];
                    [self recordRotationRate:r];
                    [self recordUserAcceleration:a];
                    [self recordAttitudeQuaternion:q];
                    recordIndex++;
                    // }
                    if(count%30 == 0){
                        [self logOrientation];
                    }
                    count++;
                }
            }];
        }
    }
    else {
        [motionManager stopDeviceMotionUpdates];
    }
}

-(void)draw3DGraphs{
    static int screenRotate;
    
    static const GLfloat XAxis[] = {-1.0f, 0.0f, 0.0f, 1.0f, 0.0f, 0.0f};
    static const GLfloat YAxis[] = {0.0f, -1.0f, 0.0f, 0.0f, 1.0f, 0.0f};
    static const GLfloat ZAxis[] = {0.0f, 0.0f, -1.0f, 0.0f, 0.0f, 1.0f};
    //                   bottom left   top left   top right   bottom right
//    GLfloat vertices[] = {-1, -1, 0,   -1, 1, 0,   1, 1, 0,   1, -1, 0};
//    GLubyte indices[] = {0,1,2,  0,2,3};
    
    glPushMatrix();
    
    glTranslatef(0.0, 0.0, -2.0);
    glRotatef(10.0, 1.0, 0.0, 0.0);
    glRotatef(screenRotate/2.0, 0.0, 1.0, 0.0);
    
//    bool isInvertible;
//    GLKMatrix4 inverse = GLKMatrix4Invert(_attitudeMatrix, &isInvertible);
    
    glLineWidth(1.0);
    glColor4f(0.5, 0.5, 1.0, 1.0);
    glVertexPointer(3, GL_FLOAT, 0, XAxis);
    glEnableClientState(GL_VERTEX_ARRAY);
    glDrawArrays(GL_LINE_LOOP, 0, 2);
    glVertexPointer(3, GL_FLOAT, 0, YAxis);
    glEnableClientState(GL_VERTEX_ARRAY);
    glDrawArrays(GL_LINE_LOOP, 0, 2);
    glVertexPointer(3, GL_FLOAT, 0, ZAxis);
    glEnableClientState(GL_VERTEX_ARRAY);
    glDrawArrays(GL_LINE_LOOP, 0, 2);

    glPushMatrix();
    
    glLineWidth(1.0);
    
    // Rotation Rate
    for(int i = 0; i < recordIndex; i++){
        glColor4f(0.0, 0.0+i/(float)recordIndex, 1.0-i/(float)recordIndex, 1.0);
        GLfloat rotationVector[] = {0.0f, 0.0f, 0.0f, rotationRates[3*i], rotationRates[3*i+1], rotationRates[3*i+2]};
        glVertexPointer(3, GL_FLOAT, 0, rotationVector);
        glEnableClientState(GL_VERTEX_ARRAY);
        glDrawArrays(GL_LINE_LOOP, 0, 2);
    }
    
    // Device Acceleration
    for(int i = 0; i < recordIndex; i++){
        glColor4f(1.0, 0.0+i/(float)recordIndex, 0.0, 1.0);
        GLfloat userAccelerationVector[] = {0.0f, 0.0f, 0.0f, userAccelerations[3*i], userAccelerations[3*i+1], userAccelerations[3*i+2]};
        glVertexPointer(3, GL_FLOAT, 0, userAccelerationVector);
        glEnableClientState(GL_VERTEX_ARRAY);
        glDrawArrays(GL_LINE_LOOP, 0, 2);
    }
    
    // Quaternion Orientation
    for(int i = 0; i < recordIndex; i++){
        glColor4f(0.25+i/(float)recordIndex*.75, 0.25+i/(float)recordIndex*.75, 0.25+i/(float)recordIndex*.75, 1.0);
        GLfloat quaternionVector[] = {0.0f, 0.0f, 0.0f, attitudeQuaternions[3*i], attitudeQuaternions[3*i+1], attitudeQuaternions[3*i+2]};
        glVertexPointer(3, GL_FLOAT, 0, quaternionVector);
        glEnableClientState(GL_VERTEX_ARRAY);
        glDrawArrays(GL_LINE_LOOP, 0, 2);
    }

//    // Attitude Planes
//    glColor4f(1.0, 1.0, 1.0, 0.1);
//    for(int i = 0; i < recordIndex; i++){
//        glPushMatrix();
//        glLoadIdentity();
//        glTranslatef(0.0, 0.0, -2.0);
//        glRotatef(10.0, 1.0, 0.0, 0.0);
//        glRotatef(screenRotate/2.0, 0.0, 1.0, 0.0);
//        GLKMatrix4 position = GLKMatrix4Make(
//            [attitudeMatrixArray[9*i] floatValue], [attitudeMatrixArray[9*i+1] floatValue], [attitudeMatrixArray[9*i+2] floatValue], 0.0,
//            [attitudeMatrixArray[9*i+3] floatValue], [attitudeMatrixArray[9*i+4] floatValue], [attitudeMatrixArray[9*i+5] floatValue], 0.0,
//            [attitudeMatrixArray[9*i+6] floatValue], [attitudeMatrixArray[9*i+7] floatValue], [attitudeMatrixArray[9*i+8] floatValue], 0.0,
//            0.0, 0.0, 0.0, 1.0);
//        glMultMatrixf(position.m);
//        glVertexPointer(3, GL_FLOAT, 0, vertices);
//        glDrawElements(GL_TRIANGLES, 6, GL_UNSIGNED_BYTE, indices);
//        glPopMatrix();
//    }
    glPopMatrix();
    glPopMatrix();
    screenRotate++;
}

-(void)drawHexagons{
    static const GLfloat hexVertices[] = {
        -.5f, -.8660254f, -1.0f, 0.0f, -.5f, .8660254f,
        .5f, .8660254f,    1.0f, 0.0f,  .5f, -.8660254f
    };
    
    glLineWidth(1.0);
    glTranslatef([[UIScreen mainScreen] bounds].size.height*.5, [[UIScreen mainScreen] bounds].size.width*.5, 0.0);
    glScalef(100/_aspectRatio, 100*_aspectRatio, 1);
    
    // red
    glColor4f(1.0, 0.5, 0.5, 1.0);
    glVertexPointer(2, GL_FLOAT, 0, hexVertices);
    glEnableClientState(GL_VERTEX_ARRAY);
    glDrawArrays(GL_LINE_LOOP, 0, 6);
    
    // blue
    glColor4f(0.5, 0.5, 1.0, 1.0);
    glScalef(1.175, 1.175, 1);
    glRotatef(-atan2f(_attitudeMatrix.m10, _attitudeMatrix.m11)*180/M_PI, 0, 0, 1);
    glDrawArrays(GL_LINE_LOOP, 0, 6);
    
    // green
    glLoadIdentity();
    glColor4f(0.5, 1.0, 0.5, 1.0);
    glTranslatef([[UIScreen mainScreen] bounds].size.height*.5, [[UIScreen mainScreen] bounds].size.width*.5, 0.0);
    glScalef(100/_aspectRatio/1.175, 100*_aspectRatio/1.175, 1);
    glRotatef(-atan2f(_attitudeMatrix.m00, _attitudeMatrix.m01)*180/M_PI, 0, 0, 1);
    glDrawArrays(GL_LINE_LOOP, 0, 6);
    
    glLoadIdentity();
}

#pragma mark - GLKView and GLKViewController delegate methods

- (void)glkView:(GLKView *)view drawInRect:(CGRect)rect{
    glClearColor(backgroundColor, backgroundColor, backgroundColor, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    glMatrixMode(GL_MODELVIEW);
    
    if(recordMode){
        [self enterOrthographic];
        [self drawHexagons];
        [self exitOrthographic];
    }
    else{
        [self draw3DGraphs];
    }
}

-(void)initGL{
    EAGLContext *context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES1];
    [EAGLContext setCurrentContext:context];
    self.context = context;
    
    _fieldOfView = 75;
    _aspectRatio = (float)[[UIScreen mainScreen] bounds].size.width / (float)[[UIScreen mainScreen] bounds].size.height;
    if([UIApplication sharedApplication].statusBarOrientation > 2)
        _aspectRatio = 1/_aspectRatio;
    
    glEnable(GL_BLEND);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    glEnable(GL_TEXTURE_2D);
    glEnableClientState(GL_VERTEX_ARRAY);
    glEnableClientState(GL_TEXTURE_COORD_ARRAY);
    glCullFace(GL_FRONT_AND_BACK);
    
    glMatrixMode(GL_PROJECTION);
    glLoadIdentity();
    float zNear = 0.01;
    float zFar = 1000;
    GLfloat frustum = zNear * tanf(GLKMathDegreesToRadians(_fieldOfView) / 2.0);
    glFrustumf(-frustum, frustum, -frustum/_aspectRatio, frustum/_aspectRatio, zNear, zFar);
    glViewport(0, 0, [[UIScreen mainScreen] bounds].size.height, [[UIScreen mainScreen] bounds].size.width);
    glMatrixMode(GL_MODELVIEW);
    glEnable(GL_DEPTH_TEST);
    glLoadIdentity();
}

-(void)enterOrthographic{
    glDisable(GL_DEPTH_TEST);
    glMatrixMode(GL_PROJECTION);
    glPushMatrix();
    glLoadIdentity();
    glOrthof(0, [[UIScreen mainScreen] bounds].size.height, 0, [[UIScreen mainScreen] bounds].size.width, -5, 1);
    glMatrixMode(GL_MODELVIEW);
    glLoadIdentity();
}

-(void)exitOrthographic{
    glEnable(GL_DEPTH_TEST);
    glMatrixMode(GL_PROJECTION);
    glPopMatrix();
    glMatrixMode(GL_MODELVIEW);
}

-(void)logOrientation{
//    NSLog(@"\n%.3f, %.3f, %.3f\n%.3f, %.3f, %.3f\n%.3f, %.3f, %.3f",
//          _attitudeMatrix.m00, _attitudeMatrix.m01, _attitudeMatrix.m02,
//          _attitudeMatrix.m10, _attitudeMatrix.m11, _attitudeMatrix.m12,
//          _attitudeMatrix.m20, _attitudeMatrix.m21, _attitudeMatrix.m22);
    NSLog(@"(%.4f, %.4f, %.4f) (%.4f, %.4f, %.4f)",_userAcceleration.x, _userAcceleration.y, _userAcceleration.z, _rotationRate.x,_rotationRate.y,_rotationRate.z );
}

- (void)tearDownGL{
    [EAGLContext setCurrentContext:self.context];
    //unload shapes
//    glDeleteBuffers(1, &_vertexBuffer);
//    glDeleteVertexArraysOES(1, &_vertexArray);
    self.effect = nil;
}

- (void)dealloc{
    [self tearDownGL];
    if ([EAGLContext currentContext] == self.context) {
        [EAGLContext setCurrentContext:nil];
    }
    free(rotationRates);
    free(userAccelerations);
    free(attitudeQuaternions);
}
- (void)didReceiveMemoryWarning{
    [super didReceiveMemoryWarning];
    if ([self isViewLoaded] && ([[self view] window] == nil)) {
        self.view = nil;
        [self tearDownGL];
        if ([EAGLContext currentContext] == self.context)
            [EAGLContext setCurrentContext:nil];
        
        self.context = nil;
    }
    // Dispose of any resources that can be recreated.
}

@end
