---
title: 【Easy Python】第四话：爬虫初探——玩转豆瓣二百五（下）
date: 2019/03/31 19:52:40
categories:
- Easy Python
tags:
- python
- 教程
- 爬虫
- 异步
- 代理
---

# 前言

在上篇，我们获得了豆瓣二百五的电影URL，然后存储在了一个文件里。接下来，我们要访问每一个电影URL，深入敌后，获取情报~

所有的代码都已存储在我的Github仓库：[Douban_250](https://github.com/utmhikari/Douban_250)当中~

# 设置爬取规则

对于每一个电影，我们选择爬取如下内容（虽然电影列表页就能爬得到= =）：

```
标题（title）、年份（year）、时长（time）、
导演（director）、类型（genre）、评分（score）
```

随意点击一个电影页面，用上篇所说的提取CSS选择器的方法，我们可以制作出每一种内容与内容提取规则的映射。如下所示：

<!-- more -->

```python
# sp就是上篇所说的soup解析器
# 每一种内容都可以在解析器中按特定的规则提取加工得到
content_func_map = {
	'title': lambda sp: sp.select_one('#content > h1 > span:nth-child(1)').get_text(),
	'year': lambda sp: sp.select_one('#content > h1 > span.year').get_text().replace('(', '').replace(')', ''),
	'time': lambda sp: sp.select_one('#info > span[property="v:runtime"]').get_text(),
	'director': lambda sp: sp.select_one('#info > span:nth-child(1) > span.attrs > a').get_text(),
	'genre': lambda sp: list(map(lambda item: item.get_text(), sp.select('#info > span[property="v:genre"]'))),
	'score': lambda sp: sp.select_one('#interest_sectl > div.rating_wrap.clearbox > div.rating_self.clearfix > strong').get_text()
}
```

设置完规则，大问题来了= =250个链接，一个个访问，应该会很慢吧！而且，豆瓣还有反爬虫机制，如果访问间隔太快，就会暂时封ip——这，这可怎么办呀！

# 人海战术，代理爬虫

一个个访问慢的话，一起访问，似乎会更快的吧= =
豆瓣封ip的话，如果有多个ip，效率也会增加的吧= =

## 效率调度

理想状态下，我们希望爬取每一个url的过程，都能够被当作是一个任务（task）。就像在M记一样，前台每收到一个客人的订单，都会把订单任务直接扔给厨师们，然后处理下一个客人的请求。那么，我们的厨师在哪里？

得益于python内置的`asyncio`库，我们可以模拟厨师们的工作，调度每一个爬虫任务。

然而，即使有了`asyncio`库，我们也只是通过其中的调度机制，重构了CPU指令而已，对于某些阻塞（block）任务进度的过程，并不能妥善解决。在爬取url内容的过程中，最阻碍我们任务进度的，当属请求——响应的阶段。对于调度器来讲，一个任务发送请求出去，调度器并不需要让它傻等响应回来，而是可以让这个任务歇一下，把执行权让（yield）给其它任务，直到响应回来后，再通知这个任务继续原来的工作，这样才够效率。上一章我们用的`requests`库不支持这一种机制，没关系，我们可以利用第三方的`aiohttp`库，完成这个需求。

## 获取代理池

HTTP请求支持我们通过代理发送数据，使得目标识别发送源为代理服务器。要短时间获取大量的代理服务器地址，很简单，随便找个比如[西刺代理](https://www.xicidaili.com/)或者[66代理](http://www.66ip.cn/pt.html)，利用内置查询，或者HTML解析爬取一堆，搞个一两千个就好。

## 代理服务器分配
在我们的人海战术里，每一个爬虫任务开始前，都需要分配到一个代理服务器。所以问题来了——代理服务器，该怎么分配给每一个任务呢？我们希望，每一个任务都像被等待点名一样，如果有可用的代理服务器就挑几个任务去用，如果暂时能用的代理服务器都在用的话，就歇一会儿。

当然，如果没有代理服务器能用，就凉凉了= =

得益于`asyncio`库提供条件变量（Condition Variable）的机制，可以满足我们的需求。需要获得资源的任务，就去等待（wait）资源分配器的通知，资源分配器发现资源可用，则去通知（notify）那些迫不及待的任务，叫他们赶紧获取资源去。具体如何操作？且让我徐徐道来~

首先，在爬虫任务开始之前，我们得把“获取代理池”一步拿到的代理服务器列表，放到咱们内存里。

```python
 # 初始化条件变量
cond = None 
# 代理队列采用deque()数据结构，头尾都可以添加/删除，便于代理重复利用
proxies = deque()  
# 存放当前正在使用的代理，如果同时被多个任务用的话，小心被豆瓣封= =
proxies_used = set() 


def get_proxies():
	"""
	获取存好的代理服务器列表
	"""
	contents = open('proxies.txt', encoding='utf-8').read().splitlines()
	for i in range(len(contents)):
		if not contents[i].startswith('http'):
			contents[i] = 'http://' + contents[i]
	proxies.extend(set(contents))
```

然后，开始添加我们的任务啦

```python
# 创建用于发送HTTP请求的客户端
async with aiohttp.ClientSession() as session:
	# 电影数量
	num_urls = len(movie_urls)
	# 初始化条件变量Condition Variable
	global cond
	cond = asyncio.Condition()
	# 添加任务啦~
	tasks = list()
	for i in range(num_urls):
		# crawl_movie_url就是我们爬虫任务的模版啦，具体见下面
		tasks.append(crawl_movie_url(session, movie_urls[i], i + 1))
	# 最后一个启动的任务是咱们的代理分配模块：allocate_proxy
	tasks.append(allocate_proxy(len(tasks)))
	# 开始把这堆任务跑起来，走你~
	await asyncio.gather(*tasks)
```

对于每一个任务，我们都做成一个循环（loop），直到任务完成或者没有代理服务器可用，才退出不干。因此，爬虫任务的初始逻辑如下：

```python
# 加了async，表示这个函数上升为一个可被asyncio模块调度的任务
async def crawl_movie_url(session, url, movie_num):
	while True:
		# 加了await，该任务就歇了，保存该任务状态，CPU执行权交给其它任务
		# 直到get_proxy有结果才被asyncio调度器唤醒
		proxy = await get_proxy()
		if not proxy:
			log(movie_num, 'TMD代理全部挂了，凉凉= =')
			return
		# 开始执行爬虫任务啦，具体后面说= =
		await set_proxy_in_use(proxy)
		pass
```

对于每一个任务来讲，该如何获取代理服务器呢？咱们的`get_proxy`任务代码如下：

```python
async def get_proxy():
	# cond.acquire()跟cond.release()，可以实现对一段命令的加解锁（Lock）
	# 就如同上厕所一样，一个任务执行到加锁的一段，如果另一个任务也执行到这一段，就会暂停挂起，等待排队
	# proxies跟proxies_used是每个任务共享的全局变量（Global Variable），对于共享变量的操作，是要加锁的
	# 如果代理就剩一个，然后两个任务都跑到这一段，那就出事了= =
	await cond.acquire()
	proxy = ''
	try:
		# 等待代理分配器通知= =
		# 代理分配器会在有可用代理，或者代理全部凉凉的时候唤醒这些等待者
		await cond.wait()
		# 如果有可用代理，就挑一个，没有就直接返回空字符串
		# 可以看上面的crawl_movie_url任务，直接凉凉= =
		if len(proxies) > 0:
			# 从代理队列头部取出一个代理
			proxy = proxies.popleft()
			# 把这个代理加到正在使用的代理集合中
			proxies_used.add(proxy)
	finally:
		cond.release()
	return proxy
```

面对这群嗷嗷待哺的任务们，我们的代理服务器分配任务`allocate_proxy`，就可以这样设计了

```python
async def allocate_proxy(max_tasks):
	# 代理分配任务，本身就相当于一个服务，因此这里采用循环的方式来设计
	while True:
		# 上锁，劳资要给别的任务分配代理了
		# 而且还得看代理队列呢，其他任务先别着急= =
		await cond.acquire()
		will_break = False  # 是否退出代理分配任务
		will_delay = False  # 下一个循环是否要延迟长一点
		try:
			if task_count == max_tasks:
				# task_count指当前完成的爬虫任务数
				# 如果到了最大值，说明全部任务都结束了
				# 这个时候代理分配任务也就完成任务了
				will_break = True
			# 看代理队列还有木有可用的  
			len_proxies = len(proxies)
			if len_proxies == 0:
				if len(proxies_used) == 0:
					# 代理队列没代理，连tm正在用的代理也是空的，岂不是凉凉= =
					# 把这个可怕的信息告诉给所有任务吧= =然后劳资也跑路= =
					cond.notify_all()
					will_break = True
				else:
					# 代理都在用着呢，等多一会儿再给大家分配吧= =
					will_delay = True
			else:
				# 代理队列有多少代理，最多通知多少个任务去拿代理去
				cond.notify(len_proxies)
		finally:
			cond.release()
			if will_break:
				break
			elif will_delay:
				# 歇多几秒，再分配代理给其它嗷嗷待哺的任务
				# 相当于爬虫访问网页的时间间隔设置
				# 豆瓣白天2s左右晚上3~4s左右差不多
				await asyncio.sleep(get_proxy_delay_time())
			else:
				# 歇一丢丢时间，把自己排在任务调度后面
				# 不然while True死循环，别的任务就跑不了了
				await asyncio.sleep(proxy_search_period)
```

## 爬虫主任务

有了代理分配这个强劲的后盾，我们的爬虫任务就可以顺利进行啦！

免费的代理好多都没法用的，需要在爬虫的过程中不断舍弃。废话不多说，直接上代码！

```python
async def crawl_movie_url(session, url, movie_num):
	while True:
		# 这段上面讲了= =
		proxy = await get_proxy()
		if not proxy:
			log(movie_num, 'TMD代理全部挂了，凉凉= =')
			return
		# result存储爬取的数据，log函数打印日志（得自定义实现= =）
		result = {'number': movie_num, 'url': url, 'proxy': proxy}
		log(movie_num, '代理%s正在访问%s...' % (proxy, url))
		success = True  # 是否爬取成功的标志
		try:
			# 用get获取数据，判断状态码，而后解析数据
			response = await session.get(url, proxy=proxy, headers=headers, timeout=proxy_connection_timeout)
			status_code = response.status
			if status_code == 200:
				html = await response.text()
				soup = BeautifulSoup(html, html_parser)
				for k in content_func_map.keys():
					try:
						# 按最开始设的爬取规则抓数据，存到result里
						content = content_func_map[k](soup)
						result[k] = content
					except Exception as e:
						# 如果爬不了，很有可能get到的网页变了！
						# 比如叫你登录啥啥的，这说明代理被豆瓣临时小黑屋了，果断放弃这个代理
						log(movie_num, '代理%s爬取%s信息失败！果断放弃掉！错误信息：%s\n' % (proxy, k, e))
						success = False
						break
			else:
		   		# 如果状态码不对，很有可能是400啥的，说明也被豆瓣小黑屋了，果断放弃掉这个代理
				log(movie_num, '代理%s获取数据失败！果断放弃掉！状态码: %d！' % (proxy, status_code))
				success = False
		except Exception as e:
			# 代理链接或者代理发送请求都有问题，果断不要了 
			log(movie_num, '代理%s连接出错，果断放弃掉！！！错误信息：%s！' % (proxy, e))
			success = False
		finally:
			if success:
				# 成功爬取数据，把爬取结果加上，把任务完成数加上
				global results
				global task_count
				results.append(result)
				task_count = task_count + 1
				log(movie_num, '当前爬到信息的电影数: %d，爬到信息：%s' % (task_count, str(result)))
				# 这个代理还能用，给力！proxies_used里删掉它
				# 然后把它放到proxies的尾部（append）
				await recycle_proxy(proxy)
				break
			else:
				# 这个代理不给力，直接从proxies_used删掉吧~
				await remove_proxy(proxy)
```

试试看吧~

# 总结

豆瓣Top 250爬虫，其实更多的难点，在于如何组织、调度你的资源，更有效率地处理数据。爬虫的工具、软件，其实都已经烂大街

对于软件，集搜客、八爪鱼之类的就能完成需求

对于代理池，github上就有许多项目可以clone下来去获得

对于爬虫框架，其实可以踩踩`scrapy`库的坑，这是一个非常成熟的爬虫框架

对于获取异步加载（不是当即就在response里，而是后面才加载到）的数据，可以使用[PhantomJS](http://phantomjs.org/)一类的工具，或者利用Chrome开发者工具，采用抓包+模拟HTTP请求的方式，获取相应数据。

最后介绍一个大杀器——[Selenium](https://selenium-python.readthedocs.io/)，作为一款浏览器测试驱动，selenium甚至可以模拟浏览器操作，百试不爽，谁用谁知道！

