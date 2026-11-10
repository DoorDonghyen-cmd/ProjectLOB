"""Create the illustrated delivery report from preserved originals and Godot captures."""
from pathlib import Path
from html import escape
import json
from PIL import Image
from reportlab.pdfgen import canvas
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.lib.colors import HexColor
from reportlab.lib.styles import ParagraphStyle
from reportlab.platypus import Paragraph

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / 'docs/qa/reports/assets/art_cohesion_2026-10-24'
WEAPONS = ROOT / '새-게임-프로젝트/assets/art/weapon_redesign_20261024'
OUT = ROOT / 'output/pdf/ORVASK_Art_Weapon_Report_2026-10-24.pdf'
OUT.parent.mkdir(parents=True, exist_ok=True)
pdfmetrics.registerFont(TTFont('KR', 'C:/Windows/Fonts/malgun.ttf'))
pdfmetrics.registerFont(TTFont('KRB', 'C:/Windows/Fonts/malgunbd.ttf'))
W,H=960,680
BG='#112127'; INK='#e4e3d1'; MUTED='#a5b7b2'; GOLD='#cdb482'; LINE='#354b50'
c=canvas.Canvas(str(OUT),pagesize=(W,H),pageCompression=1)
c.setTitle('ORVASK | 무기 적용과 도트 화풍 통합 | 2026-10-24')
c.setAuthor('ORVASK development review')
page=0
def text(value,x,y,size=12,color=INK,bold=False):
    c.setFillColor(HexColor(color));c.setFont('KRB' if bold else 'KR',size)
    c.drawString(x,H-y-size*.84,str(value))
def para(value,x,y,width,size=12,color=MUTED):
    style=ParagraphStyle('p',fontName='KR',fontSize=size,leading=size*1.55,textColor=HexColor(color),wordWrap='CJK')
    p=Paragraph(escape(value).replace('\n','<br/>'),style)
    _,height=p.wrap(width,H)
    assert y+height<H-35,(value[:50],y,height)
    p.drawOn(c,x,H-y-height)
    return height
def rule(y,x=32,width=896):
    c.setStrokeColor(HexColor(LINE));c.setLineWidth(.6);c.line(x,H-y,x+width,H-y)
def start(title,kicker='ART DIRECTION / LIVE BUILD'):
    global page
    if page:c.showPage()
    page+=1
    c.setFillColor(HexColor(BG));c.rect(0,0,W,H,fill=1,stroke=0)
    text('ORVASK',32,22,12,GOLD,True);text(kicker,142,24,9,MUTED)
    text('2026.10.24',856,23,10,MUTED)
    text(title,32,56,27,INK,True)
    rule(98)
    text('개발 검수 보고서 · 실제 Godot 화면 / 원본 보존',32,651,9,MUTED)
    text(f'{page:02}',902,648,12,GOLD)
    c.bookmarkPage(f'p{page}');c.addOutlineEntry(title,f'p{page}',0)
def picture(path,x,y,w,h,crop=None):
    path=Path(path)
    assert path.exists(),path
    iw,ih=Image.open(path).size
    if crop:
        sx,sy,sw,sh=crop
        scale=min(w/sw,h/sh)
        dw,dh=sw*scale,sh*scale
        xx=x+(w-dw)/2; yy=y+(h-dh)/2
        c.saveState();clip=c.beginPath();clip.rect(xx,H-yy-dh,dw,dh);c.clipPath(clip,stroke=0)
        c.drawImage(str(path),xx-sx*scale,H-yy-dh-(ih-sy-sh)*scale,iw*scale,ih*scale,mask='auto')
        c.restoreState()
    else:
        scale=min(w/iw,h/ih);dw,dh=iw*scale,ih*scale
        c.drawImage(str(path),x+(w-dw)/2,H-y-(h-dh)/2-dh,dw,dh,mask='auto')
def shot(name,x,y,w,h,crop=None):picture(ASSETS/name,x,y,w,h,crop)
def label(value,x,y):text(value,x,y,12,GOLD,True)

start('무기는 새롭게, 화풍은 같은 세계로','WEAPONS + PIXEL COHESION')
para('승인된 다섯 총기를 본편에 연결하고, 배경을 기준으로 무기와 배우의 도트 밀도·그림자를 정리했습니다.',32,112,860,15,INK)
shot('region2_after_1280.png',32,166,896,300,(0,70,1280,390))
for x,big,small in [(32,'5종','새 무기 아트·명칭·동작 적용'),(340,'35조합 × 6자세','복장 선택과 무기 파지 검수'),(650,'6,837 / 0','최종 기능 검사 / 실패')]:
    text(big,x,492,23,GOLD,True);text(small,x,530,12,MUTED)
para('이번 작업은 아트 적용과 표시 기준 통합, 리액터 규칙 연결까지입니다. 사람의 화풍 선호·장기 밸런스와 Galaxy 실기 검증은 구분해 남겼습니다.',32,579,880,12)

start('다섯 무기, 다섯 실루엣','ARSENAL / PRODUCTION')
items=[
('리벳','RIVET','single_latch_v1.png','한손 · 짧은 약실과 굵은 프레임','탄창4 / 열12 / 냉각8 / 재장전1턴'),
('래칫','RATCHET','burst_ratchet_v1.png','양손 · 후방 덮개와 짧은 탄창','같은 적3회 적중 추가 피해 · 탄창4'),
('스플린터','SPLINTER','scatter_splinter_v4.png','양손 · 원통형 세 총구, 회녹색 도장','무작위 분산 · 탄창5 / 열16'),
('리액터','REACTOR','heavy_reactor_v1.png','양손 · 청회색 방열 구조와 노심','과열 후1장 강행 · 탄창6 / 열14'),
('스파이크','SPIKE','amplifier_spike_v1.png','한손 · 길고 가는 총열, 중절식 장전','한 발 효과2배 · 처치 시 연속')]
for i,(ko,en,file,desc,stats) in enumerate(items):
    y=112+i*102
    text(ko,32,y+14,21,INK,True);text(en,33,y+46,10,MUTED)
    picture(WEAPONS/file,180,y+2,350,84)
    text(desc,558,y+18,13,GOLD,True);para(stats,558,y+49,360,12)
    if i<4:rule(y+96)

start('스플린터: 원통형은 유지하고 도색을 변경','BEFORE / AFTER')
label('형태 승인 v3 · 황토색',32,116);label('본편 v4 · 바랜 회녹색',502,116)
picture(WEAPONS/'scatter_splinter_v3.png',32,146,426,155)
picture(WEAPONS/'scatter_splinter_v4.png',502,146,426,155)
para('세 총구가 짧은 원통 안에 들어간 구조를 유지했습니다. 몸체 도색과 밝은 금속 점의 강도를 조정하고, 목재·천 감개는 재료의 차이로 남겼습니다.',32,317,896,13)
label('이전 본편 파지',32,383);label('신규 본편 파지',502,383)
shot('before/scatter_aim_1440.png',32,407,426,190,(60,135,120,110))
shot('after/scatter_aim_1440.png',502,407,426,190,(60,135,120,110))
text('같은 전투 자세의 화면 일부를 확대했습니다. 아래 비교에는 무기 형태와 표시 방식 변경이 함께 포함됩니다.',32,615,10,MUTED)

start('화풍 보정: 잔선은 줄이고 실루엣은 유지','CONTROLLED COMPARISON')
label('적 표시 보정 전',32,115);label('적 표시 보정 후',502,115)
for x,name in [(32,'region2_before_1280.png'),(502,'region2_after_1280.png')]:
    shot(name,x,141,426,145,(0,71,1280,390))
    shot(name,x,316,426,165,(705,240,540,175))
para('위아래 모두 동일 장면입니다. 무기·주인공은 두 그림에서 같으며, 기계 적의 표시 격자와 가장 어두운 경계만 비교합니다.',32,501,896,12)
para('작은 부품선은 약1.5px 화면 덩어리로 묶었습니다. 가장 어두운 윤곽은 청회색 그림자에 맞추고, 배경을 구분하는 실루엣은 유지했습니다. 블러나 일률적인 외곽선 확대는 사용하지 않았습니다.',32,552,896,13,INK)

start('같은 손 위치, 구별되는 총기와 동작','LIVE GRIP / MOTION')
shot('weapon_catalog.png',32,112,896,516,(0,70,1280,650))

start('장비 선택에서도 같은 밀도로','EQUIPMENT / TOUCH FLOW')
shot('equipment_scatter_1280.png',32,118,650,490)
label('확대 그림과 전투를 분리 검수',704,123)
para('장비 선택의 큰 총기는128열 기준으로 표시해 작은 부품 묘사가 인물보다 지나치게 선명하지 않도록 맞췄습니다.',704,159,224,13)
label('동일한 원화와 등록표',704,285)
para('손잡이·보조 손·총구·재장전 부품·발열 면을 한 곳에서 관리합니다. 추가 무기도 같은 경로로 연결할 수 있습니다.',704,320,224,13)
label('선택 → 시작 검증',704,451)
para('7개 복장 선택과5개 무기의 조합을 실제 시작 흐름으로 확인했습니다. 이전 등반 덮어쓰기 취소도 검증했습니다.',704,485,224,12)

start('각 구역의 빛 안에서도 같은 배우','REGIONAL CONTEXT')
for x,y,name,title,caption in [
 (32,118,'region1_after_1280.png','1구역 · 인간형','짙은 윤곽을 완화하되 무기와 자세를 구분'),
 (502,118,'region3_after_1280.png','3구역 · 정원','큰 생물의 색면과 도약 예고를 유지'),
 (32,367,'region4_after_1280.png','4구역 · 귀족 거주구','밝은 외부 배경에서 신규 무기 대비 확인'),
 (502,367,'region5_after_1280.png','5구역 · 중앙 통제구','차가운 실내 조명에서 실루엣 확인')]:
    label(title,x,y);shot(name,x,y+30,426,155,(0,71,1280,390));para(caption,x,y+192,426,11)
text('4~5구역의 전용 귀족·친위대 신규 몬스터 제작은 별도 후속입니다. 이번에는 기존 적 표시를 유지했습니다.',32,615,10,MUTED)

start('복장 변경 후에도 무기와 팔이 이어지도록','OUTFIT / 210 POSE CHECKS')
shot('outfit_matrix_aim.png',32,114,896,491,(0,616,1300,778))
text('신규4종의 조준 예시. 검사는 기본3종을 포함한7선택 ×5무기 ×6자세. 기본3종은 기존 전투 몸체를 공유합니다.',32,616,10,MUTED)

start('리액터: 과열을 한 발의 선택으로','NEW RUN RULE / LEGACY SAVE SAFE')
shot('reactor_heat_plan.png',32,115,650,490)
label('새 등반의 기본 수치',704,121)
para('탄창6 / 열 한계14\n일반 냉각8 / 재장전2턴',704,153,224,13,INK)
for y,title,body in [(228,'과열만 발생','강행할 탄이 없으면 강제 재장전3턴'),(320,'다음 탄1장 강행','여전히 과열이면 강제 재장전4턴'),(412,'강행 탄으로 냉각 성공','이번 사격 종료 · 남은 탄 보존\n강제 재장전 없음')]:
    label(title,704,y);para(body,704,y+30,224,12)
para('사격1턴은 별도입니다. 기존 저장은 이전 압쇄 능력과 수치를 유지하며, 새 등반부터 리액터를 사용합니다.',704,530,224,11)

start('실내와 UI는 판독성을 유지','REVIEWED / PRESERVED')
label('상점 · 파츠와 탄환',32,115);label('공방 · 작업대',502,115)
shot('place_shop_1280.png',32,144,426,300)
shot('place_workshop_1280.png',502,144,426,300)
para('실내 배경과 복장 레이어, 탄환·파츠·버튼은 현재 승인된 재질과 대비를 유지했습니다. 배우용 도트 처리로 문자나 상태 아이콘을 흐리게 만들지 않았습니다.',32,472,896,14,INK)
para('이번에 새로 생성한 원화는 스플린터 색 수정1장입니다. 다른 변경은 승인 원화의 본편 연결과 표시 방식 조정입니다. 상점·정비·보급·지도·타이틀을 확인했으며, 모든 화면을 새로 그린 작업으로 표현하지 않습니다.',32,553,896,12)

start('검증 결과와 남은 판단','FUNCTIONAL / VISUAL / HUMAN')
rows=[('리액터 규칙·예측·저장',152),('통합 UI · 세 화면 비율',436),('복장/무기6자세',210),('실제 배우 동작',509),('총기 발열·총구 잔상',100),('장비 선택·시작·저장 보호',544),('주조장 규칙·UI',2564),('정원 규칙·UI',1198),('비축 탄약 규칙',683),('전투 경로 탐색·재생',441)]
text('검사',32,116,12,GOLD,True);text('통과 / 실패',367,116,12,GOLD,True)
for i,(name,count) in enumerate(rows):
    y=150+i*31;text(name,32,y,12);text(f'{count:,} / 0',367,y,12,INK,True)
    rule(y+23,32,420)
text('총 6,837 / 0',32,482,25,GOLD,True)
label('동작과 화면',502,116)
para('실제 동작 2,977프레임에서 거리 순서·접지 오류는 0건입니다. 1280×900, 1008×630, 1440×630으로 확인했습니다. 전투는 본편의 1280×800 논리 화면 스케일을 유지합니다.',502,151,426,13)
label('균형을 확정한 것은 아닙니다',502,285)
para('20개 통제 전투 조건 중19개는 제한 탐색으로 승리 경로를 찾았습니다. 남은 리액터 보스 조건은 탐색 폭을 넓혀13턴/22장 사용으로 성공했습니다. 이 결과는 사람의 승률이 아닙니다.',502,321,426,13)
para('리액터의 탄약 소비가 높은 경향, 장기 빌드 효율, 새 화풍의 사용자 선호와 Galaxy 실기기 확인이 후속입니다.',502,463,426,13,INK)
text('격리된 저장만 사용했습니다. 중간 실패는 수정 후 재검증했으며 최종 집계에 반복 실행을 중복 합산하지 않았습니다.',32,613,10,MUTED)

start('확인할 화면과 다음 플레이','RETURN CHECK')
shot('title_1280.png',32,117,426,299);shot('place_map_1280.png',502,117,426,299)
label('바로 확인',32,447)
para('저장소의 PLAY.cmd → 새 등반 → 무기 선택.\nWEAPON_CONCEPTS.cmd에서는 본편5종의 자세와 표시 밀도를 비교할 수 있습니다.',32,482,426,13)
label('플레이에서 먼저 볼 것',502,447)
para('리액터의 강행 공격과 냉각 선택이 실제로 가치가 있는지, 탄약 부담이 지나치지 않은지. 총기와 몬스터가 배경과 어울리면서도 작은 화면에서 구별되는지 확인하면 됩니다.',502,482,426,13)
text('소스·프롬프트·원본·검증 캡처는 프로젝트에 보존했습니다. APK 및 Git 커밋/푸시는 이번 요청에 포함하지 않았습니다.',32,612,10,MUTED)
c.save()
print(json.dumps({'pdf':str(OUT),'pages':page,'bytes':OUT.stat().st_size},ensure_ascii=False))
