---
title: 【极客日常】通过motrix启动逻辑初探electron的项目结构
date: 2022/06/05 12:40:18
categories:
- 极客日常
tags:
- nodejs
- electron
- vue
- ipc
- 工具开发
---

近期准备开始做`electron`相关的开发工作，因此借着这个机会就再去了解下`electron`。在[很久以前的文章](https://utmhikari.top/2019/10/20/geekdaily/electron_react/)中有稍微玩过`electron+react+antd`的脚手架，但也只限于快速开发`electron`应用，并没有去剖析整个项目结构。因此这次，还是得深入一下。

先前一段时间特别喜欢用开源的[Motrix](https://github.com/agalwood/Motrix)下载器，就是基于`electron+vue+aria2`去实现的，所以索性就把源码给`clone`了下来。本文就从最基础的开始，以`Motrix`的启动逻辑为入口，来研究下一个`electron`应用是如何打开的。

首先看一下`Motrix`的目录结构，源码基本在`src`下，呈现这样的层级关系：

<!-- more -->

- `main`：主进程，应用内部逻辑
   - `configs`：内部环境配置
   - `core`：软件核心管理逻辑
   - `menus`：不同`os`下的菜单配置
   - `pages`：基础页面
   - `ui`：各`ui`相关的`Manager`逻辑
   - `utils`：工具方法库
   - `Application.js`：应用入口
   - `Launcher.js`：启动器入口
   - `index.js/index.dev.js`：程序入口
      - `index.dev.js`相对于`index.js`只是另外安装了`devtools`
- `renderer`：渲染进程，`vue`页面逻辑，目录结构也是`vue`默认的，可以参考[这篇文章](https://www.cnblogs.com/dragonir/p/8711761.html)
   - `api`：外部接口
   - `assets`：资源文件
   - `components`：组件页面
   - `pages`：应用页面入口，`App.vue+main.js`
   - `router`：路由
   - `store`：应用内部数据
   - `utils`：工具方法库
   - `workers`：只有一个`tray.worker.js`用来绘制托盘`icon`
- `shared`：公用逻辑/工具
   - `aria2`：下载工具`jslib`
   - `locales`：本地化
   - `utils`：公用`js`工具方法库

从`MVC`的角度，`main`主进程的逻辑相当于是`model`，`renderer`渲染进程的逻辑相当于是`view`，而至于`controller`，可以通过`electron`支持下的两个进程的`ipc`事件处理机制来呈现。这一点，我们直接看启动逻辑就能明白。

运行`yarn run dev`，会启动`.election-vue/dev-runner.js`，其中会先初始化`renderer`和`main`，然后再启动`electron`

```javascript
// .election-vue/dev-runner.js
function init () {
  greeting()

  Promise.all([startRenderer(), startMain()])
    .then(() => {
      startElectron()
    })
    .catch(err => {
      console.error(err)
    })
}
```

在`startRenderer`和`startMain`中会读取`js`配置的程序入口，编译后运行。两个进程的入口`entry`分别是：

- 渲染进程：`src/pages/index/main.js`
- 主进程：`src/main/index.dev.js`

首先看渲染进程，运行的入口在这里：

```javascript
store.dispatch('preference/fetchPreference')
  .then((config) => {
    console.info('[Motrix] load preference:', config)
    init(config)
  })
  .catch((err) => {
    alert(err)
  })
```

首先会通过`preference/fetchPreference`这个`action`来获得应用配置，然后调用`init`函数启动界面。先看获取配置的逻辑：

```javascript
// src/renderer/store/modules/preferences.js
const actions = {
  fetchPreference ({ dispatch }) {
    return new Promise((resolve) => {
      api.fetchPreference()
        .then((config) => {
          dispatch('updatePreference', config)
          resolve(config)
        })
    })
  },
}

// src/renderer/api/Api.js
export default class Api {
  fetchPreference () {
    return new Promise((resolve) => {
      this.config = this.loadConfig()
      resolve(this.config)
    })
  }
  
  async loadConfig () {
    let result = is.renderer()  // electron-is，包含electron相关的IsXXX工具函数
      ? await this.loadConfigFromNativeStore()
      : this.loadConfigFromLocalStorage()

    result = changeKeysToCamelCase(result)
    return result
  }
  
  loadConfigFromLocalStorage () {
    const result = {}
    return result
  }

  async loadConfigFromNativeStore () {
    const result = await ipcRenderer.invoke('get-app-config')
    return result
  }
}
```

可以看到最终获取配置的逻辑落到`ipcRenderer.invoke('get-app-config')`。`ipcRenderer`相当于是渲染进程里进程间（与`Main`主进程）通信的`handle`，这里相当于是向主进程`invoke`了一个`get-app-config`事件。在主进程端的`ipcMain`可以注册这个事件的监听，然后返回对应的数据。
`ipcRenderer`和`ipcMain`的通信，可以查看这两个文档：

- [ipcRenderer模块](https://www.w3cschool.cn/electronmanual/electronmanual-ipc-renderer.html)
- [ipcMain模块](https://www.w3cschool.cn/electronmanual/electronmanual-ipc-main.html)

到这里就暂停，看下主进程的启动，主进程`index.js`会启用一个`Launcher`来开始主进程逻辑

```javascript
// src/main/index.js
global.launcher = new Launcher()

// src/main/Launcher.js
export default class Launcher extends EventEmitter {
  constructor () {
    super()
    this.url = EMPTY_STRING
    this.file = EMPTY_STRING
    
    // 只有一个实例可以运行，通过app.requestSingleInstanceLock()获取
    this.makeSingleInstance(() => {
      this.init()
    })
  }
  
  init () {
    this.exceptionHandler = new ExceptionHandler()
    this.openedAtLogin = is.macOS()
      ? app.getLoginItemSettings().wasOpenedAtLogin
      : false
    if (process.argv.length > 1) {
      // 场景：网页直接下载文件或者url
      this.handleAppLaunchArgv(process.argv)
    }
    logger.info('[Motrix] openedAtLogin:', this.openedAtLogin)
    this.handleAppEvents()
  }
  
  handleAppEvents () {
    this.handleOpenUrl()
    this.handleOpenFile()
    this.handelAppReady()
    this.handleAppWillQuit()
  }
}
```
主进程启动逻辑最终落到这`handleAppEvents`里面四个`handler`，分别是如下作用：

- `handleAppReady`：监听`ready`事件，初始化`Application`实例（`global.application`）并为其注册监听事件；监听`activate`事件，打开`index`页面
- `handleOpenUrl`：监听`open-url`事件，发送`url`给`Application`
- `handleOpenFile`：监听`open-file`事件，发送`file`给`Application`
- `handleAppWillQuit`：监听`will-quit`事件，停止`Application`

`election-app`的一系列事件，可以在[这个网站](https://www.electronjs.org/zh/docs/latest/api/app)查阅具体作用
接下来看下`Application`实例的初始化：

```javascript
// src/main/Application.js
export default class Application extends EventEmitter {
  constructor () {
    super()
    this.isReady = false
    this.init()
  }

  init () {
    // 配置管理
    this.configManager = this.initConfigManager()
    // 本地化
    this.locale = this.configManager.getLocale()
    this.localeManager = setupLocaleManager(this.locale)
    this.i18n = this.localeManager.getI18n()
    // 菜单
    this.setupApplicationMenu()
    // ? Window
    this.initWindowManager()
    // ? UPnP
    this.initUPnPManager()
    // 内部engine与client
    this.startEngine()
    this.initEngineClient()
    // 界面Managers
    this.initTouchBarManager()
    this.initThemeManager()
    this.initTrayManager()
    this.initDockManager()
    this.autoLaunchManager = new AutoLaunchManager()
    this.energyManager = new EnergyManager()
    // 更新Manager
    this.initUpdaterManager()
    // 内部协议Manager
    this.initProtocolManager()
    // 注册应用操作事件的handlers
    this.handleCommands()
    // 下载进度事件的event
    this.handleEvents()
    // on/handle event channels
    this.handleIpcMessages()
    this.handleIpcInvokes()
    this.emit('application:initialized')
  }
```

其他的先不说，在`handleIpcInvokes`里面注册了`get-app-config`的`handler`，逻辑如下：

```javascript
// src/main/Application.js
export default class Application extends EventEmitter {  
  handleIpcInvokes () {
    ipcMain.handle('get-app-config', async () => {
      const systemConfig = this.configManager.getSystemConfig()
      const userConfig = this.configManager.getUserConfig()

      const result = {
        ...systemConfig,
        ...userConfig
      }
      return result
    })
  }
}

// src/main/core/ConfigManager.js
export default class ConfigManager {
  constructor () {
    this.systemConfig = {}
    this.userConfig = {}
    this.init()
  }
  
  init () {
    this.initSystemConfig()
    this.initUserConfig()
  }
  
  initSystemConfig () {
    this.systemConfig = new Store({
      name: 'system',
      defaults: {
        'all-proxy': EMPTY_STRING
        // 这里省略其他的了
      }
    })
    this.fixSystemConfig()
  }
  
  initUserConfig () {
    this.userConfig = new Store({
      name: 'user',
      defaults: {
        'all-proxy-backup': EMPTY_STRING,
        // 这里省略其他的了
      }
    })
    this.fixUserConfig()
  }
}
```
这里用了`electron-store`持久化用户配置，详情参考[这个链接](https://github.com/sindresorhus/electron-store)
最终给到渲染进程的`config`，就是`systemConfig`和`userConfig`合并的结果，因此可以再转到渲染进程查看`init(config)`的逻辑：

```javascript
// 
function init (config) {
  if (is.renderer()) {
    Vue.use(require('vue-electron'))
  }
  Vue.http = Vue.prototype.$http = axios
  Vue.config.productionTip = false
  const { locale } = config
  const localeManager = getLocaleManager()
  localeManager.changeLanguageByLocale(locale)
  Vue.use(VueI18Next)
  const i18n = new VueI18Next(localeManager.getI18n())
  Vue.use(Element, {
    size: 'mini',
    i18n: (key, value) => i18n.t(key, value)
  })
  Vue.use(Msg, Message, {
    showClose: true
  })
  Vue.component('mo-icon', Icon)
  const loading = Loading.service({
    fullscreen: true,
    background: 'rgba(0, 0, 0, 0.1)'
  })
  sync(store, router)
  /* eslint-disable no-new */
  global.app = new Vue({
    components: { App },
    router,
    store,
    i18n,
    template: '<App/>'
  }).$mount('#app')
  global.app.commands = commands
  require('./commands')
  global.app.trayWorker = initTrayWorker()
  setTimeout(() => {
    loading.close()
  }, 400)
}
```
这一段代码主要设置`Vue`的内部属性并起了`Vue`实例赋予`global.app`。在其中，加载了`App.vue`中`id=app`的页面内容，包括这些：

```html
<template>
  <div id="app">
    <mo-title-bar
      v-if="isRenderer"
      :showActions="showWindowActions"
    />
    <router-view />
    <mo-engine-client
      :secret="rpcSecret"
    />
    <mo-ipc v-if="isRenderer" />
    <mo-dynamic-tray v-if="enableTraySpeedometer" />
  </div>
</template>
```
其中，`<router-view />`是实质展示了路由为`/`的页面，对应到`routers`里面就是`@/components/Main`以及其下级的`task`的路由组件。其他几个分别是：

- `mo-title-bar`：顶层的最小化、最大化、退出按钮
- `mo-engine-client`：不渲染界面的组件，实质只有`js`逻辑，用于管理下载进度
- `mo-ipc`：不渲染界面的组件，实质只有`js`逻辑，用于`ipc`
- `mo-dynamic-tray`：下载速度显示组件

到了这里，整个`app`就启动完成了。
