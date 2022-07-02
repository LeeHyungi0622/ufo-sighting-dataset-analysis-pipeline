"""
아래 코드는 Amazon EMR의 Zeppelin에서 Spark Interpreter를 사용하여 실행한 코드입니다.
"""

%pyspark

# S3 저장소에 저장된 JSON 포멧의 데이터를 읽는다. (DataFrame)
ufo_sighting_df = sqlContext.read.format("json").load("s3://hg-project-stream-event-backup/2022/07/02/*")

print(type(ufo_sighting_df)) #<class 'pyspark.sql.dataframe.DataFrame'>

ufo_sighting_df.printSchema()
# root
#  |-- city: string (nullable = true)
#  |-- comments: string (nullable = true)
#  |-- country: string (nullable = true)
#  |-- date posted: string (nullable = true)
#  |-- datetime: string (nullable = true)
#  |-- duration (hours/min): string (nullable = true)
#  |-- duration (seconds): string (nullable = true)
#  |-- latitude: string (nullable = true)
#  |-- longitude : string (nullable = true)
#  |-- shape: string (nullable = true)
#  |-- state: string (nullable = true)

ufo_sighting_df.show() # 상위 20개의 데이터를 출력

# sql을 활용하여 분석하기 위해서 TempView 생성
ufo_sighting_df.createOrReplaceTempView("data_master")

%sql
# 한국에 대한 정보는 country column이 아닌 city에 국가명을 포함한 도시명이 표기가 되어있어 아래와 같은 조건으로 쿼리
SELECT * FROM data_master WHERE city LIKE '%korea%'; # korea가 포함된 도시명 조건으로 검색하면 총 14개의 데이터가 있음을 확인

# MapReduce로 comments에서 등장한 단어의 갯수 중에 가장 많이 등장한 단어를 분석한다. (조사 제외) 