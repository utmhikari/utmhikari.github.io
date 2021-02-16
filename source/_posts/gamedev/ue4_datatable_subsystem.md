---
title: 【游戏开发】用UE4的Subsystem来管理DataTable表格数据
date: 2021/02/16 23:31:15
categories:
- 游戏开发
tags:
- UE4
- DataTable
- Subsystem
- 游戏开发
- C++
---

在UE4游戏开发中，官方文档推荐了2套功能：[Data Driven Gameplay Elements](https://docs.unrealengine.com/en-US/InteractiveExperiences/DataDriven/index.html)以及[Programming Subsystems](https://docs.unrealengine.com/en-US/ProgrammingAndScripting/Subsystems/index.html)。我们可以结合这两者的功效，实现一个简单的表格配置数据管理模块。

Data Driven Gameplay Elements讲述了一套通过DataTable数据表的asset驱动gameplay的方式。在C++代码中，我们可以预先定义好表结构所对应的USTRUCT，然后通过导入CSV文件的方式，去创建以该USTRUCT为结构基础的DataTable。这样在游戏里，如果需要读取配置数据的话，就可以直接在蓝图中添加获取DataTable以及获取行数据的节点，填写对应的asset路径与rowname（表格主键，以`---`为标题的列），就能够获得对应行的数据了。注意这种方式如果在需要热更的手游中是不适用的，需要用其他的方式（比如将表格配置转化为lua）

Programming Subsystems讲述了UE的Subsystem编程模式。Subsystem重点解决了单例Manager在游戏中生命周期的问题，并且能够直接导出方法到蓝图中，供蓝图侧调用。

以下，我们观察一个利用Subsystem模式在C++侧创建一个DataTable Manager的功能实例：

<!-- more -->

我们首先定义一个TableSubsystem，依附于GameInstance的生命周期，并作出如下约定：

- 在游戏开始时，加载所有表格的数据
- 表格数据统一存储在`Content/Table`下，由UTF8-BOM的csv导入为DataTable，命名格式为`TB_表名`

因此可以简单写一个类：

```cpp
// TableSubsystem.h
UCLASS()
class FOUNDERBOY_API UTableSubsystem : public UGameInstanceSubsystem
{
    GENERATED_BODY()

private:
    TArray<FString> TableNames;
    TMap<FString, UDataTable*> DB;

public:
    virtual void Initialize(FSubsystemCollectionBase& Collection) override;
    virtual void Deinitialize() override;

    UFUNCTION(BlueprintCallable)
        UDataTable* GetDataTable(const FString& TableName);

private:
    FORCEINLINE FString GetTableAssetPath(const FString& TableName)
    {
        return FString::Printf(TEXT("DataTable'/Game/Table/TB_%s.TB_%s'"), *TableName, *TableName);
    };
    
    UDataTable* LoadDataTableObj(const FString& TableName);
};

// TableSubsystem.cpp
void UTableSubsystem::Initialize(FSubsystemCollectionBase& Collection)
{
    // init table data
    // TODO: load table data by cfg, not in hardcode stype
    TableNames.Add(TEXT("Monster"));

    for (auto TableName : TableNames)
    {
        UDataTable* DT = LoadDataTableObj(TableName);
        if (DT != nullptr)
        {
            DB.Add(TableName, DT);
        }
    }
}

void UTableSubsystem::Deinitialize()
{
    
}


UDataTable* UTableSubsystem::GetDataTable(const FString& TableName)
{
    UDataTable** DT = DB.Find(TableName);
    if (DT == nullptr)
    {
        return nullptr;
    }
    return *DT;
}

UDataTable* UTableSubsystem::LoadDataTableObj(const FString& TableName)
{
    FString AssetPath = GetTableAssetPath(TableName);
    return LoadObject<UDataTable>(nullptr, *AssetPath);
}
```

在这个类中，我们需要假设已经导入了一个Monster表，并且定义了对应的USTRUCT。编译完成之后，就可以在蓝图中使用`GetDataTable`节点获取已经加载的表格数据了：

![获取表格数据](/uploads/gamedev/ue4_datatable_subsystem/bp.png ''获取表格数据'')
