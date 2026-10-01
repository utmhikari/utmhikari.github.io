{% if theme.busuanzi_count.enable %}
<div class="busuanzi-count">
  {% if theme.busuanzi_count.total_visitors %}
    <span class="post-meta-item-icon">
      <i class="fa fa-{{ theme.busuanzi_count.total_visitors_icon }}"></i>
    </span>
    <span class="site-uv" title="{{ __('footer.total_visitors') }}">
      <span class="busuanzi-value" id="busuanzi_value_site_uv"></span>
    </span>
  {% endif %}

  {% if theme.busuanzi_count.total_visitors and theme.busuanzi_count.total_views %}
    <span class="post-meta-divider">|</span>
  {% endif %}

  {% if theme.busuanzi_count.total_views %}
    <span class="post-meta-item-icon">
      <i class="fa fa-{{ theme.busuanzi_count.total_views_icon }}"></i>
    </span>
    <span class="site-pv" title="{{ __('footer.total_views') }}">
      <span class="busuanzi-value" id="busuanzi_value_site_pv"></span>
    </span>
  {% endif %}
</div>
<script>
  // 不蒜子是第三方服务：脚本本体 + 其内部再发的 JSONP 数据接口，任一请求挂起都会拖住
  // window load 事件（标签页一直转圈）。原先的 async script 标签直接挂在关键路径上——
  // async 只免解析阻塞、仍参与 load 完成判定；现改为 load 完成后才动态注入，不蒜子的
  // 全部网络活动都发生在页面可交互之后，502 / 超时不再阻塞页面。
  // 注入后再给 5s 兜底：三个计数值一个都没填上就整体隐藏块体（post 页浏览数由
  // .busuanzi-post-view 承接，见 _macro/post.swig）。
  (function () {
    function loadBusuanzi() {
      var s = document.createElement('script');
      s.async = true;
      s.src = 'https://busuanzi.ibruce.info/busuanzi/2.3/busuanzi.pure.mini.js';
      document.body.appendChild(s);

      setTimeout(function () {
        var ids = ['busuanzi_value_site_uv', 'busuanzi_value_site_pv', 'busuanzi_value_page_pv'];
        var filled = ids.some(function (id) {
          var el = document.getElementById(id);
          return el && el.textContent.replace(/\s/g, '');
        });
        if (filled) return;
        var nodes = document.querySelectorAll('.busuanzi-count, .busuanzi-post-view');
        for (var i = 0; i < nodes.length; i++) nodes[i].style.display = 'none';
      }, 5000);
    }

    if (document.readyState === 'complete') {
      loadBusuanzi();
    } else {
      window.addEventListener('load', loadBusuanzi);
    }
  })();
</script>
{% endif %}
