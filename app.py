from lotex import lotex_api_calls
from vectronics import vectronics_api_calls
from database import Database

# Database.initialise(
#             dbname="sample_caribou_data",
#             user="postgres",
#             host="127.0.0.1",
#             password="Ch3k@v88",
#             port=5433)

Database.initialise(
            dbname="bctw",
            user="bctw",
            host="127.0.0.1",
            password="data4Me",
            port=5432)


lotex_api_calls()
vectronics_api_calls()

