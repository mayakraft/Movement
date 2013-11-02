//
//  ViewController.m
//  Movement
//
//  Created by Robby Kraft on 11/1/13.
//  Copyright (c) 2013 Robby Kraft. All rights reserved.
//

#import "ViewController.h"
#import <CoreMotion/CoreMotion.h>

@interface ViewController () {

    GLfloat _fieldOfView;
    GLfloat _aspectRatio;
    BOOL _orientToDevice;
    CMMotionManager *motionManager;

    GLKMatrix4 _attitudeMatrix;
    GLKMatrix4 _attitudeVelocity;
    GLKMatrix4 _attitudeAcceleration;
}
@property (strong, nonatomic) EAGLContext *context;
@property (strong, nonatomic) GLKBaseEffect *effect;

- (void)initGL;
- (void)tearDownGL;
- (void)setOrientToDevice:(BOOL)orientToDevice;

@end

@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];

    motionManager = [[CMMotionManager alloc] init];
    motionManager.deviceMotionUpdateInterval = 1.0/45.0; // this will exhaust the battery!
    [self setOrientToDevice:YES];
   
    [self initGL];

    GLKView *view = (GLKView *)self.view;
    view.context = self.context;
    view.drawableDepthFormat = GLKViewDrawableDepthFormat24;
    view.opaque = NO;  //why?
}

-(void)initGL{
    EAGLContext *context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES1];
    [EAGLContext setCurrentContext:context];
    self.context = context;
    
    _fieldOfView = 75;
    _aspectRatio = (float)[[UIScreen mainScreen] bounds].size.width / (float)[[UIScreen mainScreen] bounds].size.height;
    if([UIApplication sharedApplication].statusBarOrientation > 2)
        _aspectRatio = 1/_aspectRatio;
//    celestialSphere = [[Sphere alloc] init:15 slices:15 radius:10.0 squash:1.0 textureFile:nil];
    
    // init lighting
    glShadeModel(GL_SMOOTH);
    glLightModelf(GL_LIGHT_MODEL_TWO_SIDE,0.0);
    glEnable(GL_LIGHTING);
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
    [self enterOrthographic];
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

-(void) setOrientToDevice:(BOOL)orientToDevice{
    _orientToDevice = orientToDevice;
    if(orientToDevice){
        if(motionManager.isDeviceMotionAvailable){
            [motionManager startDeviceMotionUpdatesToQueue:[NSOperationQueue currentQueue] withHandler: ^(CMDeviceMotion *deviceMotion, NSError *error){
                CMRotationMatrix a = deviceMotion.attitude.rotationMatrix;
                _attitudeVelocity =
                GLKMatrix4Make(a.m11-_attitudeMatrix.m00, a.m21-_attitudeMatrix.m01, a.m31-_attitudeMatrix.m02, 0.0f,
                               a.m13-_attitudeMatrix.m10, a.m23-_attitudeMatrix.m11, a.m33-_attitudeMatrix.m12, 0.0f,
                               -a.m12-_attitudeMatrix.m20,-a.m22-_attitudeMatrix.m21,-a.m32-_attitudeMatrix.m22,0.0f,
                               0.0f , 0.0f , 0.0f , 1.0f);
                _attitudeMatrix =
                GLKMatrix4Make(a.m11, a.m21, a.m31, 0.0f,
                               a.m13, a.m23, a.m33, 0.0f,
                               -a.m12,-a.m22,-a.m32,0.0f,
                               0.0f , 0.0f , 0.0f , 1.0f);
                static int count;
                if(count%20==0)
                    [self logOrientation];
                count++;
            }];
        }
    }
    else {
        [motionManager stopDeviceMotionUpdates];
    }
}

-(void)drawShapes
{
    static const GLfloat hexVertices[] = {
        -.5f, -.8660254f, -1.0f, 0.0f, -.5f, .8660254f,
        .5f, .8660254f,    1.0f, 0.0f,  .5f, -.8660254f
    };
    
    glDisable(GL_TEXTURE_2D);
    glDisable(GL_BLEND);
    glLineWidth(1.0);
    glTranslatef([[UIScreen mainScreen] bounds].size.height*.5, [[UIScreen mainScreen] bounds].size.width*.5, 0.0);
    glScalef(100/_aspectRatio, 100*_aspectRatio, 1);
    
    glColor4f(0.5, 0.5, 1.0, 1.0); // blue
    glVertexPointer(2, GL_FLOAT, 0, hexVertices);
    glEnableClientState(GL_VERTEX_ARRAY);
    glDrawArrays(GL_LINE_LOOP, 0, 6);
    
    glColor4f(0.5, 0.5, 1.0, 1.0); // blue
    glScalef(1.175, 1.175, 1);
    glRotatef(-atan2f(_attitudeMatrix.m10, _attitudeMatrix.m11)*180/M_PI, 0, 0, 1);
    glDrawArrays(GL_LINE_LOOP, 0, 6);

    glLoadIdentity();
    glColor4f(0.5, 0.5, 1.0, 1.0); // blue
    glTranslatef([[UIScreen mainScreen] bounds].size.height*.5, [[UIScreen mainScreen] bounds].size.width*.5, 0.0);
    glScalef(100/_aspectRatio/1.175, 100*_aspectRatio/1.175, 1);
    glRotatef(-atan2f(_attitudeMatrix.m00, _attitudeMatrix.m01)*180/M_PI, 0, 0, 1);
    glDrawArrays(GL_LINE_LOOP, 0, 6);

    glEnable(GL_TEXTURE_2D);
    glEnable(GL_BLEND);
    
    glLoadIdentity();
}

#pragma mark - GLKView and GLKViewController delegate methods

- (void)glkView:(GLKView *)view drawInRect:(CGRect)rect{
    glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    GLfloat white[] = {1.0,1.0,1.0,1.0};
//    GLfloat black[] = {0.0,0.0,0.0,0.0};
    glMatrixMode(GL_MODELVIEW);
    glPushMatrix();
//    glMultMatrixf(_attitudeMatrix.m);
    glMaterialfv(GL_FRONT_AND_BACK, GL_EMISSION, white);
//    [self executeSphere:celestialSphere inverted:YES];
    glPushMatrix();
    glMaterialfv(GL_FRONT_AND_BACK, GL_EMISSION, white);
//    [self executeSphere:[bug sphere] inverted:NO];
//    glPopMatrix();
//    glPopMatrix();
    [self drawShapes];
}

-(void)logOrientation{
    NSLog(@"\n%.3f, %.3f, %.3f\n%.3f, %.3f, %.3f\n%.3f, %.3f, %.3f\n+++++++++++++++++++++\n%.3f, %.3f, %.3f\n%.3f, %.3f, %.3f\n%.3f, %.3f, %.3f",
          _attitudeMatrix.m00, _attitudeMatrix.m01, _attitudeMatrix.m02,
          _attitudeMatrix.m10, _attitudeMatrix.m11, _attitudeMatrix.m12,
          _attitudeMatrix.m20, _attitudeMatrix.m21, _attitudeMatrix.m22,
          _attitudeVelocity.m00, _attitudeVelocity.m01, _attitudeVelocity.m02,
          _attitudeVelocity.m10, _attitudeVelocity.m11, _attitudeVelocity.m12,
          _attitudeVelocity.m20, _attitudeVelocity.m21, _attitudeVelocity.m22);
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
