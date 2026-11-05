-- Chapter 08 개인 프로젝트(내 카페 방문 기록) 업무 질문 3개
-- 시작 상태: code/chapter07/my_cafe_project_schema.sql 실행 후 cafe_project 네 테이블이 0행
-- 끝 상태: 시작 상태와 같음. 샘플 데이터는 트랜잭션 안에서만 쓰고 마지막에 ROLLBACK 합니다.
-- 아래 카페와 방문은 검산용으로 만든 샘플이며 실제 방문 기록이 아닙니다.

BEGIN;

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM cafe_project.cafes)
       OR EXISTS (SELECT 1 FROM cafe_project.visits) THEN
        RAISE EXCEPTION '중단: cafe_project에 이미 데이터가 있어 예상값과 비교할 수 없습니다.';
    END IF;
END
$$;

INSERT INTO cafe_project.cafes (id, name, closed_on) VALUES
    (1, '카페 X', NULL),
    (2, '카페 Y', NULL),
    (3, '카페 Z', NULL),            -- 방문 0회 (P07-MR02)
    (4, '카페 W', DATE '2026-10-01'); -- 폐업 (P07-MR09)

INSERT INTO cafe_project.menu_items (id, cafe_id, name, category) VALUES
    (11, 1, '아메리카노', '음료'),
    (12, 1, '치즈케이크', '디저트'),
    (13, 1, '라떼', '음료'),         -- 주문 0회
    (21, 2, '아메리카노', '음료'),
    (22, 2, '마들렌', '디저트'),
    (31, 3, '아메리카노', '음료'),   -- 방문 0회 카페의 메뉴
    (41, 4, '라떼', '음료');

INSERT INTO cafe_project.visits (id, cafe_id, visited_on, rating) VALUES
    (1, 1, DATE '2026-10-01', 4.5),
    (2, 1, DATE '2026-10-15', 4.0),
    (3, 1, DATE '2026-11-01', NULL), -- 평점 없는 방문 (P07-MR08)
    (4, 2, DATE '2026-10-08', 3.5),
    (5, 4, DATE '2026-09-20', 5.0),
    (6, 2, DATE '2026-10-20', 4.0);  -- 주문 기록 없는 방문

INSERT INTO cafe_project.visit_items (id, visit_id, menu_item_id, price) VALUES
    (1, 1, 11, 4500),
    (2, 1, 12, 6500),
    (3, 2, 11, 4800),
    (4, 3, 11, 4800),
    (5, 3, 11, 4800),               -- 같은 메뉴 두 잔은 두 행 (P07-MQ02 잠정)
    (6, 3, 12, NULL),               -- 가격 미기록 (P07-MR07)
    (7, 4, 21, 5000),
    (8, 4, 22, 3000),
    (9, 5, 41, 5500);

\echo '=== P08 기준: 행 수 4 / 7 / 6 / 9, MR10 위반 0'
SELECT (SELECT COUNT(*) FROM cafe_project.cafes) AS cafes,
       (SELECT COUNT(*) FROM cafe_project.menu_items) AS menu_items,
       (SELECT COUNT(*) FROM cafe_project.visits) AS visits,
       (SELECT COUNT(*) FROM cafe_project.visit_items) AS visit_items,
       (SELECT COUNT(*)
        FROM cafe_project.visit_items AS vi
        JOIN cafe_project.visits AS v ON vi.visit_id = v.id
        JOIN cafe_project.menu_items AS m ON vi.menu_item_id = m.id
        WHERE m.cafe_id <> v.cafe_id) AS mr10_violations;

\echo '=== P08-Q01 카페별 방문 횟수와 평균 평점'
SELECT c.id, c.name,
       COUNT(v.id) AS visit_count,
       COUNT(v.rating) AS rated_visit_count,
       ROUND(AVG(v.rating), 2) AS avg_rating
FROM cafe_project.cafes AS c
LEFT JOIN cafe_project.visits AS v ON c.id = v.cafe_id
GROUP BY c.id, c.name
ORDER BY c.id;

\echo '=== P08-Q01 검산: 카페별 합 = visits 전체'
SELECT (SELECT COUNT(*) FROM cafe_project.visits) AS visits_total,
       SUM(x.visit_count) AS sum_by_cafe
FROM (
    SELECT COUNT(v.id) AS visit_count
    FROM cafe_project.cafes AS c
    LEFT JOIN cafe_project.visits AS v ON c.id = v.cafe_id
    GROUP BY c.id
) AS x;

\echo '=== P08-Q02 카페별 방문 횟수·주문 수·실제 지출'
SELECT c.id, c.name, c.closed_on,
       COUNT(DISTINCT v.id) AS visit_count,
       COUNT(vi.id) AS order_count,
       COUNT(vi.price) AS priced_order_count,
       COALESCE(SUM(vi.price), 0) AS spent_known
FROM cafe_project.cafes AS c
LEFT JOIN cafe_project.visits AS v ON c.id = v.cafe_id
LEFT JOIN cafe_project.visit_items AS vi ON v.id = vi.visit_id
GROUP BY c.id, c.name
ORDER BY c.id;

\echo '=== P08-Q02 과대 집계 관찰: 주문까지 JOIN한 뒤 방문을 세고 평점을 평균'
SELECT c.id, c.name,
       COUNT(v.id) AS wrong_visit_count,
       ROUND(AVG(v.rating), 2) AS wrong_avg_rating
FROM cafe_project.cafes AS c
LEFT JOIN cafe_project.visits AS v ON c.id = v.cafe_id
LEFT JOIN cafe_project.visit_items AS vi ON v.id = vi.visit_id
GROUP BY c.id, c.name
ORDER BY c.id;

\echo '=== P08-Q02 검산: 카페 X 상세와 전체 합계'
SELECT v.id AS visit_id, v.visited_on, m.name AS menu_name, vi.price
FROM cafe_project.visits AS v
JOIN cafe_project.visit_items AS vi ON v.id = vi.visit_id
JOIN cafe_project.menu_items AS m ON vi.menu_item_id = m.id
WHERE v.cafe_id = 1
ORDER BY v.id, vi.id;

SELECT COUNT(*) AS order_total, COUNT(price) AS priced_total, SUM(price) AS spent_total
FROM cafe_project.visit_items;

\echo '=== P08-Q03 메뉴별 주문 횟수와 가격 범위'
SELECT m.id, c.name AS cafe_name, m.name AS menu_name,
       COUNT(vi.id) AS order_count,
       COUNT(vi.id) - COUNT(vi.price) AS unpriced_count,
       MIN(vi.price) AS min_price,
       MAX(vi.price) AS max_price
FROM cafe_project.menu_items AS m
INNER JOIN cafe_project.cafes AS c ON m.cafe_id = c.id
LEFT JOIN cafe_project.visit_items AS vi ON m.id = vi.menu_item_id
GROUP BY m.id, c.name, m.name
ORDER BY m.id;

\echo '=== P08-Q03 검산: 메뉴별 합 = visit_items 전체, 주문 0회 메뉴'
SELECT (SELECT COUNT(*) FROM cafe_project.visit_items) AS visit_items_total,
       SUM(x.order_count) AS sum_by_menu,
       COUNT(*) FILTER (WHERE x.order_count = 0) AS never_ordered_menu_count
FROM (
    SELECT COUNT(vi.id) AS order_count
    FROM cafe_project.menu_items AS m
    LEFT JOIN cafe_project.visit_items AS vi ON m.id = vi.menu_item_id
    GROUP BY m.id
) AS x;

\echo '=== 13장 AI SQL 실행 (별도 Claude 대화에서 받은 CTE 방식)'
WITH visit_agg AS (
    SELECT v.cafe_id, COUNT(*) AS visit_count
    FROM cafe_project.visits AS v
    GROUP BY v.cafe_id
),
item_agg AS (
    SELECT v.cafe_id,
           COUNT(*) AS order_count,
           COUNT(vi.price) AS priced_order_count,
           SUM(vi.price) AS spent_known
    FROM cafe_project.visit_items AS vi
    JOIN cafe_project.visits AS v ON v.id = vi.visit_id
    GROUP BY v.cafe_id
)
SELECT c.id, c.name, c.closed_on,
       COALESCE(va.visit_count, 0) AS visit_count,
       COALESCE(ia.order_count, 0) AS order_count,
       COALESCE(ia.priced_order_count, 0) AS priced_order_count,
       COALESCE(ia.order_count, 0) - COALESCE(ia.priced_order_count, 0) AS unpriced_order_count,
       COALESCE(ia.spent_known, 0) AS spent_known
FROM cafe_project.cafes AS c
LEFT JOIN visit_agg AS va ON va.cafe_id = c.id
LEFT JOIN item_agg AS ia ON ia.cafe_id = c.id
ORDER BY c.id;

\echo '=== 13장 내 SQL과 AI SQL 양방향 EXCEPT: 둘 다 0이어야 함'
WITH visit_agg AS (
    SELECT v.cafe_id, COUNT(*) AS visit_count
    FROM cafe_project.visits AS v
    GROUP BY v.cafe_id
),
item_agg AS (
    SELECT v.cafe_id,
           COUNT(*) AS order_count,
           COUNT(vi.price) AS priced_order_count,
           SUM(vi.price) AS spent_known
    FROM cafe_project.visit_items AS vi
    JOIN cafe_project.visits AS v ON v.id = vi.visit_id
    GROUP BY v.cafe_id
),
ai AS (
    SELECT c.id, c.name, c.closed_on,
           COALESCE(va.visit_count, 0) AS visit_count,
           COALESCE(ia.order_count, 0) AS order_count,
           COALESCE(ia.priced_order_count, 0) AS priced_order_count,
           COALESCE(ia.spent_known, 0) AS spent_known
    FROM cafe_project.cafes AS c
    LEFT JOIN visit_agg AS va ON va.cafe_id = c.id
    LEFT JOIN item_agg AS ia ON ia.cafe_id = c.id
),
mine AS (
    SELECT c.id, c.name, c.closed_on,
           COUNT(DISTINCT v.id) AS visit_count,
           COUNT(vi.id) AS order_count,
           COUNT(vi.price) AS priced_order_count,
           COALESCE(SUM(vi.price), 0) AS spent_known
    FROM cafe_project.cafes AS c
    LEFT JOIN cafe_project.visits AS v ON c.id = v.cafe_id
    LEFT JOIN cafe_project.visit_items AS vi ON v.id = vi.visit_id
    GROUP BY c.id, c.name
)
SELECT (SELECT COUNT(*) FROM (SELECT * FROM mine EXCEPT SELECT * FROM ai) AS x) AS mine_only,
       (SELECT COUNT(*) FROM (SELECT * FROM ai EXCEPT SELECT * FROM mine) AS y) AS ai_only;

\echo '=== 13장 AI 제안 점검: 폐업일 이후 방문 (0행이어야 함)'
SELECT c.id, c.closed_on, v.id AS visit_id, v.visited_on
FROM cafe_project.cafes AS c
JOIN cafe_project.visits AS v ON v.cafe_id = c.id
WHERE c.closed_on IS NOT NULL
  AND v.visited_on > c.closed_on;

ROLLBACK;

\echo '=== ROLLBACK 확인: 네 테이블 모두 0행이어야 함'
SELECT (SELECT COUNT(*) FROM cafe_project.cafes) AS cafes,
       (SELECT COUNT(*) FROM cafe_project.menu_items) AS menu_items,
       (SELECT COUNT(*) FROM cafe_project.visits) AS visits,
       (SELECT COUNT(*) FROM cafe_project.visit_items) AS visit_items;
