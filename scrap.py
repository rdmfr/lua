from selenium import webdriver
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC

def scrap_roblox_login_data():
    url = "https://www.roblox.com/id/Login"
    driver = webdriver.Chrome()  
    
    driver.get(url)
    

    username_input = WebDriverWait(driver, 10).until(
        EC.presence_of_element_located((By.NAME, 'username'))
    )
    password_input = WebDriverWait(driver, 10).until(
        EC.presence_of_element_located((By.NAME, 'password'))
    )
    
    username = username_input.get_attribute('value')
    password = password_input.get_attribute('value')
    
    data = {"username": username, "password": password}
    return data

data = scrap_roblox_login_data()
print(data)
