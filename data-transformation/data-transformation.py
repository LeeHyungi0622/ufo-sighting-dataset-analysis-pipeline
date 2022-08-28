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
SELECT * FROM data_master WHERE city LIKE '%korea%' and country = ''; # korea가 포함된 도시명 조건으로 검색하면 총 14개의 데이터가 있음을 확인

# 위의 쿼리 결과를 S3의 별도 폴더에 저장
%pyspark

spark.sql("""
SELECT * FROM data_master WHERE city LIKE '%korea%' and country = ''
""").write.mode("overwrite").json("s3://hg-project-stream-event-backup/silver/korea_record/")

# UFO 목격 가능성이 가장 높은 지역
# 국가, 지역, 도시별로 그룹화해서 데이터를 필터한 다음에 목격 횟수(COUNT)를 내림차순으로 정렬해서 출력
# UFO 목격 상위 3개의 지역은 us의 wa, az, or 주의 seattle, phoenix, portland가 397, 337, 277회 목격되었다.
%sql

SELECT country, state, city, COUNT(*) AS count 
from data_master 
GROUP BY country, state, city
ORDER BY COUNT(*) DESC;

# 결과를 S3에 저장
%pyspark

spark.sql("""
SELECT country, state, city, COUNT(*) AS count 
from data_master 
GROUP BY country, state, city
ORDER BY COUNT(*) DESC
""").write.mode("overwrite").json("s3://hg-project-stream-event-backup/silver/ufo_sighting_top_region/")

# UFO가 특정 계절에 많이 목격되는지
# 상위 3개의 UFO 관측 횟수가 모두 미국(us), 7월이 두 번, 3월이 한 번 포함하고 있다.
# 1위인 시애틀 지역은 다음과 같은 날씨 정보를 가진다.
# 시애틀의 7월 평균 최저기온은 13℃, 평균 최고기온은 24℃로 우리나라 늦봄의 날씨를 보이며 평균 일교차는 11℃로 큰 편입니다. 평균 강수량은 19.3mm로 매우 적으며, 평균 강수일수는 3.4일로 비가 거의 오지 않는 편입니다.
# 포틀랜드는 여름(7월~9월)에는 쨍한 날씨로 세계 그 어느 지역보다 맑은 날씨가 연속적으로 지속된다.
# 피닉스의 3월 평균 최저기온은 9.3℃, 평균 최고기온은 24.2℃로, 우리나라의 늦봄의 날씨이다.

%sql

SELECT 
    country AS COUNTRY,
    city AS CITY,
    split(datetime,'/')[0] AS MONTH,
    COUNT(*) AS SIGHTING_COUNT,
    RANK() OVER(ORDER BY COUNT(*) DESC) AS RANK
FROM data_master
GROUP BY COUNTRY, CITY, MONTH
ORDER BY SIGHTING_COUNT DESC;

# 결과를 S3에 저장
%pyspark

spark.sql("""
SELECT 
    country AS COUNTRY,
    city AS CITY,
    split(datetime,'/')[0] AS MONTH,
    COUNT(*) AS SIGHTING_COUNT,
    RANK() OVER(ORDER BY COUNT(*) DESC) AS RANK
FROM data_master
GROUP BY COUNTRY, CITY, MONTH
ORDER BY SIGHTING_COUNT DESC
""").write.mode("overwrite").json("s3://hg-project-stream-event-backup/silver/ufo_sighting_top_season/")

# 가장 일반적으로 묘사되는 UFO의 모양은 빛(광선)의 형태와 삼각형, 원형의 형태로 목격이 되었다.
%sql

SELECT 
    shape,
    COUNT(*) AS COUNT
FROM data_master
GROUP BY shape
ORDER BY COUNT DESC;

# 결과를 S3에 저장
%pyspark

spark.sql("""
SELECT 
    shape,
    COUNT(*) AS COUNT
FROM data_master
GROUP BY shape
ORDER BY COUNT DESC
""").write.mode("overwrite").json("s3://hg-project-stream-event-backup/silver/ufo_general_describe/")
