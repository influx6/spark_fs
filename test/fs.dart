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
   n.use('spark.fs/protocols/opendir','od');
   n.use('spark.fs/protocols/pathprefix','pf');
   n.use('spark.fs/protocols/pathModShift','pmf');

   n.alwaysSchedulePacket('dir','io:conf',{ 'file':'./' });
   n.alwaysSchedulePacket('cf','io:conf',{ 'file':'./suckerbox.txt' });
   n.alwaysSchedulePacket('od','io:conf',{ 'auto': false,'file':'./' });
   n.alwaysSchedulePacket('rf','io:conf',{ 'auto':false,'file':'./suckerbox.txt' });

   n.alwaysSchedulePacket('pf','io:root','/thunderbot/');
   n.alwaysSchedulePacket('pmf','io:root','/thunderbot/');
   n.alwaysSchedulePacket('pmf','io:conf',{ 'lock': true });
   n.alwaysSchedulePacket('pf','io:conf',{ 'lock': true });

   n.boot().then((_){

     _.tapData('cf','io:stream',(n){
       _.schedulePacket('rf','io:kick',true);
       _.schedulePacket('od','io:kick',true);
       _.schedulePacket('pf','io:paths','../brother/floor/dude/boxer');
       _.schedulePacket('pf','io:paths','./brother/floor/dude/boxer');
       _.schedulePacket('pmf','io:paths','../mike/shareful/bulldog/');
       _.schedulePacket('pmf','io:paths','../../slog/shareful/bulldog/');
       _.schedulePacket('pmf','io:paths','./../slog/shareful/bulldog/');
     });

     _.tapData('pf','io:mods',(n) => Funcs.tagLog('pf-stream',n));
     _.tapData('pmf','io:mods',(n) => Funcs.tagLog('pmf-stream',n));

     _.tapData('rf','io:stream',(n) => Funcs.tagLog('rf-stream',n));
     _.tapData('rf','io:stream',(n) => Funcs.tagLog('rf-stream-data',UTF8.decode(n.data)));
     _.tapData('cf','io:stream',Funcs.tag('cf-stream'));
     _.tapData('dir','io:stream',Funcs.tag('dir-stream'));
     _.tapData('od','io:stream',(n) => Funcs.tagLog('opendir-stream',n));
     _.tapData('od','io:stream',(n) => Funcs.tagLog('opendir-stream',n.data.absolute.path));

     _.schedulePacket('cf','io:stream','thank you lord!\n');
     _.schedulePacket('dir','io:stream','wall/books/shelf');
     _.schedulePacket('od','io:path','./wall');

   });

}
