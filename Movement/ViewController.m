//
//  ViewController.m
//  Movement
//
//  Created by Robby Kraft on 11/1/13.
//  Copyright (c) 2013 Robby Kraft. All rights reserved.
//

#import "ViewController.h"

@interface ViewController () {
    GLfloat _fieldOfView;
    GLfloat _aspectRatio;

    //bottom graph data
    GLfloat *accelMagnitude;
    GLfloat *rotationMagnitude;
    
    float *rotationRates;
    float *userAccelerations;
    float *attitudeQuaternions;
    
    //recording
    GLfloat backgroundColor;
    BOOL recordMode;

    int count;
    
    Motion *motion;
}

@property (strong, nonatomic) EAGLContext *context;
@property (strong, nonatomic) GLKBaseEffect *effect;

@end

@implementation ViewController

// delegate
-(void)didFinishRecording{
    NSLog(@"didFinishRecording delegate");
    [self endRecording];
}

- (void)viewDidLoad{
    [super viewDidLoad];
    motion = [[Motion alloc] init];
    [motion setDelegate:self];
    [self initGL];
}

-(void)initGL{
    EAGLContext *context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES1];
    [EAGLContext setCurrentContext:context];
    self.context = context;

    GLKView *view = (GLKView *)self.view;
    view.context = self.context;
    
    backgroundColor = 0.0;
    
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
    glEnable(GL_BLEND);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE);
}

-(void)exitOrthographic{
    glEnable(GL_DEPTH_TEST);
    glMatrixMode(GL_PROJECTION);
    glPopMatrix();
    glMatrixMode(GL_MODELVIEW);
    glEnable(GL_BLEND);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
}

-(void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event{
    backgroundColor = 1.0;
}
-(void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event{
    backgroundColor = 0.0;
    if(![motion isRecording]){
        [self beginRecording];
        [motion recordDuration:1.0 Acceleration:YES Orientation:YES Rotation:YES];
    }
}

-(void)beginRecording{
    NSLog(@"begin recording");
    recordMode = YES;
    [motion setNumDataPoints:0];
    [motion setAttitudeMatrixArray:[NSMutableArray array]];
    [motion setRotationRateArray:[NSMutableArray array]];
    [motion setUserAccelerationArray:[NSMutableArray array]];
    [motion setAttitudeQuaternionArray:[NSMutableArray array]];
//    recordTimer = [NSTimer scheduledTimerWithTimeInterval:RECORD_LENGTH target:self selector:@selector(endRecording) userInfo:Nil repeats:NO];
    
    // opengl
    [self enterOrthographic];
}

-(void)endRecording{
    NSLog(@"end recording");
    
    free(rotationRates);
    free(userAccelerations);
    free(attitudeQuaternions);
    
    rotationRates = malloc(sizeof(float)*([[motion rotationRateArray] count]+3));
    userAccelerations = malloc(sizeof(float)*([[motion userAccelerationArray] count]+3));
    attitudeQuaternions = malloc(sizeof(float)*([[motion attitudeQuaternionArray] count]+3));
    rotationRates[0] = rotationRates[1] = rotationRates[2] = 0.0f;
    userAccelerations[0] = userAccelerations[1] = userAccelerations[2] = 0.0f;
    attitudeQuaternions[0] = attitudeQuaternions[1] = attitudeQuaternions[2] = 0.0f;

    for(int i = 0; i < [[motion rotationRateArray] count]; i++)
        rotationRates[i+3] = [[[motion rotationRateArray] objectAtIndex:i] floatValue] * .25;
    for(int i = 0; i < [[motion userAccelerationArray] count]; i++)
        userAccelerations[i+3] = [[[motion userAccelerationArray] objectAtIndex:i] floatValue];
    for(int i = 0; i < [[motion attitudeQuaternionArray] count]; i++)
        attitudeQuaternions[i+3] = [[[motion attitudeQuaternionArray] objectAtIndex:i] floatValue];
    
    // bottom graph data
    accelMagnitude = malloc(sizeof(GLfloat)*([motion numDataPoints]*2+1) * 2 );
    rotationMagnitude = malloc(sizeof(GLfloat)*([motion numDataPoints]*2+1) * 2 );
    [self enterOrthographic];
    accelMagnitude[0] = accelMagnitude[1] = 0.0f;
    rotationMagnitude[0] = rotationMagnitude[1] = 0.0f;
    for (int i = 0; i < [motion numDataPoints]; i++){
        // x1
        accelMagnitude[(i*4)+2] = i/(float)[motion numDataPoints];
        rotationMagnitude[(i*4)+2] = i/(float)[motion numDataPoints];
        // y1
        accelMagnitude[(i*4)+3] = fabsf(userAccelerations[i*3]) + fabs(userAccelerations[i*3+1]) + fabs(userAccelerations[i*3+2]);
        rotationMagnitude[(i*4)+3] = -( fabs(rotationRates[i*3]) + fabs(rotationRates[i*3+1]) + fabs(rotationRates[i*3+2]) );
        // x2
        accelMagnitude[(i*4)+4] = (i+1)/(float)[motion numDataPoints];
        rotationMagnitude[(i*4)+4] = (i+1)/(float)[motion numDataPoints];
        // y2
        accelMagnitude[(i*4)+5] = 0.0f;
        rotationMagnitude[(i*4)+5] = 0.0f;
    }

    recordMode = NO;
//    [recordTimer invalidate];
    
    // opengl
    [self exitOrthographic];
}

-(void)draw3DGraphs{
    static int playBack;
    static int screenRotate;
    
    if(screenRotate % 2 == 0) playBack++;
    
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

    if([motion numDataPoints]){
    glPushMatrix();
    
    glLineWidth(1.0);
    
    // Rotation Rate
    glEnableClientState(GL_VERTEX_ARRAY);
    glPushMatrix();
    glColor4f(0.0, 0.0, 1.0, 0.5);
    glVertexPointer(3, GL_FLOAT, 0, rotationRates);
    glDrawArrays(GL_TRIANGLE_FAN, 0, [motion numDataPoints]);
    glPopMatrix();
    glDisableClientState(GL_VERTEX_ARRAY);
    for(int i = 0; i < [motion numDataPoints]; i++){
        glColor4f(0.0, 0.0+i/(float)[motion numDataPoints], 1.0-i/(float)[motion numDataPoints], 1.0);
        GLfloat rotationVector[] = {0.0f, 0.0f, 0.0f, rotationRates[3*i], rotationRates[3*i+1], rotationRates[3*i+2]};
        glVertexPointer(3, GL_FLOAT, 0, rotationVector);
        glEnableClientState(GL_VERTEX_ARRAY);
        glDrawArrays(GL_LINE_LOOP, 0, 2);
        if(i == playBack % [motion numDataPoints] && i < [motion numDataPoints]){
            GLfloat triangle[9];
            triangle[0] = rotationRates[0];
            triangle[1] = rotationRates[1];
            triangle[2] = rotationRates[2];
            triangle[3] = rotationRates[i*3];
            triangle[4] = rotationRates[i*3+1];
            triangle[5] = rotationRates[i*3+2];
            triangle[6] = rotationRates[(i+1)*3];
            triangle[7] = rotationRates[(i+1)*3+1];
            triangle[8] = rotationRates[(i+1)*3+2];
            glEnableClientState(GL_VERTEX_ARRAY);
            glPushMatrix();
            glColor4f(0.5, 0.5, 1.0, 1.0);
            glVertexPointer(3, GL_FLOAT, 0, triangle);
            glDrawArrays(GL_TRIANGLES, 0, 3);
            glPopMatrix();
            glDisableClientState(GL_VERTEX_ARRAY);
        }
    }
    
    // Device Acceleration
    glEnableClientState(GL_VERTEX_ARRAY);
    glPushMatrix();
    glColor4f(1.0, 0.0, 0.0, 0.5);
    glVertexPointer(3, GL_FLOAT, 0, userAccelerations);
    glDrawArrays(GL_TRIANGLE_FAN, 0, [motion numDataPoints]);
    glPopMatrix();
    glDisableClientState(GL_VERTEX_ARRAY);
    for(int i = 0; i < [motion numDataPoints]; i++){
        glColor4f(1.0, 0.0+i/(float)[motion numDataPoints], 0.0, 1.0);
        GLfloat userAccelerationVector[] = {0.0f, 0.0f, 0.0f, userAccelerations[3*i], userAccelerations[3*i+1], userAccelerations[3*i+2]};
        glVertexPointer(3, GL_FLOAT, 0, userAccelerationVector);
        glEnableClientState(GL_VERTEX_ARRAY);
        glDrawArrays(GL_LINE_LOOP, 0, 2);
        if(i == playBack % [motion numDataPoints] && i < [motion numDataPoints]){
            GLfloat triangle[9];
            triangle[0] = userAccelerations[0];
            triangle[1] = userAccelerations[1];
            triangle[2] = userAccelerations[2];
            triangle[3] = userAccelerations[i*3];
            triangle[4] = userAccelerations[i*3+1];
            triangle[5] = userAccelerations[i*3+2];
            triangle[6] = userAccelerations[(i+1)*3];
            triangle[7] = userAccelerations[(i+1)*3+1];
            triangle[8] = userAccelerations[(i+1)*3+2];
            glEnableClientState(GL_VERTEX_ARRAY);
            glPushMatrix();
            glColor4f(1.0, 0.5, 0.5, 1.0);
            glVertexPointer(3, GL_FLOAT, 0, triangle);
            glDrawArrays(GL_TRIANGLES, 0, 3);
            glPopMatrix();
            glDisableClientState(GL_VERTEX_ARRAY);
        }

    }
    
    // Quaternion Orientation
    for(int i = 0; i < [motion numDataPoints]; i++){
        if(i == playBack % [motion numDataPoints])
            glColor4f(1.0, 1.0, 1.0, 1.0);
        else
            glColor4f(0.25+i/(float)[motion numDataPoints]*.75, 0.25+i/(float)[motion numDataPoints]*.75, 0.25+i/(float)[motion numDataPoints]*.75, 1.0);
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
    }
    glPopMatrix();
    
    // bottom graphs
    CGSize screenSize = [[UIScreen mainScreen] bounds].size;
    
    
    if([motion numDataPoints]){
        [self enterOrthographic];

        int i = playBack % ([motion numDataPoints]);
        glPushMatrix();
    
        glEnableClientState(GL_VERTEX_ARRAY);
        glScalef(screenSize.width/_aspectRatio, 5, 1);
        glColor4f(1.0, 0.0, 0.0, 0.5);
        glVertexPointer(2, GL_FLOAT, 0, accelMagnitude);
        glDrawArrays(GL_TRIANGLE_STRIP, 0, ([motion numDataPoints])*2);
        glDisableClientState(GL_VERTEX_ARRAY);

        glColor4f(1.0, 0.0, 0.0, 1.0);
        GLfloat timeVector[] = {accelMagnitude[4*i], accelMagnitude[4*i+1], accelMagnitude[4*i+2], accelMagnitude[4*i+3]};
        glVertexPointer(2, GL_FLOAT, 0, timeVector);
        glEnableClientState(GL_VERTEX_ARRAY);
        glDrawArrays(GL_LINE_LOOP, 0, 2);
        
        glPopMatrix();

        glPushMatrix();
        
        glEnableClientState(GL_VERTEX_ARRAY);
        glTranslatef(0.0,screenSize.height*_aspectRatio, 0);
        glScalef(screenSize.width/_aspectRatio, 5, 1);
        glColor4f(0.0, 0.0, 1.0, 0.5);
        glVertexPointer(2, GL_FLOAT, 0, rotationMagnitude);
        glDrawArrays(GL_TRIANGLE_STRIP, 0, ([motion numDataPoints])*2);
        glDisableClientState(GL_VERTEX_ARRAY);
        
        glColor4f(0.0, 0.0, 1.0, 1.0);
        GLfloat timeVector2[] = {rotationMagnitude[4*i], rotationMagnitude[4*i+1], rotationMagnitude[4*i+2], rotationMagnitude[4*i+3]};
        glVertexPointer(2, GL_FLOAT, 0, timeVector2);
        glEnableClientState(GL_VERTEX_ARRAY);
        glDrawArrays(GL_LINE_LOOP, 0, 2);
        
        glPopMatrix();

        [self exitOrthographic];
    }
    screenRotate++;
}

-(void)drawHexagons{
    static const GLfloat hexVertices[] = {
        -.5f, -.8660254f, -1.0f, 0.0f, -.5f, .8660254f,
        .5f, .8660254f,    1.0f, 0.0f,  .5f, -.8660254f
    };
    static const GLfloat hexFan[] = {
        0.0f, 0.0f,
        -.5f, -.8660254f,
        -1.0f, 0.0f,
        -.5f, .8660254f,
        .5f, .8660254f,
        1.0f, 0.0f,
        .5f, -.8660254f,
        -.5f, -.8660254f
    };
    
    glLineWidth(1.0);
    glTranslatef([[UIScreen mainScreen] bounds].size.height*.5, [[UIScreen mainScreen] bounds].size.width*.5, 0.0);
    glScalef(100/_aspectRatio, 100*_aspectRatio, 1);

    glEnableClientState(GL_VERTEX_ARRAY);
    
    glPushMatrix();
    glColor4f(0.0, 1.0, 0.0, 0.5);
    glScalef([motion attitude].x, [motion attitude].x, 1);
    glVertexPointer(2, GL_FLOAT, 0, hexFan);
    glDrawArrays(GL_TRIANGLE_FAN, 0, 8);
    glPopMatrix();
    
    float rot = ([motion rotationRate].x + [motion rotationRate].y + [motion rotationRate].z)/3.0;
    glPushMatrix();
    glColor4f(0.0, 0.0, 1.0, 0.5);
    glScalef(rot, rot, 1);
    glVertexPointer(2, GL_FLOAT, 0, hexFan);
    glDrawArrays(GL_TRIANGLE_FAN, 0, 8);
    glPopMatrix();

    float accel = ([motion acceleration].x + [motion acceleration].y + [motion acceleration].z)/3.0;
    glPushMatrix();
    glColor4f(1.0, 0.0, 0.0, 0.5);
    glScalef(accel, accel, 1);
    glVertexPointer(2, GL_FLOAT, 0, hexFan);
    glDrawArrays(GL_TRIANGLE_FAN, 0, 8);
    glPopMatrix();

    glDisableClientState(GL_VERTEX_ARRAY);

    glEnableClientState(GL_VERTEX_ARRAY);
    glVertexPointer(2, GL_FLOAT, 0, hexVertices);

    // blue
    glPushMatrix();
    glColor4f(0.5, 0.5, 1.0, 1.0);
    glScalef([motion attitude].x, [motion attitude].x, 1);
    glDrawArrays(GL_LINE_LOOP, 0, 6);
    glPopMatrix();
    
    // green
    glPushMatrix();
    glScalef([motion attitude].y, [motion attitude].y, 1);
    glColor4f(0.5, 1.0, 0.5, 1.0);
    glDrawArrays(GL_LINE_LOOP, 0, 6);
    glPopMatrix();
    
    // red
    glPushMatrix();
    glColor4f(1.0, 0.5, 0.5, 1.0);
    glScalef([motion attitude].z, [motion attitude].z, 1);
    glDrawArrays(GL_LINE_LOOP, 0, 6);
    glPopMatrix();

    glDisableClientState(GL_VERTEX_ARRAY);

    glLoadIdentity();
}

#pragma mark - GLKView and GLKViewController delegate methods

- (void)glkView:(GLKView *)view drawInRect:(CGRect)rect{
    glClearColor(backgroundColor, backgroundColor, backgroundColor, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    glMatrixMode(GL_MODELVIEW);
    if(!backgroundColor){
        if(recordMode){
            [self drawHexagons];
        }
        else{
            [self draw3DGraphs];
        }
    }
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
