#!/usr/bin/env python3

from requests.exceptions  import HTTPError
from smtplib              import SMTP_SSL
from email.mime.text      import MIMEText
from email.mime.multipart import MIMEMultipart
from subprocess           import run
import requests
import sys
import datetime
import creds as CR

def check_server():
    try:
        result = requests.get(
            f"{CR.creds['host']}{CR.creds['page']}",
            verify = False
        )
        if result.status_code == 200:
            print("Server UP")
            print(send_email(result.status_code, ""))
        else:
            print("Server Down")
            print(send_email(result.status_code, "Non 200 status code returned"))
    except HTTPError as http_err:
        print(f'HTTP error occured: {http_err}')
        print(send_email(404, http_err))
    except Exception as e:
        print(f'Other error occured: {e}')
        print(send_email(503, e))

def generate_success():
    ip = requests.get('https://api.ipify.org').content.decode('utf8')

    return """
        <h3>Successfully reached server at {}</h3>
        <p>Current IP address: {}</p>
    """.format(CR.creds["host"], ip)

def generate_fail(code, e):
    ip = requests.get('https://api.ipify.org').content.decode('utf8')
    #run(["restart-rook-server"])

    return """
        <h3>Failed to reach server at {}</h3>
        <p>Response from server: {}</p>
        <p>Error: {}</p>
        <p>Current IP address: {}</p>
    """.format(CR.creds["host"], code, e, ip)

def send_email(code, e):
    # don't send email on success if only_fail is set
    if code == 200 and len(sys.argv) > 1 and sys.argv[1] == "only-fail":
        return "Email Intentionally not sent"

    message = MIMEMultipart("alternative")
    message["From"]    = CR.creds["gmail_from"]
    message["To"]      = CR.creds["gmail_to"]
    message["Subject"] = "{}<{}>".format(CR.creds["gmail_from"], CR.creds["gmail_user"])

    body = MIMEText((generate_success() if code == 200 else generate_fail(code, e)), "html")
    message.attach(body)

    print(body)
    try:
        server = SMTP_SSL('smtp.gmail.com', 465)
        server.ehlo()
        server.login(CR.creds["gmail_user"], CR.creds["gmail_pass"])
        server.sendmail(CR.creds["gmail_user"], CR.creds["gmail_to"], message.as_string())
        server.close()

        return "Email sent."
    except Exception as e:
        return "Email failed: {}".format(e)

def pre_message():
    print("\n\n")
    print(datetime.datetime.now())
    print("Start\n")

def post_message():
    print("\nEnd")
    print(datetime.datetime.now())
    print("\n\n")
    
pre_message()
check_server()
post_message()
