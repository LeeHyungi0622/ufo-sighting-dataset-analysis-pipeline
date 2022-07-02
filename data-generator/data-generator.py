# -*- coding: utf-8 -*-

import csv
import json
import requests


def make_object_from_csv():
    csvFileList = []

    with open('./scrubbed.csv') as f:
        reader = csv.reader(f)
        for idx, row in enumerate(reader):
            if idx == 0:
                csvFileMap = {r: '' for r in row}
            else:
                key_lst = list(csvFileMap.keys())
                for j in range(len(key_lst)):
                    csvFileMap[key_lst[j]] = row[j]
                csvFileList.append(csvFileMap)
                # csvFileMap dict()의 key의 value를 초기화 시킨다.
                csvFileMap = {k: '' for k in key_lst}
    return csvFileList


def sendPost(json, url):
    return requests.post(url, data=json)


rowCount = 1

aws_api_gateway_url = '[API Gateway End Point]'
csv_object = make_object_from_csv()

for obj in csv_object:
    json_data = json.dumps(obj)
    print(f"{rowCount}번째 데이터 수신 결과", sendPost(json_data, aws_api_gateway_url))

    rowCount += 1

print("총 데이터 건 수 {0} 중에 {1}건의 데이터 발송완료".format(len(csv_object), rowCount))
