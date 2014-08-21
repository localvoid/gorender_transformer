// Copyright (c) 2014, the gorender_transformer project authors. Please see the
// AUTHORS file for details. All rights reserved. Use of this source code is
// governed by a BSD-style license that can be found in the LICENSE file.

/* Transfomer that renders go `text.template` templates using JSON data file. */
library gorender_transformer;

import 'dart:async';
import 'dart:io';
import 'package:barback/barback.dart';
import 'package:path/path.dart' as ospath;

/**
 * Transformer Options:
 *
 * [templateExtension] Extension of template files. DEFAULT: `.gtpl`
 *
 * [dataExtension] Extension of data files. DEFAULT: `.json`
 *
 * [htmlExtension] Extension of html templates. This extensions will be
 * rendered with `html.template` package. Full extension of the template
 * file will be `[htmlExtension][templateExtension]`. DEFAULT: `.html`
 */
class TransformerOptions {
  final String templateExtension;
  final String dataExtension;
  final String htmlExtension;

  TransformerOptions(this.templateExtension, this.dataExtension,
      this.htmlExtension);

  factory TransformerOptions.parse(Map configuration) {
    config(key, defaultValue) {
      var value = configuration[key];
      return value != null ? value : defaultValue;
    }

    return new TransformerOptions(
        config('template-extension', '.gtpl'),
        config('data-extension', '.json'),
        config('html-extension', '.html'));
  }
}

/**
 * Renders go `text.template` templates using JSON data file.
 *
 * This transformer assumes that data file is located near the template file.
 *
 * When the `pub` is running in `RELEASE` mode nothing is rendered and all data
 * files are ignored.
 */
class Transformer extends AggregateTransformer implements
    DeclaringAggregateTransformer {
  final BarbackSettings _settings;
  final TransformerOptions _options;

  Transformer.asPlugin(BarbackSettings s)
      : _settings = s,
        _options = new TransformerOptions.parse(s.configuration);

  String classifyPrimary(AssetId id) {
    if (id.extension == _options.templateExtension) {
      var outPath = ospath.withoutExtension(ospath.withoutExtension(id.path));
      return '${id.package}|${outPath}';
    } else if (id.extension == _options.dataExtension) {
      var outPath = ospath.withoutExtension(id.path);
      return '${id.package}|${outPath}';
    } else {
      return null;
    }
  }

  Future apply(AggregateTransform transform) {
    return transform.primaryInputs.toList().then((assets) {
      if (assets.length == 2) {
        Asset templateAsset;
        Asset dataAsset;
        bool isHtml = false;

        if (assets[0].id.extension == _options.templateExtension) {
          templateAsset = assets[0];
          dataAsset = assets[1];
        } else {
          templateAsset = assets[1];
          dataAsset = assets[0];
        }

        if (ospath.extension(ospath.withoutExtension(templateAsset.id.path)) ==
            _options.htmlExtension) {

          isHtml = true;
        }

        if (_settings.mode == BarbackMode.DEBUG) {
          return Directory.systemTemp.createTemp(
              'gorender-transformer-').then((dir) {

            var templateSink;
            var dataSink;

            return new Future.sync(() {
              templateSink = new File(
                  ospath.join(dir.path, 'template')).openWrite();
              dataSink = new File(
                  ospath.join(dir.path, 'data.json')).openWrite();

              var templateFuture = templateSink.addStream(templateAsset.read());
              var dataFuture = dataSink.addStream(dataAsset.read());

              return Future.wait([templateFuture, dataFuture]);
            }).then((files) {
              return _gorender(files[0].path, files[1].path, isHtml);
            }).then((result) {
              transform.addOutput(
                  new Asset.fromString(templateAsset.id.changeExtension(''), result));
            }).whenComplete(() {
              var futures = [];
              if (templateSink != null) {
                futures.add(templateSink.close());
              }
              if (dataSink != null) {
                futures.add(dataSink.close());
              }
              return Future.wait(futures);
            }).whenComplete(() {
              return dir.delete(recursive: true);
            });
          });
        } else {
          transform.consumePrimary(dataAsset.id);
        }
      }
    }).catchError((e) {
      transform.logger.error(e.toString());
    }, test: (e) => e is InvalidDataException);
  }

  Future declareOutputs(DeclaringAggregateTransform transform) {
    return transform.primaryIds.take(2).toList().then((assets) {
      if (assets.length < 2) {
        return;
      }

      AssetId templateAssetId;
      AssetId dataAssetId;

      if (assets[0].extension == _options.templateExtension) {
        templateAssetId = assets[0];
        dataAssetId = assets[1];
      } else {
        templateAssetId = assets[1];
        dataAssetId = assets[0];
      }

      transform.consumePrimary(dataAssetId);
      if (_settings.mode == BarbackMode.DEBUG) {
        transform.declareOutput(templateAssetId.changeExtension(''));
      }
    });
  }
}

Future<String> _gorender(String templatePath, String dataPath, bool html) {
  var flags;
  if (html) {
    flags = ['-html', '-d', dataPath, templatePath];
  } else {
    flags = ['-d', dataPath, templatePath];
  }

  return Process.run('gorender', flags).then((result) {
    if (result.exitCode != 0) {
      if (result.exitCode == 65) {
        throw new InvalidDataException(result.stderr);
      }
      throw new GorenderException(result.stderr);
    };
    return result.stdout;
  }).catchError((e) {
    throw new GorenderException("gorender: command not found");
  }, test: (e) => e is ProcessException && e.errorCode == 2);
}

class InvalidDataException implements Exception {
  final String msg;
  InvalidDataException([this.msg]);
  String toString() => msg == null ? 'InvalidData' : msg;
}

class GorenderException implements Exception {
  final String msg;
  GorenderException([this.msg]);
  String toString() => msg == null ? 'GorenderException' : msg;
}
