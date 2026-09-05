{% extends '_layout.swig' %}
{% import '_macro/post.swig' as post_template %}
{% import '_macro/sidebar.swig' as sidebar_template %}

{% block title %}{{ page.title }} | {{ title }}{% endblock %}

{% block page_class %}page-post-detail{% endblock %}

{% block content %}

  <div id="posts" class="posts-expand">
    {{ post_template.render(page) }}
  </div>

  {# 结构化数据：供搜索引擎与 AI 检索消费，置于 body 内合法 #}
  {% set jsonld_str = jsonld(page) %}
  {% if jsonld_str %}
  {% autoescape false %}
  <script type="application/ld+json">{{ jsonld_str }}</script>
  {% endautoescape %}
  {% endif %}

{% endblock %}

{% block sidebar %}
  {{ sidebar_template.render(true) }}
{% endblock %}

{% block script_extra %}
  {% include '_scripts/pages/post-details.swig' %}
{% endblock %}
