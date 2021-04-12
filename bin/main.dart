import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;
import 'dart:convert' show utf8;
import 'dart:typed_data' show Uint8List;
import 'package:info.kyorohiro.dart2.smtp/commandDivider.dart';

main() async {
  var mailServerDomain = "tetorica.net";
  var domain = "tetorica.net";
  var server = await io.ServerSocket.bind("0.0.0.0", 25);
  print("binded ${server}");

  server.listen((socket) async {
    var commandDivider = CommandDivider(socket);
    print("connect");
    //io.SecureSocket.secure(socket);
    // Connection
    socket.write(Command.message220(mailServerDomain)); // 220, 421
    //
    //

    do {
      var messageAsBytes = await commandDivider.nextCommand();
      var command = Command.parse(utf8.decode(messageAsBytes, allowMalformed: true));
      var targetDomain = "";
      var fromAddress = "";
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
          targetDomain = "";
          fromAddress = "";
          toAddress.clear();
          socket.write(Command.message250()); // S: 250 E: 500, 501, 504, 421
          break;
        case 'data':
          // I: 354 -> data -> S: 250
          //                     F: 552, 554, 451, 452
          // F: 451, 554
          // E: 500, 501, 503, 421
          socket.write(Command.message354());
          List<List<int>> buffers = [];
          await for (var v in commandDivider.data()) {
            buffers.add(v);
            //
            if (commandDivider.modeData == false) {
              // end
            }
          }
          print(utf8.decode(buffers2Buffer(buffers)));
          socket.write(Command.message250());
          break;
      }
      //if(message.startsWith("HELLO"))
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
