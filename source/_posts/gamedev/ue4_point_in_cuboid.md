---
title: 【游戏开发】UE4下判断一个点是否在特定长方体内的计算方法
date: 2021/09/01 20:40:03
categories:
- 游戏开发
tags:
- UE4
- 数学
- 源码分析
- NavModifierVolume
- 旋转矩阵
---

近期在研究寻路功能的测试工作，需要对玩家寻路过程中的行进轨迹进行采样，判断采样点是否在特定的寻路区域内。UE4自带了`NavModifierVolume`的actor，可以放置到场景里标识某个区域的寻路成本（不了解寻路相关背景的话可以参考[先前的文章](https://utmhikari.top/2021/08/07/gamedev/recastdemo/)），因此我们做采样的时候，也需要判断某个点是否在特定的`NavModifierVolume`里。由于自己所负责的游戏是网游，`NavModifierVolume`最后导出给服务器用了，实际游戏里获取不到这些actor的数据，因此实际测试时，一方面需要下载服务器上的`NavModifierVolume`数据，另一方面还要手写相关的计算方法，来达到我们的工作目的。

`NavModifierVolume`是一个空的长方体，可以旋转成任意形式。因此判断玩家寻路采样点是否在特定寻路区域内，也就必须解决这个数学问题——3D空间下判断一个点是否在特定长方体内。

通常而言，这个问题有以下的解法：

<!-- more -->

- [判断是否在3组平行平面同一侧](https://blog.csdn.net/hit1524468/article/details/79857665)
- [判断坐标是否在XYZ范围内，如果是AABB（对齐坐标轴）](https://developer.mozilla.org/zh-CN/docs/Games/Techniques/3D_collision_detection)

针对UE4环境，一个长方体会包含transform以及单位大小的信息：

- 位置Location：中心点
- 旋转Rotation：Pitch、Yaw、Roll
- 大小比例Scale

因此这个问题可以用这样的步骤解决（应该是对的吧，数学不好= =）：

- 获取中心点到目标点A的向量，其中目标点A是我们需要判断是否在长方体内的点
- 对这个向量进行基于Rotation的逆运算，这样目标点的位置会变化，得到新的目标点B
- 判断目标点B，是否在一个以Location为中心点，Scale*单位长度大小的AABB中

这里面最需要解决的，是如何求旋转。我们可以通过UE内部的源码来寻找思路。

```cpp
// UnrealMath.cpp

FVector FRotator::UnrotateVector(const FVector& V) const
{
    return FRotationMatrix(*this).GetTransposed().TransformVector( V );
}

FVector FRotator::RotateVector(const FVector& V) const
{
    return FRotationMatrix(*this).TransformVector( V );
}
```

由一个旋转`FRotator`（带Pitch、Yaw、Roll属性），以及一个向量，可以直接求得旋转后/逆旋转后的向量。旋转一个向量需要构建特定的[旋转矩阵](https://zh.wikipedia.org/zh-hans/%E6%97%8B%E8%BD%AC%E7%9F%A9%E9%98%B5)，通过矩阵乘法得到新向量分量的值。逆旋转的矩阵则是旋转矩阵的转置，而转换原向量的计算方式也是相同的。

针对不同的坐标系规则，旋转矩阵的计算方法有很多种，而实测UE4用的旋转矩阵也是独特的一种（试过网上的一些旋转矩阵老是有分量正负号不对= =）。在`FRotationMatrix`、`FRotationTranslationMatrix`的定义中，我们可以看到旋转矩阵的构造方法：

```cpp
// RotationTranslationMatrix.h

// Origin should be (0.0, 0.0, 0.0) if not defined
FORCEINLINE FRotationTranslationMatrix::FRotationTranslationMatrix(const FRotator& Rot, const FVector& Origin)
{
    float SP, SY, SR;
    float CP, CY, CR;
    FMath::SinCos(&SP, &CP, FMath::DegreesToRadians(Rot.Pitch));
    FMath::SinCos(&SY, &CY, FMath::DegreesToRadians(Rot.Yaw));
    FMath::SinCos(&SR, &CR, FMath::DegreesToRadians(Rot.Roll));

    M[0][0] = CP * CY;
    M[0][1] = CP * SY;
    M[0][2] = SP;
    M[0][3] = 0.f;

    M[1][0] = SR * SP * CY - CR * SY;
    M[1][1] = SR * SP * SY + CR * CY;
    M[1][2] = - SR * CP;
    M[1][3] = 0.f;

    M[2][0] = -( CR * SP * CY + SR * SY );
    M[2][1] = CY * SR - CR * SP * SY;
    M[2][2] = CR * CP;
    M[2][3] = 0.f;

    M[3][0] = Origin.X;
    M[3][1] = Origin.Y;
    M[3][2] = Origin.Z;
    M[3][3] = 1.f;
}
```

可以看到旋转矩阵是一个4x4的结构（因为可能有设定原点坐标）。而之后，`TransformVector`是这样计算的：

```cpp
// Matrix.inl

// Transform vector
/** 
 * Transform a direction vector - will not take into account translation part of the FMatrix. 
 * If you want to transform a surface normal (or plane) and correctly account for non-uniform scaling you should use TransformByUsingAdjointT.
 */
FORCEINLINE FVector4 FMatrix::TransformVector(const FVector& V) const
{
    return TransformFVector4(FVector4(V.X,V.Y,V.Z,0.0f));
}

// Homogeneous transform.

FORCEINLINE FVector4 FMatrix::TransformFVector4(const FVector4 &P) const
{
    FVector4 Result;
    VectorRegister VecP = VectorLoadAligned(&P);
    VectorRegister VecR = VectorTransformVector(VecP, this);
    VectorStoreAligned(VecR, &Result);
    return Result;
}

// UnrealMathSSE.h

/**
 * Calculate Homogeneous transform.
 *
 * @param VecP VectorRegister 
 * @param MatrixM FMatrix pointer to the Matrix to apply transform
 * @return VectorRegister = VecP*MatrixM
 */
FORCEINLINE VectorRegister VectorTransformVector(const VectorRegister&  VecP,  const void* MatrixM )
{
    const VectorRegister *M = (const VectorRegister *) MatrixM;
    VectorRegister VTempX, VTempY, VTempZ, VTempW;

    // Splat x,y,z and w
    VTempX = VectorReplicate(VecP, 0);
    VTempY = VectorReplicate(VecP, 1);
    VTempZ = VectorReplicate(VecP, 2);
    VTempW = VectorReplicate(VecP, 3);
    // Mul by the matrix
    VTempX = VectorMultiply(VTempX, M[0]);
    VTempY = VectorMultiply(VTempY, M[1]);
    VTempZ = VectorMultiply(VTempZ, M[2]);
    VTempW = VectorMultiply(VTempW, M[3]);
    // Add them all together
    VTempX = VectorAdd(VTempX, VTempY);
    VTempZ = VectorAdd(VTempZ, VTempW);
    VTempX = VectorAdd(VTempX, VTempZ);

    return VTempX;
}
```

最终其实就是原向量`[[x, y, z, 0]]（1x4）`乘以`转置矩阵（4x4）`，得到新的`1x4`的向量，也就是我们需要的旋转后的向量。UE4内部对计算过程做了优化，此处暂不多做分析。

得到了计算向量旋转的方法，我们也可以通过其转置矩阵，进行向量的某个旋转的逆运算，这样目标点相对于中心点的位置有所改变，但对应的长方体就是对齐坐标轴的了。这时就可以直接通过判断点的三个分量是不是在长方体X、Y、Z范围内，就能得出答案。
