# [gorender](https://github.com/localvoid/gorender)_transformer 

> [pub](https://pub.dartlang.org/) transformer that renders templates
> with [Go](http://golang.org)
> [text.template](http://golang.org/pkg/text/template/) template
> engine using JSON data file.

## Prerequisites

This transformer depends on
[gorender](https://github.com/localvoid/gorender) CLI utility that
renders templates.

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

## Options

### `template-extension`

Template extensions

TYPE: `String`  
DEFAULT: `.gtpl`

### `data-extension`

Data extensions

TYPE: `String`  
DEFAULT: `.json`

### `html-extension`

Templates that will be rendered with `html.template` package. The full
extension of the template should consist of `html-extension` and
`template-extension`, for example: `.html.gtpl`.

TYPE: `String`  
DEFAULT: `.html`