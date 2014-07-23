library spec;

import 'dart:io';
import 'dart:async';
import 'package:spark_fs/fs.dart';
import 'package:hub/hub.dart';
import 'package:spark_utils/utils.dart';

void main(){

   Fs.register();
   SparkUtils.register();

   var n =  Sparkflow.create('fs-test','a basic test fbp fs');
   n.use('spark.fs/protocols/openfile','bb');

   n.boot().then((_){
      
      _.filter('bb').then(Funcs.tag('bb'));
   });

}
