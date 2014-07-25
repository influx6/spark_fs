library spec;

import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:spark_fs/fs.dart';
import 'package:hub/hub.dart';
import 'package:spark_utils/utils.dart';

void main(){

   Fs.register();
   SparkUtils.register();

   var n =  Sparkflow.create('fs-test','a basic test fbp fs');
   n.use('spark.fs/protocols/createfile','cf');
   n.use('spark.fs/protocols/openfile','rf');
   n.use('spark.fs/protocols/writedir','dir');

   n.alwaysSchedulePacket('dir','io:conf',{ 'file':'./' });
   n.alwaysSchedulePacket('cf','io:conf',{ 'file':'./suckerbox.txt' });
   n.alwaysSchedulePacket('rf','io:conf',{ 'file':'./suckerbox.txt' });

   n.boot().then((_){

     _.tapData('rf','io:stream',(n) => Funcs.tagLog('rf-stream',UTF8.decode(n.data)));
     _.tapData('cf','io:stream',Funcs.tag('cf-stream'));
     _.tapData('dir','io:stream',Funcs.tag('dir-stream'));

     _.schedulePacket('cf','io:stream','thank you lord!\n');
     _.schedulePacket('dir','io:stream','wall/books/shelf');

   });

}
