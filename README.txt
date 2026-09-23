LIM 사장님 로그인 기반 구축 - 1단계

1. Supabase > SQL Editor > New query
2. lim_store_owner_step1.sql 전체 붙여넣기
3. Run
4. Success가 나오면 여기로 돌아와 '성공'이라고 알려주세요.

이번 SQL이 하는 일
- 기존 store_inquiries를 삭제/초기화하지 않음
- 승인된 매장을 담을 lim_stores 테이블 추가
- 관리자 승인용 approve_store_inquiry() 추가
- 사장님 계정-매장 연결용 link_store_owner() 추가
- 로그인한 사장님이 자기 매장만 가져오는 get_my_store() 추가

중요
- 아직 GitHub에 SQL 파일을 올리지 마세요.
- 아직 관리자 페이지 버튼이나 사장님 로그인 화면은 바꾸지 않습니다.
- 비밀번호/service-role key를 코드에 넣지 않습니다.
- SQL 성공 확인 후 다음 단계에서 admin_stores.html에 승인 버튼을 연결합니다.
