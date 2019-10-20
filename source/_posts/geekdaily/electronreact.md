---
title: 【极客日常】electron+react+antd深色主题打造桌面应用
date: 2019/10/07 01:40:29
categories:
- 极客日常
tags:
- electron
- react
- antd
- 桌面应用
- 前端
---

桌面应用的实现方式有很多，但谈到多操作系统平台兼容的话，就不得不提到[electron](https://electronjs.org/)。electron是前端开发的利好，做过web前端的同学只要稍微迁移下自己的项目，就能够将原本的web前端变成桌面应用。

因此，本文以react为例，以antd为UI库支持，讲解基于react的electron应用该如何搭建。

首先，[electron-react-boilerplate](https://github.com/electron-react-boilerplate/electron-react-boilerplate)项目，就帮助我们初始化了基于react的electron应用。electron-react-boilerplate内置了flow静态类型检查机制、基于webpack的electron应用打包支持以及with redux的前端架构。故在此基础上再引入其它的lib，也不会过于困难。本文采用的electron-react-boilerplate版本为0.17.1。

通过`yarn add antd`，就可以安装上antd库。要在内置的例子里以antd为layout的话，首先需要在`app`文件夹下新建`app.global.less`文件，填充内容：`@import '../node_modules/antd/dist/antd.less';`，然后我们可以再观察到，`app/containers/Root.js`是redux store的抽象层，wrap了路由；路由所在的文件为`app/Route.js`，是以`<App>`标签为根的路由集合；`<App>`主界面所在的文件为`app/containers/App.js`，我们通过更改其中的内容，就可以变换主界面的样式了。我们就以antd的layout为例，写一个App主界面：

<!-- more -->

```jsx
import React from 'react';
import PropTypes from 'prop-types';
import { withRouter } from 'react-router-dom';
import { Layout, Card, Icon, Menu, Button } from 'antd';
import { shell } from 'electron';
import routes from '../constants/routes';

const { Sider, Content } = Layout;

type Props = {
  children: React.Node
};

type State = {
  menuKey: string
};

const menuList = [
  { key: 'note', text: '笔记', icon: 'book' },
  { key: 'setting', text: '设置', icon: 'setting' }
];

class App extends React.Component<Props, State> {
  props: Props;

  static propTypes = {
    history: PropTypes.object.isRequired
  };

  state = {
    menuKey: 'note'
  };

  handleMenuClick = (e: Event) => {
    this.setState({ menuKey: e.key });
    const { history } = this.props;
    history.push(routes[e.key]);
  };

  render() {
    const { children } = this.props;
    const { menuKey } = this.state;
    return (
      <Layout style={{ minHeight: '100vh' }}>
        <Sider collapsible={false}>
          <Menu
            style={{ height: '100%' }}
            theme="dark"
            onClick={this.handleMenuClick}
            selectedKeys={[menuKey]}
            mode="inline"
          >
            {menuList.map(item => (
              <Menu.Item key={item.key}>
                <span>
                  <Icon type={item.icon} />
                  {`\t${item.text}`}
                </span>
              </Menu.Item>
            ))}
          </Menu>
        </Sider>
        <Content>
          <Card
            title={menuList.find(i => i.key === menuKey).text}
            style={{ height: '100%' }}
            extra={
              <Button
                shape="circle"
                onClick={() =>shell.openExternal('https://github.com')}
                icon="github"
              />
            }
          >
            {children}
          </Card>
        </Content>
      </Layout>
    );
  }
}

export default withRouter(App);
```

写App主界面后，记得也得实时更新`app/Route.js`以及其关联的`app/constants/routes.json`数据喔~

在`app/containers`中其它以`Page`结尾的文件，约定俗成是各个子路由绑定redux的层次。比如在上面我们设置了笔记的menu，那么在`app/containers/NotePage.js`中，就可以定义跟redux的绑定：

```jsx
import { bindActionCreators } from 'redux';
import { connect } from 'react-redux';
import Note from '../components/note/index';
import * as NoteActions from '../actions/note';

function mapStateToProps(state) {
  return { ...state.note };
}

function mapDispatchToProps(dispatch) {
  return bindActionCreators(NoteActions, dispatch);
}

export default connect(
  mapStateToProps,
  mapDispatchToProps
)(Note);
```

之后在`app/components/note/index.js`中，就可以编写笔记页面的样式了。

至于redux这块，由于flow增加了静态检查，因此会稍微麻烦一点。虽然在`app/reducers/index.js`中已经帮我们完成了reducer的绑定，但在`app/reducers/types.js`中，还需要初始化各个state的类型：

```jsx
import type { Dispatch as ReduxDispatch, Store as ReduxStore } from 'redux';

// action
export type Action = {
  +type: string
};

// note state
export type NoteState = {
  notes: Array
};

// state type
export type StateType = {
  note: NoteState
};

export type GetState = () => StateType;

export type Dispatch = ReduxDispatch<Action>;

export type Store = ReduxStore<GetState, Action>;
```

之后根据预定义的类型，再写action跟reducer。拿note笔记模块为例，action跟reducer如下：

```jsx
// app/actions/note.js
import type { Dispatch } from '../reducers/types';

export function add() {
  return (dispatch: Dispatch) => dispatch({ type: 'ADD_NOTE' });
}

export function edit(index: number) {
  return (dispatch: Dispatch) => dispatch({ type: 'EDIT_NOTE', index });
}

export function remove() {
  return (dispatch: Dispatch) => dispatch({ type: 'REMOVE_NOTE' });
}

export function clear() {
  return (dispatch: Dispatch) => dispatch({ type: 'CLEAR_NOTE' });
}

// app/reducers/note.js
import type { Action, NoteState } from './types';

const defaultState: NoteState = {
  notes: []
};

const addNote = state => ({
  ...state,
  notes: [...state.notes, state.notes.length + 1]
});

const editNote = (state, payload) => {
  const { notes } = state;
  const { index } = payload;
  console.log(payload);
  if (index >= notes.length || index < 0) {
    return state;
  }
  const newNotes = [...notes];
  newNotes[index] *= 2;
  return { ...state, notes: newNotes };
};

const removeNote = state => {
  const { notes } = state;
  if (notes.length === 0) {
    return state;
  }
  const newNotes = [...notes];
  newNotes.splice(newNotes.length - 1, 1);
  return { ...state, notes: newNotes };
};

const clearNote = state => ({ ...state, notes: [] });

export default function note(state: NoteState = defaultState, action: Action) {
  const { type, ...payload } = action;
  switch (type) {
    case 'ADD_NOTE': {
      return addNote(state);
    }
    case 'EDIT_NOTE': {
      return editNote(state, payload);
    }
    case 'REMOVE_NOTE': {
      return removeNote(state);
    }
    case 'CLEAR_NOTE': {
      return clearNote(state);
    }
    default: {
      return state;
    }
  }
}
```

这样便初始化好了基本的笔记增删改查操作，整个桌面应用就有雏形了。

桌面软件一般会有标题与菜单栏，标题的修改是在`app/app.html`的`title`标签，而菜单的修改在`app/menu.js`中。

antd的深色主题在桌面应用中显示会不错，因此我们想要最终产品为深色主题。值得注意的是，由于我们刚开始引入antd新建了less文件，但electron-react-boilerplate默认不支持less，因此需要我们在开发与生产环境的webpack配置中（`configs/webpack.config.renderer.dev.babel.js`与`configs/webpack.config.renderer.prod.babel.js`）先将antd的深色主题import进来，然后自行`yarn add less-loader`，再在配置中的`module.rules`列表中，追加一段就好：

```jsx
import antdTheme from '@ant-design/dark-theme';

...

{
  test: /\.less$/,
  use: [
    {
      loader: 'style-loader'
    },
    {
      loader: 'css-loader' // translates CSS into CommonJS
    },
    {
      loader: 'less-loader', // compiles Less to CSS
      options: {
        modifyVars: antdTheme,
        javascriptEnabled: true
      }
    }
  ]
}

...
```

这样，electron+react+antd深色主题桌面应用的基础流程就打通了。
