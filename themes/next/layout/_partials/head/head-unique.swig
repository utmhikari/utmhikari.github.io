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
  Webfont：只留 IBM Plex Mono（代码 400/700），同域自托管于 lib/fontsource/。
           IBM Plex Serif 已随字体栈移除，不再注入（省掉 2 条请求与解析）。
           汉字不挂 webfont：Mac 落 Songti SC，Windows 统一微软雅黑，
           其余环境由系统中文衬线（Ubuntu 的 Noto Serif CJK SC）兜底。
#}
<link rel="stylesheet" href="{{ url_for(theme.vendors._internal + '/fontsource/ibm-plex-mono/400.css') }}">
<link rel="stylesheet" href="{{ url_for(theme.vendors._internal + '/fontsource/ibm-plex-mono/700.css') }}">

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
