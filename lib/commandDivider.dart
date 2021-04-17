import 'dart:async';
import 'dart:typed_data' show Uint8List;
import 'package:meta/meta.dart';

class SMTP {}

class CommandParseException implements Exception {
  @override
  String toString() => "CommandParseException";
}

class Command {
  ///  https://tools.ietf.org/html/rfc821
  ///  HELO <SP> <domain> <CRLF>
  ///  MAIL <SP> FROM:<reverse-path> <CRLF>
  ///  RCPT <SP> TO:<forward-path> <CRLF>
  ///  DATA <CRLF>
  ///  RSET <CRLF>
  ///  SEND <SP> FROM:<reverse-path> <CRLF>
  ///  SOML <SP> FROM:<reverse-path> <CRLF>
  ///  SAML <SP> FROM:<reverse-path> <CRLF>
  ///  VRFY <SP> <string> <CRLF>
  ///  EXPN <SP> <string> <CRLF>
  ///  HELP [<SP> <string>] <CRLF>
  ///  NOOP <CRLF>
  ///  QUIT <CRLF>
  ///  TURN <CRLF>
  static final int CODE_220_SERVICE_READY = 220; // 220 <domain> Service ready
  static final int CODE_221_SERVICE_CLOSING = 221; // Service closing
  static final int CODE_250_REQUESTED_MAIL_ACTION_OKAY = 250; // mail action okay
  static final int CODE_354_START_INPUT = 354; // 354 Start mail input; end with <CRLF>.<CRLF>
  static final int CODE_421_SERVICE_NOT_AVAILABLE = 421; //421 <domain> Service not available
  static final int CODE_504_COMMAND_PARAMETER_NOT_IMPLEMENTED = 504; // Command parameter not implemented

  static String message220(String domain) => "220 ${domain} Service ready\r\n";
  static String message221(String domain) => "221 ${domain}\r\n";
  static String message250([String message = "OK"]) => "250 ${message}\r\n";
  static String message354([String message = "Go ahead"]) => "354 ${message}\r\n";
  static String message421(String domain) => "421 ${domain} Service ready\r\n";
  static String message504() => "504 command  parameter not support\r\n";
  //
  static final commandRefExp = RegExp("(HELO|EHLO|MAIL|RCPT|DATA|RSET|NOOP|QUIT|VRFY|[0-9]+)[ ]?(.*)\r\n", caseSensitive: false);
  static final fromRefExp = RegExp("[ ]*from[ ]*:[ ]*(.+)", caseSensitive: false);
  static final toRefExp = RegExp("[ ]*to[ ]*:[ ]*(.+)", caseSensitive: false);

  final String action;
  final String value;
  Command({@required this.action = "", @required this.value = ""});

  String get from {
    var match = fromRefExp.firstMatch(this.value);
    if (match == null || match.groupCount <= 0) {
      return "";
    }
    return match.group(1) ?? "";
  }

  String get to {
    var match = toRefExp.firstMatch(this.value);
    if (match == null || match.groupCount <= 0) {
      return "";
    }
    return match.group(1) ?? "";
  }

  static Command parse(String source) {
    var matches = commandRefExp.allMatches(source);
    if (matches.length <= 0) {
      throw CommandParseException();
    }
    var matched = matches.elementAt(0);
    if (matched.groupCount == 1) {
      return Command(action: (matched.group(1) ?? "").toLowerCase(), value: "");
    } else if (matched.groupCount == 2) {
      return Command(action: (matched.group(1) ?? "").toLowerCase(), value: matched.group(2) ?? "");
    } else {
      throw CommandParseException();
    }
  }
}

class CommandDivider {
  Stream<List<int>> stream;
  List<List<int>> buffers = [];
  List<Completer<List<int>>> futures = [];
  List<StreamController<List<int>>> streams = [];
  bool calledOnDone = false;
  bool calledOnError = false;
  bool modeData = false;

  CommandDivider(this.stream) {
    List<int> endData = Uint8List(5);
    stream.listen((v) {
      if (modeData) {
        if (v.length >= 5) {
          endData.setRange(0, 5, v, v.length - 5);
        } else {
          endData.setRange(0, 5 - v.length, endData, v.length);
          endData.setRange(5 - v.length, 5, v);
        }
        streams.forEach((stream) {
          stream.add(v);
        });
        if (endData[0] == 0x0d &&
            endData[1] == 0x0a &&
            endData[2] == 0x2e && //
            endData[3] == 0x0d &&
            endData[4] == 0x0a) {
          //
          streams.forEach((stream) {
            stream.close();
          });
          modeData = false;
        }
      } else {
        buffers.add(v);
        futures.forEach((f) {
          f.complete(v);
        });
        futures.clear();
      }
    }, onDone: () {
      calledOnDone = true;
      futures.forEach((f) {
        f.complete([]);
      });
    }, onError: (e) {
      calledOnError = true;
      futures.forEach((f) {
        f.complete([]);
      });
    });
  }

  Future waitByReceivedBytes() {
    var c = Completer<List<int>>();
    futures.add(c);
    return c.future;
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

  Stream data() {
    modeData = true;
    var c = StreamController<List<int>>();
    while (buffers.length > 0) {
      var buffer = buffers.removeAt(0);
      c.add(buffer);
    }
    streams.add(c);
    return c.stream;
  }

  Future<List<int>> nextCommand() async {
    var ret = <List<int>>[];
    var beforeByteIsCR = false;
    while (true) {
      while (buffers.length == 0) {
        if (calledOnDone || calledOnError) {
          return buffers2Buffer(ret);
        }
        await waitByReceivedBytes();
      }

      var buffer = buffers.removeAt(0);
      for (var i = 0; i < buffer.length; i++) {
        if (buffer[i] == 0x0d) {
          beforeByteIsCR = true;
          continue;
        }
        if (beforeByteIsCR == true && buffer[i] == 0x0a) {
          //
          ret.add(buffer.sublist(0, i + 1));
          if (i + 1 != buffer.length) {
            buffers.insert(0, buffer.sublist(i + 1));
          }
          return buffers2Buffer(ret);
        }
        beforeByteIsCR = false;
      }
      ret.add(buffer);
    }
  }
}
