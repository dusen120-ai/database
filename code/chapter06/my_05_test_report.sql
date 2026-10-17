-- Chapter 06. 05 테스트 결과를 한 표로 모아 보는 개인 실습 파일
-- 시작 상태: 04_add_integrity_rules.sql 적용 완료, 기준 데이터(raw 3, members 2, books 2, loans 3)
-- 각 테스트를 BEGIN ... EXCEPTION 블록 안에서 따로 실행하므로, 실패한 테스트는 그 문장만 취소되고 다음 테스트로 넘어갑니다.
-- 경계 테스트는 성공 여부를 기록한 뒤 임시 행을 바로 삭제합니다.
-- 결과는 세션 임시 테이블(pg_temp)에만 저장되며 연결을 닫으면 사라집니다.
-- 실행: 전체 실행(⌥X) 후 마지막 두 SELECT 결과를 확인합니다.

DROP TABLE IF EXISTS ch06_test_report;
CREATE TEMP TABLE ch06_test_report (
    seq INTEGER,
    test_name TEXT,
    expected TEXT,
    actual TEXT,
    sqlstate TEXT,
    constraint_name TEXT,
    message TEXT
);

DO $$
DECLARE
    t RECORD;
    v_state TEXT;
    v_constraint TEXT;
    v_message TEXT;
BEGIN
    FOR t IN
        SELECT * FROM (VALUES
            (1,  '경계 A: due_at = borrowed_at = returned_at', '성공',
                 'INSERT INTO public.books_nf (id, title, author, published_year, isbn) VALUES (1800, ''경계값 테스트 도서'', ''테스트 저자'', 2026, ''ISBN-BND-LOAN-001''); '
              || 'INSERT INTO public.loans_nf (id, member_id, book_id, borrowed_at, due_at, returned_at) VALUES (1801, 101, 1800, DATE ''2026-05-01'', DATE ''2026-05-01'', DATE ''2026-05-01'')',
                 'DELETE FROM public.loans_nf WHERE id = 1801; DELETE FROM public.books_nf WHERE id = 1800'),
            (2,  '경계 B: published_year = NULL', '성공',
                 'INSERT INTO public.books_nf (id, title, author, published_year, isbn) VALUES (1802, ''연도 미상 도서'', ''익명'', NULL, ''ISBN-BOUNDARY-001'')',
                 'DELETE FROM public.books_nf WHERE id = 1802'),
            (3,  '경계 C: 한 글자 이름', '성공',
                 'INSERT INTO public.members_nf (id, name, email, joined_at) VALUES (1803, ''김'', ''one-char@example.com'', DATE ''2026-03-20'')',
                 'DELETE FROM public.members_nf WHERE id = 1803'),
            (4,  '경계 D: returned_at = NULL (새 도서 미반납 대여)', '성공',
                 'INSERT INTO public.books_nf (id, title, author, published_year, isbn) VALUES (1804, ''미반납 경계 도서'', ''테스트 저자'', 2026, ''ISBN-BND-NULL-001''); '
              || 'INSERT INTO public.loans_nf (id, member_id, book_id, borrowed_at, due_at, returned_at) VALUES (1805, 102, 1804, DATE ''2026-05-01'', DATE ''2026-05-15'', NULL)',
                 'DELETE FROM public.loans_nf WHERE id = 1805; DELETE FROM public.books_nf WHERE id = 1804'),
            (11, '오류 1: 이름 NULL', '실패',
                 'INSERT INTO public.members_nf (id, name, email, joined_at) VALUES (1901, NULL, ''null-name@example.com'', DATE ''2026-03-20'')', NULL),
            (12, '오류 2: 이메일 중복', '실패',
                 'INSERT INTO public.members_nf (id, name, email, joined_at) VALUES (1902, ''중복 이메일 회원'', ''junho@example.com'', DATE ''2026-03-20'')', NULL),
            (13, '오류 3A: ISBN NULL', '실패',
                 'INSERT INTO public.books_nf (id, title, author, published_year, isbn) VALUES (1912, ''ISBN 없음 도서'', ''테스트 저자'', 2026, NULL)', NULL),
            (14, '오류 3B: ISBN 중복', '실패',
                 'INSERT INTO public.books_nf (id, title, author, published_year, isbn) VALUES (1903, ''중복 ISBN 도서'', ''테스트 저자'', 2026, ''ISBN-001'')', NULL),
            (15, '오류 4: 공백 이름', '실패',
                 'INSERT INTO public.members_nf (id, name, email, joined_at) VALUES (1904, ''   '', ''blank-name@example.com'', DATE ''2026-03-20'')', NULL),
            (16, '오류 5: 공백 제목', '실패',
                 'INSERT INTO public.books_nf (id, title, author, published_year, isbn) VALUES (1905, ''   '', ''테스트 저자'', 2026, ''ISBN-BLANK-001'')', NULL),
            (17, '오류 6A: 없는 회원 999', '실패',
                 'INSERT INTO public.loans_nf (id, member_id, book_id, borrowed_at, due_at, returned_at) VALUES (1906, 999, 201, DATE ''2026-04-10'', DATE ''2026-04-24'', DATE ''2026-04-12'')', NULL),
            (18, '오류 6B: 없는 도서 999', '실패',
                 'INSERT INTO public.loans_nf (id, member_id, book_id, borrowed_at, due_at, returned_at) VALUES (1910, 101, 999, DATE ''2026-04-10'', DATE ''2026-04-24'', DATE ''2026-04-12'')', NULL),
            (19, '오류 7: 반납예정일 < 대여일', '실패',
                 'INSERT INTO public.loans_nf (id, member_id, book_id, borrowed_at, due_at, returned_at) VALUES (1907, 101, 202, DATE ''2026-04-20'', DATE ''2026-04-10'', DATE ''2026-04-21'')', NULL),
            (20, '오류 8: 실제반납일 < 대여일', '실패',
                 'INSERT INTO public.loans_nf (id, member_id, book_id, borrowed_at, due_at, returned_at) VALUES (1908, 101, 202, DATE ''2026-04-20'', DATE ''2026-05-04'', DATE ''2026-04-10'')', NULL),
            (21, '오류 9: 도서 201 두 번째 미반납', '실패',
                 'INSERT INTO public.loans_nf (id, member_id, book_id, borrowed_at, due_at, returned_at) VALUES (1909, 101, 201, DATE ''2026-04-10'', DATE ''2026-04-24'', NULL)', NULL),
            (22, '오류 10: 대여 중인 회원 101 삭제', '실패',
                 'DELETE FROM public.members_nf WHERE id = 101', NULL)
        ) AS v(seq, test_name, expected, test_sql, cleanup_sql)
        ORDER BY seq
    LOOP
        BEGIN
            EXECUTE t.test_sql;
            INSERT INTO ch06_test_report VALUES (t.seq, t.test_name, t.expected, '성공', NULL, NULL, NULL);
            IF t.cleanup_sql IS NOT NULL THEN
                EXECUTE t.cleanup_sql;
            END IF;
        EXCEPTION WHEN OTHERS THEN
            GET STACKED DIAGNOSTICS
                v_state = RETURNED_SQLSTATE,
                v_constraint = CONSTRAINT_NAME,
                v_message = MESSAGE_TEXT;
            INSERT INTO ch06_test_report VALUES (t.seq, t.test_name, t.expected, '실패', v_state, v_constraint, v_message);
        END;
    END LOOP;
END
$$;

SELECT seq, test_name, expected, actual, sqlstate, constraint_name, message
FROM ch06_test_report
ORDER BY seq;

-- 테스트 후 기준 상태
SELECT (SELECT COUNT(*) FROM public.library_records_raw) AS raw,
       (SELECT COUNT(*) FROM public.members_nf) AS members,
       (SELECT COUNT(*) FROM public.books_nf) AS books,
       (SELECT COUNT(*) FROM public.loans_nf) AS loans,
       (SELECT COUNT(*) FROM public.loans_nf WHERE returned_at IS NULL) AS open_loans,
       (SELECT COUNT(*) FROM public.loans_nf l LEFT JOIN public.members_nf m ON l.member_id = m.id WHERE m.id IS NULL) AS orphan_member,
       (SELECT COUNT(*) FROM public.loans_nf l LEFT JOIN public.books_nf b ON l.book_id = b.id WHERE b.id IS NULL) AS orphan_book,
       (SELECT COUNT(*) FROM (SELECT book_id FROM public.loans_nf WHERE returned_at IS NULL GROUP BY book_id HAVING COUNT(*) > 1) d) AS active_duplicate;
