//
//  ViewController.m
//  WLQRunLoop
//
//  Created by wlq on 2018/7/25.
//  Copyright © 2018年 wanglq. All rights reserved.
//

#import "ViewController.h"

@interface ViewController ()<NSMachPortDelegate>
{
    CFRunLoopRef _runLoopRef;
    CFRunLoopSourceRef _source;
    CFRunLoopSourceContext _source_context;
}

@end

@implementation ViewController

//此输入源需要处理的后台事件
static void fire(void* info){
    
    NSLog(@"我现在正在处理后台任务");
    
    printf("%s",info);
}

static int count = 10;

- (void)viewDidLoad {
    [super viewDidLoad];
    
    //[self keepAlive];
    //[self startTimer];
    //[self sendMessage];
    [self source];
}

- (void)source {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        NSLog(@"线程开始");
        
        _runLoopRef = CFRunLoopGetCurrent();
        //初始化_source_context。
        //bzero(&_source_context, sizeof(_source_context));
        //这里创建了一个基于事件的源，绑定了一个函数
        _source_context.perform = fire;
        //参数
        _source_context.info = "你好";
        //创建一个source
        _source = CFRunLoopSourceCreate(NULL, 0, &_source_context);
        //将source添加到当前RunLoop中去
        CFRunLoopAddSource(_runLoopRef, _source, kCFRunLoopDefaultMode);
        
        //开启runloop 第三个参数设置为YES，执行完一次事件后返回
        CFRunLoopRunInMode(kCFRunLoopDefaultMode, 111111, YES);
        
        NSLog(@"线程结束");
    });
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        
        if (CFRunLoopIsWaiting(_runLoopRef)) {
            NSLog(@"RunLoop 正在等待事件输入");
            //添加输入事件
            CFRunLoopSourceSignal(_source);
            //唤醒线程，线程唤醒后发现由事件需要处理，于是立即处理事件
            CFRunLoopWakeUp(_runLoopRef);
        }else {
            NSLog(@"RunLoop 正在处理事件");
            //添加输入事件，当前正在处理一个事件，当前事件处理完成后，立即处理当前新输入的事件
            CFRunLoopSourceSignal(_source);
        }
    });
}

- (void)handlePortMessage:(id)message {//此处需要改写为id类型
    
    //只能用KVC的方式取值
    NSArray *array = [message valueForKeyPath:@"components"];
    
    NSData *data =  array[1];
    NSString *s1 = [[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding];
    NSLog(@"%@",s1);
    
    //    NSMachPort *localPort = [message valueForKeyPath:@"localPort"];
    //    NSMachPort *remotePort = [message valueForKeyPath:@"remotePort"];

}


/**
 基于NSPort的线程通讯
 */
- (void)sendMessage {
    
    NSMachPort *mainPort = [[NSMachPort alloc]init];
    NSPort *threadPort = [NSMachPort port];
    threadPort.delegate = self;
    
    [[NSRunLoop currentRunLoop] addPort:mainPort forMode:NSDefaultRunLoopMode];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSLog(@"线程开始");
        [[NSRunLoop currentRunLoop] addPort:threadPort forMode:NSDefaultRunLoopMode];
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]];
        NSLog(@"线程结束");
    });
    
    NSString *s1 = @"message";
    NSData *data = [s1 dataUsingEncoding:NSUTF8StringEncoding];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NSMutableArray *array = [NSMutableArray arrayWithObjects:mainPort,data,nil];
        NSLog(@"发送消息");
        [threadPort sendBeforeDate:[NSDate date] msgid:1000 components:array from:mainPort reserved:0];
    });
}

/**
 timer
 */
- (void)startTimer {
    count = 10;
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        NSTimer *timer = [NSTimer timerWithTimeInterval:1 target:self selector:@selector(exeTimer:) userInfo:@"timerTest" repeats:YES];
        //[timer fire];
        [[NSRunLoop currentRunLoop] addTimer:timer forMode:NSDefaultRunLoopMode];
        
        CFRunLoopRunResult result = CFRunLoopRunInMode(kCFRunLoopDefaultMode, MAXFLOAT, NO);
        
        //kCFRunLoopRunFinished = 1, //Run Loop结束，没有Timer或者其他Input Source
        //kCFRunLoopRunStopped = 2, //Run Loop被停止，使用CFRunLoopStop停止Run Loop
        //kCFRunLoopRunTimedOut = 3, //Run Loop超时
        //kCFRunLoopRunHandledSource = 4 ////Run Loop处理完事件，注意Timer事件的触发是不会让Run Loop退出返回的，即使CFRunLoopRunInMode的第三个参数是YES也不行
        
        switch (result) {
            case kCFRunLoopRunFinished:
                NSLog(@"kCFRunLoopRunFinished");
                
                break;
            case kCFRunLoopRunStopped:
                NSLog(@"kCFRunLoopRunStopped");
                
            case kCFRunLoopRunTimedOut:
                NSLog(@"kCFRunLoopRunTimedOut");
                
            case kCFRunLoopRunHandledSource:
                NSLog(@"kCFRunLoopRunHandledSource");
            default:
                break;
        }
    });
}

- (void)exeTimer:(NSTimer *)timer{
    
    NSLog(@"第%d次调用",count);
    count--;
    
    //    if (count == 8) {//验证停止
    //        CFRunLoopRef runloop = CFRunLoopGetCurrent();
    //        CFRunLoopStop(runloop);
    //    }
    if (count == 0) {//验证正常结束，timer停止，也就意味着runloop没有事件源
        [timer invalidate];
        timer = nil;
        NSLog(@"定时器结束");
    }
}

/**
 保活
 */
- (void)keepAlive {
    __block NSThread *thread;
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        
        NSLog(@"当前线程开始");
        thread = [NSThread currentThread];
        NSRunLoop *runloop = [NSRunLoop currentRunLoop];
        [runloop addPort:[NSMachPort port] forMode:NSDefaultRunLoopMode];
        [runloop runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]];
        
        NSLog(@"当前线程结束");
    });
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        
        [self performSelector:@selector(test)  onThread:thread withObject:self waitUntilDone:YES];
    });
}

- (void)test {
    NSLog(@"我还活着呢");
}



- (void)dealloc {
    NSLog(@"结束");
}

@end
