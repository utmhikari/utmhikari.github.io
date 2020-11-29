---
title: 【极客日常】python轻量级消息队列库celery的应用
date: 2020/11/29 20:34:25
categories:
- 极客日常
tags:
- python
- celery
- 消息队列
- 后台开发
- start-fastapi
---

python语言，一般适用于快速实现业务需求的用途，在大型架构方面其应用范围并没有Java、Golang以及C++那么丰富，因此相对来讲还没有形成非常统一的技术体系。在某些需求中可能需要开发多个服务，服务之间需要实现异步通信，甚至是调用对方的函数。[celery](https://docs.celeryproject.org/en/stable/)就是一个典型的例子，它提供了以将python函数注册到消息队列的方式暴露服务的方法，并且支持RabbitMQ、Redis等多种Broker中间代理形式。celery简便易用，本文笔者以自己整理的[start-fastapi](https://github.com/utmhikari/start-fastapi)为例，讲述接入celery的方法。

<!-- more -->

首先克隆start-fastapi，是笔者稍微加料的一个fastapi版本，主要在fastapi原本基础上对配置以及目录进行了整理，形成了一个开箱即用的Web后端框架。以Redis作为broker为例，我们首先需要`pip install celery[redis]`，然后可以在`service.celery`中新建一个`app.py`文件，作为celery的app实例。

```python
from celery import Celery


celery_app = Celery('celery_tester',
                    broker='redis://:helloword@localhost:6379/0',
                    backend='redis://:helloword@localhost:6379/1')

celery_app.conf.update(task_track_started=True)
```

对于整个消息队列，broker代理的信息缓存在DB0中，而backend存储每一个消息trace info，缓存在DB1中。

之后在`service.celery`新建`worker.py`文件，里面import app后，注册待暴露的函数。这里的例子是通过item_id延迟3s获取item的price，`get_item`方法获取了item basemodel的实例，通过这个实例可以拿到price

```python
from .app import celery_app
from service import item as item_service
import time


@celery_app.task(acks_late=True)
def get_item_price(item_id: int) -> float:
    item = item_service.get_item(item_id)
    time.sleep(3)
    if not item:
        return -1.0
    return item.price
```

为了让这个函数能暴露出去，我们需要应用这个worker文件的内容。进入到项目根目录，如果用venv的话，先`source ./venv/bin/activate`，然后执行`celery -A service.celery.worker worker -l info`，就能够启动celery的worker，并且可以看到tasks中有了`service.celery.worker.get_item_price`

通过`ps -ef | grep python`，我们看到如下信息，可以看到fastapi应用跟celery worker处在不同的进程

```text
root         786       1  0 20:01 ?        00:00:00 /usr/bin/python3 /usr/bin/networkd-dispatcher --run-startup-triggers
root         874       1  0 20:01 ?        00:00:00 /usr/bin/python3 /usr/share/unattended-upgrades/unattended-upgrade-shutdown --wait-for-signal
hikari      3934    3067  1 20:28 pts/0    00:00:00 /home/hikari/PycharmProjects/celery_test/venv/bin/python /home/hikari/PycharmProjects/celery_test/venv/bin/celery -A service.celery.worker worker -l info
hikari      3936    3934  0 20:28 pts/0    00:00:00 /home/hikari/PycharmProjects/celery_test/venv/bin/python /home/hikari/PycharmProjects/celery_test/venv/bin/celery -A service.celery.worker worker -l info
hikari      3937    3934  0 20:28 pts/0    00:00:00 /home/hikari/PycharmProjects/celery_test/venv/bin/python /home/hikari/PycharmProjects/celery_test/venv/bin/celery -A service.celery.worker worker -l info
hikari      3938    3934  0 20:28 pts/0    00:00:00 /home/hikari/PycharmProjects/celery_test/venv/bin/python /home/hikari/PycharmProjects/celery_test/venv/bin/celery -A service.celery.worker worker -l info
hikari      3939    3934  0 20:28 pts/0    00:00:00 /home/hikari/PycharmProjects/celery_test/venv/bin/python /home/hikari/PycharmProjects/celery_test/venv/bin/celery -A service.celery.worker worker -l info
hikari      3940    3934  0 20:28 pts/0    00:00:00 /home/hikari/PycharmProjects/celery_test/venv/bin/python /home/hikari/PycharmProjects/celery_test/venv/bin/celery -A service.celery.worker worker -l info
hikari      3941    3934  0 20:28 pts/0    00:00:00 /home/hikari/PycharmProjects/celery_test/venv/bin/python /home/hikari/PycharmProjects/celery_test/venv/bin/celery -A service.celery.worker worker -l info
hikari      3954    2728 12 20:28 ?        00:00:00 /home/hikari/PycharmProjects/celery_test/venv/bin/python /home/hikari/PycharmProjects/celery_test/main.py
hikari      3955    3954  0 20:28 ?        00:00:00 /home/hikari/PycharmProjects/celery_test/venv/bin/python -c from multiprocessing.resource_tracker import main;main(4)
hikari      3956    3954  4 20:28 ?        00:00:00 /home/hikari/PycharmProjects/celery_test/venv/bin/python -c from multiprocessing.spawn import spawn_main; spawn_main(tracker_fd=5, pipe_handle=7) --multiprocessing-fork
hikari      3968    3086  0 20:28 pts/1    00:00:00 grep --color=auto python
```

于是乎，我们增加一个controller，用来测试celery worker是否生效。controller也引用`service.celery.app`，通过`send_task`执行`service.celery.worker.get_item_price`任务，传参为1，然后再打印返回值。

```python
@router.get('/v1/test/celery')
def test_celery():
    """
    test celery example
    :return:
    """
    task = celery_app.send_task('service.celery.worker.get_item_price', args=[1])
    LOGGER.info('triggered celery task: %s' % task)
    print(task.get())
    # background_tasks.add_task(on_celery_message, task)
    return success(msg='triggered celery test!')
```

我们通过`curl http://127.0.0.1:8000/v1/test/celery`来测试这个接口。结果也很显然，约3s之后，fastapi端打印了返回值到stdout中，然后curl接口返回了success。

例子已经上传到[fastapi-celery-test](https://github.com/utmhikari/fastapi-celery-test)上，基本操作就系介样，后面再慢慢探索把~
