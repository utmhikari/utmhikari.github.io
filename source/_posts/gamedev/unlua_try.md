---
title: 【游戏开发】用Lua编写UE4游戏逻辑——UnLua上手
date: 2020/08/02 16:26:55
categories:
- 游戏开发
tags:
- UE4
- UnLua
- lua
- 游戏开发
- C++
---

大型的游戏项目包含许多错综复杂的业务逻辑，针对UE4游戏而言，如果纯粹采用C++编写的话，一方面会增加大量的劳动成本，影响效率，另一方面难以解决游戏热更的问题。lua作为胶水语言，能够与C/C++/C#等语言互通，简化业务逻辑编写，并且支持热更。针对UE4的游戏开发，[UnLua](https://github.com/Tencent/UnLua)以及[sluaunreal](https://github.com/Tencent/sluaunreal)都是采用lua编写逻辑的解决方案。

作为一个没有怎么接触过游戏开发技术栈的小白，本文主要上手UnLua的使用。

<!-- more -->

从github上，我们可以clone下来示例的project，编译后即可运行。整个demo的逻辑是在一个空间中自动生成AI敌人，玩家需要射击AI以保全自身，如果碰到AI即游戏失败。整个游戏的逻辑基本在`Content/Script`下的lua文件中，对于开发者而言，只需要`创建蓝图——导出Lua脚本——编写逻辑`，就能够完成需求。

编辑器采用VSCode + Emmylua + C/C++的搭配即可，如果有debug需求可以VS搭配Code。要导出UnLua解析的UE4的lua接口，在`UnLuaIntelliSense.Build.cs`中修改至`ENABLE_INTELLISENSE=1`，然后重新构建，即可导出lua定义到`Plugins/UnLua/Intermediate/IntelliSense`，之后调整workspace的配置即可：

```json
{
    "settings": {
        "emmylua.source.roots": ["./Plugins/UnLua/Intermediate/IntelliSense"]
    }
}
```

我们可以对示例教程中的子弹进行改装。我们可以增加一个`CustomProjectile`，其蓝图实例为`BP_CustomProjectile`，并实现UnLua的接口。我们可以自定义其Static Mesh的形状以及材质。之后，通过蓝图窗口的`lua template`可以在项目中导出蓝图接口`BP_CustomProjectile_C.lua`，而不需要自己编写蓝图逻辑。然后在蓝图的`Interfaces`中选中`Get Module Name`，返回`BP_CustomProjectile_C`所在位置即可。

首先对于CustomProjectile，可以自定义一个`ProjectileInitializer.lua`：

```lua
require "UnLua"

_G.ProjectileInitializer = ProjectileInitializer or {}

function ProjectileInitializer:GetRandomColor()
    local R = UE4.UKismetMathLibrary.RandomFloat()
    local G = UE4.UKismetMathLibrary.RandomFloat()
    local B = UE4.UKismetMathLibrary.RandomFloat()
    return UE4.FLinearColor(R, G, B, 1.0)
end

function ProjectileInitializer:GetInitializer()
    local color = self:GetRandomColor()
    return {
        Color = color,
        Ratio = (color.R + color.G + color.B) / 3,
    }
end

return ProjectileInitializer
```

之后可以编写`BP_CustomProjectile_C`的代码，和`BP_DefaultProjectile_C`基本相同：

```lua
require "UnLua"

local BP_CustomProjectile_C = Class("Weapon.BP_ProjectileBase_C")

function BP_CustomProjectile_C:Initialize(Initializer)
    self.BaseColor = Initializer.Color
    self.DamageRatio = Initializer.Ratio or 0.1
end

function BP_CustomProjectile_C:UserConstructionScript()
    self.Super.UserConstructionScript(self)
    self.Damage = self.Damage * self.DamageRatio
    print("Projectile Damage: " .. tostring(self.Damage));
    self.DamageType = UE4.UClass.Load("/Game/Core/Blueprints/BP_DamageType.BP_DamageType_C")
end

function BP_CustomProjectile_C:ReceiveBeginPlay()
    self.Super.ReceiveBeginPlay(self)
    local MID = self.StaticMesh:CreateDynamicMaterialInstance(0)
    if MID then
        MID:SetVectorParameterValue("BaseColor", self.BaseColor)
    end
end

return BP_CustomProjectile_C
```

这样即可根据颜色深度来判断projectile的伤害，实现伤害随机的效果。

对于UMG而言，也可以在UMG蓝图中先设置各个控件为变量，然后调用各个变量的反射接口以设置控件属性。

```lua
require "UnLua"

local UMG_Main_C = Class()

UMG_Main_C.ExitBtnText = "Hello World"

function UMG_Main_C:Construct()
    if not self.ExitButtonTextBlock then
        print("exit button text is nil!")
    else
        print("bind exit button text...")
        self.ExitButtonTextBlock:SetText(UMG_Main_C.ExitBtnText)
    end
    self.ExitButton.OnClicked:Add(self, UMG_Main_C.OnClicked_ExitButton)	
    --self.ExitButton.OnClicked:Add(self, function(Widget) UE4.UKismetSystemLibrary.ExecuteConsoleCommand(Widget, "exit") end )
end

function UMG_Main_C:OnClicked_ExitButton()
    UE4.UKismetSystemLibrary.ExecuteConsoleCommand(self, "exit")
end

return UMG_Main_C

```

从一个UE4初学者角度而言，UnLua的熟悉会有一定壁垒，需要建立在对UE4的C++变成较为熟悉的基础上，才能熟练应用。UnLua/sluaunreal相对于蓝图解决了一个最大的问题是逻辑的可维护性以及可热更的能力，以便支持业务逻辑的快速迭代。lua本身是没有强制静态类型的，虽然最近已有了[teal](https://github.com/teal-language/tl)的产生，但整个生态还没有完全兴起。因此如果使用lua作为胶水语言，不在lua层先做一两层业务抽象再写逻辑的话，还不如直接写C++来的稳定。因此，针对初学者或者是独立开发者，用C++加上蓝图是更加妥当的选择。

That's it，游戏开发是一门很独特的技术栈，还有许多值得探索的东西。自己虽然没有从事游戏开发工作，但说不定有一天，能够自己写一个自己的游戏呢。
