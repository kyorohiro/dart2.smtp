library bencode.test;

import 'package:info.kyorohiro.dart2.smtp/smtp_buffer.dart';
import 'dart:async' show StreamController, Completer;
import 'package:test/test.dart' as unit;
//import 'dart:typed_data' as ty;
import 'dart:convert' show utf8;

void main() {
  unit.group('divider', () {
    unit.test('basic 01', () async {
      var c = StreamController<List<int>>();
      var cm = SmtpBuffer(c.stream);
      c.add(utf8.encode('Helo xx x'));
      c.add(utf8.encode('\r\n'));
      c.add(utf8.encode('Helo xx y'));
      c.add(utf8.encode('\r\n'));
      var v = await cm.nextCommand();
      unit.expect('Helo xx x\r\n', utf8.decode(v, allowMalformed: true));
      v = await cm.nextCommand();
      unit.expect('Helo xx y\r\n', utf8.decode(v, allowMalformed: true));
      c.close();
    });
    unit.test('basic 01', () async {
      var c = StreamController<List<int>>();
      var cm = SmtpBuffer(c.stream);
      c.add(utf8.encode('Helo xx x'));
      c.add(utf8.encode('\r\n'));
      c.add(utf8.encode('Helo xx y'));
      c.close();
      var v = await cm.nextCommand();
      unit.expect('Helo xx x\r\n', utf8.decode(v, allowMalformed: true));
      v = await cm.nextCommand();
      unit.expect('Helo xx y', utf8.decode(v, allowMalformed: true));
      c.close();
    });

    unit.test('basic 01', () async {
      var c = StreamController<List<int>>();
      var cm = SmtpBuffer(c.stream);
      c.add(utf8.encode('Helo xx x'));
      var comp = Completer<List<int>>();

      cm.nextCommand().then((v) {
        comp.complete(v);
      });
      c.close();
      var v = await comp.future;
      unit.expect('Helo xx x', utf8.decode(v, allowMalformed: true));
    });
  });

  unit.group('command', () {
    unit.test('basic 01', () async {
      var c = Command.parse("HELO domain\r\n");
      unit.expect('helo', c.action);
      unit.expect('domain', c.value);

      c = Command.parse("DATA\r\n");
      unit.expect('data', c.action);
      unit.expect('', c.value);

      c = Command.parse("quit\r\n");
      unit.expect('quit', c.action);
      unit.expect('', c.value);
    });
  });
}
