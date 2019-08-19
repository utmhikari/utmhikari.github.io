---
title: 【Easy Python】第五话：小试scikit-learn数据挖掘——newsgroup数据处理与文本分类
date: 2019/04/14 01:59:24
categories:
- Easy Python
tags:
- python
- 数据挖掘
- 文本分类
- scikit-learn
- newsgroup
---

## 前言

数据挖掘（Data Mining），一般指从海量抓取的数据中经过一定的数据处理、算法，从而提取出有价值的信息的过程。它大体基于统计学、机器学习（Machine Learning）等原理，辅佐了人类的信息处理工作，为人工智能（AI）铺下道路。

幸运的是，似乎正是因数据挖掘而生的那样，Python社区中有各种数据挖掘相关的package，能够满足各种数据处理与算法模型构建需求。我们只需要`pip/conda install 包名`，然后查查api文档，熬几十行代码，就能玩一玩数据挖掘。

为此，在这一话，我们以自然语言处理（NLP）的文本分类（Text Classification）为例，设计一个最simple的，最old school的，以Python为例的，从数据获取到产生数据挖掘结果的流程。

## 文本分类是什么？

<!-- more -->

文本分类，更通常的理解，叫文本自动分类（auto-classification），是文本数据挖掘最普通不过的方法了。文本分类应用的例子比比皆是，比如某个新闻网站，爬到了海量外部的新闻文本，当人力不足以将其一个个归类时，就需要借助计算机的力量，将那些没有标注类别（category labelling）新闻自动归类到已有的类别当中。所以，我们的问题就是——怎样像人一样，去识别那些没有归类的新闻的类别呢？

俗话说的好，只要功夫深，铁杵磨成针。我们在孩提时代，是父母告诉我们，这只猫，那是狗，我们才能对不同的动物进行分辨。在数据挖掘领域，我们可以利用分类器（classifier），满足自动分类的需求。分类器就像我们的大脑一样，可以通过吸收不同知识，调整自己的决策，但其本质上，却是一个夹杂了繁复数学计算的计算机程序而已。我们要做的，则是把已有的资源，也就是归类好的那些新闻文本，去告诉分类器，这篇是A类，这篇是B类，从而训练（train）它的新闻类别识别能力。这样，面对各种未归类新闻的考验（test），分类器就可以争取像人那样，把新闻的类别识别出来了。

为此，要保证计算机的识别效果，完备优良的训练材料（training set）和精致缜密的训练方法（algorithm model）都必不可少。

## 简单的例子——newsgroup文本分类

以下，我们就开始最简单的文本分类流程示例啦！我们采用[scikit-learn](https://scikit-learn.org/stable/)提供的工具进行文本分类流程模拟。

### newsgroup数据集下载

文本分类数据集，我们采用最经典的新闻数据集：[20 newsgroup数据集](http://qwone.com/~jason/20Newsgroups/)进行模拟，使用的版本为[18828版](http://qwone.com/~jason/20Newsgroups/20news-18828.tar.gz)，记录了18828篇不重复的英文新闻。虽然`scikit-learn`库默认提供该数据集的下载处理，但是在这一话，我们就自己实现一遍吧~

下载，解压，总共有`alt.atheism`到`talk.religion.misc`20个类别的文本。打开每一个类别文件夹，能看到以新闻编号为文件名（没有后缀名）的新闻文件。用记事本打开，就能够看到里面的新闻内容啦。

### 新闻数据读取&预处理

要模拟文本分类，需要把每一个新闻跟它们的类别一一对应。在`scikit-learn`中，要实现newsgroup新闻内容与类别的对应，需要建立两个列表：

- 所有新闻的列表
- 所有新闻归属类别编号的列表（1~n）

因此，我们在读取新闻文件内容的时候，也要做一个类别标签的列表。具体代码如下：

```python
import os

# out directory to store newsgroup datasset
directory = './20news-18828'
# category_names[label_number - 1] = category name
category_names = os.listdir(directory)
# sequence of news contents --- X
news_contents = list()
# sequence of news labels  --- Y
news_labels = list()
# traverse into directories
for i in range(len(category_names)):
    category = category_names[i]
    category_dir = os.path.join(directory, category)
    for file_name in os.listdir(category_dir):
        file_path = os.path.join(category_dir, file_name)
        # get the word list of a single news file
        raw_content = open(file_path, encoding='latin1').read().strip()
        # preprocess data
        news_content = preprocess_content(raw_content)
        # append news labels and news contents
        news_labels.append(i + 1)
        news_contents.append(news_content)
```

其中，`news_contents`是我们的新闻内容；`news_labels`是我们每个新闻内容对应类别的编号的列表，跟`news_contents`一样长；而`category_names`则是类别名的列表了。我们遍历每个类别目录去读取新闻文件内容，文件编码经查证是`latin1`。没读到一个文件，我们都去用一个`preprocess_content`函数预处理（preprocessing）这个文件的内容，然后把文件内容加到`news_contents`中，把这个新闻对应的类别编号，此处设为`索引i + 1`，加到`news_labels`中。

预处理文本方便了我们后续对文本数据的操作。那么，如何预处理newsgroup文本数据呢？这就和新闻文本的数学模型表示方法有关了。把文字堆砌文本变成数学模型，分类器才能够学习不同类别的文本是这样那样的。这个过程，我们叫做拟合（fit）。对于新闻类的长文本来说，最简单粗暴oldschool的方法，就是用词频、关键词之类的信息来表示文本内容。虽然这种方法忽略了词与词之间的上下文关系，但从实践效果来看，已经很ok了。

要获取文本的词频、关键词等信息，就涉及到文本的分词。newsgroup手机的是英文新闻，因此为了让后续的分词更加方便，我们希望在预处理的过程中，**过滤掉新闻文本标点符号之类的干扰字符，把所有单词都以空格相连**，这样就完成了文本的与处理了。

完成这个需求，就需要一个文本预处理的强大武器——[正则表达式](https://docs.python.org/3/library/re.html)（Regular Expression）。通过正则表达式，我们可以匹配一个样式（pattern）的文本，并对它进行操作。

那么我们的`preprocess_content`预处理函数，就可以这样写啦：

```python
# replace any character that is not digit or letter or space with empty string
replace_with_empty_pattern = re.compile(r'[^A-Za-z0-9\s]')
# replace consecutive spaces and enters(\n) with a single space
replace_with_single_space_pattern = re.compile(r'\s{2,}|[^\S ]')


def preprocess_content(content):
    return re.sub(
        replace_with_single_space_pattern, ' ',
        re.sub(replace_with_empty_pattern, '', content)
    )
```

我们首先去掉标点符号之类的干扰字符，然后把所有的单词都以一个空格相隔。为此，我们做两个正则表达式，完成这个需求吧~

- `[^A-Za-z0-9\s]`  --- 首先，`[^嘻哈嘿]`代表不匹配`嘻哈嘿`之类的字符；然后，`A-Za-z0-9`就顾名思义，代表数字跟字母；最后，`\s`代表空白字符，包括比如空格(space)啊、回车(enter)啊、制表符（tab）之类。连起来，就是**不匹配数字、字母跟空白字符的那些文本**的意思，也就正好对应我们的干扰字符。我们用`re.sub`方法，就可以把这些干扰字符替换成空字符串`''`，从而去掉它们。
- `\s{2,}|[^\S ]` --- 首先，`\s{2,}`表示连续出现两次或以上的空白字符；其次，`|`代表“或者”的意思，最后，`[^\S ]`中的`\S`，代表非空白字符，整一下就表示空白字符里除去空格外（里边多`^`了一个空格喔）其它所有的空白字符。这样，整个正则表达式就表示——**除了单个空格外，所有空白字符组合成字符串**的情况了。我们把出现这些情况的字符串都用单个空格`' '`代替，这样所有的单词都以空格相隔了。（诶，其实嫌麻烦的话，直接`\s+`也成= =）

`print`一下试试看吧~

### 新闻文本分类

如上所说，要实现一个简单的文本分类流程，就需要准备好训练计算机的数据和用于测试计算机的数据。我们可以把刚刚处理好的新闻内容跟类别标签列表洗刷刷（shuffle），然后分隔一部分用于训练，一部分用于测试。这里，我们把训练跟测试数据集的比重设成1：1先啦~

```python
from sklearn.model_selection import train_test_split

train_contents, test_contents, train_labels, test_labels = \
    train_test_split(news_contents, news_labels, shuffle=True, test_size=0.5)
```

然后，我们需要把我们的新闻，转化成数学模型，从而被分类器识别。按照最简单粗暴的方法，我们可以把整个数据集所有出现过的不同词语整合成一个词表（vocabulary）。然后，针对每一篇文章，都计算**词表里每个词在这篇文章的关键程度**，再一整合，就成了这篇文章的数学模型表示了。

怎样计算词表里每个词在单篇文章的关键程度呢？最老掉牙但又有效的方法，就是通过[TF-IDF](https://zh.wikipedia.org/zh-hans/Tf-idf)计算了。TF（Term Frequency）代表这个词在该篇文章出现的频率，IDF（Inverse Document Frequency）代表这个词在整个数据集中地低频程度。一个词，出现在该篇文章次数多，出现在整个数据集次数少，就表示这个词语能够更加突出该篇文章的语义。

为此，我们可以通过`scikit-learn`内置的`TfidfVectorizer`，把文章的文本转化为所有词语在该篇文章关键程度的集合，也就是个向量啦~

```python
from sklearn.feature_extraction.text import TfidfVectorizer

tfidf_vectorizer = TfidfVectorizer()
```

为了把每篇文章的数学模型进行训练，我们就需要一个分类器。常用的分类器有许多，这里，我们就以SVM（Support Vector Machine，支持向量机）为例啦- -

SVM的分类原理可以用切西瓜来比喻——西瓜里有白的黑的籽，现在不管你刀的形状，怎样来一刀，使得刀两边能够尽量分别是白籽跟黑籽，然后刀到白籽黑籽两者距离的最小值能尽量大呢？比喻说的简单，实际计算还是复杂的（数学渣TAT）。但我们若是单纯引用，则不需要管这些数学问题，直接import就好啦~

```python
from sklearn.svm import LinearSVC

# LinearSVC：线性支持向量分类器
svm_classifier = LinearSVC(verbose=True)
```

在前面的`TfidfVectorizer`中，我们会先对训练集操作，最后对于每一个新闻生成的数学模型，都是一个维度很高的向量（词表长度= =）。为了能够让我们的SVM分类器训练更加效率，我们可以采用特征选择（feature selection）的方法，在词表中挑选少量来作为每个新闻数学模型的维度就好啦。

卡方统计量（chi2）是常用的特征选择指标。卡方统计量能够衡量词语跟类别的相关性，因此通过卡方指标打分筛选词表中的词语，我们就可以剔除许多影响分类效果的常见词了。

```python
from sklearn.feature_selection import SelectKBest, chi2

# 选10000个词语作为文档特征词
chi2_feature_selector = SelectKBest(chi2, k=10000)
```

最后，我们需要一个流水线（pipeline），把整个流程串起来——

```python
from sklearn.pipeline import Pipeline

pipeline = Pipeline(memory=None, steps=[
    ('tfidf', tfidf_vectorizer),
    ('chi2', chi2_feature_selector),
    ('svm', svm_classifier),
])
```

对于训练数据，我们先把其转化为以TF-IDF为基础的数学模型，然后通过chi2方法选择特定数量的词语从而剔除干扰词，最后把它输入到SVM分类器中进行训练。

对于测试数据，我们同样先将其转化为TF-IDF为基础的数据，然后在chi2流程时，把训练数据选出的词语应用到测试数据中作为每一个测试文档的特征词（feature），最后再将其输入到SVM分类器中，进行类别预测（predict），也就是“分类”啦。

得到预测结果后，我们可以通过`classification_report`模块，去展现我们的测试报告。

```python
from sklearn.metrics import classification_report

pipeline.fit(train_contents, train_labels)
result = pipeline.predict(test_contents)
report = classification_report(test_labels, result, target_names=category_names)
```

试试看吧~

## 总结

用python进行newsgroup文本分类，不过是小菜花生。在数据挖掘、机器学习领域，更多的是数学的扎实程度，代码能力并非最为重要。

newsgroup的数据，总共不到两万，算是少之又少。更为海量的数据，要进行数据处理挖掘，光靠个默认的SVM之类也是徒劳，需要更为复杂、更加深层次的模型，好比说神经网络，才能硬刚。

但是很庆幸，我们拥有python，和背后强大的社区。

我想反复说，为什么叫easy python？比python更容易上手的语言很多，lua就是其中一个。但是，lua现在支持那么多数据挖掘需求吗？并没有。

easy python，因为它就如电子琴，能够让我们随心所欲，天马行空。
