-- Chapter 10 14장: AI가 제안한 인덱스를 실제 실행 계획으로 검증
-- cafe_project는 읽지도 쓰지도 않는다. 세션 전용 TEMP 테이블에 cafe_index_experiment.sql과
-- 같은 규칙으로 합성 데이터(scale 100: 카페 200 / 메뉴 1000 / 방문 30000 / 주문 60000)를 만든다.
-- 접속이 끝나면 TEMP 테이블은 자동 삭제된다.
\set ON_ERROR_STOP on
SELECT version();
CREATE TEMP TABLE cafes (id int PRIMARY KEY, name varchar(100) NOT NULL);
CREATE TEMP TABLE menu_items (id int PRIMARY KEY, cafe_id int NOT NULL, name varchar(100) NOT NULL, category varchar(20) NOT NULL);
CREATE TEMP TABLE visits (id int PRIMARY KEY, cafe_id int NOT NULL, visited_on date NOT NULL, rating numeric(2,1));
CREATE TEMP TABLE visit_items (id int PRIMARY KEY, visit_id int NOT NULL, menu_item_id int NOT NULL, price int);
INSERT INTO cafes SELECT g, '카페 '||g FROM generate_series(1, 200) g;
INSERT INTO menu_items SELECT g, (g-1)/5+1, '메뉴 '||g, CASE WHEN g%2=0 THEN '음료' ELSE '디저트' END FROM generate_series(1, 1000) g;
INSERT INTO visits SELECT g, (g % 200)+1, DATE '2023-01-01' + (g % 1000), 3 + (g%3)*0.5 FROM generate_series(1, 30000) g;
INSERT INTO visit_items SELECT g, (g+1)/2, (((g+1)/2) % 200)*5 + 1 + (g%2), 4000 + (g%5)*500 FROM generate_series(1, 60000) g;
ANALYZE cafes; ANALYZE menu_items; ANALYZE visits; ANALYZE visit_items;

\echo '=== [주장 2] 카페 7의 방문 날짜 분포 (같은 날 방문이 여러 건인가)'
SELECT count(*) AS visits, count(DISTINCT visited_on) AS distinct_dates FROM visits WHERE cafe_id = 7;
\echo '=== [주장 2] 현재 SQL의 최근 10건: 동점(같은 날짜)이 있는가'
SELECT visited_on, count(*) FROM (SELECT visited_on FROM visits WHERE cafe_id = 7 ORDER BY visited_on DESC LIMIT 10) x GROUP BY 1;
SELECT visited_on, count(*) FROM visits WHERE cafe_id = 7 GROUP BY 1 ORDER BY 1 DESC;

\echo '########## [주장 1] AI 추천 Q01 인덱스 (cafe_id, visited_on DESC, id DESC)'
CREATE INDEX ai_q01 ON visits (cafe_id, visited_on DESC, id DESC);
\echo '=== Q01 원래 SQL'
EXPLAIN (ANALYZE, BUFFERS) SELECT id, visited_on, rating FROM visits WHERE cafe_id = 7 ORDER BY visited_on DESC LIMIT 10;
\echo '=== Q01 AI가 권한 SQL (id DESC 동점 처리)'
EXPLAIN (ANALYZE, BUFFERS) SELECT id, visited_on, rating FROM visits WHERE cafe_id = 7 ORDER BY visited_on DESC, id DESC LIMIT 10;
SELECT id, visited_on, rating FROM visits WHERE cafe_id = 7 ORDER BY visited_on DESC, id DESC LIMIT 10;
\echo '=== Q01 카페 7의 최근 10건이 테이블의 몇 개 페이지에 흩어져 있는가'
SELECT count(DISTINCT (ctid::text::point)[0]) AS heap_pages
FROM (SELECT ctid FROM visits WHERE cafe_id = 7 ORDER BY visited_on DESC, id DESC LIMIT 10) x;

\echo '########## [주장 3] INCLUDE (rating) 추가 시'
DROP INDEX ai_q01;
CREATE INDEX ai_q01_inc ON visits (cafe_id, visited_on DESC, id DESC) INCLUDE (rating);
\echo '=== VACUUM 전 (visibility map 없음)'
EXPLAIN (ANALYZE, BUFFERS) SELECT id, visited_on, rating FROM visits WHERE cafe_id = 7 ORDER BY visited_on DESC, id DESC LIMIT 10;
VACUUM visits;
\echo '=== VACUUM 후'
EXPLAIN (ANALYZE, BUFFERS) SELECT id, visited_on, rating FROM visits WHERE cafe_id = 7 ORDER BY visited_on DESC, id DESC LIMIT 10;
SELECT pg_size_pretty(pg_relation_size('ai_q01_inc')) AS include_index_size;
DROP INDEX ai_q01_inc;
CREATE INDEX ai_q01 ON visits (cafe_id, visited_on DESC, id DESC);
SELECT pg_size_pretty(pg_relation_size('ai_q01')) AS q01_index_size;

\echo '########## [주장 4] AI 추천 Q02 인덱스 visit_items (visit_id)'
\echo '=== 인덱스 전'
EXPLAIN (ANALYZE, BUFFERS) SELECT vi.id, m.name, vi.price FROM visit_items vi JOIN menu_items m ON m.id = vi.menu_item_id WHERE vi.visit_id = 150;
CREATE INDEX ai_q02 ON visit_items (visit_id);
\echo '=== 인덱스 후'
EXPLAIN (ANALYZE, BUFFERS) SELECT vi.id, m.name, vi.price FROM visit_items vi JOIN menu_items m ON m.id = vi.menu_item_id WHERE vi.visit_id = 150;

\echo '########## [주장 5] visits (rating): 플래너가 Seq Scan을 고르는가'
SELECT count(*) AS rating_ge_4, round(100.0*count(*)/30000, 1) AS pct FROM visits WHERE rating >= 4.0;
CREATE INDEX cmp_rating ON visits (rating);
EXPLAIN (ANALYZE, BUFFERS) SELECT id, cafe_id, visited_on FROM visits WHERE rating >= 4.0;
EXPLAIN (ANALYZE, BUFFERS) SELECT id, cafe_id, visited_on FROM visits WHERE rating = 3.5;
DROP INDEX cmp_rating;

\echo '########## [주장 6] (cafe_id), (visited_on) 단일 인덱스 2개만 있을 때'
DROP INDEX ai_q01;
CREATE INDEX cmp_cafe ON visits (cafe_id);
CREATE INDEX cmp_date ON visits (visited_on);
EXPLAIN (ANALYZE, BUFFERS) SELECT id, visited_on, rating FROM visits WHERE cafe_id = 7 ORDER BY visited_on DESC, id DESC LIMIT 10;

\echo '########## [주장 2 추가] 동점이 있을 때 원래 SQL의 결과가 계획에 따라 달라지는가'
DROP INDEX cmp_cafe; DROP INDEX cmp_date;
\echo '=== 인덱스 없음 (Seq Scan + Sort)'
SELECT string_agg(id::text, ',' ORDER BY id) AS ids FROM (SELECT id FROM visits WHERE cafe_id = 7 ORDER BY visited_on DESC LIMIT 10) x;
CREATE INDEX ai_q01 ON visits (cafe_id, visited_on DESC, id DESC);
\echo '=== AI 추천 인덱스 있음 (Index Scan)'
SELECT string_agg(id::text, ',' ORDER BY id) AS ids FROM (SELECT id FROM visits WHERE cafe_id = 7 ORDER BY visited_on DESC LIMIT 10) x;
