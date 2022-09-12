---
title: 【测试人生】GAutomator安卓UE4版本的实现机理与优化实战
date: 2022/09/12 17:34:58
categories:
- 测试人生
tags:
- 自动化测试
- UI自动化
- 游戏自动化
- GAutomator
- UE4
---

在[2年以前的一篇文章](https://utmhikari.top/2020/05/05/testlife/try_gautomator/)中，讲述了游戏UI自动化方案`GAutomator`的基础机理、使用方式和一些工具扩展的想法。今天，趁着`Game Of AutoTest`系列的连载，结合[游戏自动化技术选型](https://utmhikari.top/2022/08/13/gameofautotest/ii/)一文，笔者将深入剖析`GAutomator`作为`UE4`安卓游戏UI自动化方案的实现机理，以及自己在实际工作中对`GAutomator`的优化实践。

## 工作原理

`GAutomator`是这样的调用链路：

<!-- more -->

- PC和手机的连通 
   - `GAutomator`插件被启用编译，启动时在手机内启动一个`tcp-server`
   - PC端`GAClient`通过`adb forward`转发端口，然后连到手机内的`tcp-server`
- 获取控件 
   - 通过给`GAutomator-Server`发送`DUMP_TREE`命令，获取控件树的`XML`字符串
   - PC端`GAClient`接收到的控件树数据，可以被我们自己的业务逻辑取到，因此我们可以通过自定义的筛选条件找到对应控件的`Element`
- 点击控件 
   - PC端`GAClient`通过筛选控件得到的，或是自定义的`Element`，给到`click`接口
   - `click`接口发送`GET_ELEMENTS_BOUND`命令，根据`Element`信息，查询到对应控件在视口中的坐标
   - 获取坐标后，用`adb input tap`点击屏幕
  
## UE-SDK

`GAutomator`的`UE-SDK`实质是一个`UE4`插件，按需启用。

### 插件启动

插件启动时，会启动一个`TCP-Server`监听设备的某个端口，接取命令请求。

```cpp
// 插件启动
void FGAutomatorModule::StartupModule()
{
#if defined PLATFORM_IOS || defined __ANDROID__
	CommandDispatcherPtr = new WeTestU3DAutomation::FCommandDispatcher();
	CommandDispatcherPtr->Initialize();
#endif
}

// CommandDispatcher初始化
bool FCommandDispatcher::Initialize()
{
    SocketListenerThreadInstance = FRunnableThread::Create(this, TEXT("GAutomatorListenerThread"));
    return SocketListenerThreadInstance != nullptr;
}

// 服务主循环
uint32 FConnectionHandler::Run()
{
    bool result = true;
    do
    {
        result = HandleOneCommand();
    } while (result);
    return 0;
}

// handle命令
bool FConnectionHandler::HandleOneCommand() 
{
     // 获取头部长度信息
    int32 length = RecvIntLength(); 
    if (length <= 0) {
        return false;
    }
    
    // 获取命令请求body
    TArray<uint8> BodyBinrary;
    bool RecvContentResult = RecvContent(length, BodyBinrary);
    if (!RecvContentResult) {
        return false;
    }
    FString ContentStr = StringFromBinaryArray(BodyBinrary);
    UE_LOG(GALog, Log, TEXT("Recv command:%s"), *ContentStr);
    TSharedPtr<FJsonValue> JsonParsed;
    TSharedRef< TJsonReader<TCHAR> > JsonReader = TJsonReaderFactory<TCHAR>::Create(ContentStr);
    bool BFlag = FJsonSerializer::Deserialize(JsonReader, JsonParsed);
    if (!BFlag) {
        UE_LOG(GALog, Error, TEXT("Deserialize request to json failed.\n %s"));
        return false;
    }

    // handle-command并返回
    FString Response;
    bool res= HandleCommandInGameThread(JsonParsed, Response);
    length= this->SendData(Response);
    return res;
}
```

根据不同的命令码，内部会`dispatch`到不同`handler`去运行得到对应命令的结果。

### 控件信息获取

`GAutomator`最重要的一个功能是控件树导出，其实现如下：

```cpp
// 获取控件树xml字符串
FString GetCurrentWidgetTree() {
    TSharedPtr<FXmlFile> xml = CreateFXmlFile();
    FString XmlStr;
    FXmlNode* RootNode = xml->GetRootNode();
    // 遍历每层可见的根UUserWidget实例
    for (TObjectIterator<UUserWidget> Itr; Itr; ++Itr)
    {
        UUserWidget* UserWidget = *Itr;
        if (UserWidget == nullptr || !UserWidget->GetIsVisible() || UserWidget->WidgetTree == nullptr) {
            UE_LOG(GALog, Log, TEXT("UUserWidget Iterator get a null(unvisible) UUserWidget"));
            continue;
        }
        // 迭代向下遍历
        ForWidgetAndChildren(UserWidget->WidgetTree->RootWidget, RootNode);
    }
    WriteNodeHierarchy(*RootNode, FString(), XmlStr);
    return MoveTemp(XmlStr);
}

void ForWidgetAndChildren(UWidget* Widget, FXmlNode* Parent)
{
    // 过滤无效widget
    if (Widget == nullptr || Parent == nullptr || !Widget->IsVisible()) {
        return;
    }
    // 提取UWidget实例信息
    FXmlNode* WidgetXmlNode = TransformUmg2XmlElement(Widget, Parent);
    // 遍历Named-Slot，参考：https://docs.unrealengine.com/5.0/en-US/using-named-slots-in-umg-for-unreal-engine/
    if (INamedSlotInterface* NamedSlotHost = Cast<INamedSlotInterface>(Widget))
    {
        TArray<FName> SlotNames;
        NamedSlotHost->GetSlotNames(SlotNames);
        for (FName SlotName : SlotNames)
        {
            if (UWidget* SlotContent = NamedSlotHost->GetContentForSlot(SlotName))
            {
                ForWidgetAndChildren(SlotContent, WidgetXmlNode);
            }
        }
    }
    // 遍历Panel-Widget
    if (UPanelWidget* PanelParent = Cast<UPanelWidget>(Widget))
    {
        for (int32 ChildIndex = 0; ChildIndex < PanelParent->GetChildrenCount(); ChildIndex++)
        {
            if (UWidget* ChildWidget = PanelParent->GetChildAt(ChildIndex))
            {
                ForWidgetAndChildren(ChildWidget, WidgetXmlNode);
            }
        }
    }
}
```

机理上，会从所有的`Root Widget`开始向下遍历，拿到每个`Widget`的数据
而获取控件坐标方面，会涉及寻找控件的逻辑。在`UE4`插件内部，`GAutomator`默认支持通过控件名的方式查找：

```cpp
const UWidget* FindUWidgetObject(const FString& name)
{
    for (TObjectIterator<UUserWidget> Itr; Itr; ++Itr)
    {
        UUserWidget* UserWidget = *Itr;
        if (UserWidget == nullptr || !UserWidget->GetIsVisible() || UserWidget->WidgetTree == nullptr) {
            UE_LOG(GALog, Log, TEXT("UUserWidget Iterator get a null(unvisible) UUserWidget"));
            continue;
        }
        // 通过控件名寻找控件
        UWidget* Widget = UserWidget->GetWidgetFromName(FName(*name));
        if (Widget != nullptr) {
            return Widget;
        }
    }
    return nullptr;
}
```

机理上，会遍历所有根控件，调用`GetWidgetFromName`方法，找到的第一个`Widget`即返回。而之后获取屏幕视口坐标，则会从`CachedGeometry`获取到：

```cpp
bool FUWidgetHelper::GetElementBound(const FString& name, FBoundInfo& BoundInfo)
{
    const UWidget* WidgetPtr = FindUWidgetObject(name);
    // 由GetCachedGeometry获取渲染几何信息
    const FGeometry geometry = WidgetPtr->GetCachedGeometry();
    FVector2D Position = geometry.GetAbsolutePosition();
    FVector2D Size = geometry.GetAbsoluteSize();
    BoundInfo.x = Position.X / WidthScale;
    BoundInfo.y = Position.Y / HeightScale;
    BoundInfo.width = Size.X / WidthScale;
    BoundInfo.height = Size.Y / HeightScale;
    return true;
}
```
### 优化手段

`GAutomator`的`UE-SDK`在实现上，现在还存在许多不足，在笔者的实际应用中发现，很多地方没有考虑到。比如：

- 不支持`ListView`子空间的信息拉取
- 不支持富文本控件
- 不支持图片控件
- 不支持输入控件输入内容
- 不能通过`UniqueID`查询控件
   - 如果出现控件名重复，或者动态生成控件的情况，会难以定位到，甚至每次都只能查到第一个
- 不能一次性返回控件基础+坐标信息
   - 若业务侧一开始查询控件树，不会一次性返回控件坐标，执行控件操作还需要额外再查询一次
- PC游戏无法实现点击按下等操作

因此在实际业务中，笔者做了如下的优化，可供参考：

- 支持`ListView`子控件的信息提取逻辑
- 支持富文本控件信息提取（这个看具体项目富文本控件实现而定）
- 支持以资源路径为图片控件的文本信息，利于筛选特定图片
- 支持对`EditableText`等控件输入内容
- 支持通过`UniqueID`查询控件
- 支持拉取控件树时，一次性返回控件基础信息+视口坐标信息
- 支持`Broadcast`控件委托来实现点击按下等操作，从而支持PC端游戏的控件操作

## GA-Client

`GAutomator`的PC端`Client`主要的内容集中在`GAutomatorAndroid`以及`GAutomatorIos`下，本文以`GAutomatorAndroid`的部分为例，讲述`GA-Client`的核心实现。

`GAutomatorAndroid`项目本身杂糅了很多`wetest`相关的内容，以及很多无比粗糙的代码，这部分内容其实和`GA-Client`核心逻辑没有太大的联系。如果自己写一个`GA-Client`的话，可能只需要五分之一的代码量就可以了。

### 核心逻辑

`GA-Client`的核心部分在于`GameEngine`，所有与游戏内`SDK`交互的逻辑，都集中在这里：

```python
# engine.py
class GameEngine(object):
    def __init__(self, address, port,uiauto_interface):
        self.address = address
        self.port = port
        self.sdk_version = None
        # 初始化SocketClient实例，用以和游戏SDK通信
        for i in range(0, 3):
            try :
                self.socket = SocketClient(self.address, self.port)
                break
            except Exception as e:
                logger.error(e)
                time.sleep(20)
                ret = forward(self.port, unity_sdk_port)  # with retry...
        # 初始化UIAutomator实例
        self.ui_device = uiauto_interface
```

在`GameEngine`实例初始化的时候，会生成一个连接游戏内`SDK`的`socket`实例，以及一个`uiautomator`实例`ui_device`。当游戏需要和`native-ui`交互的时候（比如QQ登录），就需要`uiautomator`的支持（然而在`GameEngine`的基础方法里，`ui_device`实例没有发挥作用）。

当我们向游戏SDK发送命令的时候，会调用到`socket`的`send_command`方法：

```python
# engine.py
class GameEngine(object):
    def _get_dump_tree(self):
        """获取控件树"""
        ret = self.socket.send_command(Commands.DUMP_TREE)
    	return ret

        
# socket_client.py
class SocketClient(object):
    def send_command(self, cmd, params=None, timeout=20):
        """发送命令，带重试机制"""
        if not params:
            params = ""
        command = {}
        command["cmd"] = cmd
        command["value"] = params
        for retry in range(0, 2):
            try:
                self.socket.settimeout(timeout)
                self._send_data(command)
                ret = self._recv_data()
                return ret
            except:
                # 这里忽略异常处理/重连逻辑
                pass
        raise Exception('Socket Error')

	def _send_data(self, data):
        """发送数据"""
        try:
            serialized = json.dumps(data)
        except (TypeError, ValueError) as e:
            raise WeTestInvaildArg('You can only send JSON-serializable data')
        length = len(serialized)
        buff = struct.pack("i", length)
        self.socket.send(buff)
        if six.PY3:
            self.socket.sendall(bytes(serialized, encoding='utf-8'))
        else:
            self.socket.sendall(serialized)
```
从代码内容易知，发送命令的方式是：

- 用`json.dumps`序列化命令`cmd`和参数`params`
- 在序列化数据前`pack`一个`int`长度信息，把它和数据连起来发送给游戏内`SDK`
- 游戏内`SDK`先`recv`长度信息，再根据长度信息`recv`对应长度的数据，用`json.loads`反序列化，就得到原始命令和参数

当接收到数据时，也是跟游戏内`SDK`接收数据相同的方式。具体的实现在`recv_package`里：

```python
# socket_client.py
class SocketClient(object):
    def recv_package(self):
        # 拉取长度信息
        length_buffer = self.socket.recv(4)
        if length_buffer:
            total = struct.unpack_from("i", length_buffer)[0]
        else:
            raise WeTestSDKError('recv length is None?')
        # 拉取数据，开total长度的memoryview作为buffer
        view = memoryview(bytearray(total))
        next_offset = 0
        while total - next_offset > 0:
            recv_size = self.socket.recv_into(view[next_offset:], total - next_offset)
            next_offset += recv_size
        # 反序列化数据
        try:
            if six.PY3:
                deserialized = json.loads(str(view.tobytes(), encoding='utf-8'))
            else:
                deserialized = json.loads(view.tobytes())
            return deserialized
        except (TypeError, ValueError) as e:
            raise WeTestInvaildArg('Data received was not in JSON format')
```

类似`dump_tree`这种命令，返回的是`xml-string`，相当于是没有二次封装过的控件树。而类似`click`这种操作命令，实际用到的就是`adb shell input`这一系列的命令了。

```python
# engine.py
class GameEngine(object):
    def click(self, locator):
        if locator is None:
            return
        if isinstance(locator, Element):  # 考虑入参Element的情况
            try:
                bound = self.get_element_bound(locator)
                if bound:
                    return self.click_position(bound.x + bound.width / 2, bound.y + bound.height / 2)
            except WeTestRuntimeError as e:
                logger.error("Get element({0}) bound faild {1}".format(locator, e.message))
            return False
        else:  # 忽略只给ElementBound以及其他情况
            pass

	def click_position(self, x, y):
        x = int(x)
        y = int(y)
        cmd = "shell input tap " + str(x) + " " + str(y)
        excute_adb_process(cmd)  # adb shell input tap
        return True


# adb_process.py
def excute_adb_process(cmd, serial=None):
    if serial:
        command = "adb -s {0} {1}".format(serial, cmd)
    else:
        command = "adb {0}".format(cmd)
	# popen一个adb命令进程，执行命令
    ret = ""
    for i in range(0,3):
        p = subprocess.Popen(command, shell=True, stderr=subprocess.STDOUT, stdout=subprocess.PIPE)
        lines = p.stdout.readlines()
        ret = ""
        for line in lines:
            ret += str(line) + "\n"
        if "no devices/emulators found" in ret or "device offline" in ret:
            logger.error("rety in excute_adb_process")
            time.sleep(20)
        else:
            return ret
    return ret
```

### 优化手段

从`GA-Client`核心逻辑的实现可以看到，有很多地方是值得精简的。以笔者的经验为例，是按照自己自动化框架约定，重写了一版`GA-Client`。具体是做了以下优化：

- 单独分离出设备接口模块，用以统一管理设备信息和操作
   - 设备序列号、`adb`命令、`shell`命令，都在这个模块执行
- `GA-Client`和`uiautomator`分离，做成插件的形式
   - `GAutomator`和`uiautomator`的操作，比如点击按下这些，就可以由设备接口模块执行
- 控件树的`XML`字符串做二次封装，对每个控件抽象成`Widget`类
   - 单独做一个`GA`操作接口模块，传入`Widget`类实例就可以对控件做操作
   - `Widget`类做一些更复杂的控件筛选功能，这块就不需要游戏内`SDK`来深入做了
