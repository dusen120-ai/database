-- Chapter 08 답안 작성용 조회 모음 (데이터를 변경하지 않음)
-- 섹션 번호는 assignments/chapter08/chapter08_answer.md와 같습니다.

\echo '=== 3-1 신청 한 건마다 학생·강의'
SELECT e.id AS enrollment_id, s.name AS student_name, c.title AS course_title, e.status
FROM course_project.enrollments AS e
INNER JOIN course_project.students AS s ON e.student_id = s.id
INNER JOIN course_project.courses AS c ON e.course_id = c.id
ORDER BY e.id;

\echo '=== 3-2 학생·강의·강사'
SELECT e.id AS enrollment_id, s.name AS student_name, c.title AS course_title,
       i.name AS instructor_name, e.status, e.recorded_amount
FROM course_project.enrollments AS e
INNER JOIN course_project.students AS s ON e.student_id = s.id
INNER JOIN course_project.courses AS c ON e.course_id = c.id
INNER JOIN course_project.instructors AS i ON c.instructor_id = i.id
ORDER BY e.id;

\echo '=== 4-1, 4-2 강의별 취소 제외 신청 (COUNT 비교)'
SELECT c.id AS course_id, c.title,
       COUNT(*) AS count_star,
       COUNT(e.id) AS count_enrollment,
       COUNT(DISTINCT e.student_id) AS count_student,
       COALESCE(SUM(e.recorded_amount), 0) AS recorded_amount
FROM course_project.courses AS c
LEFT JOIN course_project.enrollments AS e
    ON c.id = e.course_id
   AND e.status <> '취소'
GROUP BY c.id, c.title
ORDER BY c.id;

\echo '=== 5-1 조건을 ON에'
SELECT s.id, s.name, COUNT(e.id) AS non_cancelled_count
FROM course_project.students AS s
LEFT JOIN course_project.enrollments AS e
    ON s.id = e.student_id
   AND e.status <> '취소'
GROUP BY s.id, s.name
ORDER BY s.id;

\echo '=== 5-2 조건을 WHERE에'
SELECT s.id, s.name, COUNT(e.id) AS non_cancelled_count
FROM course_project.students AS s
LEFT JOIN course_project.enrollments AS e
    ON s.id = e.student_id
WHERE e.status <> '취소'
GROUP BY s.id, s.name
ORDER BY s.id;

\echo '=== 6 방법 1 LEFT JOIN IS NULL'
SELECT s.id, s.name
FROM course_project.students AS s
LEFT JOIN course_project.enrollments AS e
    ON s.id = e.student_id
   AND e.status <> '취소'
WHERE e.id IS NULL
ORDER BY s.id;

\echo '=== 6 방법 2 NOT EXISTS'
SELECT s.id, s.name
FROM course_project.students AS s
WHERE NOT EXISTS (
    SELECT 1
    FROM course_project.enrollments AS e
    WHERE e.student_id = s.id
      AND e.status <> '취소'
)
ORDER BY s.id;

\echo '=== 7 기본 집계 (범위별 건수·금액·평균)'
SELECT '전체' AS scope, COUNT(*) AS cnt, SUM(recorded_amount) AS amount, ROUND(AVG(recorded_amount), 2) AS avg_amount
FROM course_project.enrollments
UNION ALL
SELECT '활성', COUNT(*), SUM(recorded_amount), ROUND(AVG(recorded_amount), 2)
FROM course_project.enrollments WHERE status IN ('신청', '수강중')
UNION ALL
SELECT '취소 제외', COUNT(*), SUM(recorded_amount), ROUND(AVG(recorded_amount), 2)
FROM course_project.enrollments WHERE status <> '취소'
UNION ALL
SELECT '취소', COUNT(*), SUM(recorded_amount), ROUND(AVG(recorded_amount), 2)
FROM course_project.enrollments WHERE status = '취소';

\echo '=== 8-1 상태별 건수'
SELECT status, COUNT(*) AS enrollment_count
FROM course_project.enrollments
GROUP BY status
ORDER BY CASE status WHEN '신청' THEN 1 WHEN '수강중' THEN 2 WHEN '완료' THEN 3 WHEN '취소' THEN 4 END;

\echo '=== 8-1 FILTER로 한 행에'
SELECT COUNT(*) AS total_count,
       COUNT(*) FILTER (WHERE status = '신청') AS requested,
       COUNT(*) FILTER (WHERE status = '수강중') AS learning,
       COUNT(*) FILTER (WHERE status = '완료') AS completed,
       COUNT(*) FILTER (WHERE status = '취소') AS cancelled
FROM course_project.enrollments;

\echo '=== 8-3 HAVING 취소 제외 2건 이상 강의'
SELECT c.id, c.title, COUNT(e.id) AS enrollment_count
FROM course_project.courses AS c
JOIN course_project.enrollments AS e ON c.id = e.course_id
WHERE e.status <> '취소'
GROUP BY c.id, c.title
HAVING COUNT(e.id) >= 2
ORDER BY c.id;

\echo '=== 9-1 잘못된 강사별 가격 합계 (신청까지 JOIN)'
SELECT i.id AS instructor_id, i.name, SUM(c.price) AS wrong_price_sum
FROM course_project.instructors AS i
JOIN course_project.courses AS c ON i.id = c.instructor_id
JOIN course_project.enrollments AS e ON c.id = e.course_id
GROUP BY i.id, i.name
ORDER BY i.id;

\echo '=== 9-2 올바른 강사별 가격 합계 (강의 수준)'
SELECT i.id AS instructor_id, i.name, COUNT(c.id) AS course_count, COALESCE(SUM(c.price), 0) AS price_sum
FROM course_project.instructors AS i
LEFT JOIN course_project.courses AS c ON i.id = c.instructor_id
GROUP BY i.id, i.name
ORDER BY i.id;

\echo '=== 9-3 JOIN 뒤 강사 201의 강의가 반복되는 모습'
SELECT c.id AS course_id, c.title, c.price, e.id AS enrollment_id, e.status
FROM course_project.courses AS c
JOIN course_project.enrollments AS e ON c.id = e.course_id
WHERE c.instructor_id = 201
ORDER BY c.id, e.id;

\echo '=== 10-1 강의 302 상세 (취소 제외)'
SELECT e.id AS enrollment_id, s.name AS student_name, e.status, e.recorded_amount
FROM course_project.enrollments AS e
JOIN course_project.students AS s ON e.student_id = s.id
WHERE e.course_id = 302
  AND e.status <> '취소'
ORDER BY e.id;

\echo '=== 10-2 강의 302 집계 (취소 제외)'
SELECT COUNT(*) AS enrollment_count, SUM(recorded_amount) AS recorded_amount
FROM course_project.enrollments
WHERE course_id = 302
  AND status <> '취소';
