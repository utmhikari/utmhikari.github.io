---
title: 【Python随笔】将requests实例转换成curl语句
date: 2024/11/03 12:11:10
categories:
- Python随笔
tags:
- python
- curl
- requests
- web开发
- 源码分析
---

在某些python的工具模块开发场景下，我们可能需要根据用户给定的web请求输入，来转化成一个curl的输出，用于一些网络请求测试，或者方便开发之间交流信息。由于python的web请求基本上一万个人里面九成九都用requests，因此今天这篇文章就简单介绍一下，如何在python里面将requests实例转化成curl语句。

这个场景下，我们需要用到一个叫做[curlify](https://pypi.org/project/curlify/)的工具库来达到效果。curlify提供了一个to_curl函数，可以将一个请求实例转化成curl语句：

<!-- more -->

```python
def to_curl(request, compressed=False, verify=True):
    parts = [
        ('curl', None),
        ('-X', request.method),
    ]

    for k, v in sorted(request.headers.items()):
        parts += [('-H', '{0}: {1}'.format(k, v))]

    if request.body:
        body = request.body
        if isinstance(body, bytes):
            body = body.decode('utf-8')
        parts += [('-d', body)]

    if compressed:
        parts += [('--compressed', None)]

    if not verify:
        parts += [('--insecure', None)]

    # 下略，主要是组装命令
```

这里有一个坑点在于，我们有时候把requests转化为curl，得在请求之前去做，而我们一般用requests.get、requests.request时候，其实已经把请求发送出去了。因此，这个情况下我们需要简单探秘一下requests的源码实现，来看需要怎么做才能给到一个请求发送之前的requests实例。

```python
def request(self):  # requests.session.request，参数略
    req = Request(
        method=method.upper(),
        url=url,
        # 其他参数略
    )
    prep = self.prepare_request(req)


def prepare_request(self, req):
    p = PreparedRequest()
    p.prepare(
        method=request.method.upper(),
        url=request.url,
        files=request.files,
        data=request.data,
        json=request.json,
        headers=merge_setting(
            request.headers, self.headers, dict_class=CaseInsensitiveDict
        ),
        params=merge_setting(request.params, self.params),
        auth=merge_setting(auth, self.auth),
        cookies=merged_cookies,
        hooks=merge_hooks(request.hooks, self.hooks),
    )
    return p
```

从requests源码中可以看到，在请求之前，会构造一个PreparedRequest实例，来存储所有的请求参数。因此，如果给定请求参数的话，我们也可以显式构造一个PreparedRequest实例，然后调用to_curl函数，将PreparedRequest转化为curl语句，满足在请求发起之间转化的需要。

```python
def to_curl(self):
    prepared_request = requests.PreparedRequest()
    prepared_request.prepare_method(self.method)
    prepared_request.prepare_url(self.url, None)
    prepared_request.prepare_headers(self.headers)
    prepared_request.prepare_body(self.body.strip(), None)
    return curlify.to_curl(prepared_request)
```
