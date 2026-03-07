---
layout: page
title: 日语笔记首页
---

这个站点由 GitHub Pages 自动发布，内容来自仓库中的 Markdown。

- 课程累计：`/courses/*.md`
- 专题笔记：`/topics/*.md`
- 临时输入：`/inbox/*.md`

点击下方任意条目可直接网页阅读。

{% assign note_files = site.static_files | where_exp: "f", "f.extname == '.md'" | sort: "path" %}
{% assign has_notes = false %}
{% for file in note_files %}
  {% if file.path contains '/courses/' or file.path contains '/topics/' or file.path contains '/inbox/' %}
    {% assign has_notes = true %}
  {% endif %}
{% endfor %}

{% if has_notes %}
| 文件 | 打开 |
| --- | --- |
{% for file in note_files %}
  {% if file.path contains '/courses/' or file.path contains '/topics/' or file.path contains '/inbox/' %}
| `{{ file.path }}` | [阅读]({{ '/viewer.html?file=' | append: file.path | uri_escape | relative_url }}) |
  {% endif %}
{% endfor %}
{% else %}
当前还没有可展示的笔记文件。
{% endif %}

