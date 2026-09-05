// 提供 jsonld 模板 helper：为文章页生成 schema.org BlogPosting JSON-LD，
// 由 source/_data/head.swig 注入到 <head> 中，供搜索引擎与 AI 检索消费
'use strict';

function stripHtml(html) {
  return String(html || '')
    .replace(/<[^>]*>/g, '')
    .replace(/\s+/g, ' ')
    .trim();
}

hexo.extend.helper.register('jsonld', function (page) {
  if (!page || page.layout !== 'post' || !page.title) return '';

  var siteUrl = this.config.url.replace(/\/$/, '');
  var tags = (page.tags && page.tags.data) ? page.tags.data : [];
  var description = stripHtml(page.description || page.excerpt || page.content).slice(0, 200);

  var jsonld = {
    '@context': 'https://schema.org',
    '@type': 'BlogPosting',
    'headline': page.title,
    'description': description,
    'datePublished': page.date.toISOString(),
    'dateModified': page.updated.toISOString(),
    'author': {
      '@type': 'Person',
      'name': this.config.author,
      'url': siteUrl + '/about/'
    },
    'mainEntityOfPage': {
      '@type': 'WebPage',
      '@id': siteUrl + '/' + page.path
    },
    'inLanguage': 'zh-CN',
    'publisher': {
      '@type': 'Organization',
      'name': this.config.title
    }
  };

  if (tags.length) {
    jsonld.keywords = tags.map(function (t) { return t.name; }).join(', ');
  }

  return JSON.stringify(jsonld).replace(/</g, '\\u003c');
});
