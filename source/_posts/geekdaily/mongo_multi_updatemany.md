---
title: 【极客日常】解决使用mongodb时同时update多条数据的问题
date: 2020/01/12 15:37:44
categories:
- 极客日常
tags:
- mongodb
- pymongo
- 并发
- 事务
- 原子性
---

在实际使用mongodb的场景中，我们经常遇到多个请求同时在某个collection里update多条document的需求。这个需求看似有许多种解法，但是具体哪种好也说不准。现在便让我们一探究竟吧~

首先我们利用pymongo添加1000000条数据，name字段为hello：

```python
from pymongo import MongoClient

client = MongoClient()
db = client['test']
coll = db['concurrency']

coll.insert_many([
    {
        "name": "hello",
        "num": i
    }
    for i in range(1000000)
])
```

然后，我们另外加一个进程，启动任务为将num字段为偶数的documents的name字段给update成aa，而主线程则update所有documents的name字段为bb。代码如下：

```python
from pymongo import MongoClient
import pprint
from multiprocessing import Pool, Process


client = MongoClient()
db = client['test']
coll = db['concurrency']


def f(name, m):
    coll.update_many(
        {"num": {"$mod": [m, 0]}},
        {"$set": {"name": str(name)}},
    )
    return 1


if __name__ == '__main__':
    p = Process(target=f, args=('aa', 2))
    p.start()
    coll.update_many({}, {"$set": {"name": 'bb'}})
    p.join()
    docs = coll.find()
    d = dict()
    for doc in docs:
        n = doc['name']
        if n not in d.keys():
            d[n] = 0
        d[n] += 1
    pprint.pprint(d)
```

最后结果是：

```text
{'aa': 9809, 'bb': 990191}
```

可以看到，两个conn提交的update_many请求，在mongo内部并不是原子的任务。进程比主线程后起，因此进程在update时，主线程已经执行了部分update任务了。但是由于进程update的documents数量较少，因此很快就追上了主线程的进度，从而只有约10000个record最后是被进程给update的。

在mongo官方的[写操作原子性](https://docs.mongodb.com/manual/core/write-operations-atomicity/)文档中提到，mongodb对于单个document的写操作是原子的。也就是说，在updateMany里，对每一个符合filter的document的修改操作是原子的，但是整个updateMany，不会阻塞其它client的update操作。

如果要多个updateMany任务不发生并发，最简便的第一种方法是在业务逻辑中加锁，或者用一个任务队列进行管理。这种方法不仅适合updateMany场景，同样也适合在update的时候，需要修改表结构的场景（document全量update，可能需要先delete后insert）。

第二种方法是利用mongodb提供的[事务](https://docs.mongodb.com/manual/core/transactions/)功能，使得在单个session上这些updateMany操作能够有序进行。事务功能启用需要mongo为副本集模式，版本至少4.0，若有分布式事务的需求需要至少4.2的版本。

第三种方法则是在每一个documents中加入version字段，在update的filter中去另外对比version版本号，从而保证最新版本的documents能够存入数据库。在这个思路下，也可以另外再加一个meta表存储最新version的信息（每一个doc里还是要version字段）。只有成功更新了meta表的version，才能updateMany数据表中的documents，否则阻止这个意向。

第三种方法相对前两种方法可控性较低，因此实际场景中，暂推荐第一种以及第二种方法。（如果有其它更有效的方法，欢迎指正orz）
