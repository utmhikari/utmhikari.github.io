---
title: 【极客日常】在UE4插件中编写一个HTTP Web Server
date: 2020/05/23 13:33:33
categories:
- 极客日常
tags:
- C++
- Unreal
- HTTP Server
- Web开发
- UE4插件
---

在某些游戏研发or测试的需求中，需要在Unreal增加一个插件或者模块，里面启动一个服务器作为SDK，然后外部通过直连或者adb forward可以连接到客户端中，获取客户端实时的场景、actor信息等等。UE4本身除了socket server支持之外，也支持简单的HTTP Web Server。由于网上没有比较好的范例，因此这里给出一个例子。

本文以Unreal 4.24为例。搭建HTTP Server，需要在`.Build.cs`中引入如下模块：

```csharp
PrivateDependencyModuleNames.AddRange(
    new string[]
    {
        "CoreUObject",
        "Engine",
        "Slate",
        "SlateCore",
        // ... add private dependencies that you statically link with here ...
        "HTTP",
        "HttpServer",
        "JsonUtilities",
        "Json",
    }
    );
```

通过`FHttpServerModule::Get()`方法，可以获得内置的HTTP Server模块的一个单例，该instance负责管理内置private的socket listeners。我们可以通过该单例获取`HTTPRouter`，然后绑定路由跟handler，然后调用`StartAllListeners`，就能够启动Web服务器。具体代码如下：

<!-- more -->

```cpp
#include "Runtime/Online/HTTPServer/Public/HttpServerModule.h"
#include "Runtime/Online/HTTPServer/Public/HttpPath.h"

void Start()
{
    // 如果插件module type为runtime之类，只要包括编辑器的，就加这个判断，这样编辑器里不会直接启动server，而standalone时候可以启动
    // 如果编辑器里直接启动了，那么改代码重新编译会卡住
    if (!GIsEditor)
    {
        StartServer(Port);
    }
}

void StartServer(uint32 Port)
{
    auto HttpServerModule = &FHttpServerModule::Get();
    TSharedPtr<IHttpRouter> HttpRouter = HttpServerModule->GetHttpRouter(Port);
    // 这里注意一个点，就是底层不支持相同http path配置不同的request method
    HttpRouter->BindRoute(FHttpPath(TEXT("/health")), EHttpServerRequestVerbs::VERB_GET, HEALTH_CHECK_HANDLER);
    HttpServerModule->StartAllListeners();
}
```

其中，HEALTH_CHECK_HANDLER需要传进来一个TFunction，可以通过相关代码查阅到。

```cpp
// Runtime\Online\HTTPServer\Private\HttpRouter.cpp

FHttpRouteHandle FHttpRouter::BindRoute(const FHttpPath& HttpPath,  const EHttpServerRequestVerbs& HttpVerbs,  const FHttpRequestHandler& Handler)
{
    check(HttpPath.IsValidPath());
    check(EHttpServerRequestVerbs::VERB_NONE != HttpVerbs);

    if (RequestHandlerRegistrar->Contains(HttpPath.GetPath()))
    {
        return nullptr;
    }

    auto RouteHandle = MakeShared<FHttpRouteHandleInternal>(HttpPath.GetPath(), HttpVerbs, Handler);
    RequestHandlerRegistrar->Add(HttpPath.GetPath(), RouteHandle);

    return RouteHandle;
}

// Runtime\Online\HTTPServer\Public\HttpRequestHandler.h

/**
 * FHttpRequestHandler
 *
 *  NOTE - Returning true implies that the delegate will eventually invoke OnComplete
 *  NOTE - Returning false implies that the delegate will never invoke OnComplete
 * 
 * @param Request The incoming http request to be handled
 * @param OnComplete The callback to invoke to write an http response
 * @return True if the request has been handled, false otherwise
 */
typedef TFunction<bool(const FHttpServerRequest& Request, const FHttpResultCallback& OnComplete)> FHttpRequestHandler;

// Runtime\Online\HTTPServer\Public\HttpResultCallback.h

/**
* FHttpResultCallback
* This callback is intended to be invoked exclusively by FHttpRequestHandler delegates
* 
* @param Response The response to write
*/
typedef TFunction<void(TUniquePtr<FHttpServerResponse>&& Response)> FHttpResultCallback;
```

在FHttpRequestHandler函数内部中，如果调用了`OnComplete(Response)`但`return false`的话，会`CHECK`不过造成程序crash。因此，可以封装一个生成`FHttpRequestHandler`的函数，使得实际只需要根据Request返回一个Response就可以。我们把这种函数自定义为`FHttpResponser`：

```cpp
typedef TFunction<TUniquePtr<FHttpServerResponse>(const FHttpServerRequest& Request)> FHttpResponser;

FHttpRequestHandler CreateHandler(const FHttpResponser& HttpResponser)
{
    return [HttpResponser](const FHttpServerRequest& Request, const FHttpResultCallback& OnComplete)
    {
        auto Response = HttpResponser(Request);
        if (Response == nullptr)
        {
            return false;
        }
        OnComplete(MoveTemp(Response));
        return true;
    };
}
```

然后我们实际只需要编写`FHttpResponser`就可以了。比如上面的HEALTH_CHECK_HANDLER例子如下：

```cpp
TUniquePtr<FHttpServerResponse> HealthCheck(const FHttpServerRequest& Request)
{
    UE_LOG(UALog, Log, TEXT("Health Check"));
    if (GEngine != nullptr)
    {
        GEngine->AddOnScreenDebugMessage(-1, 10.0f, FColor::Green, TEXT("Health Check Successfully!"));
    }
    return SuccessResponse("Health Check Successfully!");
}

// HttpRouter->BindRoute(
//     FHttpPath(TEXT("/health")),
//     EHttpServerRequestVerbs::VERB_GET,
//     CreateHandler(&FBaseHandler::HealthCheck));


TUniquePtr<FHttpServerResponse> SuccessResponse(TSharedPtr<FJsonObject> Data, FString Message)
{
    return JsonResponse(Data, Message, true, SUCCESS_CODE);
}

TUniquePtr<FHttpServerResponse> JsonResponse(TSharedPtr<FJsonObject> Data, FString Message, bool Success, int32 Code)
{
    TSharedPtr<FJsonObject> JsonObject = MakeShareable(new FJsonObject());
    JsonObject->SetObjectField(TEXT("data"), Data);
    JsonObject->SetStringField(TEXT("message"), Message);
    JsonObject->SetBoolField(TEXT("success"), Success);
    JsonObject->SetNumberField(TEXT("code"), (double)Code);
    FString JsonString;
    TSharedRef<TJsonWriter<>> Writer = TJsonWriterFactory<>::Create(&JsonString);
    FJsonSerializer::Serialize(JsonObject.ToSharedRef(), Writer);
    return FHttpServerResponse::Create(JsonString, TEXT("application/json"));
}
```

由于一般HTTP返回的body是json，因此可以像上述一样另外封装作为模板response body的函数。对于request body，要转换为json，可以另外加函数去获取`TSharedPtr<FJsonObject>`的request json body实例。首先检查header是否为json格式，然后转化为json。采用`UTF8_TO_TCHAR`方法可以支持转换中文。

```cpp
TSharedPtr<FJsonObject> GetRequestJsonBody(const FHttpServerRequest& Request)
{
    // check if content type is application/json
    bool IsUTF8JsonContent = IsUTF8JsonRequestContent(Request);
    if (!IsUTF8JsonContent)
    {
        UE_LOG(UALog, Warning, TEXT("caught request not in utf-8 application/json body content!"));
        return nullptr;
    }

    // body to utf8 string
    TArray<uint8> RequestBodyBytes = Request.Body;
    FString RequestBodyString = FString(UTF8_TO_TCHAR(RequestBodyBytes.GetData()));

    // string to json
    TSharedRef<TJsonReader<>> JsonReader = TJsonReaderFactory<>::Create(RequestBodyString);
    TSharedPtr<FJsonObject> RequestBody;
    if (!FJsonSerializer::Deserialize(JsonReader, RequestBody))
    {
        UE_LOG(UALog, Warning, TEXT("failed to parse request string to json: %s"), *RequestBodyString);
        return nullptr;
    }
    return RequestBody;
}

bool IsUTF8JsonRequestContent(const FHttpServerRequest& Request)
{
    bool bIsUTF8JsonContent = false;
    for (auto& HeaderElem : Request.Headers)
    {
        if (HeaderElem.Key == TEXT("Content-type"))
        {
            for (auto& Value : HeaderElem.Value)
            {
                auto LowerValue = Value.ToLower();
                if (LowerValue.StartsWith(TEXT("charset=")) && LowerValue != TEXT("charset=utf-8"))
                {
                    return false;
                }
                if (LowerValue == TEXT("application/json") || LowerValue == TEXT("text/json"))
                {
                    bIsUTF8JsonContent = true;
                }
            }
        }
    }
    return bIsUTF8JsonContent;
}
```

这样，UE4的一个基本的C++ HTTP Web Server就成型了。
