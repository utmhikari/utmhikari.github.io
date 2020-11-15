---
title: 【极客日常】UE4插件通过C++导出LLM数据的方法
date: 2020/11/08 19:53:57
categories:
- 极客日常
tags:
- UE4
- C++
- LLM
- UnrealAutomator
- UE4插件
---

近期为了丰富UE4插件[UnrealAutomator](https://github.com/utmhikari/UnrealAutomator)的基础功能，在ProfileService中增加了[LLM](https://docs.unrealengine.com/en-US/Programming/Development/Tools/LowLevelMemoryTracker/index.html)数据获取的方法。LLM拥有抓取UE4底层模块内存使用情况的功能，各种Modules按照LLM的规范实现相应宏即可将内存使用数据实时更新到LLM系统中。如果从产品外部，是难以直接访问这些信息的。

以UE4.24为例，用C++在UE4插件实现LLM数据获取的方式如下：

<!-- more -->

```cpp
/**
 * See HAL/LowLevelMemTracker.h
 * If detailed info is needed, a proper solution is to make vars/functions explicitly in LLM.h/.cpp
 */
TSharedPtr<FJsonObject> FProfileService::GetLLMStats()
{
#if ENABLE_LOW_LEVEL_MEM_TRACKER && STATS
    FLowLevelMemTracker& LLM = FLowLevelMemTracker::Get();

    // get all tags
    TArray<const TCHAR*> LLMTagNames;
    TArray<ELLMTag> LLMTags;
    TArray<FName> LLMTagStatNames;
    TArray<FName> LLMTagStatGroupNames;
    for (uint64 i = 0; i < (int32)ELLMTag::GenericTagCount; ++i)
    {
        const TCHAR* TagName = LLM.FindTagName(i);
        if (TagName != nullptr && !FString(TagName).Equals(TEXT("?")))
        {
            ELLMTag Tag = static_cast<ELLMTag>(i);
            LLMTags.Push(Tag);
            LLMTagNames.Push(TagName);
            /*LLMTagStatNames.Push(LLMGetTagStat(Tag));
            LLMTagStatGroupNames.Push(LLMGetTagStatGroup(Tag));*/
        }
    }
    for (uint64 i = LLM_CUSTOM_TAG_START; i <= LLM_CUSTOM_TAG_END; i++)
    {
        const TCHAR* TagName = LLM.FindTagName(i);
        if (TagName != nullptr && !FString(TagName).Equals(TEXT("?")))
        {
            ELLMTag Tag = static_cast<ELLMTag>(i);
            LLMTags.Push(Tag);
            LLMTagNames.Push(TagName);
            /*LLMTagStatNames.Push(LLMGetTagStat(Tag));
            LLMTagStatGroupNames.Push(LLMGetTagStatGroup(Tag));*/
        }
    }
    int32 NumTags = LLMTags.Num();
    UE_LOG(LogUnrealAutomator, Log, TEXT("Found %d LLM Tags!"), NumTags);
    if (NumTags == 0)
    {
        return nullptr;
    }

    // update stats
    LLM.UpdateStatsPerFrame();

    // gather amount
    TArray<TSharedPtr<FJsonValue>> LLMStatsArray;
    for (int32 i = 0; i < LLMTags.Num(); i++)
    {
        TSharedPtr<FJsonObject> TagAmountJson = MakeShareable(new FJsonObject());
        TagAmountJson->SetNumberField(TEXT("Amount"), LLM.GetTagAmountForTracker(ELLMTracker::Default, LLMTags[i]));
        TagAmountJson->SetStringField(TEXT("TagName"), LLMTagNames[i]);
        TagAmountJson->SetNumberField(TEXT("TagNum"), static_cast<uint64>(LLMTags[i]));
        /*TagAmountJson->SetStringField(TEXT("StatName"), LLMTagStatNames[i].ToString());
        TagAmountJson->SetStringField(TEXT("StatGroupName"), LLMTagStatGroupNames[i].ToString());*/
        LLMStatsArray.Push(MakeShareable(new FJsonValueObject(TagAmountJson)));
    }

    // make json
    TSharedPtr<FJsonObject> LLMStats = MakeShareable(new FJsonObject());
    LLMStats->SetArrayField(TEXT("Data"), LLMStatsArray);
    LLMStats->SetNumberField(TEXT("Count"), LLMStatsArray.Num());
    return LLMStats;
#else
    UE_LOG(LogUnrealAutomator, WARNING, TEXT("Cannot get LLM stats! STATS or ENABLE_LOW_LEVEL_MEM_TRACKER macro not enabled!"));
    return nullptr;
#endif
}
```

LLM追踪内存，默认给了70多个tag，如果用户需要把自己的模块加进去可以加到custom tag里。用这个实现基本能导出这些tag的实时占用数据。

值得一提的是，在引擎默认LLM的实现当中（`Core/HAL/Public/LowLevelMemTracker.h`与`Core/HAL/Private/LowLevelMemTracker.cpp`），默认屏蔽了内部的一些类以及extern函数的实现，使得用户无法通过`MODULE_API`的方式直接访问相应的数据结构及功能。如果实在有深入挖掘的需求，比如说区分`stat LLMFULL`与`LLM summary`，需要考虑更改引擎的代码，公开一部分模块内容，修改`LLMGetTagStat`与`LLMGetTagStatGroup`实现去支持custom tag，从而更加方便实现需求。

再提一嘴，除了LLM之外，如果要获得其它的stat数据，可以采用[Hook Stats](https://answers.unrealengine.com/questions/550271/saving-stats-to-file.html?sort=oldest)的方式进行。这块以后有空再慢慢研究~
