from bearerauth import BearerAuth, requests
from login import lotex_login, refresh_token
import constants
import build_query


def lotex_api_calls():
    login_dict = lotex_login()

    if type(login_dict) == dict:

        bearer_token = login_dict['access_token']

        # refresh_token_refresh_dict = refresh_token(login_dict['refresh_token'])

        lotex_ids = [32763, 34023, 42492, 80001, 80003, 80004, 80005, 80006, 80007, 80140, 80143, 80364, 81688, 81689,
                     90026]

        for i in range(len(lotex_ids)):
            print(lotex_ids[i])

            try:
                device_position_info = requests.get(constants.LOTEX_URL + '/gps?deviceId=' + str(lotex_ids[i]),
                                                    auth=BearerAuth(bearer_token))
            except requests.exceptions.RequestException as e:
                raise SystemExit(e)

            # try:
                # list_of_current_devices = requests.get(constants.LOTEX_URL + '/devices',
                                                       # auth=BearerAuth(bearer_token))
            #except requests.exceptions.RequestException as e:
                # raise SystemExit(e)

            try:
                list_of_specific_device_information = requests.get(constants.LOTEX_URL + '/devices/' + str(lotex_ids[i]),
                                                                   auth=BearerAuth(bearer_token))
            except requests.exceptions.RequestException as e:
                raise SystemExit(e)

            # Lotex
            device_info_dict = device_position_info.json()
            # list_of_current_devices_dict = list_of_current_devices.json()
            list_of_specific_device_information_dict = list_of_specific_device_information.json()

            a = [["api_lotex_device_info", list_of_specific_device_information_dict],
                 ["api_lotex_device_position_data", device_info_dict]]

                 # ,
                 # ["api_lotex_devices_by_user", list_of_current_devices_dict]]

            for ii in range(len(a)):
                table_name = a[ii][0]
                info_dict = a[ii][1]

                build_query.build_query(table_name, info_dict)

        return
