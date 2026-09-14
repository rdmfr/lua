import requests

def create_roblox_account(username, password):
    url = "https://www.roblox.com/Account/CreateAccount"
    payload = {
        "username": username,
        "password": password,
        "confirmPassword": password
    }
    headers = {
        "User-Agent": "Roblox App (iOS)"
    }

    response = requests.post(url, data=payload, headers=headers)

    if response.status_code == 200:
        print("Roblox account created successfully!")
    else:
        print("Failed to create Roblox account.")

username = "your_username"
password = "your_password"

create_roblox_account(username, password)
