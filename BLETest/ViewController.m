//
//  ViewController.m
//  BLETest
//
//  Created by YiFan on 2018/8/15.
//  Copyright © 2018年 YiFan. All rights reserved.
//

#import "ViewController.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    [self setTableView];
    self.manager = [[CBCentralManager alloc] initWithDelegate:self queue:dispatch_get_main_queue()];
    self.manager.delegate = self;
    self.BleViewPerArr = [[NSMutableArray alloc] initWithCapacity:1];
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


#pragma mark - BLEDelegate&Method
- (void)scan {
    //判断状态开始扫瞄周围设备 第一个参数为空则会扫瞄所有的可连接设备
    //你可以指定一个CBUUID对象 从而只扫瞄注册用指定服务的设备
    //scanForPeripheralsWithServices方法调用完后会调用代理CBCentralManagerDelegate的
    //- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary *)advertisementData RSSI:(NSNumber *)RSSI方法
    [self.manager scanForPeripheralsWithServices:nil options:@{ CBCentralManagerScanOptionAllowDuplicatesKey : @NO }];
    //记录目前是扫描状态
    _bluetoothState = BluetoothStateScaning;
    //清空所有外设数组
    [self.BleViewPerArr removeAllObjects];
    //如果蓝牙状态未开启，提示开启蓝牙
    if (_bluetoothFailState == BluetoothFailStateByOff) {
        NSLog(@"%@", @"检查您的蓝牙是否开启后重试");
    }
}

//蓝牙开关切换变化调用
- (void)centralManagerDidUpdateState:(CBCentralManager *)central {
    if (central.state != CBManagerStatePoweredOn) {
        NSLog(@"fail, state is off.");
        switch (central.state) {
            case CBManagerStatePoweredOff:
                NSLog(@"连接失败了\n请您再检查一下您的手机蓝牙是否开启，\n然后再试一次吧");
                _bluetoothFailState = BluetoothFailStateByOff;
                break;
            case CBManagerStateResetting:
                _bluetoothFailState = BluetoothFailStateByTimeout;
                break;
            case CBManagerStateUnsupported:
                NSLog(@"检测到您的手机不支持蓝牙4.0\n所以建立不了连接.建议更换您\n的手机再试试。");
                _bluetoothFailState = BluetoothFailStateByHW;
                break;
            case CBManagerStateUnauthorized:
                NSLog(@"连接失败了\n请您再检查一下您的手机蓝牙是否开启，\n然后再试一次吧");
                _bluetoothFailState = BluetoothFailStateUnauthorized;
                break;
            case CBManagerStateUnknown:
                _bluetoothFailState = BluetoothFailStateUnKnow;
                break;
            default:
                break;
        }
        return;
    }
    _bluetoothFailState = BluetoothFailStateUnExit;
    [self scan];
}

- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary<NSString *, id> *)advertisementData RSSI:(NSNumber *)RSSI {
    if (peripheral == nil || peripheral.identifier == nil /*||peripheral.name == nil*/) {
        return;
    }
    NSString *pername = [NSString stringWithFormat:@"%@", peripheral.name];
    //判断是否存在指定类型的设备
    NSRange range = [pername rangeOfString:@"77777"];
    //加入BleViewPerArr数组，不重复添加
    if (range.location != NSNotFound && [_BleViewPerArr containsObject:peripheral] == NO) {
        [_BleViewPerArr addObject:peripheral];
    }
    _bluetoothFailState = BluetoothFailStateUnExit;
    _bluetoothState = BluetoothStateScanSuccess;
    [_tableView reloadData];
}

//蓝牙连接成功
- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral {
    NSLog(@"%@", peripheral);
    //设置设备代理
    [peripheral setDelegate:self];
    //大概获取服务和特征
    [peripheral discoverServices:nil];
    //或许只获取你的设备蓝牙服务的uuid数组，一个或者多个
    //[peripheral discoverServices:@[[CBUUID UUIDWithString:@""],[CBUUID UUIDWithString:@""]]];
    NSLog(@"Peripheral Connected");
    
    //停止扫描
    [_manager stopScan];
    NSLog(@"Scanning stopped");
    _bluetoothState = BluetoothStateConnected;
}

//连接失败
- (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
    NSLog(@"连接失败");
    NSLog(@"%@", error);
}

//发现服务
- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error {
    if (error) {
        NSLog(@"Error discovering services: %@", [error localizedDescription]);
        return;
    }

    NSLog(@"所有的servicesUUID%@", peripheral.services);

    //遍历所有service
    for (CBService *service in peripheral.services) {
        NSLog(@"服务%@", service.UUID);

        //找到你需要的servicesuuid
        if ([service.UUID isEqual:[CBUUID UUIDWithString:@"1818"]]) {
            //监听它
            [peripheral discoverCharacteristics:nil forService:service];
        }
    }
    NSLog(@"此时链接的peripheral：%@", peripheral);
}

//发现特征
- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error {
    if (error) {
        NSLog(@"Discovered characteristics for %@ with error: %@", service.UUID, [error localizedDescription]);
        return;
    }
    NSLog(@"服务：%@", service.UUID);
    // 特征
    for (CBCharacteristic *characteristic in service.characteristics) {
        NSLog(@"%@", characteristic);
        //监听特定特征
        if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:@"2A65"]]) {
            NSLog(@"监听：%@", characteristic);
            //保存characteristic特征值对象
            //以后发信息也是用这个uuid
            _characteristic1 = characteristic;
            //监听操作
            [_discoveredPeripheral setNotifyValue:YES forCharacteristic:characteristic];
            //写入字符
            [_discoveredPeripheral writeValue:[self stringToBytes:@"wyf"] forCharacteristic:characteristic type:CBCharacteristicWriteWithoutResponse];
        }
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error {
    if (error) {
        NSLog(@"Error updating value for characteristic %@ error: %@", characteristic.UUID, [error localizedDescription]);
        return;
    }

    NSLog(@"收到的数据：%@", characteristic.value);
}

//普通字符串,转NSData
- (NSData *)stringToBytes:(NSString *)str {
    return [str dataUsingEncoding:NSASCIIStringEncoding];
}

#pragma mark - TableViewDelegate&Method
- (void)setTableView {
    _tableView = [[UITableView alloc] initWithFrame:CGRectMake(0, 20, [UIScreen mainScreen].bounds.size.width, [UIScreen mainScreen].bounds.size.height) style:UITableViewStyleGrouped];
    _tableView.delegate = self;
    _tableView.dataSource = self;
    _tableView.backgroundColor = [UIColor whiteColor];
    [self.view addSubview:_tableView];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = (UITableViewCell *)[tableView dequeueReusableCellWithIdentifier:@"IsConnect"];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"IsConnect"];
    }

    // 将蓝牙外设对象接出，取出name，显示
    //蓝牙对象在下面环节会查找出来，被放进BleViewPerArr数组里面，是CBPeripheral对象
    CBPeripheral *per = (CBPeripheral *)_BleViewPerArr[indexPath.row];
    cell.textLabel.text = per.name;
    return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 44;
}
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return _BleViewPerArr.count;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    CBPeripheral *peripheral=(CBPeripheral *)_BleViewPerArr[indexPath.row];
    //设定周边设备，指定代理者
    _discoveredPeripheral = peripheral;
    _discoveredPeripheral.delegate = self;
    //连接设备
    [_manager connectPeripheral:peripheral
                        options:@{CBConnectPeripheralOptionNotifyOnConnectionKey:@YES}];
    
}

@end
