---
title: 【游戏开发】踩坑UE4的Python脚本插件
date: 2021/11/21 01:23:17
categories:
- 游戏开发
tags:
- UE4
- C++
- python
- PythonScriptPlugin
- UE4编辑器
---

UE4以C++为基础，在游戏开发需求当中，官方推崇的是Blueprint可视化编程，而除此之外像UnLua、puerts等解决方案也提供了lua、ts等其它脚本语言的支持。至于python，UE4本身就有插件支持，叫做`PythonScriptPlugin`，启用插件后，在编辑器里，可以输入python代码执行一系列命令。在最新的4.27版本中，python的版本是3.7.7。

回到正题，之所以这篇文章标题叫踩坑，是因为真的踩坑了——尝试用`PythonScriptPlugin`来编写UE4的游戏逻辑，最终放弃。`PythonScriptPlugin`适合做一些驱动编辑器的操作，或者是做一些静态资源检查相关的工作（其实这个插件真名就叫`Python Editor Script Plugin`），如果用它来写游戏逻辑的话，很多必须的内容都难以支持。但不管怎么说，既然踩坑了还是要分享点东西出来，因此这篇文章先粗浅谈一下`PythonScriptPlugin`的工作流。

<!-- more -->

`PythonScriptPlugin`的使用方法，基本可以参考官方文档：[Scripting the Editor using Python](https://docs.unrealengine.com/4.27/en-US/ProductionPipelines/ScriptingAndAutomation/Python/)

一些必须的步骤有：

- 插件中，启用`Python Editor Script Plugin`
- 项目设置的Python插件设置里面，`sys.path`增加自己脚本的目录
- 项目设置的Python插件设置里面，启用开发者模式，重启后在`Intermediate/PythonStubs`能够看到导出的`unreal.py`
  - 将`unreal.py`放到自己脚本目录下，其它`.py`脚本就可以通过`import unreal`来调用UE相关的库了
  - `unreal.py`内容非常大，ide需要配置intellisense相关设置

如果要在游戏逻辑里执行python命令，尤其是在C++里的话（蓝图已经有支持了），需要在`Build.cs`的`PublicDependencyModuleNames`加上`PythonScriptPlugin`

在C++执行python代码的话，可以这样子做：

```cpp
// 这里笔者单独写了个GameInstanceSubsystem封装了相关方法

#include "IPythonScriptPlugin.h"


bool UPyEnvGameInstanceSubsystem::ExecPyCmd(const FString& Cmd)
{
    IPythonScriptPlugin* ScriptPlugin = GetScriptPlugin();
    if (!_IsScriptPluginAvailable(ScriptPlugin))
    {
        return false;
    }
    return ScriptPlugin->ExecPythonCommand(*Cmd);
}

IPythonScriptPlugin* UPyEnvGameInstanceSubsystem::GetScriptPlugin()
{
    return IPythonScriptPlugin::Get();
}

bool UPyEnvGameInstanceSubsystem::_IsScriptPluginAvailable(IPythonScriptPlugin* ScriptPlugin)
{
    return ScriptPlugin != nullptr && ScriptPlugin->IsPythonAvailable();
}
```

简单的代码执行可以通过`IPythonScriptPlugin`的`ExecPyCmd`实现。如果说要获取执行结果，可以调用`IPythonScriptPlugin`的`ExecPythonCommandEx`方法：

```cpp
// Engine\Plugins\Experimental\PythonScriptPlugin\Source\PythonScriptPlugin\Private\PythonScriptPlugin.cpp

bool FPythonScriptPlugin::ExecPythonCommandEx(FPythonCommandEx& InOutPythonCommand)
{
#if WITH_PYTHON
    if (!IsPythonAvailable())
#endif
    {
        InOutPythonCommand.CommandResult = TEXT("Python is not available!");
        ensureAlwaysMsgf(false, TEXT("%s"), *InOutPythonCommand.CommandResult);
        return false;
    }

#if WITH_PYTHON
    if (InOutPythonCommand.ExecutionMode == EPythonCommandExecutionMode::ExecuteFile)
    {
        // We may have been passed literal code or a file
        // To work out which, extract the first token and see if it's a .py file
        // If it is, treat the remaining text as arguments to the file
        // Otherwise, treat it as literal code
        FString ExtractedFilename;
        {
            const TCHAR* Tmp = *InOutPythonCommand.Command;
            ExtractedFilename = FParse::Token(Tmp, false);
        }
        if (FPaths::GetExtension(ExtractedFilename) == TEXT("py"))
        {
            return RunFile(*ExtractedFilename, *InOutPythonCommand.Command, InOutPythonCommand);
        }
        else
        {
            return RunString(InOutPythonCommand);
        }
    }
    else
    {
        return RunString(InOutPythonCommand);
    }
#endif // WITH_PYTHON
}

bool FPythonScriptPlugin::RunString(FPythonCommandEx& InOutPythonCommand)
{
    // Execute Python code within this block
    {
        FPyScopedGIL GIL;
        TGuardValue<bool> UnattendedScriptGuard(GIsRunningUnattendedScript, GIsRunningUnattendedScript || EnumHasAnyFlags(InOutPythonCommand.Flags, EPythonCommandFlags::Unattended));

        int PyExecMode = 0;
        switch (InOutPythonCommand.ExecutionMode)
        {
        case EPythonCommandExecutionMode::ExecuteFile:
            PyExecMode = Py_file_input;
            break;
        case EPythonCommandExecutionMode::ExecuteStatement:
            PyExecMode = Py_single_input;
            break;
        case EPythonCommandExecutionMode::EvaluateStatement:
            PyExecMode = Py_eval_input;
            break;
        default:
            checkf(false, TEXT("Invalid EPythonCommandExecutionMode!"));
            break;
        }

        FDelegateHandle LogCaptureHandle = PyCore::GetPythonLogCapture().AddLambda([&InOutPythonCommand](EPythonLogOutputType InLogType, const TCHAR* InLogString) { InOutPythonCommand.LogOutput.Add(FPythonLogOutputEntry{ InLogType, InLogString }); });
        FPyObjectPtr PyResult = FPyObjectPtr::StealReference(EvalString(*InOutPythonCommand.Command, TEXT("<string>"), PyExecMode));
        PyCore::GetPythonLogCapture().Remove(LogCaptureHandle);
        
        if (PyResult)
        {
            InOutPythonCommand.CommandResult = PyUtil::PyObjectToUEStringRepr(PyResult);
        }
        else if (PyUtil::LogPythonError(&InOutPythonCommand.CommandResult))
        {
            return false;
        }
    }

    FPyWrapperTypeReinstancer::Get().ProcessPending();
    return true;
}
```

执行时候传入`FPythonCommandEx`结构体，其`CommandResult`属性会存储执行的结果。如果要传入结果的话，得选择`EPythonCommandExecutionMode::EvaluateStatement`执行模式。而最终传入的结果，是python数据的`repr`，并非兼容成UE4的数据结构。

总结起来可以看到，直接用`PythonScriptPlugin`写游戏是不大现实，有几个点还要解决：

- python与C++之间的相互通信，数据结构兼容。只有`string repr`是肯定不行的= =
- 游戏最终呈现的性能
- 多平台发布
- 开发效率（至少自己16G烂本本干不动，还不如纯C++）
- etc

不过原生作为面向UE4编辑器工作的脚本插件，`PythonScriptPlugin`应当有其用武之地。后面有空再慢慢探索。
