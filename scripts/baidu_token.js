// 百度主动推送 token 不入库：运行时从环境变量 BAIDU_PUSH_TOKEN 注入。
// 历史明文 token 已泄漏在仓库 git 历史中（hexo 分支曾长期 public 可读），
// 如需继续使用百度推送，建议先到百度站长平台重置推送凭证。
'use strict';

hexo.on('ready', function () {
  var token = process.env.BAIDU_PUSH_TOKEN;
  if (token) {
    hexo.config.baidu_url_submit = hexo.config.baidu_url_submit || {};
    hexo.config.baidu_url_submit.token = token;
  }
});
