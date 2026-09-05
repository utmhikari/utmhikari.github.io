// 生成 llms.txt 与 llms-full.txt，供 AI 检索引擎（Perplexity / ChatGPT Search 等）读取
// llms.txt：站点简介 + 按分类组织的文章索引（标题 / 链接 / 摘要）
// llms-full.txt：全量正文（去 HTML 标签，保留代码文本）
'use strict';

function stripHtml(html) {
  return String(html || '')
    .replace(/<[^>]*>/g, '')
    .replace(/\r/g, '')
    .replace(/[ \t]+/g, ' ')
    .replace(/\n{3,}/g, '\n\n')
    .trim();
}

hexo.extend.generator.register('llms-txt', function (locals) {
  var siteUrl = hexo.config.url.replace(/\/$/, '');
  var subtitle = hexo.config.subtitle || '';
  var description = hexo.config.description || '';

  var posts = locals.posts.sort('date', -1).toArray();

  // 按分类分组
  var groups = {};
  var order = [];
  posts.forEach(function (post) {
    var categories = (post.categories && post.categories.data) ? post.categories.data : [];
    var name = categories.length ? categories[0].name : '未分类';
    if (!groups[name]) {
      groups[name] = [];
      order.push(name);
    }
    groups[name].push(post);
  });

  var lines = [
    '# ' + hexo.config.title,
    '',
    '> ' + subtitle + ' — ' + description,
    '',
    '技术博客，聚焦测试开发、游戏开发、Python / Golang 与 AI 原生工程实践。文章均为第一线工程经验总结。',
    ''
  ];

  order.forEach(function (name) {
    lines.push('## ' + name);
    lines.push('');
    groups[name].forEach(function (post) {
      var url = siteUrl + '/' + post.path;
      var summary = stripHtml(post.description || post.excerpt || post._content).slice(0, 150);
      lines.push('- [' + post.title + '](' + url + '): ' + summary);
    });
    lines.push('');
  });

  lines.push('## About');
  lines.push('');
  lines.push('- [关于笔者](' + siteUrl + '/about/)');
  lines.push('- RSS 订阅: ' + siteUrl + '/atom.xml');
  lines.push('- 全量正文（供 AI 检索）: ' + siteUrl + '/llms-full.txt');
  lines.push('');

  var full = [
    '# ' + hexo.config.title,
    '',
    '> ' + subtitle + ' — ' + description,
    '',
    '本文件包含全站文章正文，供 AI 检索与引用。',
    ''
  ];

  order.forEach(function (name) {
    groups[name].forEach(function (post) {
      var url = siteUrl + '/' + post.path;
      full.push('## ' + post.title);
      full.push('');
      full.push('- 链接: ' + url);
      full.push('- 日期: ' + post.date.format('YYYY-MM-DD'));
      full.push('');
      full.push(stripHtml(post.content || post._content));
      full.push('');
    });
  });

  return [
    { path: 'llms.txt', data: lines.join('\n') },
    { path: 'llms-full.txt', data: full.join('\n') }
  ];
});
