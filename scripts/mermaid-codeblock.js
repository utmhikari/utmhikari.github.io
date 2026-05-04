/**
 * 让 ```mermaid ...``` 代码块自动渲染为 mermaid 图。
 *
 * 原理：在 before_post_render 阶段（Hexo 还没把 markdown 交给 renderer 前），
 * 把文章正文里的 mermaid fenced code block 替换成 NexT 已注册的
 * {% mermaid %}...{% endmermaid %} tag，从而复用
 * themes/next/scripts/tags/mermaid.js + themes/next/layout/_third-party/mermaid.swig
 * 的全部现有能力，无需改主题。
 *
 * 触发条件：需要 theme.mermaid.enable === true。
 */

'use strict';

// 匹配独立成段的 ```mermaid ... ``` 代码块。
// 用 RegExp 构造函数规避字面量中的换行被源码转义的问题。
// 捕获组：1-前缀换行 2-起始反引号 3-代码内容
const FENCE_RE = new RegExp(
  '(^|\\r?\\n)[ \\t]*(`{3,})[ \\t]*mermaid[ \\t]*\\r?\\n' +
  '([\\s\\S]*?)' +
  '\\r?\\n[ \\t]*\\2[ \\t]*(?=\\r?\\n|$)',
  'g'
);

hexo.extend.filter.register('before_post_render', function (data) {
  const themeCfg = this.theme && this.theme.config && this.theme.config.mermaid;
  if (!themeCfg || !themeCfg.enable) {
    return data;
  }
  if (!data || typeof data.content !== 'string' || data.content.indexOf('mermaid') === -1) {
    return data;
  }

  data.content = data.content.replace(FENCE_RE, function (_m, lead, _fence, code) {
    // 去掉可能的行尾 \r 并原样保留缩进；tag 必须独立成行
    const body = code.replace(/\r$/gm, '');
    return `${lead}{% mermaid %}\n${body}\n{% endmermaid %}`;
  });

  return data;
}, 9);
