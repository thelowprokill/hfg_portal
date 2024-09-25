#!/usr/bin/env python3

import requests

result = requests.get("https://localhost/auth/requst", verify = False)
print(result)
