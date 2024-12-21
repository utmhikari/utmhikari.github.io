---
title: 【Python随笔】Enigma密码机的原理及python代码实现
date: 2024/12/21 17:55:59
categories:
- Python随笔
tags:
- python
- Enigma
- 密码学
- Cypher
- 面向对象
---

最近笔者接触到了Cypher这款游戏，玩法很简单，就是通过文字、图片等各种表达手段组成的谜面，猜一段英文，算是初步接触了密码学的一些知识。游戏中提到了很多类型的密码，其中Enigma密码机就是单独一种，在电影《模仿游戏》中，夏洛克.福尔摩斯费尽心力破解的德军密码，也就出自此密码机之手。在游戏里，有一道题目便是，需要根据Enigma密码机的初始设置，破译一段密文，得到明文。没办法，为了解出来这道题，只能发挥程序员的职业本性，写一段程序来跑一下了。

今天，笔者就分享一下自己用python实现的Enigma密码机，虽然代码非常粗糙，有很多优化空间，但整体逻辑比较清晰，尤其是解Cypher游戏里的题目，已经够用了。

简单来讲，一个Engima密码机是分层的，包含以下几个部分：

<!-- more -->

第一层是Keyboard键盘，是输入输出的部分，输入26个字母，输出的字母可能是26个字母之一。从打字人员的视角，按下键盘上某个字母之后，经过加密，对应密文的字母就会亮起来。

第二层是Plugboard接线板，接线板本质上会把一些字母的输入输出做交换，比如A和B两个字母接起来了，那么输入A输出就是B，反之输入B输出就是A，是一个很简单的置换密码。

第三层叫做Scrambler扰码器，在Enigma构成里也叫做Rotor转子，是整个Enigma密码机最核心的加密部分。虽然扰码器的输入是26个字母，输出也是26个字母的另一种排列，但其复杂度在于，每打一个字母，转子会转一下。比方说转子是ABCD对应DCBA，现在你输一个A，转子出来一个D，但下一次你输A就不是D了，而是C，这是因为转子转了一下，变成BCDA对应CBAD，你输A其实一直对应转子第一个位置，下一次就变成B的位置了，所以就会出来C。所以说，有了这个Scrambler，加密会变得更加复杂，而且转子起始位置不同的话，出来的结果也会不一样。

除此之外，转子还可以叠加，比如叠3个转子，第1个转子转满一圈，第2个转子转1次，第2个转子转满1圈，第3个转子转1次。这样叠下来，复杂度就更高了。如果不了解扰码器的字母映射，不了解转子起始位置，基本破解不出来。

最后一层是Reflector反射器，是Enigma构成里最鬼才的设计。有了这个东西，Enigma就成了自对称加密，也就是说，你输入明文，可能出来一组密文，但你复位到初始设置之后，输入密文，就会把最开始的明文输出出来。Reflector本身也是和Plugboard一样的接线板设计，但在整个加密过程中只经过一次，而不像其他部分经过两次。整个加密步骤是这样的：

- Keyboard输入1个字母
- 第1个转子转一下，可能带动后面的转子转
- 经过Plugboard，看是从当前位置出口输出，还是从某个接线位置的出口输出
- 逐层经过Scrambler转子1～3，从对应位置输入，从映射到的字母的当前位置输出
- 经过Reflector，从Scrambler输出的位置输入，从对应字母的当前位置输出
- 逐个反向经过Scrambler转子3～1，从上一个输出的位置输入，从映射到的字母的当前位置输出
- 反向经过Plugboard，再看是从当前位置返回给Keyboard，还是某个接线的位置返回
- 反向经过Keyboard，输出对应位置的字母

所以整个逻辑捋下来，Enigma密码机重点并非字母之间的映射，而是不同层次之间接线扣子索引位置的映射。而且，当你输入时，其实输入到输出的全加密过程的连线已经连好了，所以反过来也是一样，你输入密文，也会跟着这条连线，最终走到明文对应的字母。

捋完了逻辑，就可以写代码了，可以用简单的面向对象方式，把每个组件定义清楚。首先是PlugBoard，实现比较简单的字母位置映射：

```python
def to_chararray(o):
    if isinstance(o, list):
        return o
    return [c for c in str(o)]
    

def alphabetical_letters():
    return to_chararray('abcdefghijklmnopqrstuvwxyz')


class Plugboard(object):
    def __init__(self):  # should reflect
        self.inputs = alphabetical_letters()
        self.outputs = alphabetical_letters()
        self.mapping = {}

    def plug_one(self, c1, c2):
        idx1, idx2 = self.inputs.index(c1), self.outputs.index(c2)
        self.mapping[idx1] = idx2
        self.mapping[idx2] = idx1

    def plug_many(self, pairs):
        for c1, c2 in pairs:
            self.plug_one(c1, c2)

    def proxy(self, idx):  # inputs/outputs are the same, so forward & backward no differs
        if idx in self.mapping:
            return self.mapping[idx]
        return idx
```

然后是Scrambler（Rotor），需要实现正反向输入输出，以及重制到某个位置（字母）的功能：

```python
def rotate_array(arr: list, direction: int):
    if direction > 0:  # right
        final = arr[-1]
        for i in range(len(arr) - 1, 0, -1):
            arr[i] = arr[i - 1]
        arr[0] = final
    elif direction < 0:  # left
        final = arr[0]
        for i in range(len(arr) - 1):
            arr[i] = arr[i + 1]
        arr[-1] = final


class Scrambler(object):
    def __init__(self, inputs, outputs):
        self.inputs = to_chararray(inputs)
        self.outputs = to_chararray(outputs)
        self.direction = -1 # rotate left
        self.rotate_cnt = 0

    def rotate(self, cnt=1):
        for _ in range(cnt):
            rotate_array(self.inputs, self.direction)
            rotate_array(self.outputs, self.direction)
            self.rotate_cnt += 1

    def reset_to_idx(self, idx):
        for _ in range(idx):
            self.rotate() # 整个都要转，不是一边转
        self.rotate_cnt = 0

    def reset_to_char(self, c):
        while self.inputs[0] != c:
            self.rotate() # 看input的字母来转
        self.rotate_cnt = 0

    def forward(self, idx):
        c = self.inputs[idx]
        return self.outputs.index(c)

    def backward(self, idx):
        c = self.outputs[idx]
        return self.inputs.index(c)
```

然后是Reflector，找到output对应位置的字母，反射到input中接线字母的位置：

```python
class Reflector(object):
    def __init__(self, inputs, outputs):
        self.inputs = to_chararray(inputs)
        self.outputs = to_chararray(outputs)

    def reflect(self, idx):
        c = self.outputs[idx]
        return self.inputs.index(c)
```

最后组装成整个Enigma机：

```python
class Enigma(object):
    def __init__(self, plugboard=None, scramblers=None, reflector=None):
        self.keyboard = alphabetical_letters()
        self.plugboard: Plugboard = plugboard
        self.scramblers: List[Scrambler] = scramblers
        self.reflector: Reflector = reflector

    def _rotate_scramblers(self):
        for i in range(len(self.scramblers)):
            if i == 0 or (self.scramblers[i-1].rotate_cnt > 0 and
                          self.scramblers[i-1].rotate_cnt % len(self.keyboard) == 0):
                self.scramblers[i].rotate()

    def encode_string(self, s):
        chars = []
        for c in s:
            # input with idx
            idx = self.keyboard.index(c)

            # plugboard forward
            if self.plugboard:
                idx = self.plugboard.proxy(idx)

            # scramblers forward
            if self.scramblers:
                self._rotate_scramblers()
                for scrambler in self.scramblers:
                    idx = scrambler.forward(idx)

            # reflect and backward
            if self.reflector:
                idx = self.reflector.reflect(idx)

                if self.scramblers:
                    scramblers_cnt = len(self.scramblers)
                    for i in range(scramblers_cnt):
                        scrambler = self.scramblers[scramblers_cnt-1-i]
                        idx = scrambler.backward(idx)

                if self.plugboard:
                    idx = self.plugboard.proxy(idx)

            # output char of final idx
            chars.append(self.keyboard[idx])

        return ''.join(chars)
```

有了这些代码之后，攻克Cypher游戏中的关卡也就变得非常容易了。

```python
def debug():
    input_string = 'gyhrvflrxy'

    plugboard = Plugboard()
    plugboard.plug_many([
        ('a', 'b'),
        ('s', 'z'),
        ('u', 'y'),
        ('g', 'h'),
        ('l', 'q'),
        ('e', 'n')
    ])

    # scramblers
    scrambler_1 = Scrambler(
        inputs=alphabetical_letters(),
        outputs='uwygadfpvzbeckmthxslrinqoj'
    )
    scrambler_1.reset_to_char('e')

    scrambler_2 = Scrambler(
        inputs=alphabetical_letters(),
        outputs='ajpczwrlfbdkotyuqgenhxmivs'
    )
    scrambler_2.reset_to_char('a')

    scrambler_3 = Scrambler(
        inputs=alphabetical_letters(),
        outputs='tagbpcsdqeufvnzhyixjwlrkom'
    )
    scrambler_3.reset_to_char('b')

    # reflector
    reflector = Reflector(
        inputs=alphabetical_letters(),
        outputs='yruhqsldpxngokmiebfzcwvjat'
    )

    enigma = Enigma(
        plugboard=plugboard,
        scramblers=[
            scrambler_2,
            scrambler_1,
            scrambler_3,
        ],
        reflector=reflector
    )
    encoded = enigma.encode_string(input_string)
    print(encoded)  # blitzkrieg


if __name__ == '__main__':
    debug()
```
