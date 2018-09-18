//
//  ViewController.m
//  XDBluetoothDemo
//
//  Created by mxd_iOS on 2018/9/18.
//  Copyright © 2018年 Xudong.ma. All rights reserved.
//

#import "ViewController.h"
#import <CoreBluetooth/CoreBluetooth.h>

@interface ViewController () <CBCentralManagerDelegate, CBPeripheralDelegate>

@property (nonatomic, strong) CBCentralManager *bluetoothManager;
@property (nonatomic, strong) CBCharacteristic *characteristic;
@property (nonatomic, strong) CBPeripheral     *pripheral;

@end

@implementation ViewController

#pragma mark -
#pragma mark - LazyLoading

#pragma mark -
#pragma mark - Set_Method

#pragma mark -
#pragma mark - ViewLifeCycle

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    [self instanceBluetoothSubView];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


#pragma mark -
#pragma mark - SystemMethod

- (void)dealloc
{
    
}

#pragma mark -
#pragma mark - InitializeMethod

- (void)instanceBluetoothSubView
{
    /** 只要一触发这句代码系统会自动检测手机蓝牙状态，你必须实现其代理方法，当然得添加<CBCentralManagerDelegate>*/
    self.bluetoothManager = [[CBCentralManager alloc] initWithDelegate:self queue:nil];
    
    /** 两个参数为nil, 默认扫描所有的外设，可以设置一些服务，进行过滤搜索*/
    [self.bluetoothManager scanForPeripheralsWithServices:nil
                                                  options:nil];
}

#pragma mark -
#pragma mark - PersonalMethod

/** 4个字节Bytes 转 int*/
unsigned int bytesValueToInt(Byte *bytesValue) {
    
    unsigned int  intV;
    intV = (unsigned int ) ( ((bytesValue[3] & 0xff)<<24)
                            |((bytesValue[2] & 0xff)<<16)
                            |((bytesValue[1] & 0xff)<<8)
                            |(bytesValue[0] & 0xff));
    return intV;
}

#pragma mark -
#pragma mark - ButtonClickMethod

#pragma mark -
#pragma mark - NotificationMethod

#pragma mark -
#pragma mark - ...Delegate/DataSourceMethod

/** 从这个代理方法中你可以看到所有的状态，其实我们需要的只有on和off连个状态*/
- (void)centralManagerDidUpdateState:(CBCentralManager *)central {
    
    switch (central.state) {
        case CBManagerStateUnknown:
            NSLog(@"__CBManagerStateUnknown__");
            break;
        case CBManagerStateResetting:
            NSLog(@"__CBManagerStateResetting__");
            break;
        case CBManagerStateUnsupported:
            NSLog(@"__CBManagerStateUnsupported__");
            break;
        case CBManagerStateUnauthorized:
            NSLog(@"__CBManagerStateUnauthorized__");
            break;
        case CBManagerStatePoweredOff:
            NSLog(@"__CBManagerStatePoweredOff__");
            break;
        case CBManagerStatePoweredOn:
            NSLog(@"__CBManagerStatePoweredOn__");
            break;
        default:
            break;
    }
}

/** 这里默认扫到MI，主动连接，当然也可以手动触发连接*/
- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary *)advertisementData RSSI:(NSNumber *)RSSI
{
    NSLog(@"扫描连接外设：%@ %@", peripheral.name, RSSI);
    
    if ([peripheral.name hasSuffix:@"MI"]) {
        /** 保存外设，并停止扫描，达到节电效果*/
        self.pripheral = peripheral;
        [central stopScan];
        /** 进行连接*/
        [central connectPeripheral:peripheral options:nil];
    }
}

- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral
{
    NSLog(@"连接外设成功！%@", peripheral.name);
    [peripheral setDelegate:self];
    [peripheral discoverServices:nil];
}

/** 连接外设失败*/
- (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error
{
    NSLog(@"连接到外设 失败！名字：%@ 错误信息：%@", [peripheral name], [error localizedDescription]);
}

/** 扫描到服务*/
- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error
{
    if (error)
    {
        NSLog(@"扫描外设服务出错：%@-> %@", peripheral.name, [error localizedDescription]);
        return;
    }
    NSLog(@"扫描到外设服务：%@ -> %@", peripheral.name, peripheral.services);
    for (CBService *service in peripheral.services) {
        [peripheral discoverCharacteristics:nil forService:service];
    }
    NSLog(@"开始扫描外设服务的特征 %@...", peripheral.name);
}

/** 扫描到特征*/
- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error
{
    if (error)
    {
        NSLog(@"扫描外设的特征失败！%@->%@-> %@", peripheral.name, service.UUID, [error localizedDescription]);
        return;
    }
    
    NSLog(@"扫描到外设服务特征有：%@->%@->%@", peripheral.name, service.UUID, service.characteristics);
    //获取Characteristic的值
    for (CBCharacteristic *characteristic in service.characteristics){
        
        //这里外设需要订阅特征的通知，否则无法收到外设发送过来的数据
        [peripheral setNotifyValue:YES forCharacteristic:characteristic];
        
        //需要说明的是UUID是硬件定义好给你，如果硬件也是个新手，那你可以先打印出所有的UUID, 找出有用的
        //步数
        if ([characteristic.UUID.UUIDString isEqualToString:@"FF06"])
        {
            [peripheral readValueForCharacteristic:characteristic];
        }
        
        //电池电量
        else if ([characteristic.UUID.UUIDString isEqualToString:@"FF0C"])
        {
            [peripheral readValueForCharacteristic:characteristic];
        }
        
        else if ([characteristic.UUID.UUIDString isEqualToString:@"2A06"])
        {
            //震动
            self.characteristic = characteristic;
        }
    }
}


/** 扫描到具体的值->通讯主要的获取数据的方法*/
- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(nullable NSError *)error
{
    if (error) {
        NSLog(@"扫描外设的特征失败！%@-> %@", peripheral.name, [error localizedDescription]);
        return;
    }
    NSLog(@"%@ %@", characteristic.UUID.UUIDString, characteristic.value);
    if ([characteristic.UUID.UUIDString isEqualToString:@"FF06"]) {
        Byte *steBytes = (Byte *)characteristic.value.bytes;
        int steps = bytesValueToInt(steBytes);
        NSLog(@"%d", steps);
    } else if ([characteristic.UUID.UUIDString isEqualToString: @"FF0C"])
    {
        Byte *bufferBytes = (Byte *)characteristic.value.bytes;
        int buterys = bytesValueToInt(bufferBytes)&0xff;
        NSLog(@"电池：%d%%",buterys);
    } else if ([characteristic.UUID.UUIDString isEqualToString:@"2A06"])
    {
        Byte *infoByts = (Byte *)characteristic.value.bytes;
        NSLog(@"%s", infoByts);
        
        //这里解析infoByts得到设备信息
    }
}

- (void)writeValue:(NSData *)data forCharacteristic:(CBCharacteristic *)characteristic type:(CBCharacteristicWriteType)type
{
    /**
     我们只需要在搜索每个服务的特征，记录这个特征，然后向这个特征发送数据就可以了。
     */
}

- (void)cancelPeripheralConnection:(CBPeripheral *)peripheral
{
    /*
     
      以上呢是整个蓝牙的开发过程，系统提供的框架api就这么多，开发起来也不是很难，要是你认为这篇文章到这里就结束了，你就大错特错了，这篇文章的精华内容将从这里开始，由于公司项目的保密性，我不能以它为例，那我就以小米手环为实例，主要分享一下数据解析。
     
     */
}

#pragma mark -
#pragma mark - NetworkHandlerMethod

@end
