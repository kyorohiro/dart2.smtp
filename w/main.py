# -*- coding: utf-8 -*-

import smtplib
from io import StringIO
import sys
import dns.resolver
# from DNS import Respip install dnspython

if __name__ == "__main__":

    argvs = sys.argv
    v = 10
    print(f"Hello {argvs} {len(argvs)}")

    if len(argvs) != 3:
        print('Usage arg1 = to_address, arg2 = from_address')
        quit()

    to_address = argvs[1]
    from_address = argvs[2]
    to_list = to_address.split('@')

    to_address = '<' + to_address + '>'
    from_address = '<' + from_address + '>'

    if len(to_list) < 2:
        print('format error to_address')
        quit()

    domain = to_list[1]
    mailserver = dns.resolver.resolve(domain, 'MX')

    if len(mailserver) < 1:
        print('not found mx recored')
        quit()

    mailserver = mailserver[0].to_text().split(' ')
    mailserver = mailserver[1][:-1]
    print(f"{mailserver}")

    charset = "ISO-2022-JP"
    subject = u"this is Python test mail!"
    text = u"this is Python test mail!"

    #msg = MIMEText(text.encode(charset), "plain", charset)
    #msg["Subject"] = Header(subject, charset)
    #msg["From"] = from_address
    #msg["To"] = to_address
    #msg["Date"] = formatdate(localtime=True)

    smtp = smtplib.SMTP(mailserver)
    smtp.sendmail(from_address, to_address, "Hello!!")
    smtp.close()

