---
title: 【游戏开发】UE4用C++编写行为树的Task、Service、Decorator节点
date: 2021/08/21 14:43:15
categories:
- 游戏开发
tags:
- UE4
- C++
- 行为树
- AI
- 行为树节点
---

在游戏领域，行为树是常用的AI解决方案，用行为树可以快速明了地描述AI的行为模型，而UE4提也供了非常完善的行为树解决方案，不仅有用户友好的界面，而且也有多样化的底层支持。在官网的[行为树快速入门指南](https://docs.unrealengine.com/4.27/zh-CN/InteractiveExperiences/ArtificialIntelligence/BehaviorTrees/BehaviorTreeQuickStart/)中，我们可以了解到UE4行为树编辑器的使用以及用蓝图创造行为树节点的方式，而在一些特定的需求当中，蓝图相对于C++并不会非常灵活。因此，笔者稍微研究了下行为树C++层次中的内容，简单分享下行为树里各种节点的C++写法

首先上一张行为树完整图，是基于[场景查询系统（EQS）快速入门](https://docs.unrealengine.com/4.27/zh-CN/InteractiveExperiences/ArtificialIntelligence/EQS/EQSQuickStart/)制作的：

<!-- more -->

![btree](/uploads/gamedev/ue4_cpp_btree_nodes/btree.png ''btree'')

在[官网EQS入门](https://docs.unrealengine.com/4.27/zh-CN/InteractiveExperiences/ArtificialIntelligence/EQS/EQSQuickStart/)的例子中，AI大致遵循这样的逻辑：

- 没看到玩家，特定范围随机某个点巡逻
- 视觉感知到玩家，会转向看着玩家
- 玩家离开视线，调用EQS找到当前时刻最好的能看到玩家的位置，走过去
- 看不到玩家，再回到随机巡逻

而在笔者的行为树完整图中，添加了以下的节点：

- 任务节点（Task）：JumpForNTimes -> 跳N次
- 服务节点（Service）：TraceDistance -> 监控AI到某个点的距离
- 装饰器节点（Decorator）：CheckActorDistance -> 检查AI到某个Actor的距离

最终想要达到的AI目的：

- 没看到玩家，特定范围随机某个点巡逻
- 视觉感知到玩家，会转向看着玩家，然后跳N次（JumpForNTimes），并且会在屏幕实时打印AI跟玩家的距离（TraceDistance）
- 玩家离开视线，调用EQS找到当前时刻最好的能看到玩家的位置，走过去
- 看不到玩家，再回到随机巡逻。但如果玩家再次接近到一定距离，AI会“警觉”（CheckActorDistance），执行跳N次的操作

下面就一起来看下这三个节点具体的写法。在写这些行为树节点具体逻辑之前，首先需要在`Build.cs`的`PublicDependencyModuleNames`加上`AIModule`跟`GameplayTasks`，保证三种节点所需要的方法都能支持

## Task节点：JumpForNTimes

[task节点](https://docs.unrealengine.com/4.27/zh-CN/InteractiveExperiences/ArtificialIntelligence/BehaviorTrees/BehaviorTreeNodeReference/BehaviorTreeNodeReferenceTasks/)表示AI实际的一种操作，我们在UE4源码的`Runtime/AIModule/Classes/BehaviorTree/Tasks`中能够看到预设的许多task节点的定义。`JumpForNTimes`这类操作并不是瞬时的，需要跳完N次后才会执行后面的动作，因此在写法上，可以参考`BTTask_Wait`的实现。

首先创建`BTTask_JumpForNTimes`类，继承`UBTTaskNode`

```cpp
// BTTask_JumpForNTimes.h

struct FBTJumpForNTimesTaskMemory
{
    int32 JumpTimesInternal;
};


/**
 * jump for n times btree task
 */
UCLASS()
class TESTEQS_API UBTTask_JumpForNTimes : public UBTTaskNode
{
    GENERATED_UCLASS_BODY()

    /** jump times */
    UPROPERTY(Category = Jump, EditAnywhere)
    int32 JumpTimes;

    virtual EBTNodeResult::Type ExecuteTask(UBehaviorTreeComponent& OwnerComp, uint8* NodeMemory) override;

    virtual uint16 GetInstanceMemorySize() const override;

#if WITH_EDITOR
    virtual FName GetNodeIconName() const override;
#endif // WITH_EDITOR

protected:

    virtual void TickTask(UBehaviorTreeComponent& OwnerComp, uint8* NodeMemory, float DeltaSeconds) override;
};
```

- UBTTask_JumpForNTimes：JumpForNTimes任务节点定义
  - JumpTimes：跳跃次数，是需要我们在编辑器里设置的内容，因此需要标注`UPROPERTY`+`EditAnywhere`
  - ExecuteTask：任务执行时的逻辑。
    - `EBTNodeResult`是task节点执行的结果表示
    - 对于非瞬时完成的任务（比如Wait），可以在`ExecuteTask`接口中返回`EBTNodeResult::InProgress`（任务进行中），并在后面的`TickTask`中判断完成条件，执行`FinishLatentTask(OwnerComp, EBTNodeResult)`来通知任务的完成结果
  - TickTask：每个tick中该任务执行的逻辑
  - GetInstanceMemorySize：获取节点实例自己的内存空间大小，用于预分配内存
  - GetNodeIconName：编辑器里节点icon
- FBTJumpForNTimesTaskMemory：我们任务节点自带的内存空间，放着节点私有的变量
  - JumpTimesInternal：实际用来记录跳跃次数的计数器
  - 在GetInstanceMemorySize返回sizeof结构体，这样引擎会预分配相应大小的内存块
  - 在ExecuteTask、TickTask可以通过转换uint8* NodeMemory获得内存块对应结构体的实例

在cpp逻辑里，`JumpForNTimes`可以这样实现：

```cpp
// BTTask_JumpForNTimes.cpp

// 构造函数，启用tick -> bNotifyTick = true
UBTTask_JumpForNTimes::UBTTask_JumpForNTimes(const FObjectInitializer& ObjectInitializer) : Super(ObjectInitializer)
{
    NodeName = "JumpForNTimes";
    JumpTimes = 3;
    bNotifyTick = true;
}

// 开始执行任务，先重置JumpTimesInternal，返回InProgress
EBTNodeResult::Type UBTTask_JumpForNTimes::ExecuteTask(UBehaviorTreeComponent& OwnerComp, uint8* NodeMemory)
{
    if (JumpTimes <= 0)
    {
        return EBTNodeResult::Failed;
    }

    FBTJumpForNTimesTaskMemory* MyMemory = (FBTJumpForNTimesTaskMemory*)NodeMemory;
    MyMemory->JumpTimesInternal = JumpTimes;

    const AController* Controller = Cast<AController>(OwnerComp.GetOwner());
    ACharacter* Character = Controller ? Controller->GetCharacter() : nullptr;
    if (!Character)
    {
        return EBTNodeResult::Failed;
    }

    return EBTNodeResult::InProgress;
}

// 在tick中，检查玩家是否在跳跃过程
// 如果没有的话，看下计数是否到0，到0了就不跳，还没有就继续跳
void UBTTask_JumpForNTimes::TickTask(UBehaviorTreeComponent& OwnerComp, uint8* NodeMemory, float DeltaSeconds)
{
    
    const AController* Controller = Cast<AController>(OwnerComp.GetOwner());
    ACharacter* Character = Controller ? Controller->GetCharacter() : nullptr;
    if (!Character) {
        FinishLatentTask(OwnerComp, EBTNodeResult::Failed);
        return;
    }
    
    if (!Character->GetMovementComponent()->IsFalling())
    {
        FBTJumpForNTimesTaskMemory* MyMemory = (FBTJumpForNTimesTaskMemory*)NodeMemory;
        if (MyMemory->JumpTimesInternal <= 0)
        {
            FinishLatentTask(OwnerComp, EBTNodeResult::Succeeded);
        }
        else if (!Character->bPressedJump)
        {
            Character->Jump();
            MyMemory->JumpTimesInternal--;
            UE_LOG(LogTemp, Log, TEXT("[BTTask_JumpForNTimes] JumpTimes--"))
        }
    }
}

// 返回结构体大小
uint16 UBTTask_JumpForNTimes::GetInstanceMemorySize() const
{
    return sizeof(FBTJumpForNTimesTaskMemory);
}

#if WITH_EDITOR
// 随便返回个icon名字就好了
FName UBTTask_JumpForNTimes::GetNodeIconName() const
{
    // use MakeNoise icon for jump~
    return FName("BTEditor.Graph.BTNode.Task.MakeNoise.Icon");
}
#endif
```

## Service节点：TraceDistance

[Service节点](https://docs.unrealengine.com/4.27/zh-CN/InteractiveExperiences/ArtificialIntelligence/BehaviorTrees/BehaviorTreeNodeReference/BehaviorTreeNodeReferenceServices/)通常用于在某个行为节点/分支执行过程中，执行响应的检查逻辑更新黑板，亦或是作为sidecar式的逻辑监控节点/分支的运行情况。

TraceDistance只用于实时监控AI到某个点的距离，并且在屏幕上打印数据。在实现上可以参考已有的`BTService_DefaultFocus`跟`BTService_RunEQS`来写

```cpp
// BTService_TraceDistance.h

UCLASS()
class TESTEQS_API UBTService_TraceDistance : public UBTService_BlackboardBase
{
    GENERATED_BODY()

protected:
    UBTService_TraceDistance(const FObjectInitializer& ObjectInitializer = FObjectInitializer::Get());


    virtual void TickNode(UBehaviorTreeComponent& OwnerComp, uint8* NodeMemory, float DeltaSeconds) override;
    virtual void OnCeaseRelevant(UBehaviorTreeComponent& OwnerComp, uint8* NodeMemory) override;

#if WITH_EDITOR
    virtual FName GetNodeIconName() const override;
#endif // WITH_EDITOR
    
private:
    static const int32 LogKey = 9527;
};
```

在头文件里定义`UBTService_TraceDistance`，继承`UBTService_BlackboardBase`。`UBTService_BlackboardBase`默认提供了一个可选黑板Key的属性，在编辑器里可以看到这个选项的。其他属性如下：

- `TickNode`是这个Service生命周期里的一个hook函数，表示每Tick的行为
- `OnCeaseRelevant`也是这个Service生命周期里的hook函数，表示当行为树运行到和这个Service不相关（Service结束服务）时候的逻辑操作
- 当然除了这两者还有一个`OnBecomeRelevant`钩子表示当运行到和Service相关的节点/分支时候的逻辑操作。

我们打算在每个tick时候在特定的`LogKey`打印AI与玩家的距离，而在玩家没法再看到（TargetActor被清空）时候打印“追踪距离结束”的字样。因此cpp里可以这样写：

```cpp
// BTService_TraceDistance.cpp

UBTService_TraceDistance::UBTService_TraceDistance(const FObjectInitializer& ObjectInitializer)
    : Super(ObjectInitializer)
{
    NodeName = "Trace Distance";

    // 启用tick跟CeaseRelevant，不启用BecomeRelevant
    bNotifyTick = true;
    bTickIntervals = true;
    bNotifyBecomeRelevant = false;
    bNotifyCeaseRelevant = true;

    // accept only actors and vectors，限制只能选某个特定位置，或者actor
    BlackboardKey.AddObjectFilter(this, GET_MEMBER_NAME_CHECKED(UBTService_TraceDistance, BlackboardKey), AActor::StaticClass());
    BlackboardKey.AddVectorFilter(this, GET_MEMBER_NAME_CHECKED(UBTService_TraceDistance, BlackboardKey));
}

void UBTService_TraceDistance::TickNode(UBehaviorTreeComponent& OwnerComp, uint8* NodeMemory, float DeltaSeconds)
{
    if (!GEngine)
    {
        return;
    }

    // get controlled pawn location
    const AController* Controller = Cast<AController>(OwnerComp.GetOwner());
    APawn* Pawn = Controller ? Controller->GetPawn() : nullptr;
    if (!Pawn)
    {
        GEngine->AddOnScreenDebugMessage(LogKey, 5.0f, FColor::Red, TEXT("cannot get controlled pawn"));
        return;
    }
    FVector PawnLoc = Pawn->GetActorLocation();
    
    // get target location
    UBlackboardComponent* Blackboard = OwnerComp.GetBlackboardComponent();
    if (!Blackboard)
    {
        GEngine->AddOnScreenDebugMessage(LogKey, 5.0f, FColor::Red, TEXT("cannot get blackboard"));
        return;
    }
    float Distance = 0.0f;
    if (BlackboardKey.SelectedKeyType == UBlackboardKeyType_Object::StaticClass())
    {
        // object
        UObject* KeyValue = Blackboard->GetValue<UBlackboardKeyType_Object>(BlackboardKey.GetSelectedKeyID());
        AActor* TargetActor = Cast<AActor>(KeyValue);
        if (TargetActor)
        {
            Distance = FVector::Distance(PawnLoc, TargetActor->GetActorLocation());
        }
    }
    else
    {
        // vector
        FVector DestLoc = Blackboard->GetValue<UBlackboardKeyType_Vector>(BlackboardKey.GetSelectedKeyID());
        Distance = FVector::Distance(PawnLoc, DestLoc);
    }
    
    // print log
    FString Msg = FString::Printf(TEXT("distance to destination: %.2f"), Distance);
    GEngine->AddOnScreenDebugMessage(LogKey, 5.0f, FColor::Yellow, Msg);

    Super::TickNode(OwnerComp, NodeMemory, DeltaSeconds);
}

void UBTService_TraceDistance::OnCeaseRelevant(UBehaviorTreeComponent& OwnerComp, uint8* NodeMemory)
{
    if (GEngine)
    {
        GEngine->AddOnScreenDebugMessage(LogKey, 5.0f, FColor::Yellow, TEXT("trace distance finished"));
    }
}
```

## Decorator节点：CheckActorDistance

[Decorator装饰器节点](https://docs.unrealengine.com/4.27/zh-CN/InteractiveExperiences/ArtificialIntelligence/BehaviorTrees/BehaviorTreeNodeReference/BehaviorTreeNodeReferenceDecorators/)通常用来表示某种条件判断。条件判断成立后，AI的某些行为是否执行，或者执行优先级，都会有所变化。

在CheckActorDistance装饰器里，我们希望实现判断AI跟某个Actor距离在某个范围内，就优先执行装饰器装饰到的节点/分支的行为。我们可以参照其它预设装饰器的实现，来编写CheckActorDistance的逻辑

```cpp
// BTDecorator_CheckActorDistance.h

/**
 * Check Actor Distance
 * activated if distance to specific actor is in specific radius
 */
UCLASS()
class TESTEQS_API UBTDecorator_CheckActorDistance : public UBTDecorator_BlackboardBase
{
    GENERATED_BODY()


protected:
    UPROPERTY(EditAnywhere, Category = CheckActorDistance)
        float DistanceRadius;


protected:
    virtual bool CalculateRawConditionValue(UBehaviorTreeComponent& OwnerComp, uint8* NodeMemory) const override;

protected:
    UBTDecorator_CheckActorDistance(const FObjectInitializer& ObjectInitializer = FObjectInitializer::Get());
    
};
```

- DistanceRadius：编辑器里需要设置的半径范围
- CalculateRawConditionValue：用来计算装饰器条件是否成立的接口

我们只需要在`CalculateRawConditionValue`里判断距离是否在给定范围内就好。

```cpp
// BTDecorator_CheckActorDistance.cpp

BTDecorator_CheckActorDistance::UBTDecorator_CheckActorDistance(const FObjectInitializer& ObjectInitializer) : Super(ObjectInitializer)
{
    NodeName = "Check Actor Distance";

    BlackboardKey.AddObjectFilter(this, GET_MEMBER_NAME_CHECKED(UBTDecorator_CheckActorDistance, BlackboardKey), AActor::StaticClass());

    // Default to using Self Actor
    BlackboardKey.SelectedKeyName = FBlackboard::KeySelf;
    DistanceRadius = 0.0f;
}

// 判断黑板的某个actor跟ai控制的pawn是不是在给定DistanceRadius内
bool UBTDecorator_CheckActorDistance::CalculateRawConditionValue(UBehaviorTreeComponent& OwnerComp, uint8* NodeMemory) const
{
    if (UKismetMathLibrary::LessEqual_FloatFloat(DistanceRadius, 0.0f))
    {
        return false;
    }

    const UBlackboardComponent* BlackboardComp = OwnerComp.GetBlackboardComponent();
    if (!BlackboardComp)
    {
        return false;
    }

    AActor* TargetActor = Cast<AActor>(BlackboardComp->GetValue<UBlackboardKeyType_Object>(BlackboardKey.GetSelectedKeyID()));
    if (!TargetActor)
    {
        return false;
    }

    const AController* Controller = Cast<AController>(OwnerComp.GetOwner());
    APawn* Pawn = Controller ? Controller->GetPawn() : nullptr;
    if (!Pawn)
    {
        return false;
    }

    float Distance = FVector::Dist(TargetActor->GetActorLocation(), Pawn->GetActorLocation());
    return UKismetMathLibrary::LessEqual_FloatFloat(Distance, DistanceRadius);
}
```

值得一提的是，在黑板里最好加个`LastTargetActor`表示上一个看到的`TargetActor`，然后在AIController里丢失视线的逻辑中，在清空`TargetActor`之前，把`LastTargetActor`设置为当前的`TargetActor`，这样上一个`TargetActor`在丢失视线后回来到一定范围，AI就会有“预警”效果了

## 总结

UE的AIModule非常的大，行为树只是冰山一角，还有很多需要细细研究。
