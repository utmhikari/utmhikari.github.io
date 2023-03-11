---
title: 【Python随笔】一天搞定，爬虫爬取w3schools的sql语句案例集
date: 2023/03/11 17:16:15
categories:
- Python随笔
tags:
- python
- 爬虫
- SQL
- BeautifulSoup
- HTML
---

在很久以前的[Easy Python](https://utmhikari.top/categories/Easy-Python/)系列中，介绍了通过爬虫手段[爬取豆瓣电影信息](https://utmhikari.top/2019/03/31/easypython/iii/)的一种技术套路。今天故技重施，为了迎合先前做[SQL语句分析](https://utmhikari.top/2023/03/04/gofromzero/09_sql_parser/)的需要，决定爬取[w3schools网站](https://www.w3schools.com/sql/)上面所有SQL案例，用作测试用例。

本文就来详细讲述，爬取w3schools网站的实现方式，以及里面需要注意的一些点。代码统一放在[这里](https://github.com/utmhikari/w3schools_sqls_crawler)。

<!-- more -->

首先需要定位包含SQL语句的页面和元素。在w3schools网站当中，侧边栏部分（`id='leftmenuinnerinner'`）列举了所有页面的链接，通过网页的`<a target='_top>`标签就能筛选到，通过`href`属性的指向就能够知道对应网页的URL。之后，对于每个网页里的SQL语句，所有语句都封装在`class=w3-code notranslate sqlHigh`样式的标签当中。因此，我们只需要拿到所有网页，遍历打开所有页面，再把所有SQL标签里的语句文本抽出来，处理一下就可以了。

通过request的GET方式，能够直接获取到URL对应的网页内容，再用BeautifulSoup解析，就能够拿到HTML树，然后就可以按照这些条件来寻找对应元素以及里面的内容了。

比如，获取所有网页的代码如下：

```python
def _get_all_pages() -> List[Tuple[str, str]]:
    # get root page
    page_url = ROOT_URL
    print('get all pages from %s' % page_url)
    resp = requests.get(page_url, headers=_headers())
    soup = BeautifulSoup(resp.text, 'html.parser')

    # find leftmenuinnerinner
    left_menu = soup.find(id='leftmenuinnerinner')

    # find all pages at <a target="_top">
    links = left_menu.find_all(name='a', target='_top')
    pages = []
    for link in links:
        pages.append((link.text, link['href']))
    print('all pages are: %s' % json.dumps(pages, indent=2, ensure_ascii=False))
    print('overall %d pages!' % len(pages))

    return pages
```

爬取一个网页的SQL案例集的逻辑如下：

```python
def _crawl_sqls(name, page, referer_page=''):
    sql_set = set()
    url = _page_url(page)
    print('[%s] crawling page url %s...' % (name, url))
    resp = requests.get(url, headers=_headers(referer_page=referer_page))
    soup = BeautifulSoup(resp.text, 'html.parser')

    # get all examples in class="w3-code notranslate sqlHigh"
    sql_blocks = soup.find_all(class_='w3-code notranslate sqlHigh')
    print('[%s] overall %d sql blocks' % (name, len(sql_blocks)))
    for sql_block in sql_blocks:
        # some children blocks may not contain space, which leads to
        # extracting non-separated SQLs like -> SELECT * FROM CustomersLIMIT 3;
        # so we should use get_text API
        # instead of using sql_block.text straightly
        sql_text_no_endl = sql_block.get_text(' ', strip=True).replace('\n', ' ').strip()
        sql_text = re.sub(r'\s+', ' ', sql_text_no_endl)
        if not sql_text.endswith(';'):  # add semicolon
            sql_text = sql_text + ';'

        if sql_text not in sql_set:
            print('[%s] crawled new sql -> %s' % (name, sql_text))
            sql_set.add(sql_text)
        else:
            print('[%s] detected duplicated sql -> %s' % (name, sql_text))

    sqls = list(sql_set)
    print('[%s] crawl finished! added %d sqls!' % (name, len(sqls)))
    return sqls
```

这两块代码就基本上形成了爬虫的主逻辑，但是仅有这些还是远远不够的。很多网站为了反爬虫，会有一些限流操作，比如在w3schools每秒爬一个网页的话，爬到中间会request不到网页的内容，这就有可能触发限流机制了。面对这种场景，有几个方法可以规避：

- 时间间隔：调整长一点，比如10s一次
- User-Agent：随机设置为不同浏览器的UA，使得限流认为是不同的访问
- Referer：设置为网站主站，表示是从主站访问过来当前网页的
- 自动存储进度：每爬一个网站就把当前进度存下来，这样失败了下一次爬，就可以不需要从一开始爬起

如果还有更高级点，可以用代理服务器来爬，这样也能规避限流机制。通过以上的方式，就能把w3schools上面几百条SQL都给爬取到了。一天搞定，EZPZ！
