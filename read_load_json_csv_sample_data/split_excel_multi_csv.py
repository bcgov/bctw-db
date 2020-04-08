import csv
import xlrd
import sys

'''This python script is to extract each sheet in an Excel workbook as a new csv file'''

xrange = range
workbook = xlrd.open_workbook(
    'C:/Users/paulp/Desktop/Cariboo Project/Kickoff_20200303_to_Quartech/Collar metadata/January_2020_Monthly_Collar_Summary_20200220.xlsx')
csv_file_base_path = 'C:/Users/paulp/Desktop/Cariboo Project/Kickoff_20200303_to_Quartech/Collar metadata/'
for sheet_name in workbook.sheet_names():
    print('processing - ' + sheet_name)
    worksheet = workbook.sheet_by_name(sheet_name)
    csv_file_full_path = csv_file_base_path + sheet_name.lower().replace(" - ", "_").replace(" ", "_") + '.csv'
    csvfile = open(csv_file_full_path, 'w')
    writetocsv = csv.writer(csvfile, quoting=csv.QUOTE_ALL)
    for rownum in xrange(worksheet.nrows):
        writetocsv.writerow(
            list(worksheet.row_values(rownum)
                 )
        )
    csvfile.close()
    print(sheet_name + ' has been saved at - ' + csv_file_full_path)
