{#
  Windows 嗅探：给 <html> 挂 os-win 类，供 custom.styl 16 节在 Windows 上加发丝描边
  （补偿 Palatino Linotype 在 ClearType 下的发浅渲染；字体栈与全局一致）；Mac/移动端不命中，零影响
#}
<script>
  if (/Windows NT/.test(navigator.userAgent)) {
    document.documentElement.className += ' os-win';
  }
</script>

{#
  Webfont：Noto Serif SC（汉字衬线 400/600）+ IBM Plex Mono（代码 400/700）
           + IBM Plex Serif（拉丁衬线 400/600，仅作无 Palatino 环境的兜底网：
             栈里系统 Palatino 族命中时浏览器不会下载其字形，零成本）
  fontsource CDN（gcore 镜像，与主题其它 vendors 同源）；不可达时回退系统字体栈
#}
<link rel="preconnect" href="https://gcore.jsdelivr.net" crossorigin>
<link rel="stylesheet" href="//gcore.jsdelivr.net/npm/@fontsource/ibm-plex-serif@5/400.css">
<link rel="stylesheet" href="//gcore.jsdelivr.net/npm/@fontsource/ibm-plex-serif@5/600.css">
<link rel="stylesheet" href="//gcore.jsdelivr.net/npm/@fontsource/ibm-plex-mono@5/400.css">
<link rel="stylesheet" href="//gcore.jsdelivr.net/npm/@fontsource/ibm-plex-mono@5/700.css">
<link rel="stylesheet" href="//gcore.jsdelivr.net/npm/@fontsource/noto-serif-sc@5/400.css">
<link rel="stylesheet" href="//gcore.jsdelivr.net/npm/@fontsource/noto-serif-sc@5/600.css">

{{
  open_graph({
    twitter_id: theme.twitter,
    google_plus: theme.google_plus,
    fb_admins: theme.fb_admins,
    fb_app_id: theme.fb_app_id
  })
}}

{% if theme.rss === '' and config.feed and config.feed.path %}
  {% set theme.rss = config.feed.path %}
{% endif %}
{% if theme.rss %}
  <link rel="alternate" href="{{ url_for(theme.rss) }}" title="{{ title }}" type="application/atom+xml"/>
{% endif %}

{# Canonical, good for google search engine (SEO) : https://support.google.com/webmasters/answer/139066 #}
{% if theme.canonical %}
  <link rel="canonical" href="{{ config.url }}/{{ page.canonical_path.replace('index.html', '') }}"/>
{% endif %}

{# Exports some front-matter variables to Front-End #}
<script id="page.configurations">
  CONFIG.page = {
    sidebar: {{ page.sidebar | json_encode }},
  };
</script>
