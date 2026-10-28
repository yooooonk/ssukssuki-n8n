# ssukssuki-n8n

보유 종목의 **종가 기준 추적손절(고점 대비 -10%)** 을 매일 확인하고 요약 메일을 보내는 n8n 워크플로우.

- 평일 15:35 실행: Google Sheets 종목 목록 → 한국투자증권(KIS) Open API 일봉 → 고점·하락률·손익 계산 → 시트 갱신 → Gmail 요약 메일
- 메일: 총 평가금액·계좌별 도넛, 손절 상태, 코스피 1개월 추이, 계좌별(연금은 IRP/퇴직연금/연금저축) 종목 표

## 구성

| 경로 | 내용 |
|---|---|
| `docker-compose.yml` | n8n 실행 (포트는 127.0.0.1 에만 열림) |
| `.env.example` | 필요한 환경 변수. `cp .env.example .env` 후 채우기 |
| `workflows/` | n8n 워크플로우 JSON. 개인 값은 `__SHEET_ID__` 등 자리표시자 |
| `scripts/workflow.sh` | 자리표시자를 `.env` 값으로 채워 서버에 배포 / 서버에서 내보내기 |
| `TODO.md` | 진행 기록 |

`.env`, `secrets/`(Google 서비스 계정 키)는 git 에 올리지 않는다.

## 사용

```bash
cp .env.example .env            # 값 채우기
docker compose up -d            # n8n 실행

scripts/workflow.sh deploy workflows/trailing-stop.json   # 서버에 배포 (import → publish → 재시작)
scripts/workflow.sh export                                # 서버 → workflows/ (개인 값은 자리표시자로)
```

credential(KIS, Google 서비스 계정, Gmail SMTP)은 n8n UI 에서 등록한다.
