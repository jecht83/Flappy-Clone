//
//  MyScene.m
//  Flappy Clone
//
//  Created by Julio Montoya on 2/23/14.
//  Copyright (c) 2014 Julio Montoya. All rights reserved.
//

#import "MyScene.h"

static const float BG_FPS = 100;
static const float PIPE_XPOS = 382;
static const float FLOOR_DISTANCE = 72;

static inline CGFloat ScalarRandomRange(CGFloat min, CGFloat max)
{
    return floorf(((double)arc4random() / 0x100000000) * (max - min) + min);
}

static inline CGFloat clamp(CGFloat min, CGFloat max, CGFloat value)
{
    if(value > max)
    {
        return max;
    }
    
    else if(value < min)
    {
        return min;
    } else {
        return value;
    }
}

typedef NS_ENUM(int32_t, FCGameState)
{
    FCGameStateStarting,
    FCGameStatePlaying,
    FCGameStateEnded,
};

typedef NS_OPTIONS(uint32_t, FCPhysicsCategory)
{
    FCBoundaryCategory     = 1 << 0,
    FCPlayerCategory       = 1 << 1,
    FCPipeCategory         = 1 << 2,
    FCGapCategory          = 1 << 3,
};

@implementation MyScene
{
    int _score;
    
    SKNode *_bgLayer;
    
    SKSpriteNode *_bird;
    SKSpriteNode *_instructions;
    
    SKLabelNode *_scoreLabel;
    
    NSTimeInterval _dt;
    NSTimeInterval _lastUpdateTime;
    
    FCGameState _gameState;
}

+ (void)initialize
{
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    NSDictionary *defaults = [NSDictionary dictionaryWithObjectsAndKeys:@"0", @"best_score", nil];
    [userDefaults registerDefaults:defaults];
}

- (id)initWithSize:(CGSize)size
{
    if (self = [super initWithSize:size])
    {
        [self initWorld];
        [self initBackground];
        [self initBird];
        
    }
    
    return self;
}

#pragma mark - Initializers

- (void)initWorld
{
    self.physicsWorld.gravity = CGVectorMake(0, -5.0);
    self.physicsWorld.contactDelegate = self;
    self.physicsBody = [SKPhysicsBody bodyWithEdgeLoopFromRect:CGRectMake(0, FLOOR_DISTANCE,
                                                                          self.frame.size.width,
                                                                          self.frame.size.height -FLOOR_DISTANCE)];
    self.physicsBody.categoryBitMask = FCBoundaryCategory;
    self.physicsBody.contactTestBitMask = FCPlayerCategory;
    
    _gameState = FCGameStateStarting;
    _score = 0;
}

- (void)initBird
{
    _bird = [SKSpriteNode spriteNodeWithImageNamed:@"bird1"];
    _bird.position = CGPointMake(100, CGRectGetMidY(self.frame));
    _bird.physicsBody = [SKPhysicsBody bodyWithCircleOfRadius:_bird.size.width/2.5];
    _bird.physicsBody.categoryBitMask = FCPlayerCategory;
    _bird.physicsBody.contactTestBitMask = FCPipeCategory | FCGapCategory | FCBoundaryCategory;
    _bird.physicsBody.collisionBitMask = FCPipeCategory | FCBoundaryCategory;
    _bird.physicsBody.affectedByGravity = NO;
    _bird.physicsBody.allowsRotation = NO;
    _bird.physicsBody.restitution = 0.0;
    [self addChild:_bird];
    
    SKTexture *texture1 = [SKTexture textureWithImageNamed:@"bird1"];
    SKTexture *texture2 = [SKTexture textureWithImageNamed:@"bird2"];
    NSArray *textures = @[texture1, texture2];
    
    [_bird runAction:[SKAction repeatActionForever:[SKAction animateWithTextures:textures timePerFrame:0.1]]];
}

- (void)initBackground
{
    _bgLayer = [SKNode node];
    [self addChild:_bgLayer];
    
    for (int i = 0; i < 2; i++)
    {
        SKSpriteNode * bg = [SKSpriteNode spriteNodeWithImageNamed:@"bg"];
        bg.anchorPoint = CGPointZero;
        bg.position = CGPointMake(i * bg.size.width, 0);
        bg.name = @"bg";
        [_bgLayer addChild:bg];
    }
    
    _scoreLabel = [SKLabelNode labelNodeWithFontNamed:@"04b_19"];
    _scoreLabel.position = CGPointMake(CGRectGetMidX(self.frame), CGRectGetMaxY(self.frame) - 100);
    _scoreLabel.text = @"0";
    [self addChild:_scoreLabel];
    
    _instructions = [SKSpriteNode spriteNodeWithImageNamed:@"TapToStart"];
    _instructions.position = CGPointMake(CGRectGetMidX(self.frame), CGRectGetMidY(self.frame) - 10);
    [self addChild:_instructions];
}

- (void)initPipes
{
    SKSpriteNode *bottom = [self getPipeWithSize:CGSizeMake(62, ScalarRandomRange(40, 360)) isUp:NO];
    bottom.position = [self convertPoint:CGPointMake(PIPE_XPOS, CGRectGetMinY(self.frame) + bottom.size.height/2 + FLOOR_DISTANCE)
                                  toNode:_bgLayer];
    bottom.physicsBody = [SKPhysicsBody bodyWithRectangleOfSize:bottom.size];
    bottom.physicsBody.categoryBitMask = FCPipeCategory;
    bottom.physicsBody.contactTestBitMask = FCPlayerCategory;
    bottom.physicsBody.collisionBitMask = FCPlayerCategory;
    bottom.physicsBody.dynamic = NO;
    [_bgLayer addChild:bottom];
    
    SKSpriteNode *loop = [SKSpriteNode spriteNodeWithColor:[SKColor clearColor] size:CGSizeMake(10, 100)];
    loop.position = [self convertPoint:CGPointMake(PIPE_XPOS, FLOOR_DISTANCE + bottom.size.height + loop.size.height/2) toNode:_bgLayer];
    loop.physicsBody = [SKPhysicsBody bodyWithRectangleOfSize:loop.size];
    loop.physicsBody.categoryBitMask = FCGapCategory;
    loop.physicsBody.contactTestBitMask = FCPlayerCategory;
    loop.physicsBody.collisionBitMask = kNilOptions;
    loop.physicsBody.dynamic = NO;
    [_bgLayer addChild:loop];
    
    float topSize = self.size.height - bottom.size.height - loop.size.height - FLOOR_DISTANCE;
    
    SKSpriteNode *top = [self getPipeWithSize:CGSizeMake(62, topSize) isUp:YES];
    top.position = [self convertPoint:CGPointMake(PIPE_XPOS, CGRectGetMaxY(self.frame) - top.size.height/2)
                               toNode:_bgLayer];
    top.physicsBody = [SKPhysicsBody bodyWithRectangleOfSize:top.size];
    top.physicsBody.categoryBitMask = FCPipeCategory;
    top.physicsBody.contactTestBitMask = FCPlayerCategory;
    top.physicsBody.collisionBitMask = FCPlayerCategory;
    top.physicsBody.dynamic = NO;
    [_bgLayer addChild:top];
}

- (void)initScoreMenu:(NSInteger)score
{
    SKSpriteNode *scoreTable = [SKSpriteNode spriteNodeWithImageNamed:@"score"];
    scoreTable.position = CGPointMake(CGRectGetMidX(self.frame), CGRectGetMidY(self.frame));
    [self addChild:scoreTable];
    [scoreTable setScale:2];
    
    SKLabelNode *dd = [SKLabelNode labelNodeWithFontNamed:@"04b_19"];
    dd.text = [NSString stringWithFormat:@"%i", score];
    dd.position = CGPointMake(CGRectGetMidX(self.frame) -53, CGRectGetMidY(self.frame) -30);
    [self addChild:dd];
    
    SKLabelNode *ddf = [SKLabelNode labelNodeWithFontNamed:@"04b_19"];
    ddf.text = [[NSUserDefaults standardUserDefaults] objectForKey:@"best_score"];
    ddf.position = CGPointMake(CGRectGetMidX(self.frame) +55, CGRectGetMidY(self.frame) -30);
    [self addChild:ddf];
    
    if (score > [[[NSUserDefaults standardUserDefaults] objectForKey:@"best_score"] intValue])
    {
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        [defaults setObject:[NSString stringWithFormat:@"%i", score] forKey:@"best_score"];
        [defaults synchronize];
    }
}

#pragma mark - Background Update Position

- (void)moveBg
{
    _bgLayer.position = CGPointMake(_bgLayer.position.x + (-BG_FPS * _dt), 0);
    
    [_bgLayer enumerateChildNodesWithName:@"bg" usingBlock: ^(SKNode *node, BOOL *stop)
     {
         SKSpriteNode *bg = (SKSpriteNode *)node;
         CGPoint bgScreenPos = [_bgLayer convertPoint:bg.position toNode:self];
         
         if (bgScreenPos.x <= -bg.size.width)
         {
             bg.position = CGPointMake(bg.position.x + bg.size.width *2, bg.position.y);
         }
     }];
}

- (SKSpriteNode *)getPipeWithSize:(CGSize)size isUp:(BOOL)side
{
    CGRect textureSize = CGRectMake(0, 0, size.width, size.height);
    CGImageRef backgroundCGImage = [UIImage imageNamed:@"pipe"].CGImage;
    
    UIGraphicsBeginImageContext(size);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextDrawTiledImage(context, textureSize, backgroundCGImage);
    UIImage *tiledBackground = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    SKTexture *backgroundTexture = [SKTexture textureWithCGImage:tiledBackground.CGImage];
    SKSpriteNode *pipe = [SKSpriteNode spriteNodeWithTexture:backgroundTexture];
    
    SKSpriteNode *cap = [SKSpriteNode spriteNodeWithImageNamed:@"bottom"];
    cap.position = CGPointMake(0, side ? -pipe.size.height/2 + cap.size.height/2 : pipe.size.height/2 - cap.size.height/2);
    [pipe addChild:cap];
    
    if (side) cap.zRotation = 3.14159265;
    
    return pipe;
}

#pragma mark - Game Lyfe Cycle

- (void)gameOver
{
    _gameState = FCGameStateEnded;
    _bird.physicsBody.categoryBitMask = kNilOptions;
    _bird.physicsBody.collisionBitMask = FCBoundaryCategory;
    [self initScoreMenu:_score];
    [self performSelector:@selector(restartGame) withObject:nil afterDelay:2];
}

- (void)restartGame
{
    [self.view presentScene:[[MyScene alloc] initWithSize:self.size]
                 transition:[SKTransition doorsCloseVerticalWithDuration:0.5f]];
}

#pragma mark - Touch Events

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    switch (_gameState)
    {
        case FCGameStateStarting:
        {
            _gameState = FCGameStatePlaying;
            
            _instructions.hidden = YES;
            _bird.physicsBody.affectedByGravity = YES;
            [_bird.physicsBody applyImpulse:CGVectorMake(0, 25)];
            
            [self runAction:[SKAction repeatActionForever:[SKAction sequence:@[
                                                                               [SKAction waitForDuration:2],
                                                                               [SKAction performSelector:@selector(initPipes)
                                                                                                onTarget:self]
                                                                               ]]]];
        }
            break;
            
        case FCGameStatePlaying:
        {
            [_bird.physicsBody applyImpulse:CGVectorMake(0, 25)];
        }
            break;
            
        default:
            break;
    }
}

#pragma mark - SKPhysicsContact Delegate

- (void)didBeginContact:(SKPhysicsContact *)contact
{
    uint32_t collision = (contact.bodyA.categoryBitMask | contact.bodyB.categoryBitMask);
    
    if (collision == (FCPlayerCategory | FCGapCategory))
    {
        _score++;
        _scoreLabel.text = [NSString stringWithFormat:@"%i", _score];
    }
    
    if (collision == (FCPlayerCategory | FCPipeCategory))
    {
        [self gameOver];
    }
    
    if (collision == (FCPlayerCategory | FCBoundaryCategory))
    {
        if (_bird.position.y < 150)
        {
            [self gameOver];
        }
    }
}

#pragma mark - Frames Per Second

- (void)update:(NSTimeInterval)currentTime
{
    if (_lastUpdateTime) _dt = currentTime - _lastUpdateTime;
    else _dt = 0;
    
    _lastUpdateTime = currentTime;
    
    if (_gameState != FCGameStateEnded)
    {
        [self moveBg];
        
        if (_bird.physicsBody.velocity.dy > 280)
        {
            _bird.physicsBody.velocity = CGVectorMake(_bird.physicsBody.velocity.dx, 280);
        }
        
        _bird.zRotation = clamp( -1, 0.0, _bird.physicsBody.velocity.dy * (_bird.physicsBody.velocity.dy < 0 ? 0.003 : 0.001));
    } else {
        _bird.zRotation = 3.14;
        [_bird removeAllActions];
    }
}

@end