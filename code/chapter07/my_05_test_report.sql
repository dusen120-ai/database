-- Chapter 07. 05 테스트 결과를 한 표로 모아 보는 개인 실습 파일
-- 시작 상태: 01 → 02 → 03 → 04 실행 완료 (최종 3/2/3/5행)
-- 각 테스트를 BEGIN ... EXCEPTION 블록 안에서 따로 실행하므로, 실패한 테스트는 그 문장만 취소되고 다음 테스트로 넘어갑니다.
-- 경계 테스트는 성공 여부를 기록한 뒤 임시 행을 바로 삭제합니다.
-- 결과는 세션 임시 테이블(pg_temp)에만 저장되며 연결을 닫으면 사라집니다.
-- 실행: 전체 실행(⌥X) 후 마지막 두 SELECT 결과를 확인합니다.

DROP TABLE IF EXISTS ch07_test_report;
CREATE TEMP TABLE ch07_test_report (
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
            (1,  '경계 A: 무료 강의 price=0, description=NULL, recorded_amount=0', '성공',
                 'INSERT INTO course_project.courses (id, instructor_id, title, description, level, price, opened_at) VALUES (1801, 202, ''무료 체험 강의'', NULL, ''basic'', 0, DATE ''2026-05-01''); '
              || 'INSERT INTO course_project.enrollments (id, student_id, course_id, enrolled_at, status, recorded_amount) VALUES (1802, 103, 1801, DATE ''2026-05-02'', ''신청'', 0)',
                 'DELETE FROM course_project.enrollments WHERE id = 1802; DELETE FROM course_project.courses WHERE id = 1801'),
            (10, '오류 0: 학생 이름 NULL', '실패',
                 'INSERT INTO course_project.students (id, name, email, joined_at) VALUES (1900, NULL, ''null-name@example.com'', DATE ''2026-03-20'')', NULL),
            (11, '오류 1: 학생 이메일 중복', '실패',
                 'INSERT INTO course_project.students (id, name, email, joined_at) VALUES (1901, ''중복 학생'', ''minji@example.com'', DATE ''2026-03-20'')', NULL),
            (12, '오류 2: 강사 이메일 중복', '실패',
                 'INSERT INTO course_project.instructors (id, name, email, specialty) VALUES (1902, ''중복 강사'', ''gilbert@example.com'', ''Database'')', NULL),
            (13, '오류 3: 없는 강사 999 참조', '실패',
                 'INSERT INTO course_project.courses (id, instructor_id, title, description, level, price, opened_at) VALUES (1903, 999, ''없는 강사 강의'', NULL, ''basic'', 10000, DATE ''2026-05-01'')', NULL),
            (14, '오류 4: 난이도 expert', '실패',
                 'INSERT INTO course_project.courses (id, instructor_id, title, description, level, price, opened_at) VALUES (1904, 201, ''잘못된 난이도'', NULL, ''expert'', 10000, DATE ''2026-05-01'')', NULL),
            (15, '오류 5: 강의 가격 -1', '실패',
                 'INSERT INTO course_project.courses (id, instructor_id, title, description, level, price, opened_at) VALUES (1905, 201, ''잘못된 가격'', NULL, ''basic'', -1, DATE ''2026-05-01'')', NULL),
            (16, '오류 6: 신청 상태 대기', '실패',
                 'INSERT INTO course_project.enrollments (id, student_id, course_id, enrolled_at, status, recorded_amount) VALUES (1906, 101, 303, DATE ''2026-05-02'', ''대기'', 150000)', NULL),
            (17, '오류 7: recorded_amount -1', '실패',
                 'INSERT INTO course_project.enrollments (id, student_id, course_id, enrolled_at, status, recorded_amount) VALUES (1907, 101, 303, DATE ''2026-05-02'', ''신청'', -1)', NULL),
            (18, '오류 8: 없는 학생 999 참조', '실패',
                 'INSERT INTO course_project.enrollments (id, student_id, course_id, enrolled_at, status, recorded_amount) VALUES (1908, 999, 303, DATE ''2026-05-02'', ''신청'', 150000)', NULL),
            (19, '오류 9: 없는 강의 999 참조', '실패',
                 'INSERT INTO course_project.enrollments (id, student_id, course_id, enrolled_at, status, recorded_amount) VALUES (1909, 101, 999, DATE ''2026-05-02'', ''신청'', 150000)', NULL),
            (20, '오류 10: 학생101·강의302 두 번째 활성 신청', '실패',
                 'INSERT INTO course_project.enrollments (id, student_id, course_id, enrolled_at, status, recorded_amount) VALUES (1910, 101, 302, DATE ''2026-05-03'', ''수강중'', 120000)', NULL),
            (21, '오류 11: 신청 이력 있는 학생 101 삭제', '실패',
                 'DELETE FROM course_project.students WHERE id = 101', NULL),
            (22, '오류 12: 강의 담당 강사 201 삭제', '실패',
                 'DELETE FROM course_project.instructors WHERE id = 201', NULL)
        ) AS v(seq, test_name, expected, test_sql, cleanup_sql)
        ORDER BY seq
    LOOP
        BEGIN
            EXECUTE t.test_sql;
            INSERT INTO ch07_test_report VALUES (t.seq, t.test_name, t.expected, '성공', NULL, NULL, NULL);
            IF t.cleanup_sql IS NOT NULL THEN
                EXECUTE t.cleanup_sql;
            END IF;
        EXCEPTION WHEN OTHERS THEN
            GET STACKED DIAGNOSTICS
                v_state = RETURNED_SQLSTATE,
                v_constraint = CONSTRAINT_NAME,
                v_message = MESSAGE_TEXT;
            INSERT INTO ch07_test_report VALUES (t.seq, t.test_name, t.expected, '실패', v_state, v_constraint, v_message);
        END;
    END LOOP;
END
$$;

SELECT seq, test_name, expected, actual, sqlstate, constraint_name, message
FROM ch07_test_report
ORDER BY seq;

-- 테스트 후 기준 상태
SELECT (SELECT COUNT(*) FROM course_project.students) AS students,
       (SELECT COUNT(*) FROM course_project.instructors) AS instructors,
       (SELECT COUNT(*) FROM course_project.courses) AS courses,
       (SELECT COUNT(*) FROM course_project.enrollments) AS enrollments,
       (SELECT SUM(recorded_amount) FROM course_project.enrollments) AS total_recorded,
       (SELECT SUM(recorded_amount) FROM course_project.enrollments WHERE status <> '취소') AS non_cancelled_recorded,
       (SELECT COUNT(*) FROM (SELECT student_id, course_id FROM course_project.enrollments
                              WHERE status IN ('신청', '수강중')
                              GROUP BY student_id, course_id HAVING COUNT(*) > 1) d) AS active_duplicate;
