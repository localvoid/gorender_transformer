# [gorender](https://github.com/localvoid/gorender)_transformer 

> [pub](https://pub.dartlang.org/) transformer that renders templates with
[Go](http://golang.org) [html.Template](http://golang.org/pkg/html/template/)
template engine using JSON data file.

## Prerequisites

This transformer depends on [gorender](https://github.com/localvoid/gorender)
CLI utility that renders templates.

## Usage example

### `pubspec.yaml`

```yaml
name: gorender_example
dependencies:
  gorender_transformer: any
transformers:
- gorender_transformer
```

### `web/example.txt.tpl`

```
Hello, {{ .user }}
```

### `web/example.json`

```json
{"user": "Guest"}
```