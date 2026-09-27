{% if theme.busuanzi_count.enable %}
<div class="busuanzi-count">
  <script async src="https://busuanzi.ibruce.info/busuanzi/2.3/busuanzi.pure.mini.js"></script>

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
  // 不蒜子是第三方服务，脚本被拦或服务超时都会留下空白图标占位。
  // 超时后若三个计数值一个都没填上，就把块体整体隐藏（post 页浏览数由 .busuanzi-post-view 承接）。
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
</script>
{% endif %}
