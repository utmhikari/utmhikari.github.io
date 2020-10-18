---
title: 【极客日常】解决UE4中FJsonObject转USTRUCT的坑
date: 2020/10/18 22:05:13
categories:
- 极客日常
tags:
- UE4
- FJsonObject
- USTRUCT
- C++
- 源码分析
---

前些天在写[UnrealAutomator](https://github.com/utmhikari/UnrealAutomator)的Web解析模块的时候，遇到了一些USTRUCT方面的问题，由于笔者以前并非UE4程序员，因此踩了一些坑，果断分享一下踩坑历程。

首先聊一下USTRUCT的生成。USTRUCT是UE4的特性之一，从非C++/UE4程序员的角度来讲，USTRUCT、UPROPERTY、GENERATED_BODY之类的概念类似于注释和装饰器的作用，可以在编译等时期将代码标识的内涵纳入自己的Runtime。举一个例子，UnrealAutomator中的UIModel.h：

<!-- more -->

```cpp
#pragma once

#include "CoreMinimal.h"
#include "Components/Widget.h"

// 必须要有这个，include之后通过UE4刷新项目生成相关代码，用于支持USTRUCT等宏的识别
#include "UIModel.generated.h"

/**
 * Query template for ui widget
 */
USTRUCT()
struct FUIWidgetQuery
{
    GENERATED_BODY()

public:
    UPROPERTY()
        int32 ID = 0;

    UPROPERTY()
        FString Name = TEXT("");

    UPROPERTY()
        FString Text = TEXT("");

    // properties below are relatively no need to be modified

    UPROPERTY()
        FString ClassName = TEXT("");

    UPROPERTY()
        bool bIsNameAsKeyword = false;

    UPROPERTY()
        bool bIsTextAsKeyword = false;

    FUIWidgetQuery()
        : ID(0)
        , Name(TEXT(""))
        , Text(TEXT(""))
        , ClassName(TEXT(""))
        , bIsNameAsKeyword(false)
        , bIsTextAsKeyword(false)
    {}

    FUIWidgetQuery(int32 InID,
        FString InName,
        FString InText,
        FString InClassName,
        bool bInIsNameAsKeyword,
        bool bInIsTextAsKeyword)
        : ID(InID)
        , Name(InName)
        , Text(InText)
        , ClassName(InClassName)
        , bIsNameAsKeyword(bInIsNameAsKeyword)
        , bIsTextAsKeyword(bInIsTextAsKeyword)
    {}

    // 记得要有cpp文件实现它，当然不管有没有这个函数，都得加一个cpp文件
    bool IsMatch(UWidget* Widget,
        bool bIsDisabledIncluded = false,
        bool bIsInvisibleIncluded = false);
};
```

现在有一个需求，就是把一个以json字符串为body的http request解析成这个USTRUCT，自然而然会需要FJsonObject相关的功能。http request的body原生为`TArray<uint8>`的格式，得先转为`FString`，然后转为`FJsonObject`，之后再转为`USTRUCT`

```cpp
// TArray<uint8> to FString
FString FWebUtil::GetRequestStringBody(const FHttpServerRequest& Request)
{
    // Body to utf8 string, should be called after CheckRequestContent(Request, bIsCheckUTF8 = true)
    TArray<uint8> RequestBodyBytes = Request.Body;
    FString RequestBodyString = FString(UTF8_TO_TCHAR(RequestBodyBytes.GetData()));
    UE_LOG(UALog, Log, TEXT("Request string body: %s"), *RequestBodyString);
    return RequestBodyString;
}

// FString to TSharedPtr<FJsonObject>
TSharedPtr<FJsonObject> FCommonUtil::JsonParse(FString Str)
{
    // string to json
    TSharedRef<TJsonReader<>> JsonReader = TJsonReaderFactory<>::Create(Str);
    TSharedPtr<FJsonObject> JsonObject;
    bool bSuccess = FJsonSerializer::Deserialize(JsonReader, JsonObject);
    if (!bSuccess)
    {
        return nullptr;
    }
    return JsonObject;
}

// TSharedPtr<FJsonObject> to USTRUCT
// 就算用FJsonObjectConverter::JsonObjectStringToUStruct，也需要经历先转到Json再转到USTRUCT的过程
template <typename UStructType>
static bool GetRequestUStructBody(const FHttpServerRequest& Request, UStructType* StructBody)
{
    verifyf(StructBody != nullptr, TEXT("USTRUCT to be converted should not be null~"));

    TSharedPtr<FJsonObject> JsonBody = GetRequestJsonBody(Request);
    if (JsonBody == nullptr)
    {
        return false;
    }

    // extend/update struct with json values
    // 如果原来struct有预设值，在json convert中，会覆盖原来的值
    if (!FJsonObjectConverter::JsonObjectToUStruct<UStructType>(JsonBody.ToSharedRef(), StructBody, 0, 0))
    {
        UE_LOG(UALog, Warning, TEXT("failed to parse json body to ustruct!"))
        return false;
    }

    if (StructBody == nullptr)
    {
        UE_LOG(UALog, Warning, TEXT("cast to USTRUCT failed! struct ptr is still null!"));
        return false;
    }

    UE_LOG(UALog, Log, TEXT("convert to USTRUCT successfully!"));

    return true;
}
```

值得一提的是，json转USTRUCT的过程中，不能通过传空指针USTRUCT的方式企图希望`FJsonObjectConverter::JsonObjectToUStruct`能够对USTRUCT进行重赋值。一方面是C++左右值的特性引起的，另一方面在转属性的过程中，也需要读取原来USTRUCT的属性值相关信息，如果传进去的是空指针就会crash。

```cpp
// 模板json转ustruct函数
template<typename OutStructType>
static bool JsonObjectToUStruct(const TSharedRef<FJsonObject>& JsonObject, OutStructType* OutStruct, int64 CheckFlags = 0, int64 SkipFlags = 0)
{
    return JsonObjectToUStruct(JsonObject, OutStructType::StaticStruct(), OutStruct, CheckFlags, SkipFlags);
}

// 跳到JsonAttributesToUStruct
bool FJsonObjectConverter::JsonObjectToUStruct(const TSharedRef<FJsonObject>& JsonObject, const UStruct* StructDefinition, void* OutStruct, int64 CheckFlags, int64 SkipFlags)
{
    return JsonAttributesToUStruct(JsonObject->Values, StructDefinition, OutStruct, CheckFlags, SkipFlags);
}

// 跳到JsonAttributesToUStructWithContainer
bool FJsonObjectConverter::JsonAttributesToUStruct(const TMap< FString, TSharedPtr<FJsonValue> >& JsonAttributes, const UStruct* StructDefinition, void* OutStruct, int64 CheckFlags, int64 SkipFlags)
{
    return JsonAttributesToUStructWithContainer(JsonAttributes, StructDefinition, OutStruct, StructDefinition, OutStruct, CheckFlags, SkipFlags);
}

bool JsonAttributesToUStructWithContainer(const TMap< FString, TSharedPtr<FJsonValue> >& JsonAttributes, const UStruct* StructDefinition, void* OutStruct, const UStruct* ContainerStruct, void* Container, int64 CheckFlags, int64 SkipFlags)
{
    // 如果是FJsonObjectWrapper，可以直接转换
    if (StructDefinition == FJsonObjectWrapper::StaticStruct())
    {
        // Just copy it into the object
        FJsonObjectWrapper* ProxyObject = (FJsonObjectWrapper *)OutStruct;
        ProxyObject->JsonObject = MakeShared<FJsonObject>();
        ProxyObject->JsonObject->Values = JsonAttributes;
        return true;
    }

    // 如果未声明properties，直接返回
    int32 NumUnclaimedProperties = JsonAttributes.Num();
    if (NumUnclaimedProperties <= 0)
    {
        return true;
    }

    // iterate over the struct properties
    for (TFieldIterator<UProperty> PropIt(StructDefinition); PropIt; ++PropIt)
    {
        UProperty* Property = *PropIt;

        // Check to see if we should ignore this property
        if (CheckFlags != 0 && !Property->HasAnyPropertyFlags(CheckFlags))
        {
            continue;
        }
        if (Property->HasAnyPropertyFlags(SkipFlags))
        {
            continue;
        }

        // find a json value matching this property name
        const TSharedPtr<FJsonValue>* JsonValue = JsonAttributes.Find(Property->GetName());
        if (!JsonValue)
        {
            // we allow values to not be found since this mirrors the typical UObject mantra that all the fields are optional when deserializing
            continue;
        }

        if (JsonValue->IsValid() && !(*JsonValue)->IsNull())
        {
            // 这里就需要取到OutStruct的属性的Value值了，如果是OutStruct是空指针，就会crash掉
            void* Value = Property->ContainerPtrToValuePtr<uint8>(OutStruct);
            if (!JsonValueToUPropertyWithContainer(*JsonValue, Property, Value, ContainerStruct, Container, CheckFlags, SkipFlags))
            {
                UE_LOG(LogJson, Error, TEXT("JsonObjectToUStruct - Unable to parse %s.%s from JSON"), *StructDefinition->GetName(), *Property->GetName());
                return false;
            }
        }

        if (--NumUnclaimedProperties <= 0)
        {
            // If we found all properties that were in the JsonAttributes map, there is no reason to keep looking for more.
            break;
        }
    }

    return true;
}
```

规避了这些坑，FJsonObject转USTRUCT就顺利了
