###前言

其实最近一直在研究iOS蓝牙开发```CoreBluetooth ```，网上有关于iOS蓝牙开发一堆一堆的， 本人也是想写个学习笔记，基本阐述一些```蓝牙```的基本概念以及常规用法。

###正文
#####我们得明确一下很重要的几个概念

>1.当前ios中开发蓝牙所运用的系统库是```<CoreBluetooth/CoreBluetooth.h>```
2.蓝牙外设必须为4.0及以上，否则无法开发，蓝牙4.0设备因为低耗电，所以也叫做BLE。
3.```CoreBluetooth```框架的核心其实是两个东西，```peripheral```和```central```, 可以理解成外设和中心，就是你的苹果手机就是中心，外部蓝牙称为外设。
4.服务和特征```(service and characteristic)```：简而言之，外部蓝牙中它有若干个服务```service```（服务你可以理解为蓝牙所拥有的能力），而每个服务```service```下拥有若干个特征```characteristic```（特征你可以理解为解释这个服务的属性）。
5.```Descriptor```（描述）用来描述```characteristic```变量的属性。例如，一个```descriptor```可以规定一个可读的描述，或者一个```characteristic```变量可接受的范围，或者一个```characteristic```变量特定的单位。
6.跟硬件亲测，```iOS蓝牙```每次最多接收155字节的数据，安卓5.0以下最大接收20字节，5.0以上可以更改最大接收量，能达到500多字节。


#####通过以上关键信息的解释，然后看一下蓝牙的开发流程：
>建立中心管理者
>1. 扫描外设（discover）
>2. 连接外设(connect)
>3. 扫描外设中的服务和特征(discover)
>4. 4.1 获取外设的services
>5. 4.2 获取外设的Characteristics,获取Characteristics的值，
>6. 获取Characteristics的Descriptor和Descriptor的值
>7. 与外设做数据交互(explore and interact)
>8. 断开连接(disconnect)

####具体实例： 
######1.创建一个中心管理者
```
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
```
当发现蓝牙状态是开启状态，你就可以利用中央设备进行扫描外设，如果为关闭状态，系统会自动弹出让用户去设置蓝牙，这个不需要我们开发者关心

######2.利用中心去扫描外设
```
/** 两个参数为nil, 默认扫描所有的外设，可以设置一些服务，进行过滤搜索*/
[self.bluetoothManager scanForPeripheralsWithServices:nil
                                                  options:nil];
```
2.1当扫描到外设，触发以下代理方法

>在这里需要说明的是，
一.当扫描到外设，我们可以读到相应外设广播信息，RSSI信号强度（可以利用RSSI计算中心和外设的距离）。
二.我们可以根据一定的规则进行连接，一般是默认名字或者名字和信号强度的规则来连接。
三.像我现在做的无钥匙启动车辆锁定车辆，就需要加密通讯，不能谁来连接都可以操作车辆，需要和外设进行加密通讯，但是一切的通过算法的校验都是在和外设连接上的基础上进行，例如连接上了，你发送一种和硬件约定好的算法数据，硬件接收到校验通过了就正常操作，无法通过则由硬件（外设）主动断开。

```
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
```


#####3.当连接到外设，会调用以下代理方法
这里需要说明的是
当成功连接到外设，需要设置外设的代理，为了扫描服务调用相应代理方法

```
- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral{
    
    NSLog(@"连接外设成功！%@", peripheral.name);
    [peripheral setDelegate:self];
    [peripheral discoverServices:nil];
}

/** 连接外设失败*/
- (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error
{
    NSLog(@"连接到外设 失败！名字：%@ 错误信息：%@", [peripheral name], [error localizedDescription]);
}
```

#####4.扫描外设中的服务和特征
```
/** 扫描到服务*/
-(void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error{
    if (error)
    {
        NSLog(@"扫描外设服务出错：%@-> %@", peripheral.name, [error localizedDescription]);
        return;
    }
    NSLog(@"扫描到外设服务：%@ -> %@",peripheral.name,peripheral.services);
    for (CBService *service in peripheral.services) {
        [peripheral discoverCharacteristics:nil forService:service];
    }
    NSLog(@"开始扫描外设服务的特征 %@...",peripheral.name);
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
```

#####5.与外设做数据交互

需要说明的是苹果官方提供发送数据的方法很简单,只需要调用下面的方法

```
- (void)writeValue:(NSData *)data forCharacteristic:(CBCharacteristic *)characteristic type:(CBCharacteristicWriteType)type
{
    /**
     我们只需要在搜索每个服务的特征，记录这个特征，然后向这个特征发送数据就可以了。
     */
}
```

######6.断开连接

调用以下代码,需要说明的是中心断开与外设的连接。
```
- (void)cancelPeripheralConnection:(CBPeripheral *)peripheral
{
    /*
      以上呢是整个蓝牙的开发过程，系统提供的框架api就这么多；
     */
}
```

>结语： 目前先总结到这里。
扩展： 正在研究iOS应用与Siri交互
例如：对着Siri说 “支付宝付款码” 会自动访问支付宝并且弹出付款码。 或者 对着Siri说“给xxx发送一条微信” 会弹出自定义UI页面 然后可以直接操作， 不需要在打开微信 等相关功能

在之后会更新学习成果。
