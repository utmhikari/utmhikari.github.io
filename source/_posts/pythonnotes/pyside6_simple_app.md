---
title: 【Python随笔】如何用pyside6开发并部署简单的postman工具
date: 2024/12/21 19:42:13
categories:
- Python随笔
tags:
- python
- 工具开发
- pyside6
- requests
- 教程
---

最近一段时间闲来无事，简单研究了一下pyside6，也就是PyQt5的升级版。做这个的目的，也是回顾下桌面开发的基础，兴许未来可能用得上。虽然在日常工作中，可能用到桌面开发的场景比较少，桌面工具的成果也比较难包装，但有一个这样的工具，确实可以解决许多工作效率方面的问题。

在之前笔者也写过几篇pyside6文章，但不是特别系统，比如说：

- [pyside6安装](https://utmhikari.top/2024/08/11/pythonnotes/pyside6_intro/)
- [pyside6绘制时钟](https://utmhikari.top/2024/10/13/pythonnotes/pyside6_clocks/)

因此，今天这篇文章就系统分享一下，怎么样用pyside6写一个postman接口调用的小功能，开发并部署出来。作为一个自己写的教学文章，这篇文章会重点提一些自己觉得实操过程中的要点，少一些ChatGPT就能回答的东西。有了这些基础之后，做其他的工具需求，也会变得更加简单一点。

## 项目初始化

安装方面不再赘述，详情可以看官网的[Getting Started](https://doc.qt.io/qtforpython-6/gettingstarted.html)以及[Tools](https://doc.qt.io/qtforpython-6/tools/index.html)的部分，然后先前的文章也基本上把目录组织和最小demo给讲清楚了。

核心要解决的问题就是通过目录组织，把工作流的每一个模块给拆出来，互不影响。比如这样：

<!-- more -->

- pyside6-designer：.ui文件
- ui定义py文件
- 继承ui，具体view的py文件
- viewmodel层
- service、config之类，和界面无关的底层逻辑
- util工具类

## 界面设计

界面设计上，用一个TabWidget就可以简单做个门户入口，区分多个子功能的界面，每个子功能也可以单独在一个ui界面去设计。

每一个Widget里面需要定义组件的排版（layout），在designer里面，一般是Widget包含了一个组件才能够编辑layout。layout有很多种，垂直（vertical）的话类似于web前端里面一个个Row的排列，水平（horizontal）的话则类似于一个个Col的排列，栅格（Grid）布局的话每个组件的占用面积可能和旁边组件相关联，还有一种表单（Form）布局则专门用于填写表单配置类，是label+input的阻塞。

在layout限制下，每个组件可能占据一块区域，但组件自己也有一些填充策略。像PushButton，一般水平或垂直策略需要调整成fixed，保证不填充到整个区域，要按照自己本身的大小来填，而比如Spacer，需要做占位把组件分割成左右两块的，默认会设置成Expanding来占位。

layout的作用，比方说，做一个json格式转换工具，可以先用一个HorizontalLayout设置两行，第一行工具栏，第二行是TextEdit输入输出界面。工具栏设置成VerticalLayout，装几个Button外加Spacer填充空位，输入输出可以直接占第二行的左右两边，也是搞成VerticalLayout。右边的TextEdit弄成只读，左边的TextEdit用于输入yaml、json等字符串，这样再结合自己实现的model跟service逻辑，整个模块就差不多做起来了。

## postman逻辑编写

工具逻辑方面，本文就给一个简单的postman工具实现，满足调http接口拿返回信息的一个需求。没有全部源码，没有一张图片，只说要点。

首先，界面设计方面，直接抄postman的一些基本元素就可以了，比如说：

- Request：Method、URL、SubmitButton、Headers、Body、Settings
- Response：Headers、Body、StatusCode、ElapsedTime

每个组件可能还有比较细微的需求，比如Headers可以做成QTableWidget的形式，支持增删改功能，用setRowCount、setItem、removeRow之类的接口就可以满足这些操作。Settings可以简单做成FormLayout，设置超时时间就可以。ElapsedTime则在ui设计上需要留空内容，请求的时候动态渲染当前请求消耗了多少秒钟。

ui设计差不多好了之后，我们需要写单独的一个http请求模块，让http请求的执行和审计可以独立出来运行。这是因为，桌面工具ui渲染是大头，不是说执行了一个http请求ui渲染就会阻塞，这样界面就会卡住了。怎么样不让界面卡住这是另一个话题，先解决http请求，让其可以单独执行。

我们可以基于requests库来实现http调用逻辑，需要单独把Request和Response类抽象出来。直接上代码：

```python
import requests


class Response:
    def __init__(self,
                 status_code: int = 200,
                 headers: Optional[Dict[str, str]] = None,
                 body: str = None):
        # 只需要状态码、headers、body
        self.status_code = status_code
        self.headers = headers if isinstance(headers, dict) else {}
        self.body = body

    @classmethod
    def from_response(cls, resp: requests.Response):  # 从requests的返回中提取内容
        status_code = resp.status_code
        headers = dict(resp.headers)
        body = resp.text
        return cls(status_code, headers, body)


class RequestMethod:
    GET = 'GET'
    POST = 'POST'
    PUT = 'PUT'
    DELETE = 'DELETE'
    PATCH = 'PATCH'


def _default_request_headers():
    return {
        'Content-Type': 'application/json',
    }


class Request:
    def __init__(self,
                 url: str = '',
                 method: str = RequestMethod.GET,
                 headers: Optional[Dict[str, str]] = None,
                 body: str = '',
                 settings: Optional[RequestSettings] = None):
        # 对应界面设置里头的东西
        self.url = url
        self.method = method
        self.headers = headers if isinstance(headers, dict) else _default_request_headers()
        self.body = body
        self.settings = settings if isinstance(settings, RequestSettings) else RequestSettings()

    def validate(self):
        if not self.url:
            return ValueError('url is required')
        if not self.method:
            return ValueError('method is required')
        return None

    def args(self):  # 组成requests的参数
        return {
            'method': self.method,
            'url': self.url,
            'headers': self.headers,
            'data': self.body.strip(),
            'timeout': (
                self.settings.connect_timeout_seconds(),
                self.settings.read_timeout_seconds()
            )
        }

    def invoke(self) -> (Response, Exception):
        try:
            resp = requests.request(**self.args())
            return Response.from_response(resp), None
        except Exception as e:
            return None, e
```

有了这些代码之后，单个http请求就可以独立运行，并且请求、返回的数据上下文也可以单独审计。

接下来要解决的问题是，怎么把view逻辑和这个request串联起来。这里需要用到QThread加上signal的机制，通过一个RequestWorker串联，保证http请求干扰不到ui运转。

View层面，逻辑可以简写成这样：

```python
class ToolWidget(QWidget):
    def __init__(self):
        super(ToolWidget, self).__init__()
        self.ui = Ui_ToolWidget()
        self.ui.setupUi(self)

        # request worker
        self._request_worker: Optional[RequestWorkerThread] = None

        # init actions and widget
        self._init_actions()
        self._init_widget()

    def _init_actions(self):
        # do request
        self.ui.requestInvokeButton.clicked.connect(self.invoke_request)
        
        # headers CRUD
        self.ui.requestHeadersResetButton.clicked.connect(self.reset_request_headers)
        self.ui.requestHeadersAddButton.clicked.connect(self.add_request_header)
        self.ui.requestHeadersRemoveButton.clicked.connect(self.remove_request_header)

    def _init_widget(self):
        # fill in request
        default_request = Request()
        self.ui.requestMethodComboBox.setCurrentText(default_request.method)

        # request headers
        self.reset_request_headers()

        # request settings
        default_request_settings = default_request.settings
        self.ui.requestSettingsConnectTimeoutLineEdit.setText(str(default_request_settings.connect_timeout))
        self.ui.requestSettingsReadTimeoutLineEdit.setText(str(default_request_settings.read_timeout))

    def _reset_request_state(self):  # 重置request界面和worker
        """clear all previous request states"""
        if self._request_worker is not None:  # quit+wait+deleteLater三连
            self._request_worker.quit()
            self._request_worker.wait()
            self._request_worker.deleteLater()
            self._request_worker = None

        self.ui.requestRespBodyTextEdit.clear()
        self.ui.requestRespHeadersTableWidget.setRowCount(0)
        self.ui.requestRespDetailTextEdit.clear()

    def invoke_request(self):
        LOGGER.debug('invoke request -> triggered')
        if self._request_worker is not None and self._request_worker.isRunning():
            LOGGER.warning(f'cannot invoke request, request worker is active')
            return
        self._reset_request_state()
        req = self._gen_request()
        LOGGER.debug(f'invoke request -> req: {req.args()}')
        # request不同阶段的事件（signal），串联到ui层不同的回调
        self._request_worker = RequestWorkerThread(req, parent=self)
        self._request_worker.signals.start.connect(self.on_request_start)
        self._request_worker.signals.progress.connect(self.on_request_progress)
        self._request_worker.signals.finish.connect(self.on_request_finish)
        self._request_worker.start(priority=QThread.Priority.LowPriority)
        LOGGER.debug(f'invoke request -> thread started')

    def on_request_start(self, _):  # 请求开始，此时不能再发起请求
        LOGGER.debug(f'request start')
        self.ui.requestInvokeButton.setEnabled(False)
        self._set_request_status('执行中')
        self._set_request_duration(0)

    def on_request_progress(self, evt: RequestProgressEvent):  # 显示当前耗时，由worker提供
        LOGGER.debug(f'request progress -> seconds: {evt.seconds}')
        self._set_request_duration(evt.seconds)

    def on_request_finish(self, evt: RequestFinishEvent):  # 展示response数据
        LOGGER.debug(f'request finish -> resp: {str(evt.resp)}, err: {evt.err}')

        # set resp status
        if evt.resp is None:
            if evt.err is None:
                self._set_request_status('无响应')
            else:  # 展示worker提供的错误信息
                if isinstance(evt.err, (Timeout, ConnectTimeout, ReadTimeout)):
                    self._set_request_status('请求超时')
                else:
                    self._set_request_status('请求异常')
        else:  # 展示状态码对应文案
            status_code = evt.resp.status_code
            if 200 <= status_code < 300:
                self._set_request_status(f'{status_code} 成功')
            elif 300 <= status_code < 400:
                self._set_request_status(f'{status_code} 重定向')
            elif 400 <= status_code < 500:
                self._set_request_status(f'{status_code} 客户端错误')
            elif 500 <= status_code < 600:
                self._set_request_status(f'{status_code} 服务器错误')
            else:
                self._set_request_status(f'{status_code} 未知')

        # set resp duration
        self._set_request_duration(evt.seconds)

        # set resp body
        if evt.resp is None:
            self.ui.requestRespBodyTextEdit.clear()
        else:
            body = json_pretty(evt.resp.body)
            self.ui.requestRespBodyTextEdit.setText(body)

        # set resp headers
        if evt.resp is None:
            self.ui.requestRespHeadersTableWidget.setRowCount(0)
        else:
            headers = evt.resp.headers
            headers_size = len(headers.keys())
            self.ui.requestRespHeadersTableWidget.setRowCount(headers_size)
            r = 0
            for k in sorted(headers.keys()):
                v = headers[k]
                self.ui.requestRespHeadersTableWidget.setItem(r, 0, QTableWidgetItem(k))
                self.ui.requestRespHeadersTableWidget.setItem(r, 1, QTableWidgetItem(v))
                r += 1

        # set resp detail，审计信息
        detail = self._gen_resp_detail(evt)
        self.ui.requestRespDetailTextEdit.setText(detail)

        # clear all states，请求完毕后，清除关联的request worker
        if self._request_worker:
            self._request_worker.quit()
            self._request_worker.wait()
            self._request_worker.deleteLater()
            self._request_worker = None
        self.ui.requestInvokeButton.setEnabled(True)
```

而RequestWorker可以这样写：

```python
# 省略imports

# 用多进程，把request放到其他进程里，防止view层运行python代码阻塞
_REQUEST_POOL = ProcessPoolExecutor(max_workers=3)


def _executor():
    return _REQUEST_POOL


class RequestStartEvent:  # 请求开始的事件
    def __init__(self):
        pass

class RequestProgressEvent:  # 请求中
    def __init__(self, seconds: float):
        self.seconds = seconds

class RequestFinishEvent:  # 请求完成，如果发起失败或者有exception也算完成
    def __init__(self,
                 req: Optional[Request],
                 resp: Optional[Response],
                 err: Optional[Exception],
                 seconds: float):
        self.req = req
        self.resp = resp
        self.err = err
        self.seconds = seconds


class RequestSignals(QObject):  # 定义request的信号（事件）
    start = Signal(RequestStartEvent)
    progress = Signal(RequestProgressEvent)
    finish = Signal(RequestFinishEvent)


class RequestWorkerThread(QThread):
    def __init__(self, req: Request, parent=None):
        QThread.__init__(self, parent)
        self.req = req
        self.signals = RequestSignals()

    def run(self):
        LOGGER.info(f'do request at thread: {str(QThread.currentThread())}')
        req = self.req
        if not isinstance(req, Request):  # 类型不符，直接finish
            evt = RequestFinishEvent(
                req=None,
                resp=None,
                err=ValueError('req must be Request instance'),
                seconds=0
            )
            self.signals.finish.emit(evt)
            return
        validate_err = req.validate()
        if validate_err:  # 校验失败，直接finish
            evt = RequestFinishEvent(
                req=req,
                resp=None,
                err=validate_err,
                seconds=0
            )
            self.signals.finish.emit(evt)
            return
        self.signals.start.emit(RequestStartEvent())  # 开始请求，发事件

        executor = _executor()
        start_time = timeutil.now()
        future = executor.submit(req.invoke)  # submit给executor后返回future，可以随时调用done方法，看invoke是否完成了
        while not future.done():  # 没完成就把当前耗时emit给到view层
            cur_time = timeutil.now()
            seconds = (cur_time - start_time).total_seconds()
            evt = RequestProgressEvent(
                seconds=seconds
            )
            self.signals.progress.emit(evt)
            sleep_ms = random.randint(50, 150)  # sleep一个间隔，防止当前py虚拟机阻塞
            QThread.msleep(sleep_ms)
        resp, err = future.result()  # done了之后取result，即Response实例
        end_time = timeutil.now()
        seconds = (end_time - start_time).total_seconds()
        evt = RequestFinishEvent(
            req=req,
            resp=resp,
            err=err,
            seconds=seconds
        )
        self.signals.finish.emit(evt)  # 完成请求，发事件
```

这样，通过在worker里把request放到ProcessPoolExecutor里另一个进程，实时监控执行，再结合signal机制防止view层阻塞，就可以把简单的http请求能力串联起来。至于想了解ProcessPoolExecutor怎么运作的，可以参考笔者以前写的[这篇文章](https://utmhikari.top/2021/06/08/pythonnotes/python_processpoolexecutor/)。

## 项目部署

部署方面可以参考官网[Deployment](https://doc.qt.io/qtforpython-6/deployment/index.html)文档，采用[pyside6-deploy](https://doc.qt.io/qtforpython-6/deployment/deployment-pyside6-deploy.html)工具来做二进制的部署。部署本身可能需要安装其他的python库，比如Nuitka，这些在自己的python环境里准备就好。部署默认会生成pysidedeploy.spec文件，是部署的配置文件，如果有部署不成功的问题可以改配置文件解决，比如：

- project_dir：项目路径，相对于你运行部署的路径，填写一个点就行
- input_file：相对的入口文件路径，比如main.py
- exec_directory：相对的输出路径，比如output、build、dist之类，按自己情况来
- python_path：venv可以设置成绝对路径
- packages：可以指定某些库要安装，如果当前python版本没有对应库的话可以改版本号试试
- qml_files：相对的qml文件路径。没有qml的话，需要随便指定某个文件，不然会把整个项目include进去，venv开发的话过不了

设置好了跑通之后，预期就会在exec_directory生成二进制文件了。
