-- Chapter 06. 개인 서비스(내 카페 방문 기록) 무결성 규칙 추가
-- 시작 상태: code/chapter05/my_cafe_schema.sql로 만든 cafes, menu_items, visits, visit_items가 있음
-- 완료 상태: 확정 규칙 P06-C01~C04만 이름 붙은 제약조건으로 추가됨
-- 미확정 정책(P06-C05 평점 범위, 같은 날 재방문, 카페별 메뉴, 폐업 처리)은 제약으로 만들지 않습니다.
-- 기존 데이터 검사와 규칙 추가를 하나의 트랜잭션으로 묶습니다.

SELECT current_database();

BEGIN;

-- 1. 기존 데이터가 새 규칙을 어기지 않는지 먼저 검사
DO $$
DECLARE
    v_blank_cafe bigint;
    v_blank_menu bigint;
    v_bad_category bigint;
    v_negative_price bigint;
BEGIN
    IF to_regclass('public.cafes') IS NULL
       OR to_regclass('public.menu_items') IS NULL
       OR to_regclass('public.visits') IS NULL
       OR to_regclass('public.visit_items') IS NULL THEN
        RAISE EXCEPTION '중단: Chapter 05 카페 테이블이 없습니다. code/chapter05/my_cafe_schema.sql을 먼저 실행하세요.';
    END IF;

    SELECT COUNT(*) INTO v_blank_cafe FROM public.cafes WHERE btrim(name) = '';
    SELECT COUNT(*) INTO v_blank_menu FROM public.menu_items WHERE btrim(name) = '';
    SELECT COUNT(*) INTO v_bad_category FROM public.menu_items WHERE category NOT IN ('음료', '디저트');
    SELECT COUNT(*) INTO v_negative_price FROM public.visit_items WHERE price < 0;

    IF v_blank_cafe + v_blank_menu + v_bad_category + v_negative_price > 0 THEN
        RAISE EXCEPTION '중단: 규칙을 어기는 기존 데이터가 있습니다. blank_cafe=%, blank_menu=%, bad_category=%, negative_price=%',
            v_blank_cafe, v_blank_menu, v_bad_category, v_negative_price;
    END IF;
END
$$;

-- P06-C01 카페 이름·메뉴 이름 공백 금지
ALTER TABLE public.cafes
    ADD CONSTRAINT chk_cafes_name_not_blank CHECK (btrim(name) <> '');
ALTER TABLE public.menu_items
    ADD CONSTRAINT chk_menu_items_name_not_blank CHECK (btrim(name) <> '');

-- P06-C02 메뉴 분류는 음료 또는 디저트 (P05-R05)
ALTER TABLE public.menu_items
    ADD CONSTRAINT chk_menu_items_category CHECK (category IN ('음료', '디저트'));

-- P06-C03 가격은 NULL(기록 안 함) 또는 0 이상
ALTER TABLE public.visit_items
    ADD CONSTRAINT chk_visit_items_price CHECK (price IS NULL OR price >= 0);

-- P06-C04 방문·주문 기록이 있는 부모는 삭제 금지 (이력 보호)
-- Chapter 05의 이름 없는 FK를 이름 붙은 ON DELETE RESTRICT FK로 바꿉니다.
DO $$
DECLARE
    r RECORD;
BEGIN
    FOR r IN
        SELECT conrelid::regclass AS tbl, conname
        FROM pg_constraint
        WHERE contype = 'f'
          AND conrelid IN ('public.visits'::regclass, 'public.visit_items'::regclass)
    LOOP
        EXECUTE format('ALTER TABLE %s DROP CONSTRAINT %I', r.tbl, r.conname);
    END LOOP;
END
$$;

ALTER TABLE public.visits
    ADD CONSTRAINT fk_visits_cafe
    FOREIGN KEY (cafe_id) REFERENCES public.cafes(id) ON DELETE RESTRICT;
ALTER TABLE public.visit_items
    ADD CONSTRAINT fk_visit_items_visit
    FOREIGN KEY (visit_id) REFERENCES public.visits(id) ON DELETE RESTRICT;
ALTER TABLE public.visit_items
    ADD CONSTRAINT fk_visit_items_menu_item
    FOREIGN KEY (menu_item_id) REFERENCES public.menu_items(id) ON DELETE RESTRICT;

COMMIT;

-- 적용 결과 확인 (7행)
SELECT conrelid::regclass AS table_name, conname AS constraint_name, contype AS constraint_type
FROM pg_constraint
WHERE conrelid IN ('public.cafes'::regclass, 'public.menu_items'::regclass,
                   'public.visits'::regclass, 'public.visit_items'::regclass)
  AND contype IN ('c', 'f')
ORDER BY conrelid::regclass::text, conname;
