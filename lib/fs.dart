library spark_server;

import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:sparkflow/sparkflow.dart';
import 'package:guardedfs/guardedfs.dart';
import 'package:hub/hub.dart';
import 'package:path/path.dart' as paths;

export 'package:guardedfs/guardedfs.dart';
export 'package:sparkflow/sparkflow.dart';


class Fs{

  static RegExp pathChar = new RegExp(r'..|\+|/+|.');
  static RegExp pathWrd = new RegExp(r'^\s*?\S*?\w+\d*?\D*?\W*?\s*?\w*?$');

  static String bitShiftPath(String uri){
    var pt = paths.split(paths.normalize(uri));
    Enums.eachAsync(pt,(e,i,o,fn){
      if(pathChar.hasMatch(e)) pt[i] ="";
      if(pathWrd.hasMatch(e)){
          pt[i] = "";
          return fn(true);
      }
      return fn(null);
    });
    return paths.normalize(paths.joinAll(pt));
  }

  static void register(){
      
     Sparkflow.createRegistry('spark.fs',(r){

       r.addMutation('protocols/_pathMods',(v){

          v.sd.update('conf',MapDecorator.useMap({ 'lock': false }));

          var conf = v.sd.get('conf');

          v.makeInport('io:root',meta: { 'desc':'takes the root paths to prefix all paths with' });
          v.makeInport('io:paths', meta: {'desc': 'takes the paths to prefix'});
          v.makeInport('io:conf', meta: {'desc': 'allows configuration of behaviour'});
          v.makeOutport('io:mods',meta: {'desc': 'returns the new prefix ports'});

          v.port('io:paths').forceCondition(Valids.isString);
          v.port('io:conf').forceCondition(Valids.isMap);
          v.port('io:root').forceCondition(Valids.isString);
          v.port('io:mods').forceCondition(Valids.isString);

          v.port('io:paths').pause();

          v.tap('io:conf',(n){
            conf.storage = n.data;
            if(!conf.has('lock')) conf.update('lock',false);
          });

          v.tap('io:root',(n){
            v.sd.update('root',n.data);
            v.sd.update('nr',paths.normalize(n.data));
            v.port('io:paths').resume();
          });

          v.port('io:mods').forceCondition((n){
            if(Valids.isFalse(conf.get('lock'))) return true;
            if(paths.isWithin(v.sd.get('nr'),n)) return true;
            return false;
          });

       });

       r.addBaseMutation('protocols/_pathMods','protocols/pathPrefix',(v){
          v.meta('desc','checks where a path is a file of not');

          v.tap('io:paths',(n){
            var pt = n.data, mod = paths.join(v.sd.get('nr'),paths.normalize(pt));
            v.port('io:mods').send(paths.normalize(mod));
          });

       });

       r.addBaseMutation('protocols/_pathMods','protocols/pathModShift',(v){
          v.meta('desc','checks where a path is a file of not');

          v.tap('io:paths',(n){
            var mod = [v.sd.get('nr')];
            mod.add(Fs.bitShiftPath(n.data));
            v.port('io:mods').send(paths.joinAll(mod));
          });

       });

       r.addMutation('protocols/isFile',(v){
          v.meta('desc','checks where a path is a file of not');

          v.makeInport('io:path');
          v.makeOutport('io:yes');
          v.makeOutport('io:no');

          v.port('io:path').forceCondition(Valids.isString);

          v.tap('io:path',(n){
             GuardedFS.isFile(n.data).then((_){
               v.send('io:yes',n);
             },onError: (e){
               v.send('io:no',e);
             }).catchError((e){
               v.send('io:no',e);
             });
          });
       });

       r.addMutation('protocols/isDirectory',(v){
          v.meta('desc','checks where a path is a directory of not');

          v.makeInport('io:path');
          v.makeOutport('io:yes');
          v.makeOutport('io:no');

          v.port('io:path').forceCondition(Valids.isString);

          v.tap('io:path',(n){
             GuardedFS.isDir(n.data).then((_){
               v.send('io:yes',n);
             },onError: (e){
               v.send('io:no',e);
             }).catchError((e){
               v.send('io:no',e);
             });
          });
       });

       r.addMutation('protocols/_fs',(e){
          e.meta('desc','component to handle all fs operations');

          e.sd.add('kicking',false);
          e.sd.add('init',(n){});
          e.sd.add('_kickforce',(m){
            if(!e.sd.get('kicking')) return true;
            return false;
          });

          e.sd.add('conf',MapDecorator.create());

          var conf = e.sd.get('conf'), sample;
          
          e.createSpace('io');
          e.makeInport('io:kick');
          e.makeInport('io:conf');
          e.makeInport('io:path');
          e.makeOutport('io:error');
          e.makeOutport('io:vfs');
          e.makeOutport('io:ended');

          e.port('io:path').forceCondition(Valids.isString);
          e.port('io:conf').forceCondition(Valids.isMap);
          e.port('io:kick').forceCondition((n){
            if(conf.has('file')) return true;
            return false;
          });

          e.port('io:conf').forceCondition((m){
            if(m.containsKey('path') || m.containsKey('file')) return true;
            return false;
          });

          e.port('io:conf').tap((n){
            conf.storage = n.data;
            e.port('io:path').send(conf.has('path') ? conf.get('path') : conf.get('file'));
            if(!conf.has('lockRoot')) conf.update('lockRoot',false);
            if(!conf.has('readOnly')) conf.update('readOnly',false);
          });

          e.port('io:path').tap((n){
            conf.update('file',n.data);
          });

          e.port('io:kick').tap((n){
            if(Valids.exist(sample)){
              if(!Valids.match(sample,e.sd.get('conf').core)) e.sd.get('init')(n);
            }else e.sd.get('init')(n);
            sample = e.sd.get('conf').core;
            e.send('io:vfs',e.sd.get('fs'));
          });
       });


       r.addBaseMutation('protocols/_fs','protocols/_controller',(e){
          e.meta('desc','provides the central control port logic for all fs startup');

          var conf = e.sd.get('conf');

          e.port('io:path').tap((n){
              if(conf.has('auto') && Valids.isFalse(conf.get('auto'))) return null;
              e.port('io:kick').send(true);
          });

       });

       r.addBaseMutation('protocols/_controller','protocols/_readers',(e){

          e.makeOutport('io:stream');
          e.makeInport('io:readkick');

          e.port('io:readkick').forceCondition(e.sd.get('_kickforce'));

          e.port('io:stream').tap((n){
            e.sd.update('kicking',true);
          });
          
          e.port('io:stream').tapEnd((n){
            e.sd.update('kicking',false);
          });

          e.port('io:kick').tap((n){
            e.port('io:readkick').send(true);
          });
       });

       r.addBaseMutation('protocols/_controller','protocols/_writers',(e){

          e.makeInport('io:writekick');
          e.makeInport('io:stream');

          e.port('io:writekick').forceCondition(e.sd.get('_kickforce'));

          e.port('io:stream').tap((n){
            e.sd.update('kicking',true);
          });
          
          e.port('io:stream').tapEnd((n){
            e.sd.update('kicking',false);
          });

          e.port('io:kick').tap((n){
            e.port('io:writekick').send(true);
          });
       });

       r.addBaseMutation('protocols/_readers','protocols/_filereaders',(e){
          e.meta('desc','component to handle all file reading operations');

          var conf = e.sd.get('conf');

          e.sd.update('init',(n){
            try{
              e.sd.update('fs',GuardedFile.create(conf.get('file'),true));
            }catch(f){
              e.port('io:error').send(f);
            }
          });

          e.port('io:readkick').tap((n){
            e.port('io:path').pause();
             var count = 0;
             if(e.sd.has('fs') && Valids.exist(e.sd.get('fs'))){
                 e.sd.get('fs').openRead().listen((f){
                   e.port('io:stream').beginGroup(count);
                   e.port('io:stream').send(f);
                   e.port('io:stream').endGroup(count);
                   count += 1;
                },onDone:(){
                  e.port('io:stream').endStream();
                },onError:(v){
                  e.port('io:error').send(v);
                  e.port('io:stream').endStream();
                });
             }
          });

          e.port('io:stream').tapEnd((n){
            e.port('io:path').resume();
          });

       });

       r.addBaseMutation('protocols/_writers','protocols/_filewriters',(e){
          e.meta('desc','component to handle all file reading operations');

          var conf = e.sd.get('conf');

          e.sd.update('init',(n){
            try{
              e.sd.update('fs',GuardedFile.create(conf.get('file'),false));
            }catch(f){
              e.port('io:error').send(f);
            }
          });

          e.port('io:writekick').tap((n){
            e.port('io:path').pause();
            e.port('io:stream').resume();
          });

          e.port('io:stream').tapEnd((n){
            e.port('io:path').resume();
          });

       });

       r.addBaseMutation('protocols/_filewriters','protocols/_fileInputers',(e){
          e.meta('desc','component to create a new file');

          var conf = e.sd.get('conf');

          e.port('io:stream').tapData((n){
            if(e.sd.has('writer')){
              if(Valids.isList(n.data)) e.sd.get('writer').writeAll(n.data);
              if(!Valids.isList(n.data)) e.sd.get('writer').write(n.data);
            }
          });

          e.port('io:stream').tapEnd((n){
            if(e.sd.has('writer')) e.sd.get('writer').close();
          });

       });

       r.addBaseMutation('protocols/_readers','protocols/opendir',(e){
          e.meta('desc','component to handle all dir operations');

          var conf = e.sd.get('conf');

          e.makeInport('io:readPath',meta:{'desc':'reads the path relative to the directory'});

          e.sd.update('init',(n){
            try{
              e.sd.update('fs',GuardedDirectory.create(conf.get('file'),conf.get('readOnly'),conf.get('lockRoot')));
            }catch(f){
              e.port('io:error').send(f);
            }
          });

          e.port('io:readPath').forceCondition(Valids.isString);
          e.port('io:readPath').pause();

          e.tap('io:kick',(n){
            e.port('io:readPath').resume();
          });

          e.port('io:readkick').tap((n){
             if(e.sd.has('fs') && Valids.exist(e.sd.get('fs'))){
                e.port('io:path').pause();
                 var count = 0;
                 e.sd.get('fs').list().listen((f){
                   e.port('io:stream').beginGroup(e.sd.get('file'));
                   e.port('io:stream').send(f);
                   e.port('io:stream').endGroup(count);
                   count += 1;
                },onDone:(){
                  e.port('io:stream').endStream();
                },onError:(f){
                  e.port('io:error').send(f);
                  e.port('io:stream').endStream();
                });
             }
          });

          e.port('io:readPath').tap((n){
             if(e.sd.has('fs') && Valids.exist(e.sd.get('fs'))){
                e.port('io:path').pause();
                 var count = 0;
                 e.sd.get('fs').openNewDir(paths.normalize(n.data)).then((dir){
                      dir.list().listen((f){
                         e.port('io:stream').beginGroup(dir.path);
                         e.port('io:stream').send(f);
                         e.port('io:stream').endGroup(count);
                         count += 1;
                      },onDone:(){
                        e.port('io:stream').endStream();
                      },onError:(f){
                        e.port('io:error').send(f);
                        e.port('io:stream').endStream();
                      });
                 }).catchError((e) => e.port('io:error').send(e));
             }
          });

       });

       r.addBaseMutation('protocols/_writers','protocols/writedir',(e){
          e.meta('desc','component to handle all dir operations');

          var conf = e.sd.get('conf');

          e.sd.update('init',(n){
            try{
              e.sd.update('fs',GuardedDirectory.create(conf.get('file'),conf.get('readOnly'),conf.get('lockRoot')));
            }catch(f){
              e.port('io:error').send(f);
            }
          });

          e.port('io:writekick').tap((n){
            e.port('io:path').pause();
            e.port('io:stream').resume();
          });


          e.port('io:stream').tapEnd((n){
            e.port('io:path').resume();
          });

          e.port('io:stream').forceCondition(Valids.isString);

          e.port('io:stream').tapData((n){
            if(e.sd.has('fs'))
            e.sd.get('fs').createNewDir(n.data,true).then((dir){
                e.port('io:stream').endStream();
            });
          });

       });

       r.addBaseMutation('protocols/_fileInputers','protocols/createfile',(e){
          e.meta('desc','component to create a new file');

          var conf = e.sd.get('conf');

          e.port('io:stream').tapOnce((n){
             if(e.sd.has('fs') && Valids.exist(e.sd.get('fs'))){
                e.sd.update('writer',e.sd.get('fs').openWrite());
             }
          });

       });

       r.addBaseMutation('protocols/_fileInputers','protocols/appendfile',(e){
          e.meta('desc','component to create a new file');

          var conf = e.sd.get('conf');

          e.port('io:stream').tapOnce((n){
             if(e.sd.has('fs') && Valids.exist(e.sd.get('fs'))){
                e.sd.update('writer',e.sd.get('fs').openAppend());
             }
          });

       });

       r.addBaseMutation('protocols/_filereaders','protocols/openfile',(e){
          e.meta('desc','component to handle exisiting file reading operations');

          var conf = e.sd.get('conf');

          e.sd.update('init',(n){
            try{
              e.sd.update('fs',GuardedFile.use(conf.get('file'),true));
            }catch(f){
              e.port('io:error').send(f);
            }
          });

       });

     });
  }
}
