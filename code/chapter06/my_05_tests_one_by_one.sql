-- Chapter 06. 05 테스트를 하나씩 실행하기 위한 개인 실습 파일
-- 원본: 05_integrity_tests.sql (주석을 풀어 문장별로 정리)
-- 사용법: 커서를 문장 안에 두고 ⌘+Enter(Execute SQL statement)로 한 문장씩 실행합니다.
-- 경계 테스트는 성공 후 바로 아래 DELETE로 임시 행을 지웁니다.
-- 오류 테스트는 오류가 나야 성공입니다. Auto-commit이므로 ROLLBACK은 필요 없습니다.

-- [경계 A] 같은 날 대여·반납 (due_at = borrowed_at, returned_at = borrowed_at)
INSERT INTO public.books_nf (id, title, author, published_year, isbn)
VALUES (1800, '경계값 테스트 도서', '테스트 저자', 2026, 'ISBN-BND-LOAN-001');

INSERT INTO public.loans_nf (id, member_id, book_id, borrowed_at, due_at, returned_at)
VALUES (1801, 101, 1800, DATE '2026-05-01', DATE '2026-05-01', DATE '2026-05-01');

DELETE FROM public.loans_nf WHERE id = 1801;

DELETE FROM public.books_nf WHERE id = 1800;

-- [경계 B] published_year = NULL
INSERT INTO public.books_nf (id, title, author, published_year, isbn)
VALUES (1802, '연도 미상 도서', '익명', NULL, 'ISBN-BOUNDARY-001');

DELETE FROM public.books_nf WHERE id = 1802;

-- [경계 C] 공백이 아닌 한 글자 이름
INSERT INTO public.members_nf (id, name, email, joined_at)
VALUES (1803, '김', 'one-char@example.com', DATE '2026-03-20');

DELETE FROM public.members_nf WHERE id = 1803;

-- [오류 1] 필수값 NULL (NOT NULL)
INSERT INTO public.members_nf (id, name, email, joined_at)
VALUES (1901, NULL, 'null-name@example.com', DATE '2026-03-20');

-- [오류 2] 이메일 중복 (uq_members_nf_email)
INSERT INTO public.members_nf (id, name, email, joined_at)
VALUES (1902, '중복 이메일 회원', 'junho@example.com', DATE '2026-03-20');

-- [오류 3A] ISBN NULL (NOT NULL)
INSERT INTO public.books_nf (id, title, author, published_year, isbn)
VALUES (1912, 'ISBN 없음 도서', '테스트 저자', 2026, NULL);

-- [오류 3B] ISBN 중복 (uq_books_nf_isbn)
INSERT INTO public.books_nf (id, title, author, published_year, isbn)
VALUES (1903, '중복 ISBN 도서', '테스트 저자', 2026, 'ISBN-001');

-- [오류 4] 공백 이름 (chk_members_nf_name_not_blank)
INSERT INTO public.members_nf (id, name, email, joined_at)
VALUES (1904, '   ', 'blank-name@example.com', DATE '2026-03-20');

-- [오류 5] 공백 제목 (chk_books_nf_title_not_blank)
INSERT INTO public.books_nf (id, title, author, published_year, isbn)
VALUES (1905, '   ', '테스트 저자', 2026, 'ISBN-BLANK-001');

-- [오류 6A] 존재하지 않는 회원 (fk_loans_nf_member)
INSERT INTO public.loans_nf (id, member_id, book_id, borrowed_at, due_at, returned_at)
VALUES (1906, 999, 201, DATE '2026-04-10', DATE '2026-04-24', DATE '2026-04-12');

-- [오류 6B] 존재하지 않는 도서 (fk_loans_nf_book)
INSERT INTO public.loans_nf (id, member_id, book_id, borrowed_at, due_at, returned_at)
VALUES (1910, 101, 999, DATE '2026-04-10', DATE '2026-04-24', DATE '2026-04-12');

-- [오류 7] 반납예정일이 대여일보다 이전 (chk_loans_nf_due_date)
INSERT INTO public.loans_nf (id, member_id, book_id, borrowed_at, due_at, returned_at)
VALUES (1907, 101, 202, DATE '2026-04-20', DATE '2026-04-10', DATE '2026-04-21');

-- [오류 8] 실제반납일이 대여일보다 이전 (chk_loans_nf_returned_date)
INSERT INTO public.loans_nf (id, member_id, book_id, borrowed_at, due_at, returned_at)
VALUES (1908, 101, 202, DATE '2026-04-20', DATE '2026-05-04', DATE '2026-04-10');

-- [오류 9] 같은 도서의 두 번째 미반납 대여 (uq_loans_nf_active_book)
INSERT INTO public.loans_nf (id, member_id, book_id, borrowed_at, due_at, returned_at)
VALUES (1909, 101, 201, DATE '2026-04-10', DATE '2026-04-24', NULL);

-- [오류 10] 참조 중인 부모 삭제 (fk_loans_nf_member, RESTRICT)
DELETE FROM public.members_nf WHERE id = 101;

-- [기준 상태 재검증] 이 아래는 05_integrity_tests.sql 마지막 부분을 실행하거나 다음 한 줄로 확인합니다.
SELECT (SELECT COUNT(*) FROM public.library_records_raw) AS raw,
       (SELECT COUNT(*) FROM public.members_nf) AS members,
       (SELECT COUNT(*) FROM public.books_nf) AS books,
       (SELECT COUNT(*) FROM public.loans_nf) AS loans,
       (SELECT COUNT(*) FROM public.loans_nf WHERE returned_at IS NULL) AS open_loans,
       (SELECT COUNT(*) FROM public.loans_nf l LEFT JOIN public.members_nf m ON l.member_id = m.id WHERE m.id IS NULL) AS orphan_member,
       (SELECT COUNT(*) FROM public.loans_nf l LEFT JOIN public.books_nf b ON l.book_id = b.id WHERE b.id IS NULL) AS orphan_book,
       (SELECT COUNT(*) FROM (SELECT book_id FROM public.loans_nf WHERE returned_at IS NULL GROUP BY book_id HAVING COUNT(*) > 1) d) AS active_duplicate;
