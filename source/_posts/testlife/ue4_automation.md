---
title: 【测试人生】在UE4插件中启用Automation自动化测试功能
date: 2020/12/20 16:05:53
categories:
- 测试人生
tags:
- 游戏测试
- UE4
- UE4 Automation
- 游戏自动化
- UE4插件
---

UE4本身支持在前端会话中执行自动化测试功能。有了它，我们可以用C++编写对应的自动化脚本，在编辑器的生命周期中随时随地运行，测试整个研发系统的子功能。

![会话前端](/uploads/testlife/ue4_automation/session_frontend.png ''会话前端'')

要深入了解UE4自带的自动化测试功能，可以参考[自动化系统概述](https://docs.unrealengine.com/zh-CN/TestingAndOptimization/Automation/index.html)文章系列。而本文则介绍最简单的接入UE4自带Automation自动化测试的方法，以[UnrealAutomator](https://github.com/utmhikari/UnrealAutomator)插件为例，提供一个最小的插件+Automation的范例

<!-- more -->

按照约定，每个插件需要在`Private/Tests`文件夹下，建立`插件名RunTests.cpp`，作为自动化测试的入口。

然后，通过宏注册自动化测试的类，并实现其`RunTest`函数，如下所示：

```cpp
IMPLEMENT_SIMPLE_AUTOMATION_TEST(FUnrealAutomatorWidgetTest, "UnrealAutomator.Widget", EAutomationTestFlags::EditorContext | EAutomationTestFlags::EngineFilter)

bool FUnrealAutomatorWidgetTest::RunTest(const FString& Parameters)
{
    // 查看当前是否存在UWidget
    UE_LOG(LogUnrealAutomator, Log, TEXT("Start UA Widget Test..."));
    auto WidgetJson = FUIService::GetWidgetTreeJson();
    auto WidgetJsonString = FCommonUtil::JsonStringify(WidgetJson);
    UE_LOG(LogUnrealAutomator, Log, TEXT("Current widget: %s"), *WidgetJsonString);
    TSharedPtr<FJsonObject> DefaultJsonObj = MakeShareable(new FJsonObject());
    return !WidgetJsonString.IsEmpty() &&
        !WidgetJsonString.Equals(FCommonUtil::JsonStringify(DefaultJsonObj));
}
```

编译，重启编辑器，打开会话前端的自动化测试页签，就能够看到该测试用例了：`UnrealAutomator.Widget`。

在编辑器中打开游戏，执行该测试用例，就能够判断当前是否存在UWidget了。

这是最简单的一种自动化测试，更为复杂的逻辑与测试机制可以参考[自动化技术指南](https://docs.unrealengine.com/zh-CN/TestingAndOptimization/Automation/TechnicalGuide/index.html)以及周边文章。后续的测试方式，还要慢慢研究~
