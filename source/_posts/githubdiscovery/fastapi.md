---
title: 【GitHub探索】FastAPI——新一代实用python轻量级Web后端框架
date: 2020/02/01 18:20:28
categories:
- GitHub探索
tags:
- python
- fastapi
- 后端
- 效率工具
- web开发
---

本月，一款名为[FastAPI](https://github.com/tiangolo/fastapi)的轻量级Web框架在trending榜上有名。本着踩坑的心态试用了fastapi，发现其坑并没有许多相同量级web框架（比如flask）来的多，上手极其容易。因此果断整理了一下fastapi的上手过程。

FastAPI基于[Starlette](https://www.starlette.io/)网络框架进行封装，不仅性能优异，并且解决了许多用python开发效率工具或是轻量级应用的后端同学的痛点。比如：

- 结合[pydantic](https://pydantic-docs.helpmanual.io/)，实现param与body的静态类型检查
- 用妥当的方式接收/返回json body
- 结合Starlette，从而自带restful api以及middleware的支持
- 自带调试router，基本顶替postman的工作
- etc

安装fastapi需要python3.6以上，预先`pip3 install fastapi uvicorn`。我们来看一下FastAPI的例子：

<!-- more -->

```python
# example.py
from fastapi import FastAPI
from pydantic import BaseModel
import uvicorn


app = FastAPI()


class Item(BaseModel):
    name: str
    price: float
    is_offer: bool = None


@app.get("/")
def read_root():
    return {"Hello": "World"}


@app.get("/items/{item_id}")
def read_item(item_id: int, q: str = None):  # 此处q为query的字段
    return {"item_id": item_id, "q": q}


@app.put("/items/{item_id}")
def update_item(item_id: int, item: Item):  # 此处Item为body的schema
    return {"item_name": item.name, "item_id": item_id}


if __name__ == '__main__':
    uvicorn.run('example:app')
```

采用[Uvicorn](https://www.uvicorn.org/)打开`app`，我们的后端便能够起起来。进入`http://localhost:8000/docs`，就能够进入路由的描述与调试界面。
在调试界面中我们可以自己输入params/query/body，如果输入值的类型不对或者是缺少相应的body字段，response会自动带错误码以及detail信息。比如在`put /items/{item_id}`中，我们输入body为：

```json
{
  "named": "string",
  "price": 0,
  "is_offer": true
}
```

根据Item model定义缺少了name字段，故返回422错误码以及json body：

```json
{
  "detail": [
    {
      "loc": [
        "body",
        "item",
        "name"
      ],
      "msg": "field required",
      "type": "value_error.missing"
    }
  ]
}
```

可以说对于开发人员而言是非常方便了。

实际采用fastapi + uvicorn开发时会遇到部分customization的问题，比如[跨域cors](https://developer.mozilla.org/zh-CN/docs/Web/HTTP/Access_control_CORS)的header处理以及logger配置之类。针对这些，笔者把fastapi可能用到的一些基本的后端配置与目录结构进行了整理，放到了[start-fastapi](https://github.com/utmhikari/start-fastapi)项目中，相当于一个模板。针对上述的例子，跨域处理一般放到middleware中，可以添加Starlette所带的CORSMiddleware进行处理；而用uvicorn启动的话，logging日志模块会被uvicorn重写，因此若要自定义日志，需要参考[uvicorn config](https://github.com/encode/uvicorn/blob/master/uvicorn/config.py)中的`LOGGING_CONFIG`来自己重写，加载到uvicorn的`log_config`配置中。如果还有额外的自定义需求，可参考[fastapi项目生成模板](https://fastapi.tiangolo.com/project-generation/)以及该官网中其它的文档自行定制。

FastAPI的生产环境暂时没有踩坑。但从FastAPI的定位以及研发环境提供的功能与API来看，已经能够极大提升研发效能。后续有空再封装下生产环境部署流程，以后要开发后端小工具就基本上用这个跟start-fastapi上了。
