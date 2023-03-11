---
title: 【Easy Python】第三话：爬虫初探——玩转豆瓣二百五（上）
date: 2019/03/31 17:00:02
categories:
- Easy Python
tags:
- python
- 教程
- 爬虫
- BeautifulSoup
- HTML
---

## 前言

一直以来，爬虫都是许多同学学Python的目的之一，就连我敬爱的领导，也经常不耻下问一些爬虫方面的问题。因此，我们开始实战——以[豆瓣Top 250](https://movie.douban.com/top250)为例，试水一下基础的爬虫。

“玩转豆瓣二百五”系列分为上下两部，所有代码，可以在我的Github里[Douban_250](https://github.com/utmhikari/Douban_250)找到~

工欲善其事，必先利其器。以下浏览器操作，都基于最新版Chrome~

## 获取电影列表网页数据

爬虫爬虫，实质还是抓取网络数据= =爬虫不得急，可要一步步来——首先，我们希望获得每一个电影的链接，把它们存起来，留着后续爬取具体内容备用。

打开[豆瓣Top 250首页](https://movie.douban.com/top250)，会看到电影列表的页面，往下翻，会看到总共有10页，每页25个电影。打开第二页，可以看到浏览器的地址变成了`https://movie.douban.com/top250?start=25&filter=`，咱们观察一下链接——链接有一部分，`start=25`，是不是很突兀？按这样推算，第三页应该是`start=50`，第一页就是`start=0`嘛= =试了一下，果真是的= =

因此，爬取250个电影链接，不难规划。具体如下：

<!-- more -->

- 打开10个电影列表页面——`https://movie.douban.com/top250?start=$movie_num&filter=`，其中`$movie_num`是`25 * (页数 - 1)`
- 获取10个页面的网页内容——我们都知道点击电影名就能进到电影链接里，那么电影链接在网页内容的概率就很大
- 解析网页内容，提取链接信息

因此，每一页的链接，可以如下表示：

```python
def get_start_url(page):
    # page = 0 相当于第一页
    start_num = 25 * page
    return 'https://movie.douban.com/top250?start=%d&filter=' % start_num
```

然后，我们需要获取这些每一页的网页信息了——要获取信息，就涉及到交流，要交流，就要有共同的语言，约定俗成的数据格式——我们可称之为协议（Protocol）。获取网页信息，我们就常用超文本传输协议（HTTP），如果需要进一步保证传输数据的安全性，就采用超文本传输安全协议（HTTPS），是HTTP的扩展。豆瓣的链接以https开头，可见是采用了HTTPS作为数据传输的协议。

对于一个网站来说，每一个网页，都只是一种资源（Resource）。资源的链接，不论是所谓的网页，还是什么种子下载地址，都归属于一个概念——统一资源定位符（URL）。通常来讲，如果服务器允许的话，我们采用HTTP或者HTTPS的数据格式，采用协议约定的GET请求方式（Request Method）访问一个URL，就可以获取该URL下相应的资源。相应地，对豆瓣二百五每一页的URL发出GET请求，就应当可以获取到网页的内容。

因此首先，我们去给上述所有电影列表页面发请求，获取所有网页数据。在python3里，我们可以通过requests库发送http/https请求，获得请求的响应（Response）数据，提取网页信息。

```python
import requests
for i in range(10):
    url = get_start_url(i)  # 就用上面说的get_start_url函数
    response = requests.get(url)
    # HTTP/HTTPS协议里，response数据的不同状态码（status code）有不同含义
    # 一般2字头表示整个请求&响应数据过程成功进行，200最常见
    # 4字头表示请求有问题，无法获得想要的数据，也有可能是你被服务器小黑屋了
    # 5字头表示服务器背锅，处理你的请求过程中bug了，或者是根本没法处理请求
    if response.status_code == 200:
        html = response.text  # 提取相应的文本信息，在此为网页数据
        解析(html)
        存储数据()
    else:
        print('Error at page %d with status %d!' %
              (i + 1, response.status_code))
```

## 解析提取电影URL

### HTML解析

获得了电影列表网页数据之后，我们需要通过某种规则，获取网页里边的电影链接。网页数据文本一般遵从HTML（超文本标记语言）格式，我们可以通过右键网页查看源代码看到，每一个网页的元素（Element），都被标签（Tag）包裹着，形式类似于这样——`<tag1><tag2>...</tag2>...</tag1>`，标签层层相扣，而最外层有一个`<html>`标签包裹着所有的内容，因此整一个网页数据类似于由标签、元素组成，以`<html>`标签为根的树状结构。在Python中，有许多第三方库（需要额外安装~）可以满足解析HTML的需求，这里以`bs4`的`BeautifulSoup`解析库以及`lxml`解析引擎为例，尝试提取豆瓣电影的链接。

```python
from bs4 import BeautifulSoup
html = response.text  # 接上
html_parser = 'lxml'  # 指定解析引擎为lxml
soup = BeautifulSoup(html, html_parser)  # 基于网页数据构建一个解析器
```

接下来，随便在哪一个电影列表页面打开Chrome开发者工具，选择Elements一栏，点击开发者工具左上角的鼠标，再点一个电影标题，就可以
在开发者工具中定位到该标题所在的元素。

所以，看到有个标签，`<a href="啥啥啥">...</a>`了吗？点击那个href里的内容，是不是进到了每部电影的页面？试试看吧~

### 定位标签

要定位这个`<a href="啥啥啥">...</a>`元素的位置，我们可以在开发者工具的Elements界面中右键点击标签头部，也就是`<a href="啥啥啥">`这一部分，然后，选择copy -> selector，获取该元素CSS选择器的代码。选择器（Selector），可以满足定位一组或是一个特定HTML元素的需求。而BeautifulSoup，则对CSS选择器（CSS Selector）有着较好的支持。

以第一页的《肖申克的救赎》为例操作，copy出来的选择器的代码是——`#content > div > div.article > ol > li:nth-child(1) > div > div.info > div.hd > a`，看起来很长，那有没有简单的版本呢？仔细观察，我们可以发现：标签的属性（比如`<a href="啥啥啥">`里，`href`就是标签的属性）里，`class`跟`id`是较为常见的两个。标签属性`class`一般指代一类特定的网页元素排版样式，而`id`则一般用于指代一个特定的元素。每一个电影链接的上层，都有一个`<div class="hd">`的标签，为此，我们可以通过这个标签下层的`<a>`标签，寻找对应的电影链接，并存储起来：

```python
movie_url_file = open('movie_urls.txt', 'w', encoding='utf-8')
for movies in soup.find_all('div', class_='hd'):
    # movies表示网页中每一个<div class="hd">标签下的元素
    movie_url = movies.find('a')['href']  # 提取该元素下层<a>标签的href属性
    movie_url_file.write(movie_url + '\n')  # 把链接写入文件
movie_url_file.close()
```

通过这样的操作，我们就可以获得250个电影的url了。试试看吧~

## 小结

上半部分，初试爬虫，我们抓到了豆瓣250个电影的链接。

下半部分，我们就在这250个电影的链接中，一探究竟吧~
