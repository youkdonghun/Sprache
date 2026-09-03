import { createHash } from 'node:crypto';
import { mkdir, readFile, writeFile } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const outputDirectory = path.join(root, 'exam-packs', 'packs');
const outputPath = path.join(outputDirectory, 'sprache-business-english-practice-1.json');
const catalogPath = path.join(root, 'exam-packs', 'catalog.json');
const check = process.argv.includes('--check');

const stimuli = [];
const questions = [];

function addStimulus(value) {
  stimuli.push(value);
  return value.id;
}

function rotatedChoices(correct, distractors, position) {
  const values = [...distractors];
  values.splice(position, 0, correct);
  return values;
}

function addQuestion({ id, part, prompt, correct, distractors, explanation, skill, stimulusId, difficulty = 'intermediate', correctIndex = 0 }) {
  const expected = part === 2 ? 3 : 4;
  if (distractors.length !== expected - 1) throw new Error(`${id}: invalid distractor count`);
  const position = correctIndex % expected;
  const choices = rotatedChoices(correct, distractors, position);
  questions.push({
    id,
    part,
    prompt,
    choices,
    correctIndex: position,
    explanation,
    choiceExplanations: choices.map((choice, index) =>
      index === position
        ? `정답입니다. ${explanation}`
        : `“${choice}”은(는) 질문이나 지문의 핵심 근거와 맞지 않습니다.`,
    ),
    skill,
    difficulty,
    ...(stimulusId ? { stimulusId } : {}),
  });
}

const photoScenes = [
  ['회의실', '두 직원이 회의실 탁자 위의 서류를 함께 살펴보고 있다.', 'Two coworkers are reviewing documents at a conference table.', ['The chairs are being stacked outside.', 'A man is repairing a window.', 'The room is completely empty.']],
  ['기차역', '여행객 한 명이 전광판을 확인하며 여행 가방 손잡이를 잡고 있다.', 'A traveler is checking a departure board.', ['Several passengers are boarding a ship.', 'A suitcase is being weighed at a counter.', 'The display screen has been removed.']],
  ['식당', '종업원이 야외 테이블에 접시를 놓고 있다.', 'A server is placing dishes on an outdoor table.', ['The customers are washing the dishes.', 'The tables have been folded for storage.', 'A chef is painting a wall.']],
  ['창고', '작업자가 선반에 상자를 정리하고 있다.', 'A worker is arranging boxes on a shelf.', ['A delivery truck is leaving the warehouse.', 'The shelves are being taken apart.', 'Some boxes are floating in water.']],
  ['사무실', '한 여성이 책상에서 헤드셋을 끼고 전화 통화를 하고 있다.', 'A woman is speaking on a headset at her desk.', ['She is hanging a picture on the wall.', 'The computers are covered with cloth.', 'She is carrying the desk downstairs.']],
  ['공원', '관리인이 산책로 옆 화단에 물을 주고 있다.', 'A gardener is watering plants beside a walkway.', ['Visitors are crossing a bridge.', 'The path is covered with snow.', 'A fountain is being repaired indoors.']],
];
photoScenes.forEach(([title, visualDescription, correct, distractors], index) => {
  const stimulusId = addStimulus({ id: `p1-scene-${index + 1}`, kind: 'photo', title, visualDescription });
  addQuestion({ id: `p1-q${index + 1}`, part: 1, prompt: '장면을 가장 정확하게 설명한 문장을 고르세요.', correct, distractors, stimulusId, correctIndex: index % 4, explanation: `장면의 인물과 행동을 모두 직접 설명하는 문장은 “${correct}”입니다.`, skill: '현재진행형과 장면 묘사', difficulty: index < 2 ? 'foundation' : 'intermediate' });
});

const part2Items = [
  ['Where should I leave these packages?', 'On the counter by the door.', ['They arrived yesterday.', 'No, I did not order lunch.'], 'where는 장소를 묻기 때문에 문 옆 카운터라는 장소 응답이 맞습니다.'],
  ['When will the budget meeting begin?', 'At ten thirty.', ['In the main conference room.', 'The budget was approved.'], 'when은 시간을 묻기 때문에 시각을 말한 응답이 맞습니다.'],
  ['Who is leading the orientation today?', 'Ms. Patel from Human Resources.', ['It lasts about an hour.', 'In the training room.'], 'who는 사람을 묻습니다.'],
  ['Why was the shipment delayed?', 'There was a problem at the port.', ['By express delivery.', 'About twenty boxes.'], 'why에는 지연 원인을 설명해야 합니다.'],
  ['How often is the safety equipment inspected?', 'Once every three months.', ['The inspector is downstairs.', 'It is very reliable.'], 'how often은 빈도를 묻습니다.'],
  ['Could you send me the revised schedule?', 'Sure, I will e-mail it now.', ['The train was on time.', 'I revised the price.'], '요청에 대한 수락과 실행 응답이 자연스럽습니다.'],
  ['Haven’t we met at a trade show before?', 'Yes, in Singapore last year.', ['The show starts at noon.', 'I will introduce the speaker.'], '부정 의문문이어도 만난 사실을 확인하는 응답이 맞습니다.'],
  ['Which printer should I use?', 'The one next to the supply cabinet.', ['I printed fifty copies.', 'The paper is recyclable.'], 'which는 선택 대상을 묻습니다.'],
  ['Would you like tea or coffee?', 'Coffee, please.', ['Yes, I liked the café.', 'The cups are in the cabinet.'], '선택 의문문에는 제시된 항목 중 하나를 답합니다.'],
  ['The lobby renovation looks nearly finished.', 'Yes, only the lighting remains.', ['I finished the report yesterday.', 'The lobby is on the first floor.'], '평서문에 동의하며 남은 공사를 덧붙이는 응답이 자연스럽습니다.'],
  ['Do you know whether the client confirmed the order?', 'I’ll check the latest message.', ['The order form is blue.', 'We met the client downstairs.'], '확실히 모를 때 확인하겠다는 간접 응답이 적절합니다.'],
  ['Why don’t we move the display closer to the entrance?', 'That should attract more visitors.', ['The entrance fee is ten dollars.', 'I moved here last month.'], '제안의 기대 효과에 동의하는 응답입니다.'],
  ['How many applicants did you interview?', 'Six in total.', ['For the accounting position.', 'At the downtown office.'], 'how many는 수량을 묻습니다.'],
  ['Is the cafeteria still serving lunch?', 'No, it closed at two.', ['The soup was delicious.', 'I served on the committee.'], '영업 여부에 대한 직접 응답입니다.'],
  ['Where did you put the signed contract?', 'It’s in the top drawer.', ['The director signed it.', 'We renewed it for a year.'], 'where에 장소로 답했습니다.'],
  ['Should I reserve a small room or the auditorium?', 'The auditorium would be safer.', ['The reservation is under Lee.', 'The speech was interesting.'], '두 장소 중 하나를 선택하는 응답입니다.'],
  ['Can the maintenance team fix this today?', 'They are already on their way.', ['The fee is included.', 'I fixed the date on the form.'], '수리 가능 여부에 팀이 오고 있다는 간접 긍정 응답입니다.'],
  ['What did the survey participants receive?', 'A discount coupon.', ['Nearly two hundred people.', 'They completed it online.'], 'what은 받은 대상을 묻습니다.'],
  ['Didn’t Maria submit the proposal?', 'She asked for one more day.', ['The proposal has three sections.', 'Yes, Maria designed the logo.'], '제출하지 못한 사유를 간접적으로 설명합니다.'],
  ['How do I connect to the guest network?', 'Use the password on your badge.', ['The guests arrived early.', 'The network meeting was canceled.'], 'how는 방법을 묻습니다.'],
  ['When are the replacement parts expected?', 'Sometime on Thursday afternoon.', ['The machine needs three parts.', 'I replaced the batteries.'], '도착 예정 시점을 답했습니다.'],
  ['Who approved the new travel policy?', 'I believe the finance director did.', ['Travel takes about two hours.', 'The policy starts next month.'], '승인한 사람을 답했습니다.'],
  ['Would you mind lowering the volume?', 'Not at all—I’ll turn it down.', ['The volume is on the shelf.', 'I lowered the price yesterday.'], 'Would you mind 요청에는 수락 의사를 표현해야 합니다.'],
  ['Why is the west entrance locked?', 'It is being painted this morning.', ['Use the westbound platform.', 'I left my key at home.'], '출입구가 잠긴 이유를 설명합니다.'],
  ['Has the invoice been corrected yet?', 'Yes, the updated one is attached.', ['The invoice total is high.', 'I attached the poster to the wall.'], '완료 여부와 수정본 위치를 함께 답했습니다.'],
];
part2Items.forEach(([questionText, correct, distractors, explanation], index) => {
  const correctIndex = index % 3;
  const spokenChoices = rotatedChoices(correct, distractors, correctIndex);
  const labeledChoices = spokenChoices
    .map((choice, choiceIndex) => `${String.fromCharCode(65 + choiceIndex)}. ${choice}`)
    .join(' ');
  const stimulusId = addStimulus({
    id: `p2-audio-${index + 1}`,
    kind: 'questionResponse',
    title: `Question ${index + 1}`,
    audioScript: `${questionText} ${labeledChoices}`,
  });
  addQuestion({ id: `p2-q${index + 1}`, part: 2, prompt: '질문에 가장 알맞은 응답을 고르세요.', correct, distractors, stimulusId, correctIndex, explanation, skill: '의문사와 자연스러운 응답', difficulty: index < 8 ? 'foundation' : 'intermediate' });
});

const conversationTopics = [
  ['호텔 예약', 'Woman: Good morning. I booked a room for two nights, but my confirmation shows only one.\nMan: I can correct that. May I see your confirmation number?\nWoman: Certainly. It is H-4821. I also requested a room away from the elevator.', '호텔 예약 내용을 수정하려고', '예약 확인 번호', '객실 위치 요청을 확인한다'],
  ['제품 시연', 'Man: The client moved tomorrow’s product demonstration to three o’clock.\nWoman: Then we have time to test the new projector in the morning.\nMan: Good idea. I’ll also bring printed copies of the pricing sheet.', '제품 시연 준비를 논의하려고', '오전', '가격표를 인쇄해 가져간다'],
  ['배송 문의', 'Woman: My tracking page says the office chairs were delivered, but they are not here.\nMan: Let me contact the driver. The shipment may have been left at the loading entrance.\nWoman: Please ask the facilities team to check there as well.', '누락된 배송품을 찾으려고', '상하차 출입구', '운전기사에게 연락한다'],
  ['교육 일정', 'Man: Are you attending the spreadsheet workshop on Friday?\nWoman: I planned to, but my supervisor scheduled a client call at the same time.\nMan: The trainer is offering the workshop again next Tuesday.', '교육 참석 일정을 조정하려고', '고객 통화', '다음 화요일 교육에 참석한다'],
  ['식당 행사', 'Woman: We need a vegetarian option for the company dinner.\nMan: The chef can prepare mushroom pasta if we confirm the number by Wednesday.\nWoman: I’ll survey the staff this afternoon.', '회사 저녁 메뉴를 정하려고', '수요일', '직원에게 식단 선호를 조사한다'],
  ['인쇄 오류', 'Man: These brochures have the old telephone number on the back.\nWoman: I sent the printer a corrected file yesterday.\nMan: I’ll call them before they produce the remaining copies.', '브로슈어 인쇄 오류를 해결하려고', '전화번호', '인쇄업체에 전화한다'],
  ['공항 이동', 'Woman: Our flight leaves at eight, so the airport shuttle at six should work.\nMan: The hotel clerk said road construction may add thirty minutes.\nWoman: Then let’s take the five-thirty shuttle instead.', '공항 출발 시간을 정하려고', '도로 공사', '5시 30분 셔틀을 탄다'],
  ['채용 면접', 'Man: The first candidate has strong technical experience.\nWoman: Yes, but we should ask more about project leadership in the second interview.\nMan: I’ll add that topic to our interview notes.', '지원자 평가를 논의하려고', '프로젝트 리더십', '면접 노트에 질문을 추가한다'],
  ['전시 부스', 'Woman: Our booth is next to the main entrance this year.\nMan: That should bring more visitors, but we need another staff member during lunch.\nWoman: I’ll ask Daniel whether he can cover that hour.', '전시 부스 운영을 계획하려고', '점심시간 인력', 'Daniel에게 지원을 요청한다'],
  ['소프트웨어 갱신', 'Man: The accounting software license expires at the end of the month.\nWoman: The annual plan is cheaper than paying monthly.\nMan: I’ll send the annual-plan quote to the department head.', '소프트웨어 계약을 갱신하려고', '연간 요금제', '부서장에게 견적을 보낸다'],
  ['회의실 변경', 'Woman: The large conference room is unavailable because the air conditioner is being repaired.\nMan: Could we use the training room on the second floor?\nWoman: Yes, I’ll update the calendar invitation.', '회의 장소를 변경하려고', '에어컨 수리', '일정 초대를 수정한다'],
  ['재고 확인', 'Man: We have only twelve blue folders left.\nWoman: The supplier offers free shipping for orders over fifty units.\nMan: Let’s order sixty, since the new employees arrive next week.', '사무용품을 주문하려고', '60개', '신입 직원 도착에 대비한다'],
  ['고객 행사', 'Woman: Registration for Saturday’s customer event is higher than expected.\nMan: We should move the welcome desk into the lobby to reduce the line.\nWoman: I’ll ask security to open the side doors too.', '고객 행사 동선을 개선하려고', '등록 인원 증가', '보안팀에 측문 개방을 요청한다'],
];
conversationTopics.forEach(([title, transcript, purpose, detail, next], index) => {
  const stimulusId = addStimulus({ id: `p3-conversation-${index + 1}`, kind: 'conversation', title, audioScript: transcript });
  addQuestion({ id: `p3-q${index * 3 + 1}`, part: 3, prompt: '화자들이 대화하는 주된 목적은 무엇입니까?', correct: purpose, distractors: ['휴가 일정을 승인하려고', '신제품을 환불하려고', '직원 평가를 제출하려고'], stimulusId, correctIndex: index % 4, explanation: `대화 전체가 ${purpose} 관련된 정보와 다음 행동을 다룹니다.`, skill: '대화의 목적 파악' });
  addQuestion({ id: `p3-q${index * 3 + 2}`, part: 3, prompt: '대화에서 직접 언급된 핵심 정보는 무엇입니까?', correct: detail, distractors: ['분기 매출', '주차 요금', '웹사이트 비밀번호'], stimulusId, correctIndex: (index + 1) % 4, explanation: `대화에서 “${detail}”에 해당하는 내용이 직접 언급됩니다.`, skill: '세부 정보 듣기' });
  addQuestion({ id: `p3-q${index * 3 + 3}`, part: 3, prompt: '화자 중 한 명이 다음에 할 일은 무엇입니까?', correct: next, distractors: ['건물을 폐쇄한다', '계약을 취소한다', '해외 지사로 이동한다'], stimulusId, correctIndex: (index + 2) % 4, explanation: `마지막 발화에서 ${next}고 밝혔습니다.`, skill: '다음 행동 추론' });
});

const talkTopics = [
  ['도서관 안내', 'Attention, library visitors. The second-floor reading room will close at six today for carpet cleaning. The first-floor study area will remain open until nine. Please return reserved books at the service desk before leaving.', '도서관 시설 운영 변경', '2층 열람실', '예약 도서를 서비스 데스크에 반납한다'],
  ['항공편 안내', 'Passengers traveling on Flight 318 to Manila should proceed to Gate 22. Boarding will begin fifteen minutes later than scheduled while the aircraft is serviced. Passengers needing assistance may speak with the agent at the gate.', '항공편 탑승 안내', '15분', 'Gate 22로 이동한다'],
  ['상점 광고', 'This weekend only, Brookfield Home Store is offering twenty percent off all desk lamps. Customers who spend over one hundred dollars will also receive free delivery. Visit our Web site to check store hours.', '주말 할인 행사를 알리기 위해', '책상용 조명', '웹사이트에서 영업시간을 확인한다'],
  ['직원 교육', 'All new employees must complete the online security course by September 18. The course takes about forty minutes and can be accessed from the staff portal. Send completion questions to Ms. Rivera in Information Technology.', '보안 교육 이수를 안내하기 위해', '9월 18일', '직원 포털에서 강의를 연다'],
  ['박물관 투어', 'Welcome to the City Design Museum. Our guided tour begins in the glass gallery and lasts approximately one hour. Photography is permitted, but please do not use flash near the historic drawings.', '박물관 관람 규칙을 설명하기 위해', '유리 전시관', '플래시를 사용하지 않는다'],
  ['공장 안전', 'Before entering the production area, visitors must put on the safety glasses provided beside the door. Stay inside the yellow walking lanes and remain with your guide at all times.', '공장 방문 안전 수칙을 알리기 위해', '안전 안경', '노란 보행선 안에 머문다'],
  ['라디오 교통', 'Drivers should avoid King Street this morning because crews are repairing a water pipe. Buses will use Pine Avenue until the work is completed at approximately two o’clock.', '교통 우회 정보를 전하기 위해', '수도관 수리', 'Pine Avenue를 이용한다'],
  ['회의 개회사', 'Thank you for attending our quarterly sales meeting. First, Ms. Chen will review regional results. After a short break, we will discuss the product launch scheduled for November.', '분기 영업회의 순서를 소개하기 위해', '지역별 실적', '11월 제품 출시를 논의한다'],
  ['음성 메시지', 'Hello, this is Omar from Westside Repairs. The replacement motor for your copier arrived this morning. A technician can visit tomorrow between one and three. Please call us to confirm that time.', '복사기 수리 일정을 잡기 위해', '교체용 모터', '방문 시간을 확인해 전화한다'],
  ['호텔 조식', 'Breakfast is served in the Garden Room from six thirty to ten. Guests leaving before six thirty may request a boxed meal at the front desk by nine the previous evening.', '호텔 조식 이용법을 알리기 위해', 'Garden Room', '전날 밤 9시까지 도시락을 요청한다'],
];
talkTopics.forEach(([title, audioScript, purpose, detail, action], index) => {
  const stimulusId = addStimulus({ id: `p4-talk-${index + 1}`, kind: 'talk', title, audioScript });
  addQuestion({ id: `p4-q${index * 3 + 1}`, part: 4, prompt: '이 안내의 목적은 무엇입니까?', correct: purpose, distractors: ['직원 채용 결과를 발표하기 위해', '설문 참여를 요청하기 위해', '분실물을 찾기 위해'], stimulusId, correctIndex: index % 4, explanation: `첫 문장과 이어지는 세부 내용이 ${purpose}라는 목적을 뒷받침합니다.`, skill: '담화 목적 파악' });
  addQuestion({ id: `p4-q${index * 3 + 2}`, part: 4, prompt: '안내에서 언급된 것은 무엇입니까?', correct: detail, distractors: ['연회장 대관료', '직원 식사 쿠폰', '온라인 결제 오류'], stimulusId, correctIndex: (index + 1) % 4, explanation: `원문에서 “${detail}”에 관한 정보가 직접 나옵니다.`, skill: '핵심 세부 정보' });
  addQuestion({ id: `p4-q${index * 3 + 3}`, part: 4, prompt: '청자가 해야 할 일로 가장 알맞은 것은 무엇입니까?', correct: action, distractors: ['영수증을 폐기한다', '행사를 취소한다', '새 계정을 만든다'], stimulusId, correctIndex: (index + 2) % 4, explanation: `안내의 행동 지침은 ${action}는 것입니다.`, skill: '행동 지침 이해' });
});

const part5Items = [
  ['All expense reports must be submitted _____ Friday afternoon.', 'by', ['at', 'from', 'during'], '마감 시점 앞에는 전치사 by를 사용합니다.', '전치사'],
  ['The marketing team is looking for a designer who can work _____.', 'independently', ['independent', 'independence', 'independently of'], '동사 work를 수식하는 부사 independently가 필요합니다.', '품사'],
  ['Ms. Lopez will lead the meeting _____ the director is away.', 'while', ['despite', 'unless', 'because of'], '뒤에 완전한 절이 오며 두 상황이 동시에 이어지므로 while이 맞습니다.', '접속사'],
  ['The new software is much easier to use _____ the previous version.', 'than', ['as', 'from', 'then'], '비교급 easier 뒤에는 than을 사용합니다.', '비교급'],
  ['Please contact reception if you require any additional _____.', 'assistance', ['assist', 'assisted', 'assisting'], '형용사 additional 뒤 목적어 자리에는 명사 assistance가 필요합니다.', '품사'],
  ['The factory increased production _____ meet growing demand.', 'to', ['for', 'so', 'by'], '목적을 나타내는 to부정사가 필요합니다.', 'to부정사'],
  ['Neither the manager nor the assistants _____ available yesterday.', 'were', ['was', 'be', 'has been'], 'neither A nor B는 가까운 주어 assistants에 수를 맞춰 were를 씁니다.', '수일치'],
  ['Customers may exchange unopened items _____ thirty days.', 'within', ['between', 'throughout', 'beside'], '정해진 기간 안을 뜻하는 within이 맞습니다.', '전치사'],
  ['The board has not _____ approved the revised proposal.', 'yet', ['ever', 'already', 'still of'], '현재완료 부정문에서 아직을 뜻하는 yet이 자연스럽습니다.', '부사'],
  ['A confirmation e-mail will be sent _____ your payment is processed.', 'once', ['during', 'therefore', 'even'], '결제가 처리되는 즉시라는 시간 조건 접속사 once가 필요합니다.', '접속사'],
  ['The conference attracted _____ five hundred participants.', 'approximately', ['approximate', 'approximated', 'approximation'], '수량을 수식하는 부사 approximately가 맞습니다.', '품사'],
  ['Employees are encouraged _____ public transportation.', 'to use', ['use', 'using', 'used'], 'be encouraged to do 구조이므로 to use가 맞습니다.', '동사 패턴'],
  ['The warranty remains valid _____ the product is used as directed.', 'provided that', ['in spite of', 'due to', 'as if of'], '조건을 나타내며 뒤에 절이 오므로 provided that이 맞습니다.', '조건 접속사'],
  ['This quarter’s sales figures are _____ than analysts expected.', 'higher', ['high', 'highest', 'highly'], 'than과 함께 비교급 higher가 필요합니다.', '비교급'],
  ['We apologize for any inconvenience _____ by the maintenance work.', 'caused', ['causing', 'cause', 'causes'], 'inconvenience를 수식하는 과거분사 caused가 맞습니다.', '분사'],
  ['The committee will review each application _____.', 'carefully', ['careful', 'care', 'more careful'], '동사 review를 수식하는 부사가 필요합니다.', '품사'],
  ['No changes can be made after the contract has been _____.', 'signed', ['signing', 'signature', 'sign'], '수동태 has been 뒤에는 과거분사 signed가 필요합니다.', '수동태'],
  ['The museum is closed on Mondays, _____ national holidays.', 'except for', ['because', 'among', 'until'], '제외 대상을 나타내는 except for가 맞습니다.', '전치사 표현'],
  ['Ms. Tanaka is responsible for _____ supplier contracts.', 'negotiating', ['negotiate', 'negotiated', 'negotiation of the'], '전치사 for 뒤에는 동명사 negotiating이 자연스럽습니다.', '동명사'],
  ['The package should arrive _____, according to the courier.', 'tomorrow', ['recent', 'previous', 'daily of'], '문장 전체의 도착 시점을 나타내는 부사 tomorrow가 맞습니다.', '시간 부사'],
  ['Only applicants with relevant experience will be _____ for an interview.', 'considered', ['considering', 'consideration', 'consider'], '수동 의미이므로 be considered가 맞습니다.', '수동태'],
  ['Our latest model consumes _____ energy than its predecessor.', 'less', ['few', 'fewer', 'least of'], '셀 수 없는 energy의 비교급은 less입니다.', '수량 표현'],
  ['The restaurant expanded its seating area _____ customer demand.', 'in response to', ['on behalf', 'apart from', 'regardless'], '수요에 대응하여라는 뜻의 in response to가 맞습니다.', '어휘 표현'],
  ['Mr. Singh will speak with the vendor _____ the pricing issue.', 'about', ['among', 'along', 'toward of'], 'speak with 사람 about 주제 구조가 자연스럽습니다.', '전치사'],
  ['The report contains information that is highly _____.', 'confidential', ['confidence', 'confidentially', 'confide'], 'be동사 뒤 보어 자리에는 형용사 confidential이 필요합니다.', '품사'],
  ['Visitors must wear their identification badges at _____ times.', 'all', ['every', 'whole', 'each of'], '항상이라는 고정 표현 at all times가 맞습니다.', '관용 표현'],
  ['The renovation was completed ahead of _____.', 'schedule', ['scheduled', 'scheduling', 'schedules are'], '예정보다 일찍이라는 고정 표현 ahead of schedule입니다.', '관용 표현'],
  ['We will notify participants if the venue _____.', 'changes', ['will change', 'changing', 'has change'], '조건절에서는 미래 의미라도 현재형 changes를 사용합니다.', '조건절'],
  ['The technician found the device to be fully _____.', 'operational', ['operate', 'operation', 'operationally'], 'be 뒤 보어로 형용사 operational이 필요합니다.', '품사'],
  ['_____ receiving approval, the team began the installation.', 'After', ['Although', 'Because', 'Unless'], '동명사 receiving 앞에서 시간의 선후를 나타내는 After가 맞습니다.', '전치사·접속사'],
];
part5Items.forEach(([prompt, correct, distractors, explanation, skill], index) => addQuestion({ id: `p5-q${index + 1}`, part: 5, prompt, correct, distractors, correctIndex: index % 4, explanation, skill, difficulty: index < 10 ? 'foundation' : index < 24 ? 'intermediate' : 'advanced' }));

const part6Documents = [
  { title: '사내 공지', body: 'To: All Staff\nSubject: Bicycle Storage\nBeginning Monday, employees should use the new bicycle racks behind Building B. The racks are covered and are available on a first-come basis. [1] Employees should register their bicycle with Security. [2] A registration sticker will be issued at no charge. [3] Bicycles left near the front entrance may be moved. [4]', blanks: [
    ['Where are the new racks located?', 'Behind Building B', ['Inside the lobby', 'Next to the cafeteria', 'Under the parking garage'], '첫 두 문장에서 Building B 뒤라고 명시합니다.', '세부 정보'],
    ['Who should register a bicycle?', 'Employees who use the racks', ['Only security officers', 'Visitors attending meetings', 'Delivery drivers'], '자전거 보관대를 이용하는 직원에게 등록을 요구합니다.', '지시 대상'],
    ['How much does a sticker cost?', 'It is free.', ['Five dollars', 'A monthly fee', 'The notice does not say.'], 'at no charge는 무료라는 뜻입니다.', '동의 표현'],
    ['Which sentence best completes [4]?', 'Please remove personal items from bicycles before leaving them overnight.', ['The annual picnic was held last Friday.', 'Building B has twelve meeting rooms.', 'The cafeteria menu changes daily.'], '자전거 보관 지침과 이어지는 문장만 문맥상 적절합니다.', '문장 삽입'],
  ]},
  { title: '고객 이메일', body: 'Dear Ms. Park,\nThank you for ordering the Luma desk chair. [1] Your order will leave our warehouse on June 12. [2] Delivery normally takes three business days. [3] We will send a tracking link as soon as the carrier collects the package. [4]\nSincerely,\nNorthline Furnishings', blanks: [
    ['What product was ordered?', 'A desk chair', ['A lamp', 'A bookshelf', 'A conference table'], '첫 문단에 Luma desk chair라고 나옵니다.', '세부 정보'],
    ['When will the order leave the warehouse?', 'June 12', ['June 3', 'June 15', 'July 12'], '둘째 문장에서 출고일을 명시합니다.', '날짜 파악'],
    ['What will the customer receive later?', 'A tracking link', ['A store coupon', 'An assembly video', 'A new invoice'], '운송사가 수거하면 tracking link를 보낸다고 했습니다.', '후속 조치'],
    ['Which sentence best fits at [1]?', 'We are pleased to confirm that the item is now ready for shipment.', ['Our showroom closes at six on Sundays.', 'The chair was designed by an architect.', 'Please apply for the vacant position online.'], '주문 감사와 출고 일정 사이에는 출고 준비 완료 확인이 가장 자연스럽습니다.', '문장 삽입'],
  ]},
  { title: '시설 안내', body: 'The Westbrook Fitness Center pool will be unavailable from August 2 through August 5 for routine maintenance. [1] During this period, members may use the pool at our Eastside location by showing their membership card. [2] Swimming classes scheduled for those dates will be moved to the following week. [3] Contact the front desk if you need to change a class reservation. [4]', blanks: [
    ['Why will the pool close?', 'For routine maintenance', ['For a private event', 'Because of bad weather', 'To train new staff'], '첫 문장에서 정기 유지보수가 이유라고 밝힙니다.', '원인 파악'],
    ['What must members show at Eastside?', 'A membership card', ['A receipt', 'A class schedule', 'A photo application'], 'Eastside 수영장 이용 시 membership card를 제시해야 합니다.', '조건 파악'],
    ['What will happen to swimming classes?', 'They will be held the following week.', ['They will move outdoors.', 'They will become free.', 'They will be canceled permanently.'], '해당 수업은 다음 주로 옮겨집니다.', '일정 변경'],
    ['Which sentence best fits at [2]?', 'The Eastside pool is open from seven in the morning until eight in the evening.', ['Membership fees increased last year.', 'The parking lot was recently painted.', 'A new instructor wrote a book.'], '대체 수영장 이용 안내 뒤에는 영업시간 정보가 자연스럽습니다.', '문장 삽입'],
  ]},
  { title: '프로젝트 메모', body: 'The Web site redesign team will present its first prototype on October 6. [1] Before the presentation, each department should review the draft pages shared in the project folder. [2] Comments must be added by October 3 so the design team has time to make revisions. [3] Department heads will receive a calendar invitation this afternoon. [4]', blanks: [
    ['What will be presented?', 'A Web site prototype', ['A hiring policy', 'A sales contract', 'A building plan'], '첫 문장에 Web site redesign의 first prototype이라고 나옵니다.', '주제 파악'],
    ['Where can departments find the draft pages?', 'In the project folder', ['On a public poster', 'At the reception desk', 'In a printed handbook'], 'project folder에 공유했다고 명시합니다.', '위치 파악'],
    ['Why are comments due by October 3?', 'To allow time for revisions', ['To reserve a meeting room', 'To calculate travel costs', 'To order new computers'], '디자인 팀의 수정 시간을 확보하기 위해서입니다.', '목적 파악'],
    ['Which sentence best fits at [4]?', 'Please accept the invitation to confirm your attendance.', ['The cafeteria serves breakfast every day.', 'Several employees commute by train.', 'Office chairs are available in three colors.'], '캘린더 초대 안내 다음에는 참석 확인 요청이 자연스럽습니다.', '문장 삽입'],
  ]},
];
part6Documents.forEach((document, documentIndex) => {
  const stimulusId = addStimulus({ id: `p6-document-${documentIndex + 1}`, kind: 'document', title: document.title, body: document.body });
  document.blanks.forEach(([prompt, correct, distractors, explanation, skill], questionIndex) => addQuestion({ id: `p6-q${documentIndex * 4 + questionIndex + 1}`, part: 6, prompt, correct, distractors, correctIndex: (documentIndex + questionIndex) % 4, explanation, skill, stimulusId, difficulty: documentIndex < 2 ? 'intermediate' : 'advanced' }));
});

const singlePassages = [
  ['회의실 예약', 'Room 4A will be unavailable on Tuesday morning while new video equipment is installed. Meetings already scheduled there have been moved to Room 3C. The online calendar has been updated.', '회의실 변경을 알리기 위해', '새 영상 장비 설치', '온라인 일정에서 새 장소를 확인할 수 있다'],
  ['채용 공고', 'Riverton Foods seeks a purchasing assistant with two years of office experience. Applicants should submit a résumé and cover letter by May 8. Knowledge of inventory software is preferred but not required.', '구매 보조 직원을 채용하기 위해', '2년의 사무 경험', '재고 프로그램 경험은 필수가 아니다'],
  ['공연 안내', 'The Lakeside Theater performance on Saturday will begin at 7:30 P.M. Doors open forty-five minutes earlier. Tickets may be collected at the box office with photo identification.', '공연 관람 정보를 제공하기 위해', '사진이 있는 신분증', '입장은 공연 45분 전에 시작된다'],
  ['환불 정책', 'Unopened electronics may be returned within fourteen days with the original receipt. Opened software and personalized products cannot be returned. Refunds are issued to the original payment method.', '상품 반품 조건을 설명하기 위해', '원본 영수증', '개인 맞춤 상품은 반품할 수 없다'],
  ['배송 메시지', 'Your order 7742 is scheduled for delivery on Wednesday between 1 and 4 P.M. Someone must be present to sign for the package. To change the date, use the link below before noon on Tuesday.', '배송 일정을 알려 주기 위해', '수령 서명', '화요일 정오 전에 날짜를 바꿔야 한다'],
  ['강좌 소개', 'The introductory photography course meets on four consecutive Thursdays. Participants should bring a camera to the first class. Editing software will be provided in the computer lab.', '사진 강좌 준비물을 안내하기 위해', '카메라', '편집 프로그램은 실습실에서 제공된다'],
  ['식당 공지', 'Harbor Café will open one hour later than usual on Monday because of a staff meeting. Online breakfast orders placed before eight will be available for pickup at the side window.', '월요일 영업시간 변경을 알리기 위해', '직원 회의', '온라인 주문은 측면 창구에서 찾는다'],
  ['박람회 초대', 'Register by March 20 for free admission to the Green Building Expo. Workshops require separate reservations because seating is limited. A complete schedule is available on the event Web site.', '건축 박람회 등록을 권하기 위해', '워크숍 별도 예약', '좌석 수가 제한되어 있다'],
  ['서비스 보고', 'A technician inspected the elevator in Building C this morning. No mechanical fault was found, but the door sensor was cleaned and tested. Normal service resumed at 11:15.', '승강기 점검 결과를 보고하기 위해', '문 센서', '기계적 결함은 발견되지 않았다'],
  ['회원 갱신', 'Your museum membership expires on December 31. Renew online by December 15 to receive two complimentary guest passes. New cards will be mailed within five business days.', '박물관 회원권 갱신을 안내하기 위해', '무료 동반 입장권 두 장', '새 카드는 우편으로 발송된다'],
];
singlePassages.forEach(([title, body, purpose, detail, inference], index) => {
  const stimulusId = addStimulus({ id: `p7-single-${index + 1}`, kind: 'document', title, body });
  addQuestion({ id: `p7-s${index + 1}-q1`, part: 7, prompt: '이 글의 주된 목적은 무엇입니까?', correct: purpose, distractors: ['설문 결과를 비교하기 위해', '직원의 승진을 축하하기 위해', '분실물의 주인을 찾기 위해'], correctIndex: index % 4, explanation: `글 전체가 ${purpose} 필요한 내용을 제공합니다.`, skill: '글의 목적', stimulusId });
  addQuestion({ id: `p7-s${index + 1}-q2`, part: 7, prompt: '글에서 직접 언급된 것은 무엇입니까?', correct: detail, distractors: ['무료 주차권', '해외 배송료', '전화 면접'], correctIndex: (index + 1) % 4, explanation: `본문에 “${detail}”에 해당하는 표현이 직접 나옵니다.`, skill: '세부 정보', stimulusId });
  if (index < 9) addQuestion({ id: `p7-s${index + 1}-q3`, part: 7, prompt: '글을 통해 알 수 있는 것은 무엇입니까?', correct: inference, distractors: ['모든 서비스가 영구 중단된다', '독자는 반드시 현금을 내야 한다', '행사는 해외에서만 열린다'], correctIndex: (index + 2) % 4, explanation: `본문의 조건과 일정을 종합하면 ${inference}는 것을 알 수 있습니다.`, skill: '추론', stimulusId, difficulty: 'advanced' });
});

const multiplePassages = [
  ['교육 신청', 'E-mail from Training Office:\nThe presentation workshop on July 9 is full. A second session has been added on July 16 from 2 to 5 P.M. Register through the staff portal.\n\nReply from Mina:\nPlease enroll me in the July 16 session. I will be meeting a supplier on July 9, and the later date works better.', '발표 워크숍 일정 변경', '7월 16일', '직원 포털', '공급업체와 회의가 있어서', 'Mina는 추가 회차에 참석하려 한다'],
  ['호텔과 교통', 'Hotel notice:\nThe airport shuttle departs every hour from 6 A.M. to 10 P.M. Reservations are required after 8 P.M.\n\nGuest message:\nMy flight lands at 8:20 P.M. on Friday. Please reserve a seat for me on the 9 P.M. shuttle.', '공항 셔틀 이용', '오후 9시', '오후 8시 이후 예약 필요', '비행기가 8시 20분에 도착해서', '투숙객은 늦은 셔틀을 예약했다'],
  ['주문과 재고', 'Supplier e-mail:\nThe gray filing cabinets are temporarily out of stock. Black cabinets can ship immediately, or gray units will be available next month.\n\nBuyer reply:\nPlease send six black cabinets now. Our records room opens in two weeks, so we cannot wait until next month.', '캐비닛 주문 변경', '검은색 6개', '회색 제품 품절', '기록실이 2주 후 열려서', '구매자는 빠른 배송을 우선했다'],
  ['행사와 날씨', 'Event notice:\nThe outdoor concert is planned for Riverside Park at 7 P.M. In case of heavy rain, it will move to Central Hall.\n\nWeather alert:\nHeavy rain is expected after 5 P.M. today. Travelers should allow extra time because several roads may close.', '콘서트 장소 변경 가능성', 'Central Hall', '폭우 예보', '일부 도로가 닫힐 수 있어서', '행사는 실내에서 열릴 가능성이 높다'],
  ['수리와 청구', 'Repair invoice:\nLaptop screen replacement: $180\nExpress service: $25\nTotal: $205\n\nCustomer e-mail:\nThank you for finishing the repair today. The invoice includes express service, but I requested standard three-day service. Please review the charge before I pay.', '수리 청구 금액 문의', '$205', '특급 서비스 비용', '일반 서비스를 요청했기 때문에', '청구서 수정이 필요할 수 있다'],
];
multiplePassages.forEach(([title, body, purpose, detail, evidence, reason, inference], index) => {
  const stimulusId = addStimulus({ id: `p7-multiple-${index + 1}`, kind: 'document', title, body });
  const rows = [
    ['두 문서는 주로 무엇에 관한 것입니까?', purpose, ['직원 건강검진', '신제품 광고', '사무실 이전'], '두 문서의 공통 주제입니다.', '복수 지문 주제'],
    ['두 문서에서 확인할 수 있는 정보는 무엇입니까?', detail, ['12월 1일', '무료 점심', '온라인 면접'], '두 문서의 일정·수량·금액 정보를 연결하면 확인할 수 있습니다.', '정보 연결'],
    ['첫 번째 문서에서 중요한 조건은 무엇입니까?', evidence, ['신분증 재발급', '해외 송금', '주차장 폐쇄'], '첫 번째 문서가 제시한 조건 또는 변경 사항입니다.', '첫 지문 세부 정보'],
    ['두 번째 문서의 작성자가 결정을 내린 이유는 무엇입니까?', reason, ['휴가를 떠나기 때문에', '가격이 무료이기 때문에', '관리자가 퇴사했기 때문에'], '두 번째 문서에서 이유를 직접 설명합니다.', '이유 파악'],
    ['두 문서를 종합해 알 수 있는 것은 무엇입니까?', inference, ['모든 예약이 취소됐다', '작성자가 답장을 받지 못했다', '서비스가 영구 종료됐다'], '두 문서의 시간·조건·요청을 함께 보면 가능한 결론입니다.', '복수 지문 추론'],
  ];
  rows.forEach(([prompt, correct, distractors, explanation, skill], questionIndex) => addQuestion({ id: `p7-m${index + 1}-q${questionIndex + 1}`, part: 7, prompt, correct, distractors, correctIndex: (index + questionIndex) % 4, explanation: `${explanation} 따라서 “${correct}”이 정답입니다.`, skill, stimulusId, difficulty: questionIndex >= 3 ? 'advanced' : 'intermediate' }));
});

const expectedCounts = new Map([[1, 6], [2, 25], [3, 39], [4, 30], [5, 30], [6, 16], [7, 54]]);
for (const [part, expected] of expectedCounts) {
  const actual = questions.filter((question) => question.part === part).length;
  if (actual !== expected) throw new Error(`Part ${part}: expected ${expected}, got ${actual}`);
}

const pack = {
  schemaVersion: 1,
  id: 'sprache-business-english-practice-1',
  title: '비즈니스 영어 실전 문제팩 1',
  description: 'Part 1~7 구성의 독자 제작 200문제와 정답 근거·선택지 풀이를 제공합니다.',
  language: 'en',
  version: '1.0.0',
  revision: 1,
  publishedAt: '2026-09-03T03:00:00.000Z',
  license: 'Sprache-original-practice-content',
  attribution: 'Original questions authored for the Sprache project; format references ETS public test descriptions only.',
  disclaimer: 'TOEIC® is a registered trademark of ETS. This product is not endorsed or approved by ETS. 공식 또는 기출문제를 포함하지 않습니다.',
  stimuli,
  questions,
};
const packText = `${JSON.stringify(pack, null, 2)}\n`;
const packBytes = Buffer.from(packText, 'utf8');
const catalog = {
  schemaVersion: 1,
  updatedAt: '2026-09-03T03:00:00.000Z',
  packs: [{
    id: pack.id,
    title: pack.title,
    description: pack.description,
    language: 'en',
    version: pack.version,
    revision: pack.revision,
    questionCount: questions.length,
    sizeBytes: packBytes.length,
    sha256: createHash('sha256').update(packBytes).digest('hex'),
    path: `packs/${path.basename(outputPath)}`,
    license: pack.license,
    attribution: pack.attribution,
  }],
};
const catalogText = `${JSON.stringify(catalog, null, 2)}\n`;

if (check) {
  const [existingPack, existingCatalog] = await Promise.all([
    readFile(outputPath, 'utf8'),
    readFile(catalogPath, 'utf8'),
  ]);
  if (existingPack !== packText || existingCatalog !== catalogText) {
    throw new Error('Exam pack output is stale. Run node tool/build-exam-pack.mjs.');
  }
} else {
  await mkdir(outputDirectory, { recursive: true });
  await Promise.all([
    writeFile(outputPath, packText, 'utf8'),
    writeFile(catalogPath, catalogText, 'utf8'),
  ]);
}

process.stdout.write(`exam pack: ${questions.length} questions, ${stimuli.length} stimuli, ${packBytes.length} bytes\n`);
