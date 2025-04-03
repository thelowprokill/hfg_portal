#!/usr/bin/env python3

import os
import pickle
from googleapiclient.discovery import build
from google_auth_oauthlib.flow import InstalledAppFlow
from google.auth.transport.requests import Request
from base64 import urlsafe_b64encode
from email.mime.text import MIMEText

# Define the required scope for Gmail API
SCOPES = ['https://mail.google.com/']

# Function to authenticate Gmail API
def authenticate_gmail_api():
    print("start auth")
    creds = None
    # Check if token.pickle exists for saved credentials
    if os.path.exists("token.pickle"):
        print("token exists")
        with open("token.pickle", "rb") as token:
            creds = pickle.load(token)
    # If no valid credentials, initiate manual sign-in
    if not creds or not creds.valid:
        print("creds not valid")
        if creds and creds.expired and creds.refresh_token:
            print("creds expired")
            creds.refresh(Request())
        else:
            print("create token")
            flow = InstalledAppFlow.from_client_secrets_file('credentials.json', SCOPES)
            print("load creds")
            creds = flow.run_local_server(port=0)
            print("save creds")
# Store the login information for later use.

        print("pickle dump")
        with open("token.pickle", "wb") as token:
            pickle.dump(creds, token)
    return build('gmail', 'v1', credentials=creds)

def create_email(to, subject, body):
    message = MIMEText(body)
    message['to'] = to
    #message['from'] = ''
    message['subject'] = subject
    return {'raw': urlsafe_b64encode(message.as_bytes()).decode()}

def send_email(service, to, subject, body):
    email = create_email(to, subject, body)
    service.users().messages().send(userId='me', body=email).execute()

def print_the_foo():
    print("foo")

print("Define all the stuffs")
print_the_foo()
# Authenticate and initialize Gmail API service
service = authenticate_gmail_api()

# Send an email
#send_email(service, 'straightedge.gamestudios@gmail.com', 'subject', 'Email test')

print("Done")

