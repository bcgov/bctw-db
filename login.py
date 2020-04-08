import requests
import constants


def lotex_login():
    login_payload = {'grant_type': 'password',
                     'username': 'demo',
                     'password': 'PASSWORD09'}

    login = requests.get('https://webservice.lotek.com/API/user/login', data=login_payload,
                         headers=constants.X_WWW_HEADERS,
                         timeout=3)

    return login.json()


def refresh_token(token):
    refresh_token_payload = {'grant_type': 'refresh_token',
                             'username': 'demo',
                             'refresh_token': token}

    refresh = refresh_token_refresh = requests.get('https://webservice.lotek.com/API/user/login',
                                                   data=refresh_token_payload,
                                                   timeout=3,
                                                   headers=constants.X_WWW_HEADERS)

    return refresh.json()
