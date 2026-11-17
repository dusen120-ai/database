-- Chapter 10 개인 프로젝트 인덱스 후보 검증 (cafe_project는 읽지도 쓰지도 않음)
-- 세션 전용 TEMP 테이블에 cafe_project와 같은 구조의 합성 데이터를 만들어 비교한다.
-- 접속이 끝나면 TEMP 테이블은 자동 삭제된다. 데이터는 실제 방문 기록이 아닌 합성 샘플이다.
-- v2: AI 리뷰(14장)를 반영해 P10-Q01에 동점 처리(id DESC)를 추가하고 인덱스를 (cafe_id, visited_on DESC, id DESC)로 바꿨다.
--     v1 스크립트와 로그는 plans/cafe_index_experiment_v1.sql, plans/cafe_scale*_v1.txt에 보존한다.
\set ON_ERROR_STOP on
\echo '########## 규모:' :scale
CREATE TEMP TABLE cafes (id int PRIMARY KEY, name varchar(100) NOT NULL);
CREATE TEMP TABLE menu_items (id int PRIMARY KEY, cafe_id int NOT NULL, name varchar(100) NOT NULL, category varchar(20) NOT NULL);
CREATE TEMP TABLE visits (id int PRIMARY KEY, cafe_id int NOT NULL, visited_on date NOT NULL, rating numeric(2,1));
CREATE TEMP TABLE visit_items (id int PRIMARY KEY, visit_id int NOT NULL, menu_item_id int NOT NULL, price int);
-- :scale = 1 → 카페 20 / 방문 300 / 주문 600 (현재 개인 기록 수준)
-- :scale = 100 → 카페 200 / 방문 30000 / 주문 60000 (수년 누적 가정)
INSERT INTO cafes SELECT g, '카페 '||g FROM generate_series(1, CASE WHEN :scale=1 THEN 20 ELSE 200 END) g;
INSERT INTO menu_items SELECT g, (g-1)/5+1, '메뉴 '||g, CASE WHEN g%2=0 THEN '음료' ELSE '디저트' END
FROM generate_series(1, (SELECT count(*)*5 FROM cafes)) g;
INSERT INTO visits SELECT g, (g % (SELECT count(*) FROM cafes))+1, DATE '2023-01-01' + (g % 1000), 3 + (g%3)*0.5
FROM generate_series(1, 300*:scale) g;
INSERT INTO visit_items SELECT g, (g+1)/2, (((g+1)/2) % (SELECT count(*) FROM cafes))*5 + 1 + (g%2), 4000 + (g%5)*500
FROM generate_series(1, 600*:scale) g;
ANALYZE cafes; ANALYZE menu_items; ANALYZE visits; ANALYZE visit_items;

\echo '=== 결과 id 목록 (인덱스 전)'
SELECT string_agg(id::text, ',' ORDER BY id) AS q01_ids FROM (SELECT id FROM visits WHERE cafe_id = 7 ORDER BY visited_on DESC, id DESC LIMIT 10) x;
SELECT string_agg(id::text, ',' ORDER BY id) AS q02_ids FROM visit_items WHERE visit_id = 150;

\echo '=== BEFORE P10-Q01: 카페 7의 최근 방문 10건'
EXPLAIN (ANALYZE, BUFFERS) SELECT id, visited_on, rating FROM visits WHERE cafe_id = 7 ORDER BY visited_on DESC, id DESC LIMIT 10;
\echo '=== BEFORE P10-Q02: 방문 150의 주문 내역'
EXPLAIN (ANALYZE, BUFFERS) SELECT vi.id, m.name, vi.price FROM visit_items vi JOIN menu_items m ON m.id = vi.menu_item_id WHERE vi.visit_id = 150;
\echo '=== BEFORE 비교용(rating): 평점 4.0 이상 방문 (약 33% 반환)'
EXPLAIN (ANALYZE, BUFFERS) SELECT id, cafe_id, visited_on FROM visits WHERE rating >= 4.0;

CREATE INDEX idx_visits_cafe_visited_on_id ON visits(cafe_id, visited_on DESC, id DESC);
CREATE INDEX idx_visit_items_visit_id ON visit_items(visit_id);
CREATE INDEX idx_visits_rating ON visits(rating);

\echo '=== AFTER P10-Q01'
EXPLAIN (ANALYZE, BUFFERS) SELECT id, visited_on, rating FROM visits WHERE cafe_id = 7 ORDER BY visited_on DESC, id DESC LIMIT 10;
\echo '=== AFTER P10-Q02'
EXPLAIN (ANALYZE, BUFFERS) SELECT vi.id, m.name, vi.price FROM visit_items vi JOIN menu_items m ON m.id = vi.menu_item_id WHERE vi.visit_id = 150;
\echo '=== AFTER 비교용(rating)'
EXPLAIN (ANALYZE, BUFFERS) SELECT id, cafe_id, visited_on FROM visits WHERE rating >= 4.0;
\echo '=== 결과 id 목록 (인덱스 후, 인덱스 전과 같아야 함)'
SELECT string_agg(id::text, ',' ORDER BY id) AS q01_ids FROM (SELECT id FROM visits WHERE cafe_id = 7 ORDER BY visited_on DESC, id DESC LIMIT 10) x;
SELECT string_agg(id::text, ',' ORDER BY id) AS q02_ids FROM visit_items WHERE visit_id = 150;
SELECT count(*) AS rating_cmp_rows FROM visits WHERE rating >= 4.0;
SELECT relname, pg_size_pretty(pg_relation_size(oid)) FROM pg_class WHERE relname IN ('visits','visit_items','idx_visits_cafe_visited_on_id','idx_visit_items_visit_id','idx_visits_rating') ORDER BY 1;
