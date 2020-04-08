# from sqlalchemy import create_engine
import d6tstack as d6tstack
import pandas as pd

# engine = create_engine('postgresql://postgres:ch3k0v88@localhost/')

# df = pd.read_csv('C:/Users/paulp/Desktop/Cariboo Project/Kickoff_20200303_to_Quartech/SampleRawData/Sample_ATS/Cumulative_D10005_20150519114607.txt')
# uri_psql = 'postgresql+psycopg2://postgres:Ch3k@v88@localhost/sample_caribou_data'
# d6tstack.utils.pd_to_psql(df, uri_psql, 'sample_ATS')

# df = pd.read_csv(
   # 'C:/Users/paulp/Desktop/Cariboo Project/Kickoff_20200303_to_Quartech/SampleRawData/Sample_GPSPlusX/Collar15024_GPS_Default_Storage.csv',
   # encoding='unicode_escape')
# uri_psql = 'postgresql+psycopg2://postgres:Ch3k@v88@localhost/sample_caribou_data'
# d6tstack.utils.pd_to_psql(df, uri_psql, 'sample_GPSPlusX_collar_15024')

# df = pd.read_csv(
     # 'C:/Users/paulp/Desktop/Cariboo Project/Kickoff_20200303_to_Quartech/SampleRawData/Sample_GPSPlusX/Collar16263_GPS_Default_Storage.csv',
     # encoding='unicode_escape')
# uri_psql = 'postgresql+psycopg2://postgres:Ch3k@v88@localhost/sample_caribou_data'
# d6tstack.utils.pd_to_psql(df, uri_psql, 'sample_GPSPlusX_collar_16263')

# df = pd.read_csv(
#     'C:/Users/paulp/Desktop/Cariboo Project/Kickoff_20200303_to_Quartech/SampleRawData/Sample_Lotek/GPS_0081267.csv',
#     encoding='unicode_escape')
# uri_psql = 'postgresql+psycopg2://postgres:Ch3k@v88@localhost/sample_caribou_data'
# d6tstack.utils.pd_to_psql(df, uri_psql, 'sample_lotex_GPS_0081267')
#
# df = pd.read_csv(
#     'C:/Users/paulp/Desktop/Cariboo Project/Kickoff_20200303_to_Quartech/SampleRawData/Sample_Lotek/GPS_0101891.csv',
#     encoding='unicode_escape')
# uri_psql = 'postgresql+psycopg2://postgres:Ch3k@v88@localhost/sample_caribou_data'
# d6tstack.utils.pd_to_psql(df, uri_psql, 'sample_lotex_GPS_0101891')
#
# df = pd.read_csv(
#     'C:/Users/paulp/Desktop/Cariboo Project/Kickoff_20200303_to_Quartech/SampleRawData/Sample_Lotek/MRT_0081267.csv',
#     encoding='unicode_escape')
# uri_psql = 'postgresql+psycopg2://postgres:Ch3k@v88@localhost/sample_caribou_data'
# d6tstack.utils.pd_to_psql(df, uri_psql, 'sample_lotex_MRT_0081267')
#
# df = pd.read_csv(
#     'C:/Users/paulp/Desktop/Cariboo Project/Kickoff_20200303_to_Quartech/SampleRawData/Sample_Lotek/MRT_0101835.csv',
#     encoding='unicode_escape')
# uri_psql = 'postgresql+psycopg2://postgres:Ch3k@v88@localhost/sample_caribou_data'
# d6tstack.utils.pd_to_psql(df, uri_psql, 'sample_lotex_MRT_0101835')

# df = pd.read_csv(
#     'C:/Users/paulp/Desktop/Cariboo Project/Kickoff_20200303_to_Quartech/Collar metadata/cariboo.csv',
#     encoding='unicode_escape')
# uri_psql = 'postgresql+psycopg2://postgres:Ch3k@v88@localhost/sample_caribou_data'
# d6tstack.utils.pd_to_psql(df, uri_psql, 'collar_metadata_cariboo_minus_quotes')

# df = pd.read_csv(
#     'C:/Users/paulp/Desktop/Cariboo Project/Kickoff_20200303_to_Quartech/Collar metadata/field_validation.csv',
#     encoding='unicode_escape')
# uri_psql = 'postgresql+psycopg2://postgres:Ch3k@v88@localhost/sample_caribou_data'
# d6tstack.utils.pd_to_psql(df, uri_psql, 'collar_metadata_field_validation')

# df = pd.read_csv(
#     'C:/Users/paulp/Desktop/Cariboo Project/Kickoff_20200303_to_Quartech/Collar metadata/kootenay.csv',
#     encoding='unicode_escape')
# uri_psql = 'postgresql+psycopg2://postgres:Ch3k@v88@localhost/sample_caribou_data'
# d6tstack.utils.pd_to_psql(df, uri_psql, 'collar_metadata_kootenay')
#
# df = pd.read_csv(
#     'C:/Users/paulp/Desktop/Cariboo Project/Kickoff_20200303_to_Quartech/Collar metadata/monthly_summary.csv',
#     encoding='unicode_escape')
# uri_psql = 'postgresql+psycopg2://postgres:Ch3k@v88@localhost/sample_caribou_data'
# d6tstack.utils.pd_to_psql(df, uri_psql, 'collar_metadata_monthly_summary')
#
# df = pd.read_csv(
#     'C:/Users/paulp/Desktop/Cariboo Project/Kickoff_20200303_to_Quartech/Collar metadata/omineca.csv',
#     encoding='unicode_escape')
# uri_psql = 'postgresql+psycopg2://postgres:Ch3k@v88@localhost/sample_caribou_data'
# d6tstack.utils.pd_to_psql(df, uri_psql, 'collar_metadata_omineca')
#
# df = pd.read_csv(
#     'C:/Users/paulp/Desktop/Cariboo Project/Kickoff_20200303_to_Quartech/Collar metadata/thompson.csv',
#     encoding='unicode_escape')
# uri_psql = 'postgresql+psycopg2://postgres:Ch3k@v88@localhost/sample_caribou_data'
# d6tstack.utils.pd_to_psql(df, uri_psql, 'collar_metadata_thompson')
#
# df = pd.read_csv(
#     'C:/Users/paulp/Desktop/Cariboo Project/Kickoff_20200303_to_Quartech/Collar metadata/peace.csv',
#     encoding='unicode_escape')
# uri_psql = 'postgresql+psycopg2://postgres:Ch3k@v88@localhost/sample_caribou_data'
# d6tstack.utils.pd_to_psql(df, uri_psql, 'collar_metadata_peace')
#
# df = pd.read_csv(
#     'C:/Users/paulp/Desktop/Cariboo Project/Kickoff_20200303_to_Quartech/Collar metadata/skeena.csv',
#     encoding='unicode_escape')
# uri_psql = 'postgresql+psycopg2://postgres:Ch3k@v88@localhost/sample_caribou_data'
# d6tstack.utils.pd_to_psql(df, uri_psql, 'collar_metadata_skeena')
#
df = pd.read_csv(
    'C:/Users/paulp/Desktop/Cariboo Project/Kickoff_20200303_to_Quartech/Collar metadata/unknown.csv',
    encoding='unicode_escape')
uri_psql = 'postgresql+psycopg2://postgres:Ch3k@v88@localhost/sample_caribou_data'
d6tstack.utils.pd_to_psql(df, uri_psql, 'collar_metadata_unknown')