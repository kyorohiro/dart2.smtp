import 'dart:convert';
import 'dart:io' as io;
import 'dart:convert' show utf8;
import 'dart:typed_data' show Uint8List;
import 'package:info.kyorohiro.dart2.smtp/smtp_buffer.dart';

void main() async {
  var mailServerDomain = 'tetorica.net';
  var server = await io.ServerSocket.bind('0.0.0.0', 25);
  print('binded ${server}');

  server.listen((socket) async {
    var smtpBuffer = SmtpBuffer(socket);
    print('address from ${socket.address} ${socket.port}');
    print('remoteAddress from ${socket.remoteAddress} ${socket.remotePort}');

    //
    // service ready message
    socket.write(Command.message220(mailServerDomain)); // 220, 421

    do {
      var messageAsBytes = await smtpBuffer.nextCommand();
      var command = Command(action: '', value: '');
      try {
        print('cmd: ${utf8.decode(messageAsBytes, allowMalformed: true)}');
        if (smtpBuffer.calledOnDone || smtpBuffer.calledOnError) {
          break;
        }
        command = Command.parse(utf8.decode(messageAsBytes, allowMalformed: true));
      } catch (e, s) {
        print('err: ${e} ${s}');
        socket.write(Command.message504());
        continue;
      }

      var targetDomain = '';
      var fromAddress = '';
      List<String> toAddress = [];
      switch (command.action) {
        case 'helo':
          // start
          targetDomain = command.value;
          socket.write(Command.message250(mailServerDomain)); // 250, 500, 501, 504, 421
          break;
        case 'ehlo':
          // start with extension
          targetDomain = command.value;
          socket.write(Command.message250(mailServerDomain)); // 250, 552, 451, 452, 500, 501, 421
          break;
        case 'mail':
          // from address
          fromAddress = command.from;
          socket.write(Command.message250()); // S: 250 F: 552, 451, 452 E: 500, 501, 421
          break;
        case 'rcpt':
          // to address
          toAddress.add(command.from);
          socket.write(Command.message250()); // S: 250, 251 F: 550, 551, 552, 553, 450, 451, 452 E: 500, 501, 503, 421
          break;
        case 'quit':
          // close connection
          socket.write(Command.message221(mailServerDomain)); // S:221 E:500
          socket.close();
          break;
        case 'rset':
          // clear all buffer
          //
          targetDomain = '';
          fromAddress = '';
          toAddress.clear();
          socket.write(Command.message250()); // S: 250 E: 500, 501, 504, 421
          break;
        case 'data':
          // I: 354 -> data -> S: 250
          //                   F: 552, 554, 451, 452
          // F: 451, 554
          // E: 500, 501, 503, 421
          socket.write(Command.message354());
          var buffers = <List<int>>[];
          await for (var v in smtpBuffer.nextData()) {
            buffers.add(v);
            //
            if (smtpBuffer.modeData == false) {
              // end
              break;
            }
          }
          print(utf8.decode(buffers2Buffer(buffers)));
          socket.write(Command.message250());
          break;
        default:
          socket.write(Command.message504());
      }
      //if(message.startsWith('HELLO'))
    } while (true);
    await socket.flush();
    socket.close();
  });
}

List<int> buffers2Buffer(List<List<int>> ret) {
  var length = ret.fold<int>(0, (c, n) => c + n.length);
  var r = Uint8List(length);
  var index = 0;
  ret.forEach((b) {
    //
    r.setAll(index, b);
    index += b.length;
  });
  return r;
}
