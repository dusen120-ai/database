-- Chapter 08 전체 실행 (저장소 루트에서 psql -f 로 실행)
-- 오류가 나면 바로 멈추고, course_project 데이터는 변경하지 않습니다.
\set ON_ERROR_STOP on
\pset pager off

\echo '########## 환경'
SELECT current_database(), current_user, version();

\echo '########## 00_check_course_project.sql'
\ir 00_check_course_project.sql

\echo '########## my_chapter08_answers.sql'
\ir my_chapter08_answers.sql

\echo '########## 03_join_aggregation_validation.sql'
\ir 03_join_aggregation_validation.sql

\echo '########## my_cafe_questions.sql'
\ir my_cafe_questions.sql

\echo '########## 끝까지 실행됨'
