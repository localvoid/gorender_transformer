// Copyright (c) 2014, the gorender_transformer project authors. Please see the
// AUTHORS file for details. All rights reserved. Use of this source code is
// governed by a BSD-style license that can be found in the LICENSE file.

/* Transfomer that renders go `html.Template` templates using JSON data file. */
library gorender_transformer;

import 'dart:async';
import 'dart:io';
import 'package:barback/barback.dart';
import 'package:path/path.dart' as ospath;

/**
 * Renders go `html.Template` templates using JSON data file.
 *
 * This transformer assumes that data file is located near the template file.
 *
 * When the `pub` is running in `RELEASE` mode nothing is rendered and all data
 * files are ignored.
 */
class Transformer extends AggregateTransformer implements
    DeclaringAggregateTransformer {
  final BarbackSettings _settings;

  Transformer.asPlugin(this._settings);

  String classifyPrimary(AssetId id) {
    if (id.extension == '.tpl') {
      var outPath = ospath.withoutExtension(ospath.withoutExtension(id.path));
      return '${id.package}|${outPath}';
    } else if (id.extension == '.json') {
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

        if (assets[0].id.extension == '.tpl') {
          templateAsset = assets[0];
          dataAsset = assets[1];
        } else {
          templateAsset = assets[1];
          dataAsset = assets[0];
        }

        if (_settings.mode == BarbackMode.DEBUG) {
          return Directory.systemTemp.createTemp(
              'gorender-transformer-').then((dir) {

            var templateSink =
                new File(ospath.join(dir.path, 'template')).openWrite();
            var dataSink =
                new File(ospath.join(dir.path, 'data.json')).openWrite();

            var templateFuture = templateSink.addStream(templateAsset.read());
            var dataFuture = dataSink.addStream(dataAsset.read());

            return Future.wait([templateFuture, dataFuture]).then((files) {
              return _gorender(files[0].path, files[1].path);
            }).then((result) {
              transform.addOutput(
                  new Asset.fromString(templateAsset.id.changeExtension(''), result));
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
    });
  }

  Future declareOutputs(DeclaringAggregateTransform transform) {
    return transform.primaryIds.take(2).toList().then((assets) {
      AssetId templateAssetId;
      AssetId dataAssetId;

      if (assets[0].extension == '.tpl') {
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

Future<String> _gorender(String templatePath, String dataPath) {
  var flags = ['-d', dataPath, templatePath];
  return Process.run('gorender', flags).then((result) {
    if (result.exitCode != 0) {
      throw new GorenderException(result.stderr);
    }
    return result.stdout;
  }).catchError((e) {
    throw new GorenderException("gorender: command not found");
  }, test: (e) => e is ProcessException && e.errorCode == 2);
}

class GorenderException implements Exception {
  final String msg;
  GorenderException([this.msg]);
  String toString() => msg == null ? 'GorenderException' : msg;
}
