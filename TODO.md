# 추적손절매 알림 (dont-stock) TODO

> 스펙: 한국 주식 / 매수일 이후 **종가 기준 고점 대비 -10%** 도달 시 **Gmail** 알림
> 진행하면서 `- [ ]` → `- [x]` 로 체크

## Phase 0. 로컬 n8n 띄우기
- [x] Docker 설치 확인
- [x] `docker-compose.yml`, `.env.example` 작성
- [x] `cp .env.example .env` 후 `N8N_ENCRYPTION_KEY` 채우기 (`openssl rand -hex 32`)
- [x] `docker compose up -d` → http://localhost:5678 접속 (n8n 2.12.2, Asia/Seoul)
- [x] n8n 오너 계정 생성

## Phase 1. Gmail 알림
> 2026-10-19: 현재 네트워크에서 api.telegram.org 차단 확인 → Telegram 대신 Gmail(SMTP)로 변경
- [x] 네트워크 확인: smtp.gmail.com 465/587, Yahoo 시세 API 접속 가능
- [x] Google 계정 2단계 인증 켜기
- [x] 앱 비밀번호 발급 (https://myaccount.google.com/apppasswords)
- [x] `.env` 에 `GMAIL_ADDRESS`, `GMAIL_APP_PASSWORD`, `ALERT_TO` 입력 (SMTP 로그인 확인)
- [x] n8n에 SMTP credential 등록 (`Gmail SMTP`)
- [x] 테스트 워크플로우(Manual Trigger → Send Email)로 메일 수신 확인

## Phase 2. 종목 시트 (Google Sheets, 서비스 계정 방식)
- [x] Google Cloud 프로젝트 준비 (기존 프로젝트 `investment-j` 재사용)
- [x] Google Sheets API, Google Drive API 사용 설정
- [x] 서비스 계정 생성 → JSON 키 다운로드 → `secrets/gcp-sa.json` 에 저장
- [x] 시트 생성 후 서비스 계정 이메일에 **편집자** 공유
- [x] 헤더 작성: `ticker | name | buy_date | status | peak_close | peak_date | last_close | drawdown | alerted_at | note`
- [x] n8n에 Google Service Account credential 등록
- [x] 테스트 종목 입력 (`005930.KS 삼성전자(테스트)`)
- [x] n8n `[TEST] 시트 읽기 테스트` 실행 → 1행 읽히는지 확인

## Phase 3. 메인 워크플로우 (`추적손절 알림`, [workflows/trailing-stop.json](workflows/trailing-stop.json))
- [x] Schedule Trigger: 월~금 16:30 (+ 테스트용 Manual Trigger)
- [x] Google Sheets: Get rows (`status = active`)
- [x] Prepare: ticker 정리, buy_date 파싱
- [x] HTTP Request: Yahoo chart API (매수일 ~ 오늘, 1d, 재시도 3회)
- [x] Calculate: 고점 / 최근 종가 / 하락률 계산 (기준 `THRESHOLD = -0.10`)
- [x] Update metrics: 시트에 peak/last/drawdown/note 기록
- [x] IF: 하락률 ≤ -10% AND `alerted_at` 비어있음 → 메일 발송 → `alerted_at` 기록
- [x] 워크플로우 JSON을 `workflows/` 에 저장
- [x] UI에서 수동 실행 테스트 (삼성전자 샘플 -23.64% → 알림 메일 1통, 시트 갱신 확인)
- [x] 재실행 시 중복 메일 안 오는지 확인
- [ ] ~~샘플 행 삭제, 실제 보유 종목 입력~~ → Phase 3-2 이후로
- [ ] ~~워크플로우 Publish(활성화)~~ → Phase 3-2 이후로

## Phase 3-2. 한국투자증권(KIS) Open API 전환
> 2026-10-19 결정: **종가 기준 확정 알림만** (평일 15:35). 예비(15:00) 알림은 검토 후 제외
> 알림 받으면 시간외 종가(15:40~16:00) / 시간외 단일가(~18:00)로 당일 매도
- [x] 네트워크 확인: KIS 실전/모의 도메인 접속 가능 (현재 와이파이)
- [x] 한국투자증권 계좌 준비
- [x] KIS Developers 에서 API 신청 → APP KEY / APP SECRET 발급 (모의투자 키)
- [x] `.env` 에 `KIS_APP_KEY`, `KIS_APP_SECRET`, `KIS_ENV` 입력
- [x] 토큰 발급 + 일봉 조회 테스트 (삼성전자, 모의투자 도메인 OK)
- [x] 워크플로우 수정: Yahoo → KIS, 스케줄 평일 15:35
- [x] 장 마감 전 수동 실행 시 오늘(장중) 가격 제외 → 항상 확정 종가만 사용
- [x] 계산 로직 시뮬레이션 + UI 실행 테스트 (알림 메일 / 중복 방지)
- [x] 모의투자 키 유지 결정 (2026-10-19)
- [ ] 2026-10-20 오전: KIS 모의 일봉의 10/19 종가가 218,000(Yahoo) 또는 218,500(KIS 일별시세)으로 고정됐는지 확인
  - 고정 안 되거나 차이 크면 → 실전 키로 전환 검토
- [x] 샘플 행 삭제, 실제 보유 종목 5개 입력 (초기 고점은 매수일부터 전체 종가로 계산해 기록)
- [x] 모의투자 초당 호출 한도(EGW00201) 대응: KIS 호출 간격 1.1초
- [x] 알림 방식 변경: 손절권만 → **매일 전 종목 요약 메일 1통** (일간 등락률, 고점대비, 손절가 여유, 손절권 진입일 표시)
- [x] 시트 열 변경: `day_change` 추가, `alerted_at` → `breach_since`
- [x] 실제 5종목 데이터로 시뮬레이션
- [x] UI 실행 → 요약 메일 확인
- [x] 손익 추가: 시트에 `account`(일반/연금), `qty`, `avg_price` 입력 → 종목별 평가금액·매입금액·평가손익·수익률, 계좌별 소계, 전체 합계, 오늘 변동
- [x] 가상 수량으로 손익 계산 시뮬레이션 (합계 검산 OK)
- [x] 실제 계좌/수량/평균단가 입력
- [ ] UI 실행 → 손익 포함 요약 메일 확인
- [x] 워크플로우 Publish(활성화) — 2026-10-26 (그 전엔 미활성 + 10/22~10/26 n8n 꺼져 있어 자동 발송 없었음)

## Phase 4. 운영 안정화
- [x] Error Workflow 설정 (`실패 알림`, 메인 워크플로우에 연결)
- [ ] (선택) 일일 요약: 전체 종목 현재 하락률을 한 메시지로
- [ ] (선택) 폼 입력: n8n Form Trigger → 시트 Append
- [ ] 상시 구동 환경으로 이전 (**Google Cloud e2-micro**, 2026-10-26 Oracle 대신 결정) — 맥이 잠들거나 회사망이면 스케줄 누락됨
  - [x] SSH 키 생성 (`~/.ssh/oracle_n8n`)
  - [x] GCP 결제 계정 연결 + Compute Engine API 사용 설정
  - [x] VM 생성: e2-micro / us-central1 / Ubuntu 24.04 Minimal / 표준 영구 디스크 30GB / 스냅샷 없음 → 외부 IP는 `~/.ssh/config` 참조 (ssh 별칭 `dont-stock`, 사용자 `n8n`)
  - [x] 예상 비용 확인 (콘솔 정가 표시 $6.11, 무료 등급으로 차감 예정)
  - [ ] 1주 후 결제 → 보고서에서 실제 청구 0원 확인 (외부 IPv4 과금 여부 포함)
  - [x] 서버 세팅: Docker 29.9, swap 2GB, 타임존 Asia/Seoul
  - [x] 로컬 n8n 데이터(워크플로우·credential·실행기록) 백업 → 서버 복원
  - [x] 서버에서 실행 확인: 2026-10-26 15:35 정기 실행 성공, 시트 8행 갱신 (KIS/Google/Gmail/Telegram 모두 접속 가능)
  - [x] 로컬 n8n 중지 (중복 발송 방지)
  - [x] 서버 내부 전용 실행 웹훅 추가: `ssh dont-stock 'curl -X POST localhost:5678/webhook/dont-stock-run'` → 즉시 리포트 발송
  - [x] 계좌 드롭다운에 ISA 추가, 리포트 계좌 순서 일반 → ISA → 연금
  - [x] 기준점 재설정: 시트 `track_from` 열 추가, 2026-10-26 종가부터 고점 재추적 (고점 추적 시작 = max(buy_date, track_from))
  - [x] 메일 개선 (2026-10-28): 상단 코스피 카드(지수·일간 등락·1개월 추이 그래프, KIS 업종 일봉 `FHKUP03500100` + QuickChart 이미지), 연금 계좌 소분류(시트 `sub_account` 열: IRP/퇴직연금/연금저축)별 묶음+소계. 요약 표 분류는 그대로
  - [x] 메일 디자인 개편 (2026-10-28): 모바일 우선 카드형. 종합 카드(총액·오늘/누적·계좌 도넛·계좌 표) → 손절 상태 배너 → 코스피 → 계좌별 카드(같은 형식 + 고점대비 열, 연금은 소분류 도넛). 제목: `오늘 +금액 (+%)`
  - [x] 서버 배포 (import → publish → 재시작) + 웹훅 발송 확인 (2026-10-28 16:32)
  - [ ] 맥에서 SSH 터널로 n8n 편집: `ssh -N dont-stock` 실행 후 http://localhost:5678

## Phase 4-2. 투자 원칙 반영 (선택)
- [ ] 계좌별 성격/규칙 정리 (연금=장기·리밸런싱, ISA=중기, 일반=추세)
- [ ] 종목별 손절 폭 `stop_pct` 열 (변동성에 맞게)
- [ ] 원금 대비 손실 한도 경고
- [ ] 리포트에 종목·업종 비중 + 한도 초과 경고 (현재 반도체 대형주 비중 약 80%)
- [ ] 손절선 직전 '주의' 구간 표시

## Phase 5. LLM 연동 (선택)
- [ ] 용도 결정 (알림 메시지에 해당 종목 최근 뉴스 요약 첨부 등)
- [ ] 무료 모델 credential 등록 (Google Gemini API 무료 등급)
- [ ] 알림 분기(true)에만 LLM 노드 연결 → 호출 횟수 최소화
